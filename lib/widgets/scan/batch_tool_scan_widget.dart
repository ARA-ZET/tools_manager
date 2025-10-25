import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/mallon_theme.dart';
import '../../models/staff.dart';
import '../../models/tool.dart';
import '../../models/consumable.dart';
import '../../providers/tools_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/consumables_provider.dart';
import '../../services/consumable_transaction_service.dart';
import '../universal_scanner.dart';
import 'tool_scan_dialogs.dart';
import 'tool_transaction_handler.dart';

/// Widget for batch tool scanning mode
/// Allows scanning multiple tools and performing batch operations
class BatchToolScanWidget extends StatefulWidget {
  final Staff? currentStaff;

  const BatchToolScanWidget({super.key, required this.currentStaff});

  @override
  State<BatchToolScanWidget> createState() => _BatchToolScanWidgetState();
}

class _BatchToolScanWidgetState extends State<BatchToolScanWidget> {
  final TextEditingController _batchSearchController = TextEditingController();
  bool _isDialogShowing = false;
  String? _lastScannedId;
  String? _lastScannedType;
  bool _isProcessing = false;

  @override
  void dispose() {
    _batchSearchController.dispose();
    super.dispose();
  }

  /// Update scan feedback UI
  void _updateScanFeedback(String id, String type, bool processing) {
    if (mounted) {
      setState(() {
        _lastScannedId = id;
        _lastScannedType = type;
        _isProcessing = processing;
      });
    }
  }

  /// Clear scan feedback UI
  void _clearScanFeedback() {
    if (mounted) {
      setState(() {
        _lastScannedId = null;
        _lastScannedType = null;
        _isProcessing = false;
      });
    }
  }

  /// Handle scanned item in batch mode
  void _handleScannedItem(ScannedItem scannedItem) async {
    debugPrint(
      '🔍 Batch mode - Scanned: ${scannedItem.typeLabel} ${scannedItem.id}',
    );

    // Prevent multiple dialogs
    if (_isDialogShowing) {
      debugPrint('🚫 Dialog already showing - ignoring scan');
      return;
    }

    final scanProvider = context.read<ScanProvider>();

    // Check if already processing
    if (scanProvider.isProcessing) {
      debugPrint('🚫 Already processing a scan - ignoring');
      return;
    }

    // Handle based on item type
    if (scannedItem.type == ScannedItemType.tool) {
      final tool = scannedItem.item as Tool;
      // Update UI feedback
      _updateScanFeedback(scannedItem.id, 'Tool', true);
      _handleScannedCode(tool.qrPayload);
    } else if (scannedItem.type == ScannedItemType.consumable) {
      final consumable = scannedItem.item as Consumable;

      // Update UI feedback
      _updateScanFeedback(
        scannedItem.id,
        'Consumable: ${consumable.name}',
        true,
      );

      // For consumables in batch mode, show quantity dialog
      _isDialogShowing = true;

      if (!mounted) {
        _isDialogShowing = false;
        _clearScanFeedback();
        return;
      }

      debugPrint(
        '🔍 Batch mode - showing quantity dialog for ${consumable.name}',
      );

      final scanProvider = context.read<ScanProvider>();

      // Determine action based on batch type
      // If batch is checkin, treat consumable as restock (adding back to stock)
      // If batch is checkout or not set, treat as usage (removing from stock)
      bool isRestock = scanProvider.batchType == BatchType.checkin;

      // If no batch type set yet and this is first item, default to usage
      if (!scanProvider.isBatchTypeSet) {
        scanProvider.setBatchType(BatchType.consumable_usage);
      }

      // Show quantity dialog with appropriate context
      final quantity = await _showConsumableQuantityDialog(
        consumable,
        isRestock: isRestock,
      );

      if (quantity != null && quantity > 0) {
        // Add to batch with quantity
        scanProvider.addConsumableToBatch(
          consumable.uniqueId,
          quantity: quantity,
        );

        // Show success feedback with appropriate message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRestock
                    ? '✓ ${consumable.name} ($quantity ${consumable.unit.name}) added to restock batch'
                    : '✓ ${consumable.name} ($quantity ${consumable.unit.name}) added to batch',
              ),
              backgroundColor: MallonColors.primaryGreen,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // User cancelled or entered 0
        debugPrint('❌ User cancelled quantity dialog or entered 0');
      }

      if (!mounted) {
        _isDialogShowing = false;
        _clearScanFeedback();
        return;
      }

      // Clear feedback and reset flag
      _clearScanFeedback();
      _isDialogShowing = false;

      debugPrint(
        '✅ Batch mode - ready for new scan after consumable processed',
      );
    } else {
      // Unknown item type - show in UI
      _updateScanFeedback(scannedItem.id, 'Unknown', false);
      await Future.delayed(const Duration(seconds: 2));
      _clearScanFeedback();
    }
  }

  /// Handle scanned code in batch mode (for tools)
  void _handleScannedCode(String code) async {
    debugPrint('🔍 Batch mode - Scanned code: $code');

    // Prevent multiple dialogs
    if (_isDialogShowing) {
      debugPrint('🚫 Dialog already showing - ignoring scan');
      return;
    }

    final scanProvider = context.read<ScanProvider>();

    // Check if already processing
    if (scanProvider.isProcessing) {
      debugPrint('🚫 Already processing a scan - ignoring');
      return;
    }

    // Handle the scanned code and check if it was processed
    final wasProcessed = await scanProvider.handleScannedCode(code);

    if (!wasProcessed) {
      debugPrint('🚫 Scan was debounced or ignored - stopping here');
      return;
    }

    // Handle batch mode validation and dialogs
    await _handleBatchModeResult(code, wasProcessed);
  }

  /// Handle batch mode scan results and show appropriate dialogs
  Future<void> _handleBatchModeResult(String code, bool wasProcessed) async {
    debugPrint(
      '🎯 _handleBatchModeResult called with code: $code, wasProcessed: $wasProcessed',
    );

    // Extract tool ID from code
    String toolId = code;
    if (code.startsWith('TOOL#')) {
      toolId = code.substring(5);
    }

    // Get tools provider to check if tool exists
    final toolsProvider = context.read<ToolsProvider>();
    // Use real-time cached data - automatically updated via Firestore subscription
    final tool = toolsProvider.getToolWithLatestStatus(toolId);
    final scanProvider = context.read<ScanProvider>();

    debugPrint(
      '🔍 Tool lookup for $toolId: ${tool != null ? "Found ${tool.displayName} [Status: ${tool.status}]" : "Not found"}',
    );
    debugPrint('📊 Current batch tools: ${scanProvider.scannedTools}');
    debugPrint('🔄 Real-time data: Tool status from Firestore subscription');

    if (tool == null) {
      // Tool doesn't exist in database
      debugPrint(
        '❌ Tool $toolId not found in real-time cache - showing not found dialog',
      );
      _isDialogShowing = true;
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (context) => ToolNotFoundDialog(toolId: toolId),
      );
      _isDialogShowing = false;
      _clearScanFeedback(); // Clear processing state after dialog closes
      return;
    }

    // Check if tool is already in batch
    if (scanProvider.scannedTools.contains(toolId)) {
      debugPrint(
        '⚠️ Tool $toolId already in batch - showing already added dialog',
      );
      _isDialogShowing = true;
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (context) => ToolAlreadyInBatchDialog(toolId: toolId),
      );
      _isDialogShowing = false;
      _clearScanFeedback(); // Clear processing state after dialog closes
      return;
    }

    // Determine if this tool can be added based on batch type
    // If batch type is not set, this is the first tool - always allow
    // If batch type is set, check if tool status matches batch type
    bool canAdd = true;
    String? rejectionReason;

    debugPrint('📋 Batch validation:');
    debugPrint('  - Batch type set: ${scanProvider.isBatchTypeSet}');
    debugPrint('  - Current batch type: ${scanProvider.batchType}');
    debugPrint('  - Tool ${tool.uniqueId}:');
    debugPrint('    * status: ${tool.status}');
    debugPrint('    * isAvailable: ${tool.isAvailable}');
    debugPrint('    * currentHolder: ${tool.currentHolder?.id ?? "none"}');

    if (scanProvider.isBatchTypeSet) {
      // Batch type already determined by first tool
      canAdd = scanProvider.canAddToBatch(tool.isAvailable);

      debugPrint('  - canAddToBatch result: $canAdd');

      if (!canAdd) {
        final batchTypeStr = scanProvider.batchType == BatchType.checkout
            ? 'checkout (available tools only)'
            : 'checkin (checked out tools only)';

        rejectionReason =
            'This batch is for $batchTypeStr.\n\n'
            'Tool: ${tool.displayName}\n'
            'Status: ${tool.isAvailable ? "Available" : "Checked Out"}';
      }
    }
    // If batch type not set, this is first tool - always allow

    if (!canAdd && rejectionReason != null) {
      // Tool doesn't match established batch type - show error
      debugPrint(
        '🚫 Tool ${tool.displayName} rejected: Status is ${tool.status}, batch type is ${scanProvider.batchType}',
      );
      _isDialogShowing = true;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Mix Batch Types'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rejectionReason!, style: TextStyle(fontSize: 14)),
              SizedBox(height: 12),
              Text(
                tool.isAvailable
                    ? 'This tool is available and cannot be added to a check-in batch.'
                    : 'This tool is checked out and cannot be added to a checkout batch.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      _isDialogShowing = false;
      _clearScanFeedback();
      return;
    }

    // Tool exists, not in batch, and matches batch type - show confirmation dialog
    debugPrint('✅ Tool $toolId is valid and new - showing add dialog');
    _isDialogShowing = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (context) => AddToBatchConfirmationDialog(
        tool: tool,
        isBatchTypeSet: scanProvider.isBatchTypeSet,
        batchTypeLabel: scanProvider.batchType?.name,
      ),
    );
    _isDialogShowing = false;
    _clearScanFeedback(); // Clear processing state after dialog closes

    // If user confirmed, add to batch
    if (confirmed == true && mounted) {
      // Set batch type based on first tool
      if (!scanProvider.isBatchTypeSet) {
        final batchType = tool.isAvailable
            ? BatchType.checkout
            : BatchType.checkin;
        debugPrint(
          '🎯 Setting batch type: $batchType (first tool: ${tool.uniqueId}, isAvailable: ${tool.isAvailable})',
        );
        scanProvider.setBatchType(batchType);
      }

      debugPrint(
        '✅ Adding tool ${tool.uniqueId} to batch (current batch type: ${scanProvider.batchType})',
      );
      scanProvider.addToBatch(tool.uniqueId);
      // Success feedback shown in camera overlay
    } else {
      // User cancelled or dismissed - ready for next scan
      debugPrint('✅ Dialog dismissed - ready for next scan');
    }
  }

  /// Add tool to batch from manual search
  void _addToolToBatch(String input) async {
    final toolsProvider = context.read<ToolsProvider>();

    // Try exact match by unique ID first
    Tool? exactMatch = toolsProvider.getToolByUniqueId(input.trim());

    // If no exact match, try searching by name/brand
    if (exactMatch == null) {
      final searchResults = toolsProvider.searchTools(input.trim());
      exactMatch = searchResults.isNotEmpty ? searchResults.first : null;
    }

    if (exactMatch != null) {
      // Use the same validation flow as scanning
      await _handleBatchModeResult(exactMatch.uniqueId, true);
    } else {
      // Show tool not found dialog
      _isDialogShowing = true;
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (context) => ToolNotFoundDialog(toolId: input.trim()),
      );
      _isDialogShowing = false;
    }

    // Clear the search field
    _batchSearchController.clear();
  }

  /// Remove tool or consumable from batch
  void _removeBatchTool(String itemId) {
    final scanProvider = context.read<ScanProvider>();
    // Try to remove as tool first
    if (scanProvider.scannedTools.contains(itemId)) {
      scanProvider.removeFromBatch(itemId);
    } else {
      // Remove as consumable
      scanProvider.removeConsumableFromBatch(itemId);
    }
    // Removal feedback shown in batch list UI
  }

  /// Show dialog to enter quantity for consumable
  Future<double?> _showConsumableQuantityDialog(
    Consumable consumable, {
    bool isRestock = false,
  }) async {
    final TextEditingController quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isRestock ? Icons.add_circle : Icons.inventory_2,
              color: MallonColors.primaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRestock ? 'Restock Quantity' : 'Enter Quantity',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                consumable.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Stock: ${consumable.currentQuantity} ${consumable.unit.name}',
                style: TextStyle(
                  color: consumable.currentQuantity <= consumable.minQuantity
                      ? MallonColors.error
                      : MallonColors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isRestock
                      ? 'Quantity to add back'
                      : 'Quantity to assign',
                  suffixText: consumable.unit.name,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(isRestock ? Icons.add : Icons.numbers),
                  helperText: isRestock ? 'Returning items to stock' : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid number greater than 0';
                  }
                  // Only validate against available stock for usage (not restock)
                  if (!isRestock && quantity > consumable.currentQuantity) {
                    return 'Not enough stock (${consumable.currentQuantity} available)';
                  }
                  return null;
                },
                onFieldSubmitted: (value) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(double.tryParse(value));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final quantity = double.tryParse(quantityController.text);
                Navigator.of(context).pop(quantity);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(isRestock ? 'Add to Restock' : 'Add to Batch'),
          ),
        ],
      ),
    );
  }

  /// Show batch submit dialog with checkout/checkin options
  void _showBatchSubmitDialog() {
    final scanProvider = context.read<ScanProvider>();

    final hasTools = scanProvider.scannedTools.isNotEmpty;
    final hasConsumables = scanProvider.scannedConsumables.isNotEmpty;

    // If only consumables, show consumable dialog
    if (hasConsumables && !hasTools) {
      _showConsumableBatchDialog();
      return;
    }

    // If only tools or mixed batch, show combined dialog
    final toolsProvider = context.read<ToolsProvider>();

    // Check how many tools are available vs checked out using real-time data
    int availableCount = 0;
    int checkedOutCount = 0;

    debugPrint('📋 Checking batch status using real-time Firestore data...');
    for (final toolId in scanProvider.scannedTools) {
      // Use real-time cached status
      final tool = toolsProvider.getToolWithLatestStatus(toolId);
      if (tool != null) {
        if (tool.isAvailable) {
          availableCount++;
          debugPrint('  ✅ $toolId: Available (can checkout)');
        } else {
          checkedOutCount++;
          debugPrint('  🔒 $toolId: Checked out (can checkin)');
        }
      } else {
        debugPrint('  ⚠️ $toolId: Not found in real-time cache');
      }
    }

    showDialog(
      context: context,
      builder: (context) => _BatchSubmitDialog(
        toolCount: scanProvider.scannedTools.length,
        consumableCount: scanProvider.scannedConsumables.length,
        availableCount: availableCount,
        checkedOutCount: checkedOutCount,
        toolIds: scanProvider.scannedTools,
        onCheckOut: _handleBatchCheckOut,
        onCheckIn: _handleBatchCheckIn,
        onMixedBatch: hasConsumables ? _handleMixedBatch : null,
      ),
    );
  }

  /// Show consumable batch dialog for staff assignment
  void _showConsumableBatchDialog() async {
    final scanProvider = context.read<ScanProvider>();
    final staffProvider = context.read<StaffProvider>();

    // Get active staff list
    final allStaff = staffProvider.allStaff.where((s) => s.isActive).toList();

    if (allStaff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active staff members found'),
          backgroundColor: MallonColors.error,
        ),
      );
      return;
    }

    // Show staff selection dialog
    final selectedStaff = await showDialog<Staff>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: MallonColors.primaryGreen),
            const SizedBox(width: 8),
            const Text('Assign Consumables'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${scanProvider.scannedConsumables.length} consumable(s) to assign',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Select staff member to assign to:'),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: allStaff.map((staff) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: MallonColors.primaryGreen,
                        child: Text(
                          staff.fullName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(staff.fullName),
                      subtitle: Text(staff.jobCode),
                      onTap: () => Navigator.of(context).pop(staff),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedStaff != null) {
      await _handleBatchConsumableAssignment(selectedStaff);
    }
  }

  /// Handle batch consumable assignment (usage or restock based on batch type)
  Future<void> _handleBatchConsumableAssignment(
    Staff assignedTo, {
    String? batchId,
    bool skipClearAndMessage = false,
  }) async {
    final scanProvider = context.read<ScanProvider>();
    final consumablesProvider = context.read<ConsumablesProvider>();
    final transactionService = ConsumableTransactionService();

    // Generate unique batch ID if not provided (for mixed batches)
    final actualBatchId =
        batchId ?? 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

    // Determine if this is a restock (checkin batch) or usage
    final isRestock = scanProvider.batchType == BatchType.checkin;

    try {
      if (!skipClearAndMessage) {
        setState(() => _isProcessing = true);
      }

      int successCount = 0;
      int failCount = 0;

      // Process each consumable
      for (final consumableId in scanProvider.scannedConsumableIds) {
        final quantity = scanProvider.getConsumableQuantity(consumableId);
        final consumable = consumablesProvider.getConsumableByUniqueId(
          consumableId,
        );

        if (consumable == null || quantity == null) {
          failCount++;
          continue;
        }

        try {
          if (isRestock) {
            // Restock - add back to inventory (return from staff)
            await transactionService.recordRestock(
              consumableId: consumable.id,
              quantity: quantity,
              restockedBy: widget.currentStaff!.uid,
              notes:
                  'Batch return/restock (Batch ID: $actualBatchId) - Returned by ${assignedTo.fullName}',
            );

            // Update quantity (add back)
            final newQuantity = consumable.currentQuantity + quantity;
            await consumablesProvider.updateConsumable(consumable.id, {
              'currentQuantity': newQuantity,
            });
          } else {
            // Usage - assign/remove from inventory
            await transactionService.recordUsage(
              consumableId: consumable.id,
              quantity: quantity,
              usedBy: widget.currentStaff!.uid,
              assignedTo: assignedTo.uid,
              notes: 'Batch assignment (Batch ID: $actualBatchId)',
            );

            // Update quantity (subtract)
            final newQuantity = consumable.currentQuantity - quantity;
            await consumablesProvider.updateConsumable(consumable.id, {
              'currentQuantity': newQuantity,
            });
          }

          successCount++;
        } catch (e) {
          debugPrint('❌ Error processing consumable $consumableId: $e');
          failCount++;
        }
      }

      if (mounted) {
        // Clear batch only if not called from mixed batch
        if (!skipClearAndMessage) {
          scanProvider.clearBatch();
        }

        // Show success message only if not called from mixed batch
        if (!skipClearAndMessage) {
          final actionText = isRestock ? 'restocked' : 'assigned';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successCount > 0
                    ? 'Successfully $actionText $successCount consumable(s)${failCount > 0 ? " ($failCount failed)" : ""}'
                    : 'Failed to ${isRestock ? "restock" : "assign"} consumables',
              ),
              backgroundColor: successCount > 0
                  ? MallonColors.successGreen
                  : MallonColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Batch consumable assignment error: $e');
      if (mounted && !skipClearAndMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    } finally {
      if (mounted && !skipClearAndMessage) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Handle batch checkout operation
  Future<void> _handleBatchCheckOut(Staff? selectedStaff) async {
    final scanProvider = context.read<ScanProvider>();

    // Generate unique batch ID
    final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

    final transactionHandler = ToolTransactionHandler(
      context: context,
      currentStaff: widget.currentStaff,
    );

    await transactionHandler.processBatchCheckout(
      scanProvider.scannedTools,
      assignToStaff: selectedStaff,
      batchId: batchId,
      () {
        // Success callback - clear batch
        if (mounted) {
          scanProvider.clearBatch();
          // Success feedback shown by transaction handler
        }
      },
    );
  }

  /// Handle batch checkin operation
  /// Handle batch check-in operation
  Future<void> _handleBatchCheckIn() async {
    final scanProvider = context.read<ScanProvider>();

    // Generate unique batch ID
    final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

    final transactionHandler = ToolTransactionHandler(
      context: context,
      currentStaff: widget.currentStaff,
    );

    await transactionHandler.processBatchCheckin(
      scanProvider.scannedTools,
      batchId: batchId,
      () {
        // Success callback - clear batch
        if (mounted) {
          scanProvider.clearBatch();
          // Success feedback shown by transaction handler
        }
      },
    );
  }

  /// Handle mixed batch (tools + consumables)
  Future<void> _handleMixedBatch(Staff? selectedStaff, String action) async {
    final scanProvider = context.read<ScanProvider>();

    // Generate unique batch ID
    final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

    // Store counts before processing
    final toolCount = scanProvider.scannedTools.length;
    final consumableCount = scanProvider.scannedConsumables.length;

    setState(() => _isProcessing = true);

    try {
      int toolsProcessed = 0;

      // Process tools first
      if (scanProvider.scannedTools.isNotEmpty) {
        final transactionHandler = ToolTransactionHandler(
          context: context,
          currentStaff: widget.currentStaff,
        );

        if (action == 'checkout') {
          await transactionHandler.processBatchCheckout(
            scanProvider.scannedTools,
            assignToStaff: selectedStaff,
            batchId: batchId,
            () {
              toolsProcessed = scanProvider.scannedTools.length;
              debugPrint('✅ $toolsProcessed tools processed in mixed batch');
            },
          );
        } else {
          await transactionHandler.processBatchCheckin(
            scanProvider.scannedTools,
            batchId: batchId,
            () {
              toolsProcessed = scanProvider.scannedTools.length;
              debugPrint('✅ $toolsProcessed tools processed in mixed batch');
            },
          );
        }
      }

      // Process consumables if staff selected
      if (scanProvider.scannedConsumables.isNotEmpty && selectedStaff != null) {
        await _handleBatchConsumableAssignment(
          selectedStaff,
          batchId: batchId,
          skipClearAndMessage: true,
        );
      }

      if (mounted) {
        // Clear batch after processing
        scanProvider.clearBatch();

        // Show success message with original counts
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully processed: ${toolCount > 0 ? "$toolCount tool(s)" : ""}${toolCount > 0 && consumableCount > 0 ? " and " : ""}${consumableCount > 0 ? "$consumableCount consumable(s)" : ""}',
            ),
            backgroundColor: MallonColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Mixed batch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing mixed batch: $e'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner Area - Fixed height
        Container(
          height: 360,
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: UniversalScanner(
              onItemScanned: _handleScannedItem,
              allowTools: true,
              allowConsumables: true,
              batchMode: true,
              lastScannedId: _lastScannedId,
              lastScannedType: _lastScannedType,
              isProcessing: _isProcessing,
            ),
          ),
        ),

        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Batch Search Section
                _BatchSearchSection(
                  controller: _batchSearchController,
                  onAddToBatch: _addToolToBatch,
                ),
                const SizedBox(height: 16),

                // Batch Tools List
                _BatchToolsListCard(onRemoveTool: _removeBatchTool),
                const SizedBox(height: 16),

                // Batch Actions
                _BatchActionsCard(
                  onShowBatchSubmitDialog: _showBatchSubmitDialog,
                ),
                const SizedBox(height: 16),

                // Scan Instructions
                const _BatchScanInstructions(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Batch search section widget
class _BatchSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onAddToBatch;

  const _BatchSearchSection({
    required this.controller,
    required this.onAddToBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Or search to add tools:'),
              const SizedBox(width: 8),
              Icon(
                Icons.info_outline,
                size: 16,
                color: MallonColors.mediumGrey,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type tool ID, name, brand, or model to see suggestions and add to batch',
            style: TextStyle(fontSize: 12, color: MallonColors.secondaryText),
          ),
          const SizedBox(height: 12),
          _BatchSearchAutocomplete(
            controller: controller,
            onAddToBatch: onAddToBatch,
          ),
        ],
      ),
    );
  }
}

/// Batch search autocomplete field widget
class _BatchSearchAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onAddToBatch;

  const _BatchSearchAutocomplete({
    required this.controller,
    required this.onAddToBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ToolsProvider>(
      builder: (context, toolsProvider, child) {
        final scanProvider = context.watch<ScanProvider>();

        return Autocomplete<Tool>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty || !toolsProvider.isLoaded) {
              return const Iterable<Tool>.empty();
            }

            final searchResults = toolsProvider.searchTools(
              textEditingValue.text,
            );
            return searchResults.take(15);
          },
          displayStringForOption: (Tool option) =>
              '${option.uniqueId} - ${option.displayName}',
          fieldViewBuilder:
              (context, controller, focusNode, onEditingComplete) {
                this.controller.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText:
                        'Search by ID, name, brand... (e.g., T1234 or Drill)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                            },
                          )
                        : null,
                  ),
                  onFieldSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      onAddToBatch(value.trim());
                    }
                  },
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return _BatchSearchOptions(
              options: options,
              scannedTools: scanProvider.scannedTools,
              onSelected: onSelected,
              onAddToBatch: onAddToBatch,
            );
          },
        );
      },
    );
  }
}

/// Batch search options dropdown widget
class _BatchSearchOptions extends StatelessWidget {
  final Iterable<Tool> options;
  final List<String> scannedTools;
  final Function(Tool) onSelected;
  final Function(String) onAddToBatch;

  const _BatchSearchOptions({
    required this.options,
    required this.scannedTools,
    required this.onSelected,
    required this.onAddToBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350, maxWidth: 450),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final tool = options.elementAt(index);
              final isAlreadyInBatch = scannedTools.contains(tool.uniqueId);

              return _BatchSearchOptionTile(
                tool: tool,
                isAlreadyInBatch: isAlreadyInBatch,
                onTap: isAlreadyInBatch
                    ? null
                    : () async {
                        onSelected(tool);
                        await Future.delayed(const Duration(milliseconds: 100));
                        onAddToBatch(tool.uniqueId);
                      },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Individual search option tile widget
class _BatchSearchOptionTile extends StatelessWidget {
  final Tool tool;
  final bool isAlreadyInBatch;
  final VoidCallback? onTap;

  const _BatchSearchOptionTile({
    required this.tool,
    required this.isAlreadyInBatch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isAlreadyInBatch
            ? MallonColors.mediumGrey
            : (tool.isAvailable
                  ? MallonColors.available
                  : MallonColors.checkedOut),
        child: isAlreadyInBatch
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                tool.uniqueId.substring(tool.uniqueId.length - 2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
      title: Text(
        tool.uniqueId,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isAlreadyInBatch ? MallonColors.secondaryText : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool.displayName,
            style: TextStyle(
              fontSize: 12,
              color: isAlreadyInBatch ? MallonColors.secondaryText : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Text(
                tool.isAvailable ? 'Available' : 'Checked Out',
                style: TextStyle(
                  fontSize: 10,
                  color: isAlreadyInBatch
                      ? MallonColors.secondaryText
                      : (tool.isAvailable
                            ? MallonColors.available
                            : MallonColors.checkedOut),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isAlreadyInBatch) ...[
                const SizedBox(width: 8),
                Text(
                  '• Already added',
                  style: TextStyle(
                    fontSize: 10,
                    color: MallonColors.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: isAlreadyInBatch
          ? Icon(Icons.check_circle, color: MallonColors.successGreen, size: 16)
          : (tool.isAvailable
                ? const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                    size: 16,
                  )
                : const Icon(
                    Icons.access_time,
                    color: Colors.orange,
                    size: 16,
                  )),
      onTap: onTap,
    );
  }
}

/// Batch tools list card widget
class _BatchToolsListCard extends StatelessWidget {
  final Function(String) onRemoveTool;

  const _BatchToolsListCard({required this.onRemoveTool});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, scanProvider, child) {
        final totalCount =
            scanProvider.scannedTools.length +
            scanProvider.scannedConsumables.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: MallonColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Scanned Items',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: MallonColors.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (scanProvider.scannedTools.isNotEmpty ||
                    scanProvider.scannedConsumables.isNotEmpty)
                  _BatchItemsList(
                    scannedTools: scanProvider.scannedTools,
                    scannedConsumableIds: scanProvider.scannedConsumableIds,
                    onRemoveItem: onRemoveTool,
                  )
                else
                  const _EmptyBatchList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Batch items list content widget (tools + consumables)
class _BatchItemsList extends StatelessWidget {
  final List<String> scannedTools;
  final List<String> scannedConsumableIds;
  final Function(String) onRemoveItem;

  const _BatchItemsList({
    required this.scannedTools,
    required this.scannedConsumableIds,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = scannedTools.length + scannedConsumableIds.length;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          // Show tools first, then consumables
          if (index < scannedTools.length) {
            final toolId = scannedTools[index];
            return _BatchToolTile(
              toolId: toolId,
              index: index,
              onRemove: () => onRemoveItem(toolId),
            );
          } else {
            final consumableIndex = index - scannedTools.length;
            final consumableId = scannedConsumableIds[consumableIndex];
            return _BatchConsumableTile(
              consumableId: consumableId,
              index: index,
              onRemove: () => onRemoveItem(consumableId),
            );
          }
        },
      ),
    );
  }
}

/// Empty batch list placeholder widget
class _EmptyBatchList extends StatelessWidget {
  const _EmptyBatchList();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: MallonColors.mediumGrey),
          const SizedBox(height: 8),
          Text(
            'No items scanned yet',
            style: TextStyle(color: MallonColors.mediumGrey, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Start scanning QR codes to add tools and consumables to your batch',
            style: TextStyle(color: MallonColors.secondaryText, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Individual batch tool tile widget
class _BatchToolTile extends StatelessWidget {
  final String toolId;
  final int index;
  final VoidCallback onRemove;

  const _BatchToolTile({
    required this.toolId,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Consumer listens to real-time Firestore updates via ToolsProvider
    return Consumer<ToolsProvider>(
      builder: (context, toolsProvider, child) {
        // Get tool with latest status from real-time subscription
        final tool =
            toolsProvider.getToolWithLatestStatus(toolId) ??
            toolsProvider.allTools
                .where((t) => t.uniqueId.toUpperCase() == toolId.toUpperCase())
                .firstOrNull;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: (tool != null && !tool.isAvailable)
              ? MallonColors.warning.withValues(alpha: 0.05)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (tool != null && !tool.isAvailable)
                  ? MallonColors.warning
                  : MallonColors.primaryGreen,
              child: (tool != null && !tool.isAvailable)
                  ? const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    tool?.displayName ?? toolId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (tool != null && !tool.isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MallonColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CHECKED OUT',
                      style: TextStyle(
                        color: MallonColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: $toolId'),
                if (tool != null) ...[
                  Text('Brand: ${tool.brand}'),
                  Text('Model: ${tool.model}'),
                  Row(
                    children: [
                      Text('Status: '),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tool.isAvailable
                              ? MallonColors.available.withValues(alpha: 0.2)
                              : MallonColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tool.status,
                          style: TextStyle(
                            color: tool.isAvailable
                                ? MallonColors.available
                                : MallonColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.remove_circle, color: MallonColors.error),
              onPressed: onRemove,
              tooltip: 'Remove from batch',
            ),
            isThreeLine: tool != null,
          ),
        );
      },
    );
  }
}

/// Individual batch consumable tile widget
class _BatchConsumableTile extends StatelessWidget {
  final String consumableId;
  final int index;
  final VoidCallback onRemove;

  const _BatchConsumableTile({
    required this.consumableId,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConsumablesProvider, ScanProvider>(
      builder: (context, consumablesProvider, scanProvider, child) {
        final consumable = consumablesProvider.getConsumableByUniqueId(
          consumableId,
        );
        final quantity = scanProvider.getConsumableQuantity(consumableId) ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: MallonColors.lightGreen.withValues(alpha: 0.3),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: MallonColors.primaryGreen,
              child: Icon(Icons.inventory_2, color: Colors.white, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    consumable?.name ?? consumableId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MallonColors.primaryGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CONSUMABLE',
                    style: TextStyle(
                      color: MallonColors.primaryGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: $consumableId'),
                if (consumable != null) ...[
                  Text('Category: ${consumable.category}'),
                  Row(
                    children: [
                      Text(
                        'Assigning: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$quantity ${consumable.unit.name}',
                        style: TextStyle(
                          color: MallonColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Available: '),
                      Text(
                        '${consumable.currentQuantity} ${consumable.unit.name}',
                        style: TextStyle(
                          color:
                              consumable.currentQuantity <=
                                  consumable.minQuantity
                              ? MallonColors.error
                              : MallonColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.remove_circle, color: MallonColors.error),
              onPressed: onRemove,
              tooltip: 'Remove from batch',
            ),
            isThreeLine: consumable != null,
          ),
        );
      },
    );
  }
}

/// Batch actions card widget
class _BatchActionsCard extends StatelessWidget {
  final VoidCallback onShowBatchSubmitDialog;

  const _BatchActionsCard({required this.onShowBatchSubmitDialog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Batch Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Consumer<ScanProvider>(
                builder: (context, scanProvider, child) {
                  final hasItems = scanProvider.hasBatchItems;

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasItems
                              ? () {
                                  scanProvider.clearBatch();
                                  // Clear feedback shown in batch list UI
                                }
                              : null,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Batch'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !hasItems || scanProvider.isProcessing
                              ? null
                              : onShowBatchSubmitDialog,
                          icon: scanProvider.isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.assignment_ind),
                          label: Text(
                            scanProvider.isProcessing
                                ? 'Processing...'
                                : 'Continue to Assign',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MallonColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Batch scan instructions widget
class _BatchScanInstructions extends StatelessWidget {
  const _BatchScanInstructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Consumer<ScanProvider>(
        builder: (context, scanProvider, child) {
          return Card(
            color: scanProvider.isProcessing
                ? MallonColors.lightGrey
                : MallonColors.lightGreen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    scanProvider.isProcessing
                        ? Icons.hourglass_empty
                        : scanProvider.isBatchTypeSet
                        ? (scanProvider.batchType == BatchType.checkout
                              ? Icons.output
                              : Icons.input)
                        : Icons.info_outline,
                    color: scanProvider.isProcessing
                        ? MallonColors.mediumGrey
                        : scanProvider.isBatchTypeSet
                        ? (scanProvider.batchType == BatchType.checkout
                              ? MallonColors.checkedOut
                              : MallonColors.available)
                        : MallonColors.primaryGreen,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scanProvider.isProcessing
                        ? 'Processing previous scan...'
                        : scanProvider.isBatchTypeSet
                        ? 'Batch Mode: ${scanProvider.batchType == BatchType.checkout ? "CHECKOUT" : "CHECKIN"}\nOnly ${scanProvider.batchType == BatchType.checkout ? "available" : "checked out"} tools will be added'
                        : 'Scan multiple tools, then submit batch',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scanProvider.isProcessing
                          ? MallonColors.mediumGrey
                          : scanProvider.isBatchTypeSet
                          ? (scanProvider.batchType == BatchType.checkout
                                ? MallonColors.checkedOut
                                : MallonColors.available)
                          : MallonColors.primaryGreen,
                      fontWeight: scanProvider.isBatchTypeSet
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialog for batch operation confirmation with staff selection
class _BatchSubmitDialog extends StatefulWidget {
  final int toolCount;
  final int availableCount;
  final int checkedOutCount;
  final List<String> toolIds;
  final Function(Staff?) onCheckOut;
  final VoidCallback onCheckIn;
  final int consumableCount; // Number of consumables in batch
  final Function(Staff?, String)? onMixedBatch; // Callback for mixed batches

  const _BatchSubmitDialog({
    required this.toolCount,
    required this.availableCount,
    required this.checkedOutCount,
    required this.toolIds,
    required this.onCheckOut,
    required this.onCheckIn,
    this.consumableCount = 0,
    this.onMixedBatch,
  });

  @override
  State<_BatchSubmitDialog> createState() => _BatchSubmitDialogState();
}

class _BatchSubmitDialogState extends State<_BatchSubmitDialog> {
  Staff? _selectedStaff;
  bool _isLoadingStaff = true;
  List<Staff> _allStaff = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      // Use activeStaff getter - only show active staff members for assignment
      setState(() {
        _allStaff = staffProvider.activeStaff;
        _isLoadingStaff = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load staff: $e';
        _isLoadingStaff = false;
      });
    }
  }

  String _getStaffSelectionLabel() {
    final hasMixedBatch =
        widget.consumableCount > 0 && widget.onMixedBatch != null;

    if (hasMixedBatch) {
      if (widget.availableCount > 0) {
        return 'Assign tools and consumables to:';
      } else {
        return 'Who is returning these items?';
      }
    } else {
      return 'Assign tools to:';
    }
  }

  String _getStaffSelectionHint() {
    final hasMixedBatch =
        widget.consumableCount > 0 && widget.onMixedBatch != null;

    if (hasMixedBatch) {
      if (widget.availableCount > 0) {
        return 'Select a staff member to assign all items in this batch';
      } else {
        return 'Select the staff member who is returning these items for check-in and restock';
      }
    } else if (widget.availableCount > 0) {
      return 'Select a staff member to assign tools during checkout';
    } else {
      return 'These tools will be returned to inventory';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMixedBatch =
        widget.consumableCount > 0 && widget.onMixedBatch != null;

    return AlertDialog(
      title: const Text('Batch Operation'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tools summary
            Text(
              '${widget.toolCount} tools scanned',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: MallonColors.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text('${widget.availableCount} available'),
                const SizedBox(width: 16),
                Icon(Icons.assignment_returned, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text('${widget.checkedOutCount} checked out'),
              ],
            ),

            // Consumables summary (if present)
            if (widget.consumableCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.consumableCount} consumable(s)',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Staff selection (only shown when needed)
            if (widget.availableCount > 0 || hasMixedBatch) ...[
              Text(
                _getStaffSelectionLabel(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              if (_isLoadingStaff)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else
                DropdownButtonFormField<Staff>(
                  initialValue: _selectedStaff,
                  decoration: const InputDecoration(
                    labelText: 'Select Staff Member',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _allStaff.map((staff) {
                    return DropdownMenuItem<Staff>(
                      value: staff,
                      child: Text('${staff.fullName} (${staff.jobCode})'),
                    );
                  }).toList(),
                  onChanged: (Staff? newValue) {
                    setState(() {
                      _selectedStaff = newValue;
                    });
                  },
                ),

              const SizedBox(height: 8),
              Text(
                _getStaffSelectionHint(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ] else ...[
              // Check-in only - no staff selection needed
              Text(
                'Ready to check in tools',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'These tools will be returned to available inventory',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        // Mixed checkout batch button (tools + consumables)
        if (hasMixedBatch && widget.availableCount > 0)
          ElevatedButton.icon(
            onPressed: _selectedStaff == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onMixedBatch!(_selectedStaff, 'checkout');
                  },
            icon: const Icon(Icons.all_inclusive),
            label: Text(
              _selectedStaff == null
                  ? 'Select Staff'
                  : 'Process Mixed Checkout',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),

        // Mixed check-in batch button (checked-out tools + consumables for restock)
        if (hasMixedBatch && widget.checkedOutCount > 0)
          ElevatedButton.icon(
            onPressed: _selectedStaff == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onMixedBatch!(_selectedStaff, 'checkin');
                  },
            icon: const Icon(Icons.all_inclusive),
            label: Text(
              _selectedStaff == null
                  ? 'Select Staff'
                  : 'Process Mixed Check-in',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),

        // Tool-only checkout
        if (widget.availableCount > 0 && !hasMixedBatch)
          ElevatedButton.icon(
            onPressed: _selectedStaff == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onCheckOut(_selectedStaff);
                  },
            icon: const Icon(Icons.assignment_turned_in),
            label: Text(
              _selectedStaff == null
                  ? 'Select Staff to Check Out'
                  : 'Check Out ${widget.availableCount}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),

        // Tool-only check in button
        if (widget.checkedOutCount > 0 && !hasMixedBatch)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCheckIn();
            },
            icon: const Icon(Icons.assignment_return),
            label: Text('Check In ${widget.checkedOutCount}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/mallon_theme.dart';
import '../../models/staff.dart';
import '../../models/tool.dart';
import '../../models/consumable.dart';
import '../../providers/tools_provider.dart';
import '../../providers/scan_provider.dart';
import '../../services/secure_tool_transaction_service.dart';
import '../universal_scanner.dart';
import '../../screens/record_consumable_usage_screen.dart';
import 'tool_scan_dialogs.dart';
import 'tool_transaction_handler.dart';

/// Widget for single tool scanning mode
/// Handles scanning one tool at a time with immediate dialog presentation
class SingleToolScanWidget extends StatefulWidget {
  final Staff? currentStaff;

  const SingleToolScanWidget({super.key, required this.currentStaff});

  @override
  State<SingleToolScanWidget> createState() => _SingleToolScanWidgetState();
}

class _SingleToolScanWidgetState extends State<SingleToolScanWidget> {
  final TextEditingController _manualSearchController = TextEditingController();
  final SecureToolTransactionService _transactionService =
      SecureToolTransactionService();

  bool _isDialogShowing = false;
  String? _lastScannedId;
  String? _lastScannedType;
  bool _isProcessing = false;

  @override
  void dispose() {
    _manualSearchController.dispose();
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

  /// Reset dialog state flag
  void _resetDialogState() {
    debugPrint('🔄 Dialog state reset (was: $_isDialogShowing)');
    _isDialogShowing = false;
    _clearScanFeedback();
  }

  /// Handle scanned item in single mode
  void _handleScannedItem(ScannedItem scannedItem) async {
    debugPrint(
      '🔍 Single mode - Scanned: ${scannedItem.typeLabel} ${scannedItem.id}',
    );

    // Prevent multiple dialogs/navigations
    if (_isDialogShowing) {
      debugPrint('🚫 Dialog already showing - ignoring scan');
      return;
    }

    final scanProvider = context.read<ScanProvider>();

    // Handle based on item type
    if (scannedItem.type == ScannedItemType.tool) {
      final tool = scannedItem.item as Tool;
      // Update UI feedback
      _updateScanFeedback(scannedItem.id, 'Tool', true);
      _handleScannedCode(tool.qrPayload);
    } else if (scannedItem.type == ScannedItemType.consumable) {
      // Update UI feedback
      final consumable = scannedItem.item as Consumable;
      _updateScanFeedback(
        scannedItem.id,
        'Consumable: ${consumable.name}',
        true,
      );

      // Set flag to prevent multiple navigations
      _isDialogShowing = true;

      // Reset scanner debounce to allow new scans after returning
      scanProvider.resetDebounce();

      if (!mounted) {
        _isDialogShowing = false;
        _clearScanFeedback();
        return;
      }

      debugPrint('🔍 Navigating to record usage for ${consumable.name}');

      // Small delay to show feedback
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to minimal usage recording screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RecordConsumableUsageScreen(consumable: consumable),
        ),
      );

      // Reset flag and clear feedback after returning from navigation
      _resetDialogState();
      _clearScanFeedback();
      debugPrint('✅ Returned from consumable detail - ready for new scan');
    } else {
      // Unknown item type - show in UI
      _updateScanFeedback(scannedItem.id, 'Unknown', false);
      await Future.delayed(const Duration(seconds: 2));
      _clearScanFeedback();
    }
  }

  /// Handle scanned code in single mode (for tools)
  void _handleScannedCode(String code) async {
    debugPrint('🔍 Single mode - Scanned code: $code');

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

    // Single scan mode - show dialog if processing
    if (scanProvider.isProcessing) {
      debugPrint('📱 Single scan mode - showing dialog');
      _isDialogShowing = true;

      // Extract tool ID immediately
      String toolId = code;
      if (code.startsWith('TOOL#')) {
        toolId = code.substring(5);
      }

      // Show dialog with minimal delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _isDialogShowing) {
          debugPrint('📱 Calling _showSingleToolDialog for $toolId');
          _showSingleToolDialog(toolId);
        } else {
          debugPrint('❌ Conditions not met for dialog - resetting flag');
          _isDialogShowing = false;
        }
      });
    }
  }

  /// Show dialog for single tool scan
  void _showSingleToolDialog(String toolId) async {
    // Get scanProvider early so we can reset it even if context becomes invalid
    final scanProvider = context.read<ScanProvider>();

    debugPrint('🔧 Showing dialog for tool: $toolId');

    // Ensure we're mounted
    if (!mounted) {
      debugPrint('❌ Not mounted - returning and resetting processing');
      _isDialogShowing = false;
      scanProvider.setProcessing(false);
      return;
    }

    // Clear any existing snackbars to prevent clutter
    ScaffoldMessenger.of(context).clearSnackBars();

    try {
      // Get the tool from the provider (cached data, much faster)
      final toolsProvider = context.read<ToolsProvider>();
      final tool = toolsProvider.getToolByUniqueId(toolId);

      debugPrint(
        '🔍 Tool lookup result: ${tool != null ? "Found ${tool.displayName}" : "Not found"}',
      );

      if (tool == null) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierColor: Colors.black54,
            builder: (context) => ToolNotFoundDialog(toolId: toolId),
          );
        }
        _resetDialogState();
        scanProvider.setProcessing(false);
        return;
      }

      if (!mounted) {
        _resetDialogState();
        scanProvider.setProcessing(false);
        return;
      }

      // Check user role and show appropriate dialog
      if (scanProvider.currentStaff == null) {
        debugPrint('❌ No staff logged in');
        scanProvider.setProcessing(false);
        if (mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black54,
            builder: (context) => const NotLoggedInDialog(),
          );
        }
        _resetDialogState();
        return;
      }

      debugPrint(
        '👤 Staff: ${scanProvider.currentStaff!.fullName} (${scanProvider.currentStaff!.role.name})',
      );

      // Show different dialogs based on user role
      if (scanProvider.currentStaff!.role.isSupervisor) {
        // Admin/Supervisor can assign tools to others
        debugPrint('🔧 Showing admin dialog');
        await _showAdminToolDialog(tool);
        _resetDialogState();
      } else {
        // Staff can only view tool details
        debugPrint('👁️ Showing staff dialog');
        await _showStaffToolDialog(tool);
        _resetDialogState();
      }
    } catch (e) {
      _resetDialogState();
      scanProvider.setProcessing(false);
      // Error will be shown in dialog if needed
      debugPrint('❌ Error loading tool: $e');
    } finally {
      // ALWAYS reset processing state, even if context is not mounted
      // This prevents the "Already processing" lockup
      scanProvider.setProcessing(false);
      debugPrint('📱 Processing state reset to false');
    }
  }

  /// Show admin/supervisor tool dialog with assignment options
  Future<void> _showAdminToolDialog(Tool tool) async {
    try {
      // Get the latest tool data from provider to ensure it's current
      final toolsProvider = context.read<ToolsProvider>();
      final currentTool = toolsProvider.getToolByUniqueId(tool.uniqueId);

      if (currentTool == null) {
        debugPrint('❌ Tool ${tool.uniqueId} not found');
        return;
      }

      final toolStatus = await _transactionService.getReadableToolStatusInfo(
        currentTool.uniqueId,
      );

      if (toolStatus == null) {
        debugPrint('❌ Unable to load tool status for ${currentTool.uniqueId}');
        return;
      }

      if (!mounted) return;

      final transactionHandler = ToolTransactionHandler(
        context: context,
        currentStaff: widget.currentStaff,
      );

      // Show the actual tool dialog with loaded data
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(currentTool.displayName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolInfoSection(tool: currentTool, toolStatus: toolStatus),
                const SizedBox(height: 16),
                Text(
                  'Admin Actions',
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  currentTool.isAvailable
                      ? 'This tool is available and can be assigned to any staff member.'
                      : 'This tool is currently checked out and can be checked back in.',
                  style: TextStyle(color: MallonColors.secondaryText),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Done and New - scan another tool
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.read<ScanProvider>().resetDebounce();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                    ),
                    child: const Text(
                      'Done & New',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Done and Close - close dialog and stay
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                    ),
                    child: const Text(
                      'Done & Close',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Action button (Assign or Check In)
                Expanded(
                  child: currentTool.isAvailable
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            transactionHandler.showStaffSelectionDialog(
                              currentTool.uniqueId,
                              () {
                                context.read<ScanProvider>().resetDebounce();
                                _resetDialogState();
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MallonColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          child: const Text(
                            'Assign',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            transactionHandler.checkInTool(
                              currentTool.uniqueId,
                              () {
                                context.read<ScanProvider>().resetDebounce();
                                _resetDialogState();
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MallonColors.available,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          child: const Text(
                            'Check In',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading tool status: $e');
    }
  }

  /// Show staff tool dialog with read-only information
  Future<void> _showStaffToolDialog(Tool tool) async {
    try {
      final toolStatus = await _transactionService.getReadableToolStatusInfo(
        tool.uniqueId,
      );
      final toolHistory = await _transactionService.getReadableToolHistory(
        tool.uniqueId,
      );

      if (!mounted) return;

      final transactionHandler = ToolTransactionHandler(
        context: context,
        currentStaff: widget.currentStaff,
      );

      // Show the actual tool dialog with loaded data
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(tool.displayName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolInfoSection(tool: tool, toolStatus: toolStatus),
                const SizedBox(height: 16),
                ToolHistorySection(history: toolHistory),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Done and New - scan another tool
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.read<ScanProvider>().resetDebounce();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                    ),
                    child: const Text(
                      'Done & New',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Done and Close - close dialog and stay
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                    ),
                    child: const Text(
                      'Done & Close',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Check In button (only if user can check in this tool)
                Expanded(
                  child:
                      (!tool.isAvailable &&
                          toolStatus?['assignedStaff']?.uid ==
                              widget.currentStaff?.uid)
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            transactionHandler.checkInTool(tool.uniqueId, () {
                              context.read<ScanProvider>().resetDebounce();
                              _resetDialogState();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MallonColors.available,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          child: const Text(
                            'Check In',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                      : Container(height: 36),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading tool details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner Area - Fixed height with feedback overlay
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
              batchMode: false,
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
                // Manual Input Section with Search Suggestions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Or search for a tool:'),
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
                        'Type tool ID, name, brand, or model to see suggestions',
                        style: TextStyle(
                          fontSize: 12,
                          color: MallonColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildToolSearchField(),
                    ],
                  ),
                ),

                // Scan Instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                                    : Icons.info_outline,
                                color: scanProvider.isProcessing
                                    ? MallonColors.mediumGrey
                                    : MallonColors.primaryGreen,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                scanProvider.isProcessing
                                    ? 'Processing previous scan...'
                                    : 'Scan or enter a tool QR code to check out/in',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scanProvider.isProcessing
                                          ? MallonColors.mediumGrey
                                          : MallonColors.primaryGreen,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolSearchField() {
    return Consumer<ToolsProvider>(
      builder: (context, toolsProvider, child) {
        return Autocomplete<Tool>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty || !toolsProvider.isLoaded) {
              return const Iterable<Tool>.empty();
            }

            // Use provider's memory-based search (much faster)
            final searchResults = toolsProvider.searchTools(
              textEditingValue.text,
            );
            return searchResults.take(10); // Limit to 10 suggestions
          },
          displayStringForOption: (Tool option) =>
              '${option.uniqueId} - ${option.displayName}',
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            _manualSearchController.text = controller.text;
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search by ID, name, brand... (e.g., T1234 or Drill)',
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
                  final toolsProvider = context.read<ToolsProvider>();

                  // Try exact match by unique ID first
                  Tool? exactMatch = toolsProvider.getToolByUniqueId(
                    value.trim(),
                  );

                  // If no exact match, try searching by name/brand
                  if (exactMatch == null) {
                    final searchResults = toolsProvider.searchTools(
                      value.trim(),
                    );
                    exactMatch = searchResults.isNotEmpty
                        ? searchResults.first
                        : null;
                  }

                  if (exactMatch != null) {
                    _handleScannedCode(exactMatch.uniqueId);
                  } else {
                    // Process the input directly - let the dialog system handle "not found"
                    _handleScannedCode(value.trim());
                  }
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final tool = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: tool.isAvailable
                              ? MallonColors.available
                              : MallonColors.checkedOut,
                          child: const Icon(
                            Icons.build,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          tool.uniqueId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tool.displayName,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tool.isAvailable ? 'Available' : 'Checked Out',
                              style: TextStyle(
                                fontSize: 10,
                                color: tool.isAvailable
                                    ? MallonColors.available
                                    : MallonColors.checkedOut,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: tool.isAvailable
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              )
                            : const Icon(
                                Icons.access_time,
                                color: Colors.orange,
                                size: 16,
                              ),
                        onTap: () async {
                          onSelected(tool);
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                          if (mounted) {
                            _handleScannedCode(tool.uniqueId);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

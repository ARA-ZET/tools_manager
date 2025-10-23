import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/mallon_theme.dart';
import '../../models/staff.dart';
import '../../providers/scan_provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/secure_tool_transaction_service.dart';
import '../../services/staff_service.dart';
import '../../services/id_mapping_service.dart';

/// Helper class to handle tool transactions (checkout/checkin)
class ToolTransactionHandler {
  final BuildContext context;
  final SecureToolTransactionService _transactionService;
  final StaffService _staffService;
  final IdMappingService _idMappingService;
  final Staff? currentStaff;

  ToolTransactionHandler({required this.context, required this.currentStaff})
    : _transactionService = SecureToolTransactionService(),
      _staffService = StaffService(),
      _idMappingService = IdMappingService();

  /// Show staff selection dialog for admin/supervisor to assign tool
  Future<void> showStaffSelectionDialog(
    String toolId,
    VoidCallback onSuccess,
  ) async {
    try {
      // Use StaffProvider instead of direct service (much faster with cached data)
      final staffProvider = context.read<StaffProvider>();
      List<Staff> staffList = staffProvider.activeStaff;

      // If no staff loaded, fall back to service
      if (staffList.isEmpty) {
        staffList = await _staffService.getActiveStaffStream().first;
      }

      if (!context.mounted) return;

      // Show the staff selection dialog with loaded data
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Assign Tool to Staff'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final staff = staffList[index];
                if (!staff.isActive) return const SizedBox.shrink();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: MallonColors.primaryGreen,
                    child: Text(
                      staff.fullName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(staff.fullName),
                  subtitle: Text(
                    '${staff.jobCode} • ${staff.role.name.toUpperCase()}',
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    checkOutToStaff(toolId, staff.jobCode, onSuccess);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading staff list: ${e.toString()}'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    }
  }

  /// Handle checkout to specific staff member (admin/supervisor action)
  Future<void> checkOutToStaff(
    String toolId,
    String staffJobCode,
    VoidCallback onSuccess,
  ) async {
    if (!context.mounted) return;
    context.read<ScanProvider>().setProcessing(true);

    try {
      final success = await _transactionService.checkOutTool(
        toolUniqueId: toolId,
        staffJobCode: staffJobCode,
        notes: 'Assigned by ${currentStaff?.fullName}',
        adminName: currentStaff?.fullName,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully assigned $toolId to staff'),
              backgroundColor: MallonColors.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );

          // Call success callback
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              onSuccess();
            }
          });
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign $toolId'),
              backgroundColor: MallonColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);
      }
    }
  }

  /// Handle check-in (admin/supervisor can check in any tool)
  Future<void> checkInTool(String toolId, VoidCallback onSuccess) async {
    if (!context.mounted) return;
    context.read<ScanProvider>().setProcessing(true);

    try {
      final success = await _transactionService.checkInTool(
        toolUniqueId: toolId,
        notes: 'Checked in by ${currentStaff?.fullName}',
        adminName: currentStaff?.fullName,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully checked in $toolId'),
              backgroundColor: MallonColors.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );

          // Call success callback
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              onSuccess();
            }
          });
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check in $toolId'),
              backgroundColor: MallonColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Tool is already available')) {
          errorMessage =
              'Tool $toolId is already checked in and available. You can assign it to a staff member instead.';
        } else {
          errorMessage =
              'Error checking in tool: ${errorMessage.replaceFirst('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: MallonColors.warning,
            duration: const Duration(seconds: 4),
            action: errorMessage.contains('already checked in')
                ? SnackBarAction(
                    label: 'Assign Staff',
                    onPressed: () =>
                        showStaffSelectionDialog(toolId, onSuccess),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);
      }
    }
  }

  /// Handle batch checkout
  Future<void> processBatchCheckout(
    List<String> toolIds,
    VoidCallback onSuccess, {
    Staff? assignToStaff,
    String? batchId,
  }) async {
    if (!context.mounted) return;
    context.read<ScanProvider>().setProcessing(true);

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Use provided batch ID or generate one
      final effectiveBatchId =
          batchId ?? 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

      // Determine who to assign to: specified staff or current staff
      final targetStaff = assignToStaff ?? currentStaff;

      if (targetStaff == null) {
        throw Exception('No staff member selected for assignment');
      }

      for (final toolId in toolIds) {
        try {
          // Get staff job code for readable transaction
          final staffJobCode = await _idMappingService.getStaffJobCodeFromUid(
            targetStaff.uid,
          );
          if (staffJobCode == null) {
            throw Exception('Staff job code not found');
          }

          final success = await _transactionService.checkOutTool(
            toolUniqueId: toolId,
            staffJobCode: staffJobCode,
            adminName: currentStaff?.fullName,
            notes: 'Batch operation: $effectiveBatchId',
          );
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          errors.add(
            '$toolId: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }

      // Show results
      final message = successCount > 0
          ? 'Batch checkout completed: $successCount success${failCount > 0 ? ', $failCount failed' : ''}'
          : 'Batch checkout failed: $failCount tools could not be checked out';

      // Always reset processing state first
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: successCount > 0
                ? MallonColors.successGreen
                : MallonColors.error,
            duration: const Duration(seconds: 4),
            action: errors.isNotEmpty
                ? SnackBarAction(
                    label: 'Details',
                    onPressed: () {
                      _showBatchErrorDialog('Checkout Errors', errors);
                    },
                  )
                : null,
          ),
        );

        // Call success callback if all successful
        if (failCount == 0) {
          onSuccess();
        }
      }
    } catch (e) {
      // Reset processing state on error
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch checkout failed: ${e.toString()}'),
            backgroundColor: MallonColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Handle batch checkin
  Future<void> processBatchCheckin(
    List<String> toolIds,
    VoidCallback onSuccess, {
    String? batchId,
  }) async {
    if (toolIds.isEmpty) return;
    if (!context.mounted) return;

    context.read<ScanProvider>().setProcessing(true);

    // Generate batch ID if not provided
    final effectiveBatchId =
        batchId ?? 'BATCH_${DateTime.now().millisecondsSinceEpoch}';

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (final toolId in toolIds) {
        try {
          final success = await _transactionService.checkInTool(
            toolUniqueId: toolId,
            adminName: currentStaff?.fullName,
            notes: 'Batch operation: $effectiveBatchId',
          );
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          errors.add(
            '$toolId: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }

      // Show results with batch ID
      final message = successCount > 0
          ? 'Batch checkin completed: $successCount success${failCount > 0 ? ', $failCount failed' : ''} (ID: $effectiveBatchId)'
          : 'Batch checkin failed: $failCount tools could not be checked in';

      // Always reset processing state first
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: successCount > 0
                ? MallonColors.successGreen
                : MallonColors.error,
            duration: const Duration(seconds: 4),
            action: errors.isNotEmpty
                ? SnackBarAction(
                    label: 'Details',
                    onPressed: () {
                      _showBatchErrorDialog('Checkin Errors', errors);
                    },
                  )
                : null,
          ),
        );

        // Call success callback if all successful
        if (failCount == 0) {
          onSuccess();
        }
      }
    } catch (e) {
      // Reset processing state on error
      if (context.mounted) {
        context.read<ScanProvider>().setProcessing(false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch checkin failed: ${e.toString()}'),
            backgroundColor: MallonColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show batch error details dialog
  void _showBatchErrorDialog(String title, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: errors
                  .map(
                    (error) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        error,
                        style: TextStyle(color: MallonColors.error),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

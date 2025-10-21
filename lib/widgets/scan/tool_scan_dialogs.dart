import 'package:flutter/material.dart';
import '../../core/theme/mallon_theme.dart';
import '../../models/tool.dart';
import '../../models/staff.dart';

/// Dialog widget shown when tool is not found in database
class ToolNotFoundDialog extends StatelessWidget {
  final String toolId;

  const ToolNotFoundDialog({super.key, required this.toolId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Tool Not Found'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: MallonColors.error),
          const SizedBox(height: 16),
          Text(
            'Tool "$toolId" was not found in the system.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check the tool ID and try again.',
            style: TextStyle(color: MallonColors.secondaryText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Dialog widget shown when tool is already in batch
class ToolAlreadyInBatchDialog extends StatelessWidget {
  final String toolId;

  const ToolAlreadyInBatchDialog({super.key, required this.toolId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Already in Batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.playlist_add_check, size: 64, color: MallonColors.warning),
          const SizedBox(height: 16),
          Text(
            'Tool "$toolId" is already in your batch.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your batch list below.',
            style: TextStyle(color: MallonColors.secondaryText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog widget to confirm adding tool to batch
class AddToBatchConfirmationDialog extends StatelessWidget {
  final Tool tool;

  const AddToBatchConfirmationDialog({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Add to Batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MallonColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MallonColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.build, color: MallonColors.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tool.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${tool.uniqueId}',
                  style: TextStyle(
                    color: MallonColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                if (tool.brand.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Brand: ${tool.brand}',
                    style: TextStyle(
                      color: MallonColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (tool.model.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Model: ${tool.model}',
                    style: TextStyle(
                      color: MallonColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tool.isAvailable
                            ? MallonColors.successGreen.withValues(alpha: 0.2)
                            : MallonColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tool.isAvailable ? 'Available' : 'Not Available',
                        style: TextStyle(
                          color: tool.isAvailable
                              ? MallonColors.successGreen
                              : MallonColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Warning if tool is not available
          if (!tool.isAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MallonColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MallonColors.warning),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: MallonColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This tool is currently checked out and not available.',
                      style: TextStyle(
                        color: MallonColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            tool.isAvailable
                ? 'Do you want to add this tool to your batch?'
                : 'This tool is not available. Do you still want to add it to your batch for check-in?',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: tool.isAvailable
                ? MallonColors.primaryGreen
                : MallonColors.warning,
            foregroundColor: Colors.white,
          ),
          child: Text(tool.isAvailable ? 'Add to Batch' : 'Add Anyway'),
        ),
      ],
    );
  }
}

/// Dialog widget shown when user is not logged in
class NotLoggedInDialog extends StatelessWidget {
  const NotLoggedInDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Authentication Issue'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your account is not linked to a staff profile.'),
          SizedBox(height: 8),
          Text('Please contact your administrator to link your account.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Widget that displays tool information section (reusable in dialogs)
class ToolInfoSection extends StatelessWidget {
  final Tool tool;
  final Map<String, dynamic>? toolStatus;

  const ToolInfoSection({super.key, required this.tool, this.toolStatus});

  @override
  Widget build(BuildContext context) {
    final assignedStaff = toolStatus?['assignedStaff'] as Staff?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tool ID: ${tool.uniqueId}'),
        if (tool.num.isNotEmpty) Text('Tool #: ${tool.num}'),
        Text('Brand: ${tool.brand}'),
        Text('Model: ${tool.model}'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Status: '),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tool.isAvailable
                    ? MallonColors.available.withOpacity(0.1)
                    : MallonColors.checkedOut.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tool.isAvailable
                      ? MallonColors.available
                      : MallonColors.checkedOut,
                ),
              ),
              child: Text(
                tool.isAvailable ? 'AVAILABLE' : 'CHECKED OUT',
                style: TextStyle(
                  color: tool.isAvailable
                      ? MallonColors.available
                      : MallonColors.checkedOut,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (!tool.isAvailable && assignedStaff != null) ...[
          const SizedBox(height: 8),
          Text('Assigned to: ${assignedStaff.fullName}'),
          Text('Job Code: ${assignedStaff.jobCode}'),
        ],
      ],
    );
  }
}

/// Widget that displays tool history section (reusable in dialogs)
class ToolHistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const ToolHistorySection({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent History',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No history available',
            style: TextStyle(color: MallonColors.secondaryText),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent History',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...history
            .take(3)
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      entry['action'] == 'checkout'
                          ? Icons.output
                          : Icons.input,
                      size: 16,
                      color: entry['action'] == 'checkout'
                          ? MallonColors.checkedOut
                          : MallonColors.available,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry['action']} by ${entry['metadata']?['staffName'] ?? entry['staffId'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

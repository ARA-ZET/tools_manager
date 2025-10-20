import 'package:flutter/material.dart';
import '../core/theme/mallon_theme.dart';
import '../models/tool.dart';
import '../models/staff.dart';
import '../services/tool_transaction_service.dart';

/// Screen showing tools assigned to a specific staff member
class StaffToolsScreen extends StatefulWidget {
  final Staff staff;

  const StaffToolsScreen({super.key, required this.staff});

  @override
  State<StaffToolsScreen> createState() => _StaffToolsScreenState();
}

class _StaffToolsScreenState extends State<StaffToolsScreen> {
  final ToolTransactionService _transactionService = ToolTransactionService();
  List<Tool> _assignedTools = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedTools();
  }

  Future<void> _loadAssignedTools() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tools = await _transactionService.getToolsAssignedToStaff(
        widget.staff.uid,
      );
      setState(() {
        _assignedTools = tools;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading assigned tools: $e'),
          backgroundColor: MallonColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.staff.fullName} - Tools'),
        actions: [
          IconButton(
            onPressed: _loadAssignedTools,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedTools.isEmpty
          ? _buildEmptyState()
          : _buildToolsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: MallonColors.mediumGrey),
          const SizedBox(height: 16),
          Text(
            'No Tools Assigned',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: MallonColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.staff.fullName} has no tools currently checked out.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MallonColors.secondaryText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAssignedTools,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsList() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MallonColors.lightGreen,
            border: Border(bottom: BorderSide(color: MallonColors.outline)),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: MallonColors.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.staff.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.staff.jobCode} • ${widget.staff.role.name.toUpperCase()}',
                      style: TextStyle(color: MallonColors.secondaryText),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MallonColors.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_assignedTools.length} Tools',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tools List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _assignedTools.length,
            itemBuilder: (context, index) {
              final tool = _assignedTools[index];
              return _buildToolCard(tool);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(Tool tool) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MallonColors.checkedOut,
          child: const Icon(Icons.build, color: Colors.white, size: 20),
        ),
        title: Text(
          tool.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${tool.uniqueId}'),
            if (tool.num.isNotEmpty) Text('Tool #: ${tool.num}'),
            if (tool.brand.isNotEmpty) Text('Brand: ${tool.brand}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MallonColors.checkedOut.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MallonColors.checkedOut),
          ),
          child: Text(
            'CHECKED OUT',
            style: TextStyle(
              color: MallonColors.checkedOut,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showToolDetails(tool),
      ),
    );
  }

  void _showToolDetails(Tool tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tool.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tool ID', tool.uniqueId),
            if (tool.num.isNotEmpty) _buildDetailRow('Tool Number', tool.num),
            _buildDetailRow('Brand', tool.brand),
            _buildDetailRow('Model', tool.model),
            _buildDetailRow('Status', tool.status.toUpperCase()),
            const SizedBox(height: 16),
            Text(
              'QR Payload: ${tool.qrPayload}',
              style: TextStyle(
                color: MallonColors.secondaryText,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _checkInTool(tool);
            },
            icon: const Icon(Icons.input),
            label: const Text('Check In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.available,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _checkInTool(Tool tool) async {
    try {
      final success = await _transactionService.checkInTool(
        toolId: tool.uniqueId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully checked in ${tool.displayName}'),
            backgroundColor: MallonColors.successGreen,
          ),
        );
        _loadAssignedTools(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check in ${tool.displayName}'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: MallonColors.error,
        ),
      );
    }
  }
}

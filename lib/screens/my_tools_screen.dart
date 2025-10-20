import 'package:flutter/material.dart';
import '../core/theme/mallon_theme.dart';
import '../models/tool.dart';
import '../models/staff.dart';
import '../services/tool_transaction_service.dart';
import '../services/staff_service.dart';
import '../services/auth_service.dart';

/// Screen showing tools assigned to current user
class MyToolsScreen extends StatefulWidget {
  const MyToolsScreen({super.key});

  @override
  State<MyToolsScreen> createState() => _MyToolsScreenState();
}

class _MyToolsScreenState extends State<MyToolsScreen> {
  final ToolTransactionService _transactionService = ToolTransactionService();
  final StaffService _staffService = StaffService();
  final AuthService _authService = AuthService();

  Staff? _currentStaff;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentStaff();
  }

  Future<void> _loadCurrentStaff() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final staff = await _staffService.getStaffByAuthUid(user.uid);
        setState(() {
          _currentStaff = staff;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tools'),
        backgroundColor: MallonColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentStaff == null) {
      return _buildNotSignedInView();
    }

    return FutureBuilder<List<Tool>>(
      future: _transactionService.getToolsAssignedToStaff(_currentStaff!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        final tools = snapshot.data ?? [];

        if (tools.isEmpty) {
          return _buildEmptyView();
        }

        return _buildToolsList(tools);
      },
    );
  }

  Widget _buildNotSignedInView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: MallonColors.mediumGrey),
          const SizedBox(height: 16),
          Text(
            'Not Signed In',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: MallonColors.mediumGrey),
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in to view your assigned tools',
            style: TextStyle(color: MallonColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: MallonColors.error),
          const SizedBox(height: 16),
          Text(
            'Error Loading Tools',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: MallonColors.error),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: MallonColors.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: MallonColors.mediumGrey),
          const SizedBox(height: 16),
          Text(
            'No Tools Assigned',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: MallonColors.mediumGrey),
          ),
          const SizedBox(height: 8),
          Text(
            'You currently have no tools checked out',
            style: TextStyle(color: MallonColors.secondaryText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate back to scan screen
              Navigator.pop(context);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Tools'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsList(List<Tool> tools) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: MallonColors.lightGreen,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: MallonColors.primaryGreen,
                child: Text(
                  _currentStaff!.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStaff!.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${tools.length} tool${tools.length == 1 ? '' : 's'} checked out',
                      style: TextStyle(color: MallonColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tools List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
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
            Text(
              'Checked out',
              style: TextStyle(
                color: MallonColors.checkedOut,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'checkin':
                _showCheckInDialog(tool);
                break;
              case 'history':
                // TODO: Show tool history
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'checkin',
              child: ListTile(
                leading: Icon(Icons.input),
                title: Text('Check In'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'history',
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('View History'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInDialog(Tool tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Check In Tool'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to check in this tool?'),
            const SizedBox(height: 16),
            Text(
              tool.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('ID: ${tool.uniqueId}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _handleCheckIn(tool);
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

  Future<void> _handleCheckIn(Tool tool) async {
    try {
      final success = await _transactionService.checkInTool(
        toolId: tool.uniqueId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully checked in ${tool.uniqueId}'),
            backgroundColor: MallonColors.successGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to check in tool: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: MallonColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

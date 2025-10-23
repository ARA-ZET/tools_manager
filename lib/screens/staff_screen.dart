import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../models/staff.dart';
import '../providers/staff_provider.dart';
import '../services/staff_service.dart';
import '../services/user_approval_service.dart';

/// Staff management screen
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final StaffService _staffService =
      StaffService(); // Still needed for write operations
  final UserApprovalService _approvalService = UserApprovalService();
  late TabController _tabController;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Staff'),
            Tab(
              child: StreamBuilder<int>(
                stream: _approvalService.getPendingUsers().map(
                  (users) =>
                      users.where((u) => u['status'] == 'pending').length,
                ),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending Approvals'),
                      if (count > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MallonColors.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Force re-initialize staff provider
              final staffProvider = context.read<StaffProvider>();
              staffProvider.initialize(true); // Force as admin for debugging
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Staff data refreshed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStaffTab(), _buildPendingApprovalsTab()],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddEditStaffDialog(),
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildStaffTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search staff...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isSelected: _selectedFilter == 'all',
                onTap: () => _updateFilter('all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Admin',
                isSelected: _selectedFilter == 'admin',
                onTap: () => _updateFilter('admin'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Supervisor',
                isSelected: _selectedFilter == 'supervisor',
                onTap: () => _updateFilter('supervisor'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Worker',
                isSelected: _selectedFilter == 'worker',
                onTap: () => _updateFilter('worker'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Staff List
        Expanded(child: _buildStaffList()),
      ],
    );
  }

  Widget _buildPendingApprovalsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _approvalService.getPendingUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: MallonColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading pending users',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MallonColors.secondaryText),
                ),
              ],
            ),
          );
        }

        final pendingUsers = snapshot.data ?? [];
        final activePending = pendingUsers
            .where((user) => user['status'] == 'pending')
            .toList();

        if (activePending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: MallonColors.mediumGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending approvals',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'All registration requests have been processed',
                  style: TextStyle(color: MallonColors.secondaryText),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activePending.length,
          itemBuilder: (context, index) {
            final user = activePending[index];
            return _PendingUserCard(
              user: user,
              onApprove: () => _showApprovalDialog(user),
              onReject: () => _handleReject(user),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffList() {
    return Consumer<StaffProvider>(
      builder: (context, staffProvider, child) {
        if (staffProvider.isLoading && !staffProvider.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (staffProvider.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: MallonColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading staff',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  staffProvider.errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MallonColors.secondaryText),
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

        if (staffProvider.isUnauthorized) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 64, color: MallonColors.warning),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Staff management requires administrator privileges.\nState: ${staffProvider.loadingState}\nAuthorized: ${staffProvider.isAuthorized}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MallonColors.secondaryText),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Force reinitialize as admin
                    staffProvider.initialize(true);
                  },
                  child: const Text('Retry as Admin'),
                ),
              ],
            ),
          );
        }

        // Get filtered staff from provider (memory-based filtering)
        final staff = _getFilteredStaff(staffProvider);

        if (staff.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: MallonColors.mediumGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No staff members found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first staff member to get started',
                  style: TextStyle(color: MallonColors.secondaryText),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: staff.length,
          itemBuilder: (context, index) {
            final member = staff[index];
            return _StaffCard(
              staff: member,
              onTap: () => _showStaffOptions(member),
            );
          },
        );
      },
    );
  }

  /// Get filtered staff from provider based on search and filter
  List<Staff> _getFilteredStaff(StaffProvider staffProvider) {
    // Debug: Check provider state
    debugPrint(
      'StaffScreen: Provider state - isUnauthorized: ${staffProvider.isUnauthorized}, isAuthorized: ${staffProvider.isAuthorized}, loadingState: ${staffProvider.loadingState}, allStaff count: ${staffProvider.allStaff.length}',
    );

    if (staffProvider.isUnauthorized) {
      debugPrint('StaffScreen: Provider is unauthorized, returning empty list');
      return []; // Return empty list if unauthorized
    }

    var filteredList = staffProvider.allStaff;

    // Apply role filter in memory
    if (_selectedFilter != 'all') {
      final targetRole = StaffRole.fromString(_selectedFilter);
      filteredList = filteredList
          .where((staff) => staff.role == targetRole)
          .toList();
    }

    // Apply search filter in memory
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filteredList = filteredList.where((staff) {
        return staff.fullName.toLowerCase().contains(lowerQuery) ||
            staff.email.toLowerCase().contains(lowerQuery) ||
            staff.jobCode.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    // Sort the results - create a new modifiable list to avoid sort() errors
    final sortableList = List<Staff>.from(filteredList);
    sortableList.sort((a, b) => a.fullName.compareTo(b.fullName));
    filteredList = sortableList;

    return filteredList;
  }

  /// Show staff options menu
  void _showStaffOptions(Staff staff) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Staff'),
              onTap: () {
                Navigator.pop(context);
                _showAddEditStaffDialog(staff);
              },
            ),
            ListTile(
              leading: Icon(
                staff.isActive ? Icons.person_off : Icons.person,
                color: staff.isActive
                    ? MallonColors.error
                    : MallonColors.primaryGreen,
              ),
              title: Text(staff.isActive ? 'Deactivate' : 'Activate'),
              onTap: () {
                Navigator.pop(context);
                _toggleStaffActive(staff);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Change Role'),
              onTap: () {
                Navigator.pop(context);
                _showChangeRoleDialog(staff);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  /// Show approval dialog with job code and role assignment
  void _showApprovalDialog(Map<String, dynamic> pendingUser) {
    final formKey = GlobalKey<FormState>();
    final jobCodeController = TextEditingController();
    StaffRole selectedRole = StaffRole.worker;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Approve ${pendingUser['displayName'] ?? pendingUser['email']}',
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MallonColors.lightGreen.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MallonColors.primaryGreen.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email: ${pendingUser['email']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (pendingUser['displayName'] != null)
                          Text(
                            'Name: ${pendingUser['displayName']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        Text(
                          'Requested: ${_formatDate(pendingUser['createdAt'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: MallonColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Job Code field
                  TextFormField(
                    controller: jobCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Job Code*',
                      helperText: '3-10 alphanumeric characters',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Job code is required';
                      }
                      if (!RegExp(
                        r'^[A-Za-z0-9]{3,10}$',
                      ).hasMatch(value.trim())) {
                        return 'Must be 3-10 alphanumeric characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role dropdown
                  DropdownButtonFormField<StaffRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Assign Role*',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items: StaffRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (role) {
                      if (role != null) {
                        setState(() {
                          selectedRole = role;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _handleApprove(
                    pendingUser,
                    jobCodeController.text.trim().toUpperCase(),
                    selectedRole,
                  );
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MallonColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle user approval
  Future<void> _handleApprove(
    Map<String, dynamic> pendingUser,
    String jobCode,
    StaffRole role,
  ) async {
    try {
      await _approvalService.approveUser(
        uid: pendingUser['uid'],
        email: pendingUser['email'],
        displayName: pendingUser['displayName'],
        jobCode: jobCode,
        role: role,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pendingUser['displayName'] ?? pendingUser['email']} approved successfully',
            ),
            backgroundColor: MallonColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    }
  }

  /// Handle user rejection
  Future<void> _handleReject(Map<String, dynamic> pendingUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Text(
          'Are you sure you want to reject the registration request from ${pendingUser['displayName'] ?? pendingUser['email']}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _approvalService.rejectUser(
          pendingUser['uid'],
          reason: 'Rejected by admin',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${pendingUser['displayName'] ?? pendingUser['email']} rejected',
              ),
              backgroundColor: MallonColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting user: $e'),
              backgroundColor: MallonColors.error,
            ),
          );
        }
      }
    }
  }

  /// Format Firestore timestamp for display
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Show add or edit staff dialog
  void _showAddEditStaffDialog([Staff? staff]) {
    showDialog(
      context: context,
      builder: (context) => _AddEditStaffDialog(
        staff: staff,
        onSave: (staffData) async {
          try {
            if (staff != null) {
              // Update existing staff
              await _staffService.updateStaff(staff.uid, {
                'fullName': staffData['fullName'],
                'jobCode': staffData['jobCode'],
                'role': staffData['role'],
                'email': staffData['email'],
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${staffData['fullName']} updated successfully',
                    ),
                    backgroundColor: MallonColors.successGreen,
                  ),
                );
              }
            } else {
              // Create new staff member
              final createAuth = staffData['createAuthAccount'] == true;

              if (createAuth) {
                // Create staff with Firebase Auth account
                final authResult = await _staffService.createStaffWithAuth(
                  fullName: staffData['fullName'],
                  email: staffData['email'],
                  jobCode: staffData['jobCode'],
                  role: StaffRole.fromString(staffData['role']),
                );

                if (mounted) {
                  _showCredentialsDialog(
                    staffData['fullName'],
                    staffData['email'],
                    authResult.temporaryPassword,
                    authResult.staffUid,
                  );
                }
              } else {
                // Create staff without Firebase Auth account
                await _staffService.createStaffWithData(
                  fullName: staffData['fullName'],
                  email: staffData['email'],
                  jobCode: staffData['jobCode'],
                  role: StaffRole.fromString(staffData['role']),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${staffData['fullName']} added successfully',
                      ),
                      backgroundColor: MallonColors.successGreen,
                    ),
                  );
                }
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: MallonColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// Toggle staff active status
  void _toggleStaffActive(Staff staff) async {
    try {
      if (staff.isActive) {
        await _staffService.deactivateStaff(staff.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${staff.fullName} deactivated'),
              backgroundColor: MallonColors.warning,
            ),
          );
        }
      } else {
        await _staffService.reactivateStaff(staff.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${staff.fullName} reactivated'),
              backgroundColor: MallonColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    }
  }

  /// Show change role dialog
  void _showChangeRoleDialog(Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${staff.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StaffRole.values.map((role) {
            return RadioListTile<StaffRole>(
              title: Text(role.name.toUpperCase()),
              value: role,
              groupValue: staff.role,
              onChanged: (newRole) async {
                if (newRole != null && newRole != staff.role) {
                  try {
                    await _staffService.changeStaffRole(staff.uid, newRole);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${staff.fullName} role updated to ${newRole.name}',
                          ),
                          backgroundColor: MallonColors.successGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: MallonColors.error,
                        ),
                      );
                    }
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show credentials dialog with login information for new staff
  void _showCredentialsDialog(
    String fullName,
    String email,
    String password,
    String staffUid,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: MallonColors.successGreen),
            const SizedBox(width: 8),
            const Text('Staff Account Created'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$fullName has been added successfully!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Credentials section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MallonColors.lightGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MallonColors.primaryGreen.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.key,
                          color: MallonColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Login Credentials',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCredentialRow('Email:', email),
                    const SizedBox(height: 8),
                    _buildCredentialRow(
                      'Password:',
                      password,
                      isPassword: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Save these credentials securely\n'
                      '• Provide them to the staff member\n'
                      '• Staff should change password on first login\n'
                      '• This password will not be shown again',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Technical details (collapsible)
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildDetailRow('Staff UID:', staffUid),
                        _buildDetailRow('Auth Account:', 'Linked'),
                        _buildDetailRow('Status:', 'Active'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _copyCredentials(email, password),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Credentials'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Build credential row with copy functionality
  Widget _buildCredentialRow(
    String label,
    String value, {
    bool isPassword = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: isPassword
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(
                    value,
                    isPassword ? 'Password' : 'Email',
                  ),
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy ${isPassword ? 'password' : 'email'}',
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build detail row for technical information
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  /// Copy both credentials to clipboard
  void _copyCredentials(String email, String password) {
    final credentials = 'Email: $email\nPassword: $password';
    _copyToClipboard(credentials, 'Credentials');
  }

  /// Copy text to clipboard with feedback
  void _copyToClipboard(String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type copied to clipboard'),
        backgroundColor: MallonColors.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Add/Edit staff dialog
class _AddEditStaffDialog extends StatefulWidget {
  final Staff? staff;
  final Function(Map<String, dynamic>) onSave;

  const _AddEditStaffDialog({this.staff, required this.onSave});

  @override
  State<_AddEditStaffDialog> createState() => _AddEditStaffDialogState();
}

class _AddEditStaffDialogState extends State<_AddEditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _jobCodeController = TextEditingController();
  StaffRole _selectedRole = StaffRole.worker;
  bool _createAuthAccount = false;

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _nameController.text = widget.staff!.fullName;
      _emailController.text = widget.staff!.email;
      _jobCodeController.text = widget.staff!.jobCode;
      _selectedRole = widget.staff!.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.staff != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Staff' : 'Add Staff'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Required fields notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MallonColors.lightGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MallonColors.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: MallonColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Fields marked with * are required',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name*',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email*',
                  helperText: 'Required - Used for authentication',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isEditing, // Don't allow email editing
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final email = value.trim().toLowerCase();
                  if (!RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  ).hasMatch(email)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jobCodeController,
                decoration: const InputDecoration(
                  labelText: 'Job Code*',
                  helperText: '3-10 alphanumeric characters',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a job code';
                  }
                  // Basic job code format validation (alphanumeric, 3-10 characters)
                  if (!RegExp(r'^[A-Za-z0-9]{3,10}$').hasMatch(value.trim())) {
                    return 'Job code must be 3-10 alphanumeric characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StaffRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: StaffRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (role) {
                  if (role != null) {
                    setState(() {
                      _selectedRole = role;
                    });
                  }
                },
              ),
              if (!isEditing) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Create Firebase Auth Account'),
                  subtitle: const Text(
                    'Allow this staff member to sign in to the app',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _createAuthAccount,
                  onChanged: (value) {
                    setState(() {
                      _createAuthAccount = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final staffData = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'jobCode': _jobCodeController.text.trim().toUpperCase(),
        'role': _selectedRole.value,
        'createAuthAccount': _createAuthAccount,
      };

      Navigator.pop(context);
      widget.onSave(staffData);
    } else {
      // Show error message when validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: MallonColors.lightGreen,
      checkmarkColor: MallonColors.primaryGreen,
    );
  }
}

/// Staff card widget
class _StaffCard extends StatelessWidget {
  final Staff staff;
  final VoidCallback onTap;

  const _StaffCard({required this.staff, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: staff.isActive
              ? MallonColors.primaryGreen
              : MallonColors.mediumGrey,
          child: Text(
            staff.initials,
            style: const TextStyle(
              color: MallonColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          staff.fullName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: staff.isActive
                ? MallonColors.primaryText
                : MallonColors.secondaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(staff.email),
            Text(
              'Job Code: ${staff.jobCode}',
              style: const TextStyle(
                fontSize: 12,
                color: MallonColors.secondaryText,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(staff.role.value).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRoleColor(staff.role.value)),
              ),
              child: Text(
                staff.role.value.toUpperCase(),
                style: TextStyle(
                  color: _getRoleColor(staff.role.value),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (!staff.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MallonColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    color: MallonColors.error,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return MallonColors.error;
      case 'supervisor':
        return MallonColors.checkedOut;
      case 'worker':
        return MallonColors.primaryGreen;
      default:
        return MallonColors.mediumGrey;
    }
  }
}

/// Pending user card widget
class _PendingUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingUserCard({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(
                    _getInitials(user['displayName'] ?? user['email']),
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
                        user['displayName'] ?? 'No Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'],
                        style: TextStyle(
                          color: MallonColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(user['createdAt']),
                        style: TextStyle(
                          color: MallonColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MallonColors.error,
                    side: BorderSide(color: MallonColors.error),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MallonColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return 'Requested ${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return 'Requested ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return 'Requested ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Requested just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }
}

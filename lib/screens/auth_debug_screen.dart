import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';
import '../services/admin_initialization_service.dart';
import '../core/theme/mallon_theme.dart';

/// Debug screen to check Firebase Auth and Staff linking
class AuthDebugScreen extends StatefulWidget {
  const AuthDebugScreen({super.key});

  @override
  State<AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends State<AuthDebugScreen> {
  final StaffService _staffService = StaffService();
  final AdminInitializationService _adminService = AdminInitializationService();
  User? _currentUser;
  Staff? _linkedStaff;
  Map<String, dynamic>? _systemStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current Firebase Auth user
      _currentUser = FirebaseAuth.instance.currentUser;

      // Try to find linked staff
      if (_currentUser != null) {
        _linkedStaff = await _staffService.getStaffByAuthUid(_currentUser!.uid);
      }

      // Get system status
      _systemStatus = await _adminService.getSystemStatus();
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _copyAdminCredentials() {
    final credentials = _adminService.getDefaultAdminCredentials();
    final text =
        '''
Default Admin Credentials:
Email: ${credentials['email']}
Password: ${credentials['password']}
Job Code: ${credentials['jobCode']}
Name: ${credentials['name']}

⚠️ IMPORTANT: Change the password after first login!
''';

    Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Admin credentials copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Debug'),
        actions: [
          IconButton(
            onPressed: _checkAuthStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthSection(),
                  const SizedBox(height: 24),
                  _buildStaffSection(),
                  const SizedBox(height: 24),
                  _buildSystemStatusSection(),
                  const SizedBox(height: 24),
                  _buildActionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildAuthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentUser != null ? Icons.check_circle : Icons.error,
                  color: _currentUser != null
                      ? MallonColors.successGreen
                      : MallonColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Firebase Authentication',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentUser != null) ...[
              _buildInfoRow('Status', 'Signed In', MallonColors.successGreen),
              _buildInfoRow('Email', _currentUser!.email ?? 'No email', null),
              _buildInfoRow('UID', _currentUser!.uid, null),
              _buildInfoRow(
                'Display Name',
                _currentUser!.displayName ?? 'No display name',
                null,
              ),
              _buildInfoRow(
                'Email Verified',
                _currentUser!.emailVerified ? 'Yes' : 'No',
                _currentUser!.emailVerified
                    ? MallonColors.successGreen
                    : MallonColors.error,
              ),
            ] else ...[
              _buildInfoRow('Status', 'Not Signed In', MallonColors.error),
              const SizedBox(height: 8),
              const Text('You need to sign in with Firebase Auth first.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _linkedStaff != null ? Icons.check_circle : Icons.error,
                  color: _linkedStaff != null
                      ? MallonColors.successGreen
                      : MallonColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Staff Profile Linking',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_linkedStaff != null) ...[
              _buildInfoRow('Status', 'Linked', MallonColors.successGreen),
              _buildInfoRow('Full Name', _linkedStaff!.fullName, null),
              _buildInfoRow('Job Code', _linkedStaff!.jobCode, null),
              _buildInfoRow(
                'Role',
                _linkedStaff!.role.name.toUpperCase(),
                null,
              ),
              _buildInfoRow('Email', _linkedStaff!.email, null),
              _buildInfoRow(
                'Active',
                _linkedStaff!.isActive ? 'Yes' : 'No',
                _linkedStaff!.isActive
                    ? MallonColors.successGreen
                    : MallonColors.error,
              ),
              _buildInfoRow(
                'Has Auth Account',
                _linkedStaff!.hasAuthAccount ? 'Yes' : 'No',
                _linkedStaff!.hasAuthAccount
                    ? MallonColors.successGreen
                    : MallonColors.error,
              ),
            ] else if (_currentUser != null) ...[
              _buildInfoRow('Status', 'Not Linked', MallonColors.error),
              const SizedBox(height: 8),
              const Text(
                'Your Firebase Auth account is not linked to a staff profile.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact your administrator to create or link your staff profile.',
              ),
            ] else ...[
              _buildInfoRow('Status', 'Cannot Check', MallonColors.error),
              const SizedBox(height: 8),
              const Text('Sign in first to check staff profile linking.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _systemStatus?['isSystemReady'] == true
                      ? Icons.check_circle
                      : Icons.warning,
                  color: _systemStatus?['isSystemReady'] == true
                      ? MallonColors.successGreen
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_systemStatus != null) ...[
              _buildInfoRow(
                'Has Admin Users',
                _systemStatus!['hasAdmins'] ? 'Yes' : 'No',
                _systemStatus!['hasAdmins']
                    ? MallonColors.successGreen
                    : MallonColors.error,
              ),
              _buildInfoRow(
                'Total Staff',
                _systemStatus!['totalStaff'].toString(),
                null,
              ),
              _buildInfoRow(
                'Admin Count',
                _systemStatus!['adminCount'].toString(),
                null,
              ),
              _buildInfoRow(
                'System Ready',
                _systemStatus!['isSystemReady'] ? 'Yes' : 'No',
                _systemStatus!['isSystemReady']
                    ? MallonColors.successGreen
                    : MallonColors.error,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MallonColors.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MallonColors.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: MallonColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Default Admin Credentials',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: MallonColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '📧 Email: richardatclm@gmail.com',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      '🔑 Password: Admin123!',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      '👤 Job Code: ADMIN001',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _copyAdminCredentials,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text(
                          'Copy Credentials',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Loading system status...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkAuthStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
            ),
            const SizedBox(height: 8),
            if (_currentUser != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    _checkAuthStatus();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:
                    valueColor ?? Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: valueColor != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

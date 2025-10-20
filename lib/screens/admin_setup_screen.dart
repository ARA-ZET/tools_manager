import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_initialization_service.dart';
import '../core/theme/mallon_theme.dart';

/// Screen shown when no admin users exist in the system
class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final AdminInitializationService _adminService = AdminInitializationService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _systemStatus;

  @override
  void initState() {
    super.initState();
    _loadSystemStatus();
  }

  Future<void> _loadSystemStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _adminService.getSystemStatus();
      setState(() {
        _systemStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createDefaultAdmin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _adminService.ensureAdminExists();

      // Reload system status
      await _loadSystemStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Default admin user created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyCredentials() {
    final credentials = _adminService.getDefaultAdminCredentials();
    final text =
        '''
Admin Credentials:
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
      backgroundColor: MallonColors.lightGrey,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: MallonColors.primaryGreen,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'System Setup Required',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MallonColors.primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'No administrator users found in the system. You need to create an admin user to manage the application.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // System Status
                  if (_systemStatus != null) ...[
                    _buildSystemStatusCard(),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Setting up admin user...'),
                  ] else ...[
                    // Create Admin Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _systemStatus?['hasAdmins'] == true
                            ? null
                            : _createDefaultAdmin,
                        icon: const Icon(Icons.person_add),
                        label: Text(
                          _systemStatus?['hasAdmins'] == true
                              ? 'Admin User Already Exists'
                              : 'Create Default Admin User',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MallonColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Copy Credentials Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _copyCredentials,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Admin Credentials'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Refresh Button
                    TextButton.icon(
                      onPressed: _loadSystemStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                    ),
                  ],

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Instructions
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Icon(Icons.info, color: MallonColors.primaryGreen),
                            const SizedBox(width: 8),
                            Text(
                              'Default Admin Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MallonColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('📧 Email: richardatclm@gmail.com'),
                        Text('🔑 Password: Admin123!'),
                        Text('👤 Job Code: ADMIN001'),
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ Please change the default password after first login!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildStatusRow(
            'Has Admin Users',
            _systemStatus!['hasAdmins'] ? '✅ Yes' : '❌ No',
            _systemStatus!['hasAdmins'],
          ),

          _buildStatusRow(
            'Total Staff Count',
            _systemStatus!['totalStaff'].toString(),
            true,
          ),

          _buildStatusRow(
            'Admin Count',
            _systemStatus!['adminCount'].toString(),
            _systemStatus!['adminCount'] > 0,
          ),

          _buildStatusRow(
            'System Ready',
            _systemStatus!['isSystemReady'] ? '✅ Ready' : '❌ Not Ready',
            _systemStatus!['isSystemReady'],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isGood ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

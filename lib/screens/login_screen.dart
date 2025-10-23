import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/widgets/responsive_wrapper.dart';
import '../core/widgets/app_logo.dart';
import '../services/admin_initialization_service.dart';
import '../services/user_approval_service.dart';
import 'register_screen.dart';
import 'admin_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AdminInitializationService _adminService = AdminInitializationService();
  final UserApprovalService _approvalService = UserApprovalService();
  bool _obscurePassword = true;
  bool _showAdminSetup = false;
  bool _checkingAdminStatus = true;
  bool _isSigningIn =
      false; // Track sign-in state to prevent premature navigation

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final status = await _adminService.getSystemStatus();
      if (mounted) {
        setState(() {
          _showAdminSetup = !status['hasAdmins'];
          _checkingAdminStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingAdminStatus = false;
        });
      }
    }
  }

  void _showAdminSetupScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AdminSetupScreen()));
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard
      FocusScope.of(context).unfocus();

      setState(() {
        _isSigningIn = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        final success = await authProvider.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        if (success) {
          // CRITICAL: Check if user is approved IMMEDIATELY after auth
          // This must happen before router redirect can trigger
          final user = authProvider.user;
          if (user != null) {
            // Wait for approval check to complete
            final isApproved = await _approvalService.isUserApproved(user.uid);

            if (!isApproved) {
              // Sign out immediately if not approved
              // This must complete before resetting _isSigningIn
              await authProvider.signOut();

              // Wait a moment to ensure sign-out completes and auth state updates
              await Future.delayed(const Duration(milliseconds: 100));

              if (mounted) {
                setState(() {
                  _isSigningIn = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.pending, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your account is pending approval. Please contact an administrator.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange.shade700,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
              return;
            }

            // User is approved!
            // Wait for staff data to fully load before allowing navigation
            int attempts = 0;
            while (authProvider.staffData == null && attempts < 20) {
              await Future.delayed(const Duration(milliseconds: 100));
              attempts++;
            }
          }

          // User is fully authenticated and approved - router will handle navigation
          if (mounted) {
            setState(() {
              _isSigningIn = false;
            });
          }
          // Router will redirect to dashboard automatically
        } else {
          // Sign in failed
          if (mounted) {
            setState(() {
              _isSigningIn = false;
            });

            // Show detailed error message based on the error type
            String errorMessage = _getReadableErrorMessage(
              authProvider.errorMessage ?? 'Sign in failed',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );

            // Keep focus on password field for easier retry
            _passwordController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _passwordController.text.length,
            );
          }
        }
      } catch (e) {
        // Handle any unexpected errors
        if (mounted) {
          setState(() {
            _isSigningIn = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'An error occurred: ${e.toString()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      // Form validation failed - show validation errors in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please correct the errors in the form',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Convert Firebase error messages to user-friendly messages
  String _getReadableErrorMessage(String error) {
    // Remove "Exception: " prefix if present
    error = error.replaceFirst('Exception: ', '');

    // Common Firebase Auth error codes and their user-friendly messages
    if (error.contains('user-not-found') || error.contains('user not found')) {
      return 'No account found with this email address. Please check your email or sign up.';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect password. Please try again or use "Forgot Password" to reset it.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address format. Please check and try again.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed login attempts. Please try again later or reset your password.';
    } else if (error.contains('network-request-failed') ||
        error.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    } else {
      // Return the original error message with better formatting
      return error.isEmpty
          ? 'Sign in failed. Please check your credentials and try again.'
          : error;
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Please enter your email address first')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Please enter a valid email address')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.resetPassword(email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success
                      ? 'Password reset email sent! Please check your inbox.'
                      : authProvider.errorMessage ??
                            'Failed to send reset email. Please try again.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: success
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ResponsiveWrapper(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  alignment: Alignment.center,
                  width: 380,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Company Logo
                        const Center(child: LoginLogo()),

                        const SizedBox(height: 32),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isSigningIn && !authProvider.isLoading,
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                            helperText: 'Enter your registered email address',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          enabled: !_isSigningIn && !authProvider.isLoading,
                          validator: _validatePassword,
                          onFieldSubmitted: (_) {
                            if (!_isSigningIn && !authProvider.isLoading) {
                              _signIn();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            helperText:
                                'Password must be at least 6 characters',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed:
                                  (_isSigningIn || authProvider.isLoading)
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: (_isSigningIn || authProvider.isLoading)
                                ? null
                                : _resetPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sign In Button
                        ElevatedButton(
                          onPressed: (_isSigningIn || authProvider.isLoading)
                              ? null
                              : _signIn,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: (_isSigningIn || authProvider.isLoading)
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isSigningIn
                                          ? 'Verifying account...'
                                          : 'Signing in...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Admin Setup Button (shown when no admin exists)
                        if (_showAdminSetup && !_checkingAdminStatus) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: Colors.orange.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No admin users found',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'The system needs at least one administrator to function properly.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _showAdminSetupScreen,
                                    icon: const Icon(
                                      Icons.admin_panel_settings,
                                    ),
                                    label: const Text('Setup Admin User'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            TextButton(
                              onPressed:
                                  (_isSigningIn || authProvider.isLoading)
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Loading overlay - prevents interaction during authentication
                if (_isSigningIn || authProvider.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                _isSigningIn
                                    ? 'Verifying account...'
                                    : 'Authenticating...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/scan_screen.dart';
import '../../screens/tools_screen.dart';
// import '../../screens/tool_detail_screen.dart'; // Temporarily disabled
import '../../screens/staff_screen.dart';
import '../../screens/audit_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/consumables_screen.dart';
import '../widgets/responsive_wrapper.dart';

/// Navigation configuration using go_router
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Create the router configuration
  static GoRouter createRouter() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/dashboard',
      debugLogDiagnostics: true,
      redirect: _handleRedirect,
      refreshListenable: null, // We'll handle auth state changes in redirect
      routes: [
        // Login route (no shell)
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Main shell with bottom navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            // Dashboard
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),

            // Scanner
            GoRoute(
              path: '/scan',
              name: 'scan',
              builder: (context, state) => const ScanScreen(),
            ),

            // Tools
            GoRoute(
              path: '/tools',
              name: 'tools',
              builder: (context, state) => const ToolsScreen(),
              routes: [
                // Tool detail - Currently handled via direct navigation
                // TODO: Update to use proper routing with Tool object
                // GoRoute(
                //   path: '/:id',
                //   name: 'tool-detail',
                //   builder: (context, state) {
                //     final toolId = state.pathParameters['id']!;
                //     return ToolDetailScreen(tool: tool); // Need Tool object
                //   },
                // ),
              ],
            ),

            // Staff
            GoRoute(
              path: '/staff',
              name: 'staff',
              builder: (context, state) => const StaffScreen(),
            ),

            // Audit
            GoRoute(
              path: '/audit',
              name: 'audit',
              builder: (context, state) => const AuditScreen(),
            ),

            // Consumables
            GoRoute(
              path: '/consumables',
              name: 'consumables',
              builder: (context, state) => const ConsumablesScreen(),
            ),

            // Settings
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => ErrorScreen(error: state.error),
    );
  }

  /// Create the router configuration with auth provider for reactivity
  static GoRouter createRouterWithAuthProvider(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation:
          '/login', // Start at login, redirect will handle auth users
      debugLogDiagnostics: false, // Disable verbose logging
      redirect: _handleRedirect,
      refreshListenable:
          authProvider, // This makes the router reactive to auth changes
      routes: [
        // Login route (no shell)
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Main shell with bottom navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            // Dashboard
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),

            // Scanner
            GoRoute(
              path: '/scan',
              name: 'scan',
              builder: (context, state) => const ScanScreen(),
            ),

            // Tools
            GoRoute(
              path: '/tools',
              name: 'tools',
              builder: (context, state) => const ToolsScreen(),
              routes: [
                // Tool detail - Currently handled via direct navigation
                // TODO: Update to use proper routing with Tool object
                // GoRoute(
                //   path: '/:id',
                //   name: 'tool-detail',
                //   builder: (context, state) {
                //     final toolId = state.pathParameters['id']!;
                //     return ToolDetailScreen(tool: tool); // Need Tool object
                //   },
                // ),
              ],
            ),

            // Staff
            GoRoute(
              path: '/staff',
              name: 'staff',
              builder: (context, state) => const StaffScreen(),
            ),

            // Audit
            GoRoute(
              path: '/audit',
              name: 'audit',
              builder: (context, state) => const AuditScreen(),
            ),

            // Consumables
            GoRoute(
              path: '/consumables',
              name: 'consumables',
              builder: (context, state) => const ConsumablesScreen(),
            ),

            // Settings
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => ErrorScreen(error: state.error),
    );
  }

  /// Handle authentication redirects
  static String? _handleRedirect(BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = authProvider.isAuthenticated;
    final hasStaffRecord = authProvider.staffData != null;
    final isLoading =
        authProvider.status == AuthStatus.uninitialized ||
        authProvider.status == AuthStatus.authenticating;

    // Show loading while checking auth state
    if (isLoading) {
      return null; // Stay on current route while loading
    }

    // CRITICAL: If user is logged in but staff data hasn't loaded yet,
    // stay on current route to prevent premature navigation
    // This prevents the flash of dashboard before approval check completes
    if (isLoggedIn && !hasStaffRecord && state.uri.toString() == '/login') {
      return null; // Stay on login page until staff data loads
    }

    // If not logged in and not on login page, redirect to login
    if (!isLoggedIn && state.uri.toString() != '/login') {
      return '/login';
    }

    // If logged in but no staff record (not approved) and not on login page, redirect to login
    // This prevents unapproved users from accessing the app
    if (isLoggedIn && !hasStaffRecord && state.uri.toString() != '/login') {
      return '/login';
    }

    // If logged in with staff record and on login page, redirect to dashboard
    if (isLoggedIn && hasStaffRecord && state.uri.toString() == '/login') {
      return '/dashboard';
    }

    // No redirect needed
    return null;
  }
}

/// Main shell with bottom navigation and responsive layout
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final authProvider = context.watch<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet =
        MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(location),
          style: TextStyle(
            fontSize: isMobile ? 18 : (isTablet ? 20 : 22),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 2,
        // Remove logo and optimize for mobile
        centerTitle: isMobile, // Center title on mobile for better aesthetics
        titleSpacing: isMobile ? 0 : 16, // Adjust spacing
        actions: [
          // Settings button - only show icon on mobile
          if (isMobile)
            IconButton(
              onPressed: () => context.goNamed('settings'),
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              iconSize: 22,
            )
          else
            IconButton(
              onPressed: () => context.goNamed('settings'),
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
            ),
          // Staff button (admin only)
          if (authProvider.isAdmin)
            IconButton(
              onPressed: () => context.goNamed('staff'),
              icon: const Icon(Icons.people),
              tooltip: 'Staff Management',
              iconSize: isMobile ? 22 : 24,
            ),
          // User avatar with initials
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 4.0 : 8.0),
            child: PopupMenuButton<String>(
              child: CircleAvatar(
                radius: isMobile ? 16 : 18,
                backgroundColor: _getRoleColor(
                  context,
                  authProvider.staffData?.role.value,
                ),
                child: Text(
                  _getUserInitials(authProvider.staffData?.fullName ?? 'U'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authProvider.staffData?.fullName ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        authProvider.staffData?.role.value.toUpperCase() ??
                            'USER',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _showLogoutDialog(context, authProvider);
                }
              },
            ),
          ),
        ],
      ),
      body: ResponsiveWrapper(child: child),
      bottomNavigationBar: const MainBottomNavigation(),
    );
  }

  String _getAppBarTitle(String location) {
    if (location.startsWith('/dashboard')) return 'Dashboard';
    if (location.startsWith('/scan')) return 'QR Scanner';
    if (location.startsWith('/tools')) return 'Tools Management';
    if (location.startsWith('/staff')) return 'Staff Management';
    if (location.startsWith('/audit')) return 'Audit Log';
    if (location.startsWith('/consumables')) return 'Consumables';
    if (location.startsWith('/settings')) return 'Settings';
    return 'Versfeld Tool Manager';
  }

  String _getUserInitials(String fullName) {
    if (fullName.isEmpty) return 'U';

    final names = fullName.trim().split(' ');
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    } else {
      return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'
          .toUpperCase();
    }
  }

  Color _getRoleColor(BuildContext context, String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Theme.of(context).colorScheme.errorContainer;
      case 'supervisor':
        return Theme.of(context).colorScheme.tertiaryContainer;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                authProvider.signOut();
                context.goNamed('login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom navigation bar for main app sections
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final authProvider = context.watch<AuthProvider>();

    // Get user role for navigation filtering using AuthProvider getters
    final isAdmin = authProvider.isAdmin;
    final isSupervisor = authProvider.isSupervisor || isAdmin;

    int selectedIndex = _getSelectedIndex(location);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex,
      onTap: (index) => _onItemTapped(context, index, authProvider),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.build),
          label: 'Tools',
          // Only show badge for admin users
          backgroundColor: isAdmin
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Consumables',
        ),
        if (isSupervisor)
          const BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Audit',
          ),
      ],
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/scan')) return 1;
    if (location.startsWith('/tools')) return 2;
    if (location.startsWith('/consumables')) return 3;
    if (location.startsWith('/audit')) return 4;
    return 0;
  }

  void _onItemTapped(
    BuildContext context,
    int index,
    AuthProvider authProvider,
  ) {
    final isSupervisor = authProvider.isSupervisor || authProvider.isAdmin;

    switch (index) {
      case 0:
        context.goNamed('dashboard');
        break;
      case 1:
        context.goNamed('scan');
        break;
      case 2:
        context.goNamed('tools');
        break;
      case 3:
        context.goNamed('consumables');
        break;
      case 4:
        if (isSupervisor) {
          context.goNamed('audit');
        }
        break;
    }
  }
}

/// Error screen for navigation errors
class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'An unexpected error occurred',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.goNamed('dashboard'),
                icon: const Icon(Icons.home),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route path constants for easy reference
class Routes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String scan = '/scan';
  static const String tools = '/tools';
  static const String toolDetail = '/tools/:id';
  static const String staff = '/staff';
  static const String audit = '/audit';
  static const String consumables = '/consumables';
  static const String settings = '/settings';

  /// Generate tool detail path
  static String toolDetailPath(String toolId) => '/tools/$toolId';
}

/// Navigation extension for easier navigation
extension NavigationExtension on BuildContext {
  /// Navigate to tool detail page
  void goToToolDetail(String toolId) {
    goNamed('tool-detail', pathParameters: {'id': toolId});
  }

  /// Navigate to dashboard
  void goToDashboard() => goNamed('dashboard');

  /// Navigate to scanner
  void goToScanner() => goNamed('scan');

  /// Navigate to tools list
  void goToTools() => goNamed('tools');

  /// Navigate to staff list
  void goToStaff() => goNamed('staff');

  /// Navigate to audit log
  void goToAudit() => goNamed('audit');

  /// Navigate to consumables
  void goToConsumables() => goNamed('consumables');

  /// Navigate to settings
  void goToSettings() => goNamed('settings');

  /// Navigate to login
  void goToLogin() => goNamed('login');
}

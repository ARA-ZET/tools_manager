import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/tools_provider.dart';
import 'providers/staff_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/scan_provider.dart';
import 'services/admin_initialization_service.dart';
import 'core/theme/mallon_theme.dart';
import 'core/routing/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize admin user if none exists
  final adminService = AdminInitializationService();
  await adminService.ensureAdminExists();

  runApp(
    MultiProvider(
      providers: [
        // Auth provider - must be first as others depend on it
        ChangeNotifierProvider(create: (context) => AuthProvider()),

        // Tools provider - always available
        ChangeNotifierProvider(create: (context) => ToolsProvider()),

        // Staff provider - admin only, will be initialized based on auth
        ChangeNotifierProvider(create: (context) => StaffProvider()),

        // Transactions provider - admin only, will be initialized based on auth
        ChangeNotifierProvider(create: (context) => TransactionsProvider()),

        // Scan provider - always available for scanning functionality
        ChangeNotifierProvider(create: (context) => ScanProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _providersInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Initialize providers only once after auth is ready
        if (!_providersInitialized &&
            authProvider.status == AuthStatus.authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeProviders(context, authProvider);
          });
          _providersInitialized = true;
        }

        return MaterialApp.router(
          title: 'Versfeld Tool Manager',
          theme: MallonTheme.lightTheme,
          routerConfig: AppRouter.createRouterWithAuthProvider(authProvider),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  /// Initialize providers based on authentication state and user role
  void _initializeProviders(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // Give a small delay to ensure staff data is loaded
    await Future.delayed(const Duration(milliseconds: 100));

    final isAdmin = authProvider.isAdmin;
    final isSupervisor = authProvider.isSupervisor;
    final staffData = authProvider.staffData;

    print(
      'Initializing providers - isAdmin: $isAdmin, isSupervisor: $isSupervisor, staffData: ${staffData?.fullName}',
    );

    // Staff provider - initialize only for admins
    final staffProvider = context.read<StaffProvider>();
    staffProvider.initialize(isAdmin);
    print('Staff provider initialized with admin access: $isAdmin');

    // Transactions provider - initialize for admins and supervisors
    final transactionsProvider = context.read<TransactionsProvider>();
    transactionsProvider.initialize(isAdmin || isSupervisor);
    print(
      'Transactions provider initialized with access: ${isAdmin || isSupervisor}',
    );
  }

  /// Reset providers initialization flag (useful for debugging)
  void resetProviders() {
    _providersInitialized = false;
  }
}

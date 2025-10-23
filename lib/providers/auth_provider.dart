import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/admin_initialization_service.dart';
import '../services/auth_history_service.dart';
import '../models/staff.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AdminInitializationService _adminService = AdminInitializationService();
  final AuthHistoryService _authHistoryService = AuthHistoryService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  Staff? _staffData;

  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userData => _userData;
  Staff? get staffData => _staffData;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.authenticating;

  // Staff role getters
  bool get isAdmin => _staffData?.role.isAdmin ?? false;
  bool get isSupervisor => _staffData?.role.isSupervisor ?? false;
  bool get canManageTools => _staffData?.role.canManageTools ?? false;
  bool get canManageStaff => _staffData?.role.canManageStaff ?? false;
  bool get canAuthorizeCheckouts =>
      _staffData?.role.canAuthorizeCheckouts ?? false;
  bool get canViewAuditLogs => _staffData?.role.canViewAuditLogs ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize authentication state
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        _user = user;
        // Keep status as authenticating until staff data loads
        _status = AuthStatus.authenticating;
        notifyListeners(); // Notify that we're loading

        await _loadUserData();
        await _loadStaffData();

        // Record login event after staff data is loaded
        if (_staffData != null) {
          await _authHistoryService.recordLogin(
            user.uid,
            metadata: {'email': user.email, 'displayName': user.displayName},
          );
        }

        // Now set authenticated AFTER data is loaded
        _status = AuthStatus.authenticated;
        notifyListeners(); // Notify that we're fully authenticated
      } else {
        // Record logout event before clearing user data
        if (_user != null) {
          await _authHistoryService.recordLogout(_user!.uid);
        }

        _user = null;
        _userData = null;
        _staffData = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });
  }

  // Load user data from Firestore (unified users collection)
  Future<void> _loadUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot userDoc = await _authService.getUserData(_user!.uid);
        if (userDoc.exists) {
          _userData = userDoc.data() as Map<String, dynamic>?;

          // Check if user is approved in the users collection
          if (_userData?['status'] != 'approved' ||
              _userData?['isActive'] != true) {
            debugPrint(
              'User is not approved or not active: ${_userData?['status']}',
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  // Load staff data from Firestore
  Future<void> _loadStaffData() async {
    if (_user != null) {
      try {
        _staffData = await _authService.getStaffData(_user!.uid);
        if (_staffData != null) {
          debugPrint(
            'Loaded staff data for ${_staffData!.fullName} (${_staffData!.role.value})',
          );
        }
      } catch (e) {
        debugPrint('Error loading staff data: $e');
      }
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (userCredential != null && userCredential.user != null) {
        // Authentication successful - auth state listener will handle the rest
        return true;
      } else {
        _errorMessage = 'Sign in failed. Please try again.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Extract user-friendly error message
      String errorMsg = e.toString();

      // Remove "Exception: " prefix if present
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }

      _errorMessage = errorMsg;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _authService.registerWithEmailAndPassword(
        email,
        password,
        displayName,
      );

      if (userCredential != null && userCredential.user != null) {
        // Registration successful
        // NOTE: We don't set the user state here because new users need admin approval
        // The auth state listener is deliberately not triggered
        // User will be signed out immediately in the register screen
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registration failed. Please try again.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Extract user-friendly error message
      String errorMsg = e.toString();

      // Remove "Exception: " prefix if present
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }

      _errorMessage = errorMsg;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _errorMessage = null;

    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_user != null) {
      await _loadUserData();
      await _loadStaffData();
      notifyListeners();
    }
  }

  // Get system status including admin verification
  Future<Map<String, dynamic>> getSystemStatus() async {
    return await _adminService.getSystemStatus();
  }

  // Verify if email is the default admin email
  Future<bool> verifyAdminEmail(String email) async {
    return await _adminService.verifyAdminEmail(email);
  }

  // Get default admin credentials (for development)
  Map<String, String> getDefaultAdminCredentials() {
    return _adminService.getDefaultAdminCredentials();
  }
}

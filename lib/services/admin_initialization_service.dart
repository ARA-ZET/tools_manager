import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';

/// Service to ensure there's always at least one admin user in the system
class AdminInitializationService {
  static const String _defaultAdminEmail = 'richardatclm@gmail.com';
  static const String _defaultAdminName = 'Richard CLM';
  static const String _defaultAdminJobCode = 'ADMIN001';
  static const String _defaultAdminPassword = 'Admin123!';

  final StaffService _staffService = StaffService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if any admin users exist, create default admin if none found
  Future<void> ensureAdminExists() async {
    try {
      debugPrint('🔍 Checking for existing admin users...');

      // Check if any admin users exist
      final hasAdmins = await _hasAdminUsers();

      if (!hasAdmins) {
        debugPrint('⚠️ No admin users found! Creating default admin...');
        await _createDefaultAdmin();
      } else {
        debugPrint('✅ Admin users found, system is properly configured');
      }
    } catch (e) {
      debugPrint('❌ Error in admin initialization: $e');
      // Don't throw error to prevent app from crashing
      // Log the error and continue
    }
  }

  /// Check if any admin users exist in the system
  Future<bool> _hasAdminUsers() async {
    try {
      final query = await _firestore
          .collection('staff')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      final hasAdmins = query.docs.isNotEmpty;
      debugPrint('📊 Admin users count: ${query.docs.length}');
      return hasAdmins;
    } catch (e) {
      debugPrint('❌ Error checking for admin users: $e');
      return false;
    }
  }

  /// Create the default admin user
  Future<void> _createDefaultAdmin() async {
    try {
      debugPrint('🔧 Creating default admin with email: $_defaultAdminEmail');

      // Check if the email already exists in staff collection
      final existingStaff = await _staffService.getStaffByEmail(
        _defaultAdminEmail,
      );
      if (existingStaff != null) {
        debugPrint(
          '👤 Staff with admin email already exists, promoting to admin...',
        );
        await _promoteToAdmin(existingStaff);
        return;
      }

      // Check if job code already exists
      final existingJobCode = await _staffService.getStaffByJobCode(
        _defaultAdminJobCode,
      );
      if (existingJobCode != null) {
        debugPrint(
          '🔄 Job code $_defaultAdminJobCode already exists, using alternative...',
        );
        await _createAdminWithAlternativeJobCode();
        return;
      }

      // Create Firebase Auth account for admin
      debugPrint('🔐 Creating Firebase Auth account...');
      final authResult = await _createAdminAuthAccount();

      if (authResult != null) {
        debugPrint('✅ Default admin created successfully!');
        debugPrint('📧 Email: $_defaultAdminEmail');
        debugPrint('🔑 Password: $_defaultAdminPassword');
        debugPrint('👤 Job Code: $_defaultAdminJobCode');
        debugPrint('⚠️  PLEASE CHANGE THE DEFAULT PASSWORD AFTER FIRST LOGIN!');
      }
    } catch (e) {
      debugPrint('❌ Error creating default admin: $e');
      // Try creating admin without Firebase Auth as fallback
      await _createAdminWithoutAuth();
    }
  }

  /// Create admin Firebase Auth account and staff record
  Future<String?> _createAdminAuthAccount() async {
    User? originalUser = _auth.currentUser;

    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _defaultAdminEmail,
        password: _defaultAdminPassword,
      );

      final authUid = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(_defaultAdminName);

      // Create staff record
      final staff = Staff(
        uid: authUid,
        firebaseAuthUid: authUid,
        fullName: _defaultAdminName,
        jobCode: _defaultAdminJobCode,
        role: StaffRole.admin,
        email: _defaultAdminEmail,
        isActive: true,
        hasAuthAccount: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('staff')
          .doc(authUid)
          .set(staff.toFirestore());

      // Sign out the new admin user to restore previous session
      await _auth.signOut();

      // Restore original user session if there was one
      if (originalUser != null) {
        // Note: We can't directly restore the session, but the auth state listener will handle this
        debugPrint(
          '🔄 Previous user session will be restored by auth listener',
        );
      }

      return authUid;
    } catch (e) {
      debugPrint('❌ Error creating admin auth account: $e');

      // Try to clean up if auth user was created but staff creation failed
      try {
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == _defaultAdminEmail) {
          await _auth.currentUser!.delete();
        }
      } catch (cleanupError) {
        debugPrint('⚠️ Error cleaning up failed auth user: $cleanupError');
      }

      rethrow;
    }
  }

  /// Create admin staff record without Firebase Auth (fallback)
  Future<void> _createAdminWithoutAuth() async {
    try {
      debugPrint(
        '🔧 Creating admin staff record without Firebase Auth (fallback)...',
      );

      final staffUid = await _staffService.createStaffWithData(
        fullName: _defaultAdminName,
        email: _defaultAdminEmail,
        jobCode: _defaultAdminJobCode,
        role: StaffRole.admin,
      );

      debugPrint('✅ Admin staff record created (without auth): $staffUid');
      debugPrint('📧 Email: $_defaultAdminEmail');
      debugPrint('👤 Job Code: $_defaultAdminJobCode');
      debugPrint(
        '⚠️  Admin can sign up later using the email: $_defaultAdminEmail',
      );
    } catch (e) {
      debugPrint('❌ Error creating admin without auth: $e');
    }
  }

  /// Create admin with alternative job code if default is taken
  Future<void> _createAdminWithAlternativeJobCode() async {
    try {
      // Generate alternative job code
      final timestamp = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(7);
      final alternativeJobCode = 'ADMIN$timestamp';

      debugPrint('🔄 Using alternative job code: $alternativeJobCode');

      // Create Firebase Auth account
      final authResult = await _createAdminAuthAccountWithJobCode(
        alternativeJobCode,
      );

      if (authResult != null) {
        debugPrint('✅ Admin created with alternative job code!');
        debugPrint('👤 Job Code: $alternativeJobCode');
      }
    } catch (e) {
      debugPrint('❌ Error creating admin with alternative job code: $e');
      await _createAdminWithoutAuth();
    }
  }

  /// Create admin auth account with specific job code
  Future<String?> _createAdminAuthAccountWithJobCode(String jobCode) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _defaultAdminEmail,
        password: _defaultAdminPassword,
      );

      final authUid = userCredential.user!.uid;

      await userCredential.user!.updateDisplayName(_defaultAdminName);

      final staff = Staff(
        uid: authUid,
        firebaseAuthUid: authUid,
        fullName: _defaultAdminName,
        jobCode: jobCode,
        role: StaffRole.admin,
        email: _defaultAdminEmail,
        isActive: true,
        hasAuthAccount: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('staff')
          .doc(authUid)
          .set(staff.toFirestore());
      await _auth.signOut();

      return authUid;
    } catch (e) {
      debugPrint('❌ Error creating admin with job code $jobCode: $e');
      rethrow;
    }
  }

  /// Promote existing staff member to admin
  Future<void> _promoteToAdmin(Staff staff) async {
    try {
      debugPrint('⬆️ Promoting ${staff.fullName} to admin role...');

      await _staffService.updateStaff(staff.uid, {
        'role': StaffRole.admin.value,
        'isActive': true,
      });

      debugPrint('✅ Successfully promoted ${staff.fullName} to admin');
    } catch (e) {
      debugPrint('❌ Error promoting staff to admin: $e');
    }
  }

  /// Verify admin email (check if user exists and can access admin functions)
  Future<bool> verifyAdminEmail(String email) async {
    if (email != _defaultAdminEmail) {
      return false;
    }

    try {
      final staff = await _staffService.getStaffByEmail(email);
      return staff != null && staff.role.isAdmin && staff.isActive;
    } catch (e) {
      debugPrint('❌ Error verifying admin email: $e');
      return false;
    }
  }

  /// Get default admin credentials (for development/setup purposes)
  Map<String, String> getDefaultAdminCredentials() {
    return {
      'email': _defaultAdminEmail,
      'password': _defaultAdminPassword,
      'jobCode': _defaultAdminJobCode,
      'name': _defaultAdminName,
    };
  }

  /// Check system status and return information
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final hasAdmins = await _hasAdminUsers();
      final totalStaff = await _staffService.getTotalStaffCount();
      final adminCount = await _staffService.getStaffCountByRole(
        StaffRole.admin,
      );

      return {
        'hasAdmins': hasAdmins,
        'totalStaff': totalStaff,
        'adminCount': adminCount,
        'defaultAdminEmail': _defaultAdminEmail,
        'isSystemReady': hasAdmins,
      };
    } catch (e) {
      debugPrint('❌ Error getting system status: $e');
      return {
        'hasAdmins': false,
        'totalStaff': 0,
        'adminCount': 0,
        'defaultAdminEmail': _defaultAdminEmail,
        'isSystemReady': false,
        'error': e.toString(),
      };
    }
  }
}

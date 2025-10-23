import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/staff.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure user document exists and update last sign in
      if (result.user != null) {
        await _createOrUpdateUserDocument(result.user!);
        // Update staff last sign in if staff record exists
        await _updateStaffLastSignIn(result.user!.uid);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with display name
      await result.user?.updateDisplayName(displayName);

      // Create user document in Firestore
      await _createUserDocument(result.user!, displayName);

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Create user document in Firestore (called during registration)
  Future<void> _createUserDocument(User user, String displayName) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    // This is called during registration - user starts as pending
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName,
      'firebaseAuthUid': user.uid,
      'hasAuthAccount': true,
      'status': 'pending', // Will be approved by admin
      'role': null, // Will be set when approved
      'jobCode': null, // Will be set when approved
      'isActive': false, // Will be true when approved
      'createdAt': FieldValue.serverTimestamp(),
      'lastSignIn': FieldValue.serverTimestamp(),
      'approvedAt': null,
      'rejectedAt': null,
    };

    await userDoc.set(userData);
  }

  // Create or update user document for existing users
  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    // Check if document exists
    final docSnapshot = await userDoc.get();

    if (docSnapshot.exists) {
      // Document exists, just update lastSignIn
      await userDoc.update({
        'lastSignIn': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Document doesn't exist, create it as pending
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'firebaseAuthUid': user.uid,
        'hasAuthAccount': true,
        'status': 'pending',
        'role': null,
        'jobCode': null,
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'rejectedAt': null,
      };

      await userDoc.set(userData);
    }
  }

  // Update last sign in timestamp or create user document if it doesn't exist
  Future<void> updateLastSignIn() async {
    if (currentUser != null) {
      try {
        await _createOrUpdateUserDocument(currentUser!);
      } catch (e) {
        debugPrint('Error updating last sign in: $e');
        // Don't throw the error to prevent app crashes
      }
    }
  }

  // Get user data from Firestore
  Future<DocumentSnapshot> getUserData(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  // Get staff data by Firebase Auth UID
  Future<Staff?> getStaffData(String firebaseAuthUid) async {
    try {
      // First check if there's a staff record with this Firebase Auth UID
      final staffQuery = await _firestore
          .collection('staff')
          .where('firebaseAuthUid', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();

      if (staffQuery.docs.isNotEmpty) {
        return Staff.fromFirestore(staffQuery.docs.first);
      }

      // Also check if there's a staff record using the UID as document ID (legacy)
      final staffDoc = await _firestore
          .collection('staff')
          .doc(firebaseAuthUid)
          .get();
      if (staffDoc.exists) {
        return Staff.fromFirestore(staffDoc);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting staff data: $e');
      return null;
    }
  }

  // Update staff last sign in
  Future<void> _updateStaffLastSignIn(String firebaseAuthUid) async {
    try {
      // Update staff record if it exists
      final staffQuery = await _firestore
          .collection('staff')
          .where('firebaseAuthUid', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();

      if (staffQuery.docs.isNotEmpty) {
        await staffQuery.docs.first.reference.update({
          'lastSignIn': FieldValue.serverTimestamp(),
        });
      } else {
        // Check legacy format (UID as document ID)
        final staffDoc = await _firestore
            .collection('staff')
            .doc(firebaseAuthUid)
            .get();
        if (staffDoc.exists) {
          await staffDoc.reference.update({
            'lastSignIn': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating staff last sign in: $e');
      // Don't throw error to prevent auth flow interruption
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}

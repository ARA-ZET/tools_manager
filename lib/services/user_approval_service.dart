import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';
import '../models/auth_history.dart';
import 'staff_service.dart';
import 'auth_history_service.dart';

/// Service for managing user registration approvals
class UserApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StaffService _staffService = StaffService();
  final AuthHistoryService _authHistoryService = AuthHistoryService();

  /// Create a pending user registration request
  Future<void> createPendingUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'firebaseAuthUid': uid,
      'hasAuthAccount': true,
      'status': 'pending', // pending, approved, rejected
      'role': null, // Will be set when approved
      'jobCode': null, // Will be set when approved
      'isActive': false, // Will be true when approved
      'createdAt': FieldValue.serverTimestamp(),
      'lastSignIn': null,
      'approvedAt': null,
      'rejectedAt': null,
    });
  }

  /// Get all pending user requests
  Stream<List<Map<String, dynamic>>> getPendingUsers() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final allUsers = snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();

          // Sort by createdAt in descending order (newest first)
          allUsers.sort((a, b) {
            final aTime = a['createdAt'];
            final bTime = b['createdAt'];

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          return allUsers;
        });
  }

  /// Check if a user is approved
  Future<bool> isUserApproved(String uid) async {
    // Check users collection for approval status
    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['status'] == 'approved' && data?['isActive'] == true;
    }

    // User doesn't exist - not approved
    return false;
  }

  /// Approve a pending user and update their status in users collection
  Future<void> approveUser({
    required String uid,
    required String email,
    required String displayName,
    required String jobCode,
    required StaffRole role,
  }) async {
    // Update user record with approval details
    await _firestore.collection('users').doc(uid).update({
      'status': 'approved',
      'role': role.value,
      'jobCode': jobCode,
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create staff record for backward compatibility and additional staff features
    final staff = Staff(
      uid: uid,
      firebaseAuthUid: uid,
      fullName: displayName,
      jobCode: jobCode,
      role: role,
      email: email,
      isActive: true,
      hasAuthAccount: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _staffService.createStaff(staff);

    // Record account approval event in auth history
    await _authHistoryService.recordAuthEvent(
      uid: uid,
      type: AuthEventType.accountApproved,
      metadata: {
        'jobCode': jobCode,
        'role': role.value,
        'approvedBy': 'admin', // TODO: Pass actual admin UID
      },
    );
  }

  /// Reject a pending user
  Future<void> rejectUser(String uid, {String? reason}) async {
    await _firestore.collection('users').doc(uid).update({
      'status': 'rejected',
      'isActive': false,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'rejectionReason': reason,
    });

    // Record rejection event in auth history
    await _authHistoryService.recordAuthEvent(
      uid: uid,
      type: AuthEventType.accountRejected,
      metadata: {
        if (reason != null) 'reason': reason,
        'rejectedBy': 'admin', // TODO: Pass actual admin UID
      },
    );
  }

  /// Delete a user (admin only)
  Future<void> deleteUser(String uid) async {
    // Delete from users collection
    await _firestore.collection('users').doc(uid).delete();

    // Delete from staff collection if exists
    final staffDoc = await _firestore.collection('staff').doc(uid).get();
    if (staffDoc.exists) {
      await staffDoc.reference.delete();
    }

    // Note: Deleting from Firebase Auth requires admin privileges
    // This should be done through Firebase Admin SDK or Cloud Functions
  }

  /// Get pending user count
  Future<int> getPendingUserCount() async {
    final snapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();

    return snapshot.count ?? 0;
  }
}

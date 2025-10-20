import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/staff.dart';

/// Result class for staff creation with authentication
class StaffAuthResult {
  final String staffUid;
  final String temporaryPassword;

  const StaffAuthResult({
    required this.staffUid,
    required this.temporaryPassword,
  });
}

/// Service for managing staff in Firestore
class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _collection = 'staff';

  /// Get staff collection reference
  CollectionReference get _staffCollection =>
      _firestore.collection(_collection);

  /// Create a new staff member
  Future<void> createStaff(Staff staff) async {
    try {
      await _staffCollection.doc(staff.uid).set(staff.toFirestore());
      debugPrint('Staff created with UID: ${staff.uid}');
    } catch (e) {
      debugPrint('Error creating staff: $e');
      throw Exception('Failed to create staff: $e');
    }
  }

  /// Create a new staff member with generated data
  Future<String> createStaffWithData({
    required String fullName,
    required String email,
    required String jobCode,
    required StaffRole role,
    String? teamId,
    String? photoUrl,
  }) async {
    try {
      // Check if email already exists
      final existingStaff = await getStaffByEmail(email);
      if (existingStaff != null) {
        throw Exception('A staff member with this email already exists');
      }

      // Check if job code already exists
      final existingJobCode = await getStaffByJobCode(jobCode);
      if (existingJobCode != null) {
        throw Exception('A staff member with this job code already exists');
      }

      // Generate a unique UID for the staff member
      final docRef = _staffCollection.doc();
      final uid = docRef.id;

      // Create staff object
      final staff = Staff(
        uid: uid,
        fullName: fullName,
        jobCode: jobCode,
        role: role,
        teamId: teamId,
        photoUrl: photoUrl,
        email: email,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      await docRef.set(staff.toFirestore());
      debugPrint('Staff created with generated UID: $uid');

      return uid;
    } catch (e) {
      debugPrint('Error creating staff with data: $e');
      throw Exception('Failed to create staff: $e');
    }
  }

  /// Create staff member with Firebase Auth account
  Future<StaffAuthResult> createStaffWithAuth({
    required String fullName,
    required String email,
    required String jobCode,
    required StaffRole role,
    String? teamId,
    String? photoUrl,
    String? temporaryPassword,
  }) async {
    try {
      // Check if email already exists in staff
      final existingStaff = await getStaffByEmail(email);
      if (existingStaff != null) {
        throw Exception('A staff member with this email already exists');
      }

      // Check if job code already exists
      final existingJobCode = await getStaffByJobCode(jobCode);
      if (existingJobCode != null) {
        throw Exception('A staff member with this job code already exists');
      }

      // Create Firebase Auth user with temporary password
      final tempPassword = temporaryPassword ?? _generateTemporaryPassword();

      // Save current user to restore later
      final currentUser = _auth.currentUser;

      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
      } catch (e) {
        throw Exception('Failed to create Firebase Auth account: $e');
      }

      final authUid = userCredential.user!.uid;

      try {
        // Update display name
        await userCredential.user!.updateDisplayName(fullName);

        // Create staff record using Firebase Auth UID as document ID
        final staff = Staff(
          uid: authUid, // Use Firebase Auth UID as document ID
          firebaseAuthUid: authUid,
          fullName: fullName,
          jobCode: jobCode,
          role: role,
          teamId: teamId,
          photoUrl: photoUrl,
          email: email,
          isActive: true,
          hasAuthAccount: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save staff to Firestore
        await _staffCollection.doc(authUid).set(staff.toFirestore());

        // Sign out the newly created user to restore session
        await _auth.signOut();

        // Re-authenticate the original user if there was one
        if (currentUser != null) {
          // Note: We can't directly restore the user session,
          // but the auth state listener will handle this
        }

        debugPrint('Staff created with Firebase Auth UID: $authUid');
        debugPrint('Temporary password: $tempPassword');

        return StaffAuthResult(
          staffUid: authUid,
          temporaryPassword: tempPassword,
        );
      } catch (e) {
        // If staff creation fails, delete the auth user
        try {
          await userCredential.user!.delete();
        } catch (deleteError) {
          debugPrint('Error cleaning up auth user: $deleteError');
        }
        throw Exception('Failed to create staff record: $e');
      }
    } catch (e) {
      debugPrint('Error creating staff with auth: $e');
      rethrow;
    }
  }

  /// Generate a temporary password for new staff members
  String _generateTemporaryPassword() {
    // Generate a secure but user-friendly password
    // Format: Word-Word-Numbers (e.g., "Tiger-Moon-2025")

    const words = [
      'Tiger',
      'Eagle',
      'Dragon',
      'Phoenix',
      'Lion',
      'Wolf',
      'Bear',
      'Shark',
      'River',
      'Ocean',
      'Mountain',
      'Forest',
      'Cloud',
      'Storm',
      'Thunder',
      'Wind',
      'Fire',
      'Earth',
      'Light',
      'Shadow',
      'Steel',
      'Gold',
      'Silver',
      'Crystal',
      'Moon',
      'Star',
      'Sun',
      'Sky',
      'Dawn',
      'Dusk',
      'Night',
      'Day',
    ];

    final now = DateTime.now();
    final random1 = now.millisecond % words.length;
    final random2 = (now.microsecond ~/ 1000) % words.length;
    final numbers =
        (now.year % 100).toString().padLeft(2, '0') +
        (now.month + now.day).toString().padLeft(2, '0');

    // Ensure we don't get the same word twice
    int secondIndex = random2;
    if (secondIndex == random1) {
      secondIndex = (secondIndex + 1) % words.length;
    }

    return '${words[random1]}-${words[secondIndex]}-$numbers';
  }

  /// Link existing Firebase Auth user to staff record
  Future<void> linkStaffToAuth(String staffUid, String firebaseAuthUid) async {
    try {
      await _staffCollection.doc(staffUid).update({
        'firebaseAuthUid': firebaseAuthUid,
        'hasAuthAccount': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Linked staff $staffUid to Firebase Auth $firebaseAuthUid');
    } catch (e) {
      debugPrint('Error linking staff to auth: $e');
      throw Exception('Failed to link staff to auth account: $e');
    }
  }

  /// Get staff by Firebase Auth UID
  Future<Staff?> getStaffByAuthUid(String firebaseAuthUid) async {
    try {
      final query = await _staffCollection
          .where('firebaseAuthUid', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Staff.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting staff by auth UID: $e');
      throw Exception('Failed to get staff: $e');
    }
  }

  /// Get staff by UID
  Future<Staff?> getStaffById(String uid) async {
    try {
      final doc = await _staffCollection.doc(uid).get();
      if (doc.exists) {
        return Staff.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting staff by ID: $e');
      throw Exception('Failed to get staff: $e');
    }
  }

  /// Get staff by email
  Future<Staff?> getStaffByEmail(String email) async {
    try {
      final query = await _staffCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Staff.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting staff by email: $e');
      throw Exception('Failed to get staff: $e');
    }
  }

  /// Get staff by job code
  Future<Staff?> getStaffByJobCode(String jobCode) async {
    try {
      final query = await _staffCollection
          .where('jobCode', isEqualTo: jobCode)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Staff.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting staff by job code: $e');
      throw Exception('Failed to get staff: $e');
    }
  }

  /// Update staff
  Future<void> updateStaff(String uid, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _staffCollection.doc(uid).update(updates);
      debugPrint('Staff updated: $uid');
    } catch (e) {
      debugPrint('Error updating staff: $e');
      throw Exception('Failed to update staff: $e');
    }
  }

  /// Update last sign in timestamp
  Future<void> updateLastSignIn(String uid) async {
    try {
      await _staffCollection.doc(uid).update({
        'lastSignIn': FieldValue.serverTimestamp(),
      });
      debugPrint('Last sign in updated for: $uid');
    } catch (e) {
      debugPrint('Error updating last sign in: $e');
      // Don't throw error for this non-critical operation
    }
  }

  /// Delete staff (deactivate instead of hard delete)
  Future<void> deactivateStaff(String uid) async {
    try {
      await _staffCollection.doc(uid).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff deactivated: $uid');
    } catch (e) {
      debugPrint('Error deactivating staff: $e');
      throw Exception('Failed to deactivate staff: $e');
    }
  }

  /// Reactivate staff
  Future<void> reactivateStaff(String uid) async {
    try {
      await _staffCollection.doc(uid).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff reactivated: $uid');
    } catch (e) {
      debugPrint('Error reactivating staff: $e');
      throw Exception('Failed to reactivate staff: $e');
    }
  }

  /// Get all active staff stream
  Stream<List<Staff>> getActiveStaffStream() {
    return _staffCollection
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList(),
        );
  }

  /// Get all staff (including inactive) stream
  Stream<List<Staff>> getAllStaffStream() {
    return _staffCollection
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList(),
        );
  }

  /// Get staff by role
  Stream<List<Staff>> getStaffByRole(StaffRole role) {
    // Use simple query to avoid index issues
    return _staffCollection.where('role', isEqualTo: role.value).snapshots().map(
      (snapshot) {
        var staffList = snapshot.docs
            .map((doc) => Staff.fromFirestore(doc))
            .where((staff) => staff.isActive) // Filter in memory
            .toList();

        // Sort in memory - create a new modifiable list to avoid sort() errors
        final sortableList = List<Staff>.from(staffList);
        sortableList.sort((a, b) => a.fullName.compareTo(b.fullName));
        return sortableList;
      },
    );
  }

  /// Get staff by role (simple version to avoid index issues)
  Stream<List<Staff>> getStaffByRoleSimple(StaffRole role) {
    return getAllStaffStream().map((staffList) {
      final filteredList = staffList
          .where((staff) => staff.role == role && staff.isActive)
          .toList();
      // Create a new modifiable list to avoid sort() errors
      final sortableList = List<Staff>.from(filteredList);
      sortableList.sort((a, b) => a.fullName.compareTo(b.fullName));
      return sortableList;
    });
  }

  /// Get supervisors and admins (users who can authorize checkouts)
  Stream<List<Staff>> getSupervisorsStream() {
    return getAllStaffStream().map((staffList) {
      final filteredList = staffList
          .where((staff) => staff.isActive && staff.role.canAuthorizeCheckouts)
          .toList();
      // Create a new modifiable list to avoid sort() errors
      final sortableList = List<Staff>.from(filteredList);
      sortableList.sort((a, b) => a.fullName.compareTo(b.fullName));
      return sortableList;
    });
  }

  /// Get staff by team
  Stream<List<Staff>> getStaffByTeam(String teamId) {
    return _staffCollection
        .where('teamId', isEqualTo: teamId)
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList(),
        );
  }

  /// Get staff with pagination
  Future<List<Staff>> getStaffPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? searchQuery,
    StaffRole? roleFilter,
    bool includeInactive = false,
  }) async {
    try {
      Query query = _staffCollection.orderBy('fullName');

      // Apply filters
      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      if (roleFilter != null) {
        query = query.where('role', isEqualTo: roleFilter.value);
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      var staff = snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();

      // Apply search filter locally
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        staff = staff
            .where(
              (member) =>
                  member.fullName.toLowerCase().contains(lowerQuery) ||
                  member.email.toLowerCase().contains(lowerQuery) ||
                  member.jobCode.toLowerCase().contains(lowerQuery),
            )
            .toList();
      }

      return staff;
    } catch (e) {
      debugPrint('Error getting paginated staff: $e');
      throw Exception('Failed to get staff: $e');
    }
  }

  /// Get active staff count
  Future<int> getActiveStaffCount() async {
    try {
      final query = await _staffCollection
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting active staff count: $e');
      return 0;
    }
  }

  /// Get total staff count
  Future<int> getTotalStaffCount() async {
    try {
      final query = await _staffCollection.count().get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting total staff count: $e');
      return 0;
    }
  }

  /// Get staff count by role
  Future<int> getStaffCountByRole(StaffRole role) async {
    try {
      final query = await _staffCollection
          .where('role', isEqualTo: role.value)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting staff count by role: $e');
      return 0;
    }
  }

  /// Search staff by query
  Future<List<Staff>> searchStaff(
    String query, {
    bool includeInactive = false,
  }) async {
    try {
      Query firestoreQuery = _staffCollection;

      if (!includeInactive) {
        firestoreQuery = firestoreQuery.where('isActive', isEqualTo: true);
      }

      final snapshot = await firestoreQuery.get();
      final staff = snapshot.docs
          .map((doc) => Staff.fromFirestore(doc))
          .toList();

      if (query.isEmpty) return staff;

      final lowerQuery = query.toLowerCase();
      return staff
          .where(
            (member) =>
                member.fullName.toLowerCase().contains(lowerQuery) ||
                member.email.toLowerCase().contains(lowerQuery) ||
                member.jobCode.toLowerCase().contains(lowerQuery) ||
                member.roleDisplayName.toLowerCase().contains(lowerQuery),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching staff: $e');
      throw Exception('Failed to search staff: $e');
    }
  }

  /// Change staff role
  Future<void> changeStaffRole(String uid, StaffRole newRole) async {
    try {
      await _staffCollection.doc(uid).update({
        'role': newRole.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff role changed: $uid to ${newRole.value}');
    } catch (e) {
      debugPrint('Error changing staff role: $e');
      throw Exception('Failed to change staff role: $e');
    }
  }

  /// Assign staff to team
  Future<void> assignToTeam(String uid, String teamId) async {
    try {
      await _staffCollection.doc(uid).update({
        'teamId': teamId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff assigned to team: $uid to $teamId');
    } catch (e) {
      debugPrint('Error assigning staff to team: $e');
      throw Exception('Failed to assign staff to team: $e');
    }
  }

  /// Remove staff from team
  Future<void> removeFromTeam(String uid) async {
    try {
      await _staffCollection.doc(uid).update({
        'teamId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff removed from team: $uid');
    } catch (e) {
      debugPrint('Error removing staff from team: $e');
      throw Exception('Failed to remove staff from team: $e');
    }
  }

  /// Update staff photo URL
  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    try {
      await _staffCollection.doc(uid).update({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Staff photo updated: $uid');
    } catch (e) {
      debugPrint('Error updating staff photo: $e');
      throw Exception('Failed to update staff photo: $e');
    }
  }

  /// Validate staff data before creation/update
  bool validateStaff(Map<String, dynamic> staffData) {
    final requiredFields = ['fullName', 'email', 'jobCode', 'role'];

    for (final field in requiredFields) {
      if (!staffData.containsKey(field) ||
          staffData[field] == null ||
          staffData[field].toString().trim().isEmpty) {
        debugPrint('Validation failed: Missing or empty field: $field');
        return false;
      }
    }

    // Validate email format
    final email = staffData['email'] as String;
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      debugPrint('Validation failed: Invalid email format');
      return false;
    }

    // Validate role
    final role = staffData['role'] as String;
    if (!['admin', 'supervisor', 'worker'].contains(role.toLowerCase())) {
      debugPrint('Validation failed: Invalid role');
      return false;
    }

    return true;
  }

  /// Check if staff member exists
  Future<bool> staffExists(String uid) async {
    try {
      final doc = await _staffCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if staff exists: $e');
      return false;
    }
  }

  /// Check if email is already in use
  Future<bool> emailExists(String email, {String? excludeUid}) async {
    try {
      Query query = _staffCollection.where('email', isEqualTo: email);

      final snapshot = await query.get();

      if (excludeUid != null) {
        return snapshot.docs.any((doc) => doc.id != excludeUid);
      }

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if email exists: $e');
      return false;
    }
  }

  /// Create a linking method to associate existing Firebase Auth users with staff
  Future<void> linkExistingUserToStaff({
    required String staffUid,
    required String firebaseAuthUid,
  }) async {
    try {
      // Update the staff record to link it to the Firebase Auth UID
      await _staffCollection.doc(staffUid).update({
        'firebaseAuthUid': firebaseAuthUid,
        'hasAuthAccount': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'Successfully linked staff $staffUid to Firebase Auth $firebaseAuthUid',
      );
    } catch (e) {
      debugPrint('Error linking existing user to staff: $e');
      throw Exception('Failed to link user to staff: $e');
    }
  }

  /// Search for staff members who don't have Firebase Auth accounts
  Future<List<Staff>> getStaffWithoutAuthAccounts() async {
    try {
      final query = await _staffCollection
          .where('hasAuthAccount', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      return query.docs.map((doc) => Staff.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting staff without auth accounts: $e');
      throw Exception('Failed to get staff without auth accounts: $e');
    }
  }
}

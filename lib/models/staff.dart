import 'package:cloud_firestore/cloud_firestore.dart';

/// Staff roles in the system
enum StaffRole {
  admin,
  supervisor,
  worker;

  /// Convert role to string for Firestore
  String get value => name;

  /// Create role from string
  static StaffRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return StaffRole.admin;
      case 'supervisor':
        return StaffRole.supervisor;
      case 'worker':
        return StaffRole.worker;
      default:
        return StaffRole.worker;
    }
  }

  /// Check if role has admin permissions
  bool get isAdmin => this == StaffRole.admin;

  /// Check if role has supervisor permissions
  bool get isSupervisor => this == StaffRole.supervisor || isAdmin;

  /// Check if role can manage tools
  bool get canManageTools => isAdmin;

  /// Check if role can manage staff
  bool get canManageStaff => isAdmin;

  /// Check if role can authorize checkouts
  bool get canAuthorizeCheckouts => isSupervisor;

  /// Check if role can view audit logs
  bool get canViewAuditLogs => isSupervisor;
}

/// Staff member model
class Staff {
  final String uid; // Document ID (can be Firebase Auth UID or generated)
  final String? firebaseAuthUid; // Firebase Auth UID (null if no auth account)
  final String fullName;
  final String jobCode;
  final StaffRole role;
  final String? teamId; // Optional team identifier
  final String? photoUrl; // Profile photo URL
  final String email;
  final bool isActive; // Whether staff member is active
  final bool hasAuthAccount; // Whether staff has Firebase Auth account
  final List<String>
  assignedToolIds; // Tool IDs currently assigned to this staff
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSignIn;

  const Staff({
    required this.uid,
    this.firebaseAuthUid,
    required this.fullName,
    required this.jobCode,
    required this.role,
    this.teamId,
    this.photoUrl,
    required this.email,
    this.isActive = true,
    this.hasAuthAccount = false,
    this.assignedToolIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastSignIn,
  });

  /// Create Staff from Firestore document
  factory Staff.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Staff(
      uid: doc.id,
      firebaseAuthUid: data['firebaseAuthUid'],
      fullName: data['fullName'] ?? '',
      jobCode: data['jobCode'] ?? '',
      role: StaffRole.fromString(data['role'] ?? 'worker'),
      teamId: data['teamId'],
      photoUrl: data['photoUrl'],
      email: data['email'] ?? '',
      isActive: data['isActive'] ?? true,
      hasAuthAccount: data['hasAuthAccount'] ?? false,
      assignedToolIds: List<String>.from(data['assignedToolIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSignIn: (data['lastSignIn'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert Staff to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'firebaseAuthUid': firebaseAuthUid,
      'fullName': fullName,
      'jobCode': jobCode,
      'role': role.value,
      'teamId': teamId,
      'photoUrl': photoUrl,
      'email': email,
      'isActive': isActive,
      'hasAuthAccount': hasAuthAccount,
      'assignedToolIds': assignedToolIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastSignIn': lastSignIn != null ? Timestamp.fromDate(lastSignIn!) : null,
    };
  }

  /// Create a copy with updated values
  Staff copyWith({
    String? firebaseAuthUid,
    String? fullName,
    String? jobCode,
    StaffRole? role,
    String? teamId,
    String? photoUrl,
    String? email,
    bool? isActive,
    bool? hasAuthAccount,
    DateTime? updatedAt,
    DateTime? lastSignIn,
  }) {
    return Staff(
      uid: uid,
      firebaseAuthUid: firebaseAuthUid ?? this.firebaseAuthUid,
      fullName: fullName ?? this.fullName,
      jobCode: jobCode ?? this.jobCode,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      hasAuthAccount: hasAuthAccount ?? this.hasAuthAccount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastSignIn: lastSignIn ?? this.lastSignIn,
    );
  }

  /// Get initials for display
  String get initials {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names.first[0]}${names.last[0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names.first.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  /// Get display name with job code
  String get displayNameWithJob => '$fullName ($jobCode)';

  /// Get role display name
  String get roleDisplayName {
    switch (role) {
      case StaffRole.admin:
        return 'Administrator';
      case StaffRole.supervisor:
        return 'Supervisor';
      case StaffRole.worker:
        return 'Worker';
    }
  }

  /// Check if staff member can perform action
  bool canPerformAction(String action) {
    switch (action) {
      case 'manage_tools':
        return role.canManageTools;
      case 'manage_staff':
        return role.canManageStaff;
      case 'authorize_checkouts':
        return role.canAuthorizeCheckouts;
      case 'view_audit_logs':
        return role.canViewAuditLogs;
      default:
        return false;
    }
  }

  @override
  String toString() => 'Staff(uid: $uid, name: $fullName, role: ${role.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Staff && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

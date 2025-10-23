import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of authentication event
enum AuthEventType {
  login,
  logout,
  passwordReset,
  accountCreated,
  accountApproved,
  accountRejected,
  sessionExpired;

  String get value => name;

  static AuthEventType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return AuthEventType.login;
      case 'logout':
        return AuthEventType.logout;
      case 'passwordreset':
        return AuthEventType.passwordReset;
      case 'accountcreated':
        return AuthEventType.accountCreated;
      case 'accountapproved':
        return AuthEventType.accountApproved;
      case 'accountrejected':
        return AuthEventType.accountRejected;
      case 'sessionexpired':
        return AuthEventType.sessionExpired;
      default:
        return AuthEventType.login;
    }
  }
}

/// Authentication history entry
class AuthHistoryEntry {
  final String id;
  final String uid; // Firebase Auth UID
  final AuthEventType type;
  final DateTime timestamp;
  final String? ipAddress;
  final String? deviceInfo;
  final String? userAgent;
  final Map<String, dynamic>? metadata;

  const AuthHistoryEntry({
    required this.id,
    required this.uid,
    required this.type,
    required this.timestamp,
    this.ipAddress,
    this.deviceInfo,
    this.userAgent,
    this.metadata,
  });

  /// Create from Firestore document
  factory AuthHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuthHistoryEntry(
      id: doc.id,
      uid: data['uid'] ?? '',
      type: AuthEventType.fromString(data['type'] ?? 'login'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ipAddress: data['ipAddress'],
      deviceInfo: data['deviceInfo'],
      userAgent: data['userAgent'],
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'type': type.value,
      'timestamp': Timestamp.fromDate(timestamp),
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      if (userAgent != null) 'userAgent': userAgent,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Get display text for the event
  String get displayText {
    switch (type) {
      case AuthEventType.login:
        return 'Signed in';
      case AuthEventType.logout:
        return 'Signed out';
      case AuthEventType.passwordReset:
        return 'Password reset';
      case AuthEventType.accountCreated:
        return 'Account created';
      case AuthEventType.accountApproved:
        return 'Account approved';
      case AuthEventType.accountRejected:
        return 'Account rejected';
      case AuthEventType.sessionExpired:
        return 'Session expired';
    }
  }

  @override
  String toString() =>
      'AuthHistoryEntry(uid: $uid, type: ${type.value}, timestamp: $timestamp)';
}

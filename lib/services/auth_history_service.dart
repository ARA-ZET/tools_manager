import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_history.dart';

/// Service for tracking authentication history
class AuthHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record an authentication event in staff document
  Future<void> recordAuthEvent({
    required String uid,
    required AuthEventType type,
    String? ipAddress,
    String? deviceInfo,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = AuthHistoryEntry(
        id: _firestore.collection('staff').doc().id,
        uid: uid,
        type: type,
        timestamp: DateTime.now(),
        ipAddress: ipAddress,
        deviceInfo: deviceInfo,
        userAgent: userAgent,
        metadata: metadata,
      );

      // Add to staff document's authHistory subcollection
      await _firestore
          .collection('staff')
          .doc(uid)
          .collection('authHistory')
          .add(entry.toFirestore());

      // Update lastSignIn in staff document if it's a login event
      if (type == AuthEventType.login) {
        await _firestore.collection('staff').doc(uid).update({
          'lastSignIn': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Auth event recorded: ${type.value} for user $uid');
    } catch (e) {
      debugPrint('❌ Error recording auth event: $e');
      // Don't throw - logging failures shouldn't break the auth flow
    }
  }

  /// Record login event
  Future<void> recordLogin(String uid, {Map<String, dynamic>? metadata}) async {
    await recordAuthEvent(
      uid: uid,
      type: AuthEventType.login,
      deviceInfo: await _getDeviceInfo(),
      metadata: metadata,
    );
  }

  /// Record logout event
  Future<void> recordLogout(
    String uid, {
    Map<String, dynamic>? metadata,
  }) async {
    await recordAuthEvent(
      uid: uid,
      type: AuthEventType.logout,
      deviceInfo: await _getDeviceInfo(),
      metadata: metadata,
    );
  }

  /// Get auth history for a user
  Stream<List<AuthHistoryEntry>> getAuthHistory(String uid, {int? limit}) {
    Query query = _firestore
        .collection('staff')
        .doc(uid)
        .collection('authHistory')
        .orderBy('timestamp', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AuthHistoryEntry.fromFirestore(doc))
          .toList();
    });
  }

  /// Get recent auth events (last 10)
  Future<List<AuthHistoryEntry>> getRecentAuthEvents(String uid) async {
    final snapshot = await _firestore
        .collection('staff')
        .doc(uid)
        .collection('authHistory')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => AuthHistoryEntry.fromFirestore(doc))
        .toList();
  }

  /// Get login count for a user
  Future<int> getLoginCount(String uid) async {
    final snapshot = await _firestore
        .collection('staff')
        .doc(uid)
        .collection('authHistory')
        .where('type', isEqualTo: 'login')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Get last login time
  Future<DateTime?> getLastLogin(String uid) async {
    final snapshot = await _firestore
        .collection('staff')
        .doc(uid)
        .collection('authHistory')
        .where('type', isEqualTo: 'login')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final entry = AuthHistoryEntry.fromFirestore(snapshot.docs.first);
      return entry.timestamp;
    }

    return null;
  }

  /// Get device info (platform)
  Future<String> _getDeviceInfo() async {
    if (kIsWeb) {
      return 'Web Browser';
    }
    return defaultTargetPlatform.toString().split('.').last;
  }

  /// Clean up old auth history (older than specified days)
  Future<void> cleanupOldHistory(String uid, {int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _firestore
          .collection('staff')
          .doc(uid)
          .collection('authHistory')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      // Delete in batch
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint(
        '✅ Cleaned up ${snapshot.docs.length} old auth history entries for user $uid',
      );
    } catch (e) {
      debugPrint('❌ Error cleaning up old auth history: $e');
    }
  }
}

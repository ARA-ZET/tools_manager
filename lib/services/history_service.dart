import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/tool_history.dart';

/// Service for managing tool history in Firestore
class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'tool_history';
  static const String _batchCollectionName = 'batches';

  final Uuid _uuid = const Uuid();

  /// Get history collection reference
  CollectionReference get _historyCollection =>
      _firestore.collection(_collection);

  /// Get batch collection reference
  CollectionReference get _batchCollection =>
      _firestore.collection(_batchCollectionName);

  /// Create a single history entry with tool status update
  Future<String> createHistoryEntry({
    required String toolId,
    required ToolAction action,
    required String byUid,
    String? supervisorUid,
    String? assignedToUid,
    String? notes,
    String? location,
    String? batchId,
    Map<String, dynamic>? metadata,
  }) async {
    final batch = _firestore.batch();

    try {
      // Create history entry
      final historyRef = _historyCollection.doc();
      final historyData = {
        'toolRef': _firestore.doc('tools/$toolId'),
        'action': action.value,
        'by': _firestore.doc('staff/$byUid'),
        'supervisor': supervisorUid != null
            ? _firestore.doc('staff/$supervisorUid')
            : null,
        'assignedTo': assignedToUid != null
            ? _firestore.doc('staff/$assignedToUid')
            : null,
        'timestamp': FieldValue.serverTimestamp(),
        'notes': notes,
        'location': location,
        'batchId': batchId,
        'metadata': metadata ?? {},
      };

      batch.set(historyRef, historyData);

      // Update tool status
      final toolRef = _firestore.doc('tools/$toolId');
      final toolUpdate = {
        'status': action == ToolAction.checkout ? 'checked_out' : 'available',
        'currentHolder': action == ToolAction.checkout && assignedToUid != null
            ? _firestore.doc('staff/$assignedToUid')
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.update(toolRef, toolUpdate);

      await batch.commit();
      debugPrint('History entry created: ${historyRef.id} for tool $toolId');
      return historyRef.id;
    } catch (e) {
      debugPrint('Error creating history entry: $e');
      throw Exception('Failed to create history entry: $e');
    }
  }

  /// Create batch history entries with tool status updates
  Future<String> createBatchHistoryEntries({
    required List<String> toolIds,
    required ToolAction action,
    required String byUid,
    String? supervisorUid,
    String? assignedToUid,
    String? notes,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    final batch = _firestore.batch();
    final batchId = _uuid.v4();

    try {
      // Create batch document
      final batchRef = _batchCollection.doc(batchId);
      final batchData = {
        'createdBy': byUid,
        'createdAt': FieldValue.serverTimestamp(),
        'toolIds': toolIds,
        'assignedTo': assignedToUid != null
            ? _firestore.doc('staff/$assignedToUid')
            : null,
        'notes': notes,
        'action': action.value,
        'metadata': metadata ?? {},
      };

      batch.set(batchRef, batchData);

      // Create history entries for each tool
      for (final toolId in toolIds) {
        final historyRef = _historyCollection.doc();
        final historyData = {
          'toolRef': _firestore.doc('tools/$toolId'),
          'action': action.value,
          'by': _firestore.doc('staff/$byUid'),
          'supervisor': supervisorUid != null
              ? _firestore.doc('staff/$supervisorUid')
              : null,
          'assignedTo': assignedToUid != null
              ? _firestore.doc('staff/$assignedToUid')
              : null,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': notes,
          'location': location,
          'batchId': batchId,
          'metadata': metadata ?? {},
        };

        batch.set(historyRef, historyData);

        // Update tool status
        final toolRef = _firestore.doc('tools/$toolId');
        final toolUpdate = {
          'status': action == ToolAction.checkout ? 'checked_out' : 'available',
          'currentHolder':
              action == ToolAction.checkout && assignedToUid != null
              ? _firestore.doc('staff/$assignedToUid')
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.update(toolRef, toolUpdate);
      }

      await batch.commit();
      debugPrint('Batch history created: $batchId for ${toolIds.length} tools');
      return batchId;
    } catch (e) {
      debugPrint('Error creating batch history: $e');
      throw Exception('Failed to create batch history: $e');
    }
  }

  /// Get history entry by ID
  Future<ToolHistory?> getHistoryById(String id) async {
    try {
      final doc = await _historyCollection.doc(id).get();
      if (doc.exists) {
        return ToolHistory.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting history by ID: $e');
      throw Exception('Failed to get history: $e');
    }
  }

  /// Get all history entries stream
  Stream<List<ToolHistory>> getHistoryStream({int limit = 50}) {
    return _historyCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ToolHistory.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get history for a specific tool
  Stream<List<ToolHistory>> getToolHistoryStream(String toolId) {
    try {
      return _historyCollection
          .where('toolRef', isEqualTo: _firestore.doc('tools/$toolId'))
          .snapshots()
          .map((snapshot) {
            final entries = snapshot.docs
                .map((doc) => ToolHistory.fromFirestore(doc))
                .toList();

            // Sort in memory to avoid Firestore composite index requirement
            entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            return entries;
          });
    } catch (e) {
      debugPrint('Error in getToolHistoryStream: $e');
      // Return empty stream if there's an error
      return Stream.value([]);
    }
  }

  /// Get history for a specific tool using simple query (fallback method)
  Future<List<ToolHistory>> getToolHistorySimple(String toolId) async {
    try {
      // Get all history entries and filter in memory
      final snapshot = await _historyCollection
          .limit(1000) // Reasonable limit to avoid memory issues
          .get();

      final toolRef = _firestore.doc('tools/$toolId');
      final entries = snapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .where((entry) => entry.toolRef.path == toolRef.path)
          .toList();

      // Sort by timestamp descending
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return entries;
    } catch (e) {
      debugPrint('Error getting tool history simple: $e');
      return [];
    }
  }

  /// Get history for a specific staff member
  Stream<List<ToolHistory>> getStaffHistoryStream(String staffUid) {
    return _historyCollection
        .where('by', isEqualTo: _firestore.doc('staff/$staffUid'))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ToolHistory.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get history for tools assigned to a staff member
  Stream<List<ToolHistory>> getAssignedToolsHistoryStream(String staffUid) {
    return _historyCollection
        .where('assignedTo', isEqualTo: _firestore.doc('staff/$staffUid'))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ToolHistory.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get history with pagination and filters
  Future<List<ToolHistory>> getHistoryPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? toolId,
    String? staffUid,
    ToolAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? batchId,
  }) async {
    try {
      Query query = _historyCollection.orderBy('timestamp', descending: true);

      // Apply filters
      if (toolId != null) {
        query = query.where(
          'toolRef',
          isEqualTo: _firestore.doc('tools/$toolId'),
        );
      }

      if (staffUid != null) {
        query = query.where('by', isEqualTo: _firestore.doc('staff/$staffUid'));
      }

      if (actionFilter != null) {
        query = query.where('action', isEqualTo: actionFilter.value);
      }

      if (batchId != null) {
        query = query.where('batchId', isEqualTo: batchId);
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting paginated history: $e');
      throw Exception('Failed to get history: $e');
    }
  }

  /// Get recent activity
  Future<List<ToolHistory>> getRecentActivity({int limit = 10}) async {
    try {
      final snapshot = await _historyCollection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent activity: $e');
      throw Exception('Failed to get recent activity: $e');
    }
  }

  /// Get batch information
  Future<ToolBatch?> getBatchById(String batchId) async {
    try {
      final doc = await _batchCollection.doc(batchId).get();
      if (doc.exists) {
        return ToolBatch.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting batch by ID: $e');
      throw Exception('Failed to get batch: $e');
    }
  }

  /// Get history entries for a batch
  Stream<List<ToolHistory>> getBatchHistoryStream(String batchId) {
    return _historyCollection
        .where('batchId', isEqualTo: batchId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ToolHistory.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get daily activity count
  Future<int> getDailyActivityCount(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await _historyCollection
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting daily activity count: $e');
      return 0;
    }
  }

  /// Get activity count for date range
  Future<int> getActivityCount({
    DateTime? startDate,
    DateTime? endDate,
    String? staffUid,
    ToolAction? actionFilter,
  }) async {
    try {
      Query query = _historyCollection;

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      if (staffUid != null) {
        query = query.where('by', isEqualTo: _firestore.doc('staff/$staffUid'));
      }

      if (actionFilter != null) {
        query = query.where('action', isEqualTo: actionFilter.value);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting activity count: $e');
      return 0;
    }
  }

  /// Get checkout/checkin statistics
  Future<Map<String, int>> getActionStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? staffUid,
  }) async {
    try {
      final stats = <String, int>{};

      for (final action in ToolAction.values) {
        final count = await getActivityCount(
          startDate: startDate,
          endDate: endDate,
          staffUid: staffUid,
          actionFilter: action,
        );
        stats[action.value] = count;
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting action statistics: $e');
      return {};
    }
  }

  /// Get most active staff members
  Future<List<Map<String, dynamic>>> getMostActiveStaff({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    try {
      Query query = _historyCollection;

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      // Count activities by staff member
      final staffCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final history = ToolHistory.fromFirestore(doc);
        final staffId = history.byId;
        staffCounts[staffId] = (staffCounts[staffId] ?? 0) + 1;
      }

      // Sort by count and return top performers
      final sortedStaff = staffCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedStaff
          .take(limit)
          .map((entry) => {'staffId': entry.key, 'activityCount': entry.value})
          .toList();
    } catch (e) {
      debugPrint('Error getting most active staff: $e');
      return [];
    }
  }

  /// Delete history entry (admin only)
  Future<void> deleteHistoryEntry(String id) async {
    try {
      await _historyCollection.doc(id).delete();
      debugPrint('History entry deleted: $id');
    } catch (e) {
      debugPrint('Error deleting history entry: $e');
      throw Exception('Failed to delete history entry: $e');
    }
  }

  /// Update history entry notes
  Future<void> updateHistoryNotes(String id, String notes) async {
    try {
      await _historyCollection.doc(id).update({
        'notes': notes,
        'metadata.updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('History notes updated: $id');
    } catch (e) {
      debugPrint('Error updating history notes: $e');
      throw Exception('Failed to update history notes: $e');
    }
  }

  /// Generate unique batch ID
  String generateBatchId() => _uuid.v4();
}

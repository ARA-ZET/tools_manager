import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing tool history with flatter structure
/// Structure: tool_history/{monthKey}/{dayKey} with transactions array
/// Example: tool_history/10-2025/20 → {transactions: [...]}
/// This reduces nesting and enables efficient month/day based queries
class ToolHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new tool history entry
  /// Automatically organizes into month/day documents with transactions array
  Future<DocumentReference> createToolHistory({
    required DocumentReference toolRef,
    required String action, // 'checkout' or 'checkin'
    required String byStaffUid,
    String? assignedToStaffUid,
    DocumentReference? supervisorRef,
    String? batchId,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      final monthKey =
          '${now.month.toString().padLeft(2, '0')}-${now.year}'; // e.g., "10-2025"
      final dayKey = now.day.toString().padLeft(2, '0'); // e.g., "20"

      // Reference to month document and day document
      final monthDocRef = _firestore.collection('tool_history').doc(monthKey);
      final dayDocRef = monthDocRef.collection('days').doc(dayKey);

      // Transaction data
      final transactionData = {
        'id': '${now.millisecondsSinceEpoch}',
        'toolRef': toolRef,
        'toolId': toolRef.id,
        'action': action,
        'byStaffUid': byStaffUid,
        'assignedToStaffUid': assignedToStaffUid,
        'supervisorRef': supervisorRef,
        'batchId': batchId,
        'notes': notes,
        'timestamp': Timestamp.now(),
        'metadata': metadata ?? {},
      };

      // Get existing day document or create new one
      final dayDoc = await dayDocRef.get();
      final transactions = List<Map<String, dynamic>>.from(
        dayDoc.data()?['transactions'] ?? [],
      );

      // Add new transaction
      transactions.add(transactionData);

      // Write to day document with transactions array
      await dayDocRef.set({
        'monthKey': monthKey,
        'dayKey': dayKey,
        'date':
            '${now.year}-${monthKey.split('-')[0]}-$dayKey', // e.g., "2025-10-20"
        'transactions': transactions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '✅ Tool history created: tool_history/$monthKey/days/$dayKey (${transactions.length} transactions)',
      );

      // Return a fake DocumentReference (since we're not creating individual docs)
      return dayDocRef;
    } catch (e) {
      debugPrint('❌ Error creating tool history: $e');
      rethrow;
    }
  }

  /// Get tool history for a specific date range
  /// Efficiently queries only the relevant month/day documents
  Future<List<Map<String, dynamic>>> getToolHistoryForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? toolId,
    String? staffUid,
    String? action,
    int? limit,
  }) async {
    try {
      final List<Map<String, dynamic>> allTransactions = [];

      // Generate list of month-day combinations to query
      final daysToQuery = _generateDaysToQuery(startDate, endDate);

      for (final dayInfo in daysToQuery) {
        final monthKey = dayInfo['monthKey']!; // e.g., "10-2025"
        final dayKey = dayInfo['dayKey']!; // e.g., "20"

        // Get day document
        final dayDoc = await _firestore
            .collection('tool_history')
            .doc(monthKey)
            .collection('days')
            .doc(dayKey)
            .get();

        if (!dayDoc.exists) continue;

        // Extract transactions array
        final transactions = List<Map<String, dynamic>>.from(
          dayDoc.data()?['transactions'] ?? [],
        );

        for (final transaction in transactions) {
          // Apply timestamp filter
          final timestamp = transaction['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final dateTime = timestamp.toDate();
            if (dateTime.isBefore(startDate) || dateTime.isAfter(endDate)) {
              continue;
            }
          }

          // Apply action filter
          if (action != null && transaction['action'] != action) {
            continue;
          }

          // Apply toolId filter
          if (toolId != null) {
            final toolRef = transaction['toolRef'] as DocumentReference?;
            final toolIdFromTransaction = transaction['toolId'] as String?;
            if (toolRef?.id != toolId && toolIdFromTransaction != toolId) {
              continue;
            }
          }

          // Apply staffUid filter
          if (staffUid != null) {
            final byStaff = transaction['byStaffUid'] as String?;
            final assignedTo = transaction['assignedToStaffUid'] as String?;
            if (byStaff != staffUid && assignedTo != staffUid) {
              continue;
            }
          }

          allTransactions.add(transaction);
        }
      }

      // Sort by timestamp descending
      allTransactions.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate();
        final bTime = (b['timestamp'] as Timestamp?)?.toDate();
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      if (limit != null && allTransactions.length > limit) {
        return allTransactions.take(limit).toList();
      }

      return allTransactions;
    } catch (e) {
      debugPrint('❌ Error getting tool history for date range: $e');
      rethrow;
    }
  }

  /// Generate list of month-day combinations to query between start and end date
  List<Map<String, String>> _generateDaysToQuery(
    DateTime startDate,
    DateTime endDate,
  ) {
    final days = <Map<String, String>>[];
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDate = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(lastDate) ||
        currentDate.isAtSameMomentAs(lastDate)) {
      final monthKey =
          '${currentDate.month.toString().padLeft(2, '0')}-${currentDate.year}';
      final dayKey = currentDate.day.toString().padLeft(2, '0');

      days.add({
        'monthKey': monthKey, // e.g., "10-2025"
        'dayKey': dayKey, // e.g., "20"
      });
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return days;
  }

  /// Get tool history for a specific tool
  Future<List<Map<String, dynamic>>> getToolHistory({
    required String toolId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now();

    return getToolHistoryForDateRange(
      startDate: start,
      endDate: end,
      toolId: toolId,
      limit: limit,
    );
  }

  /// Get recent transactions for today
  Future<List<Map<String, dynamic>>> getTodayTransactions({
    int limit = 100,
  }) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.month.toString().padLeft(2, '0')}-${now.year}';
      final dayKey = now.day.toString().padLeft(2, '0');

      final dayDoc = await _firestore
          .collection('tool_history')
          .doc(monthKey)
          .collection('days')
          .doc(dayKey)
          .get();

      if (!dayDoc.exists) return [];

      // Extract transactions array
      final transactions = List<Map<String, dynamic>>.from(
        dayDoc.data()?['transactions'] ?? [],
      );

      // Sort by timestamp descending
      transactions.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate();
        final bTime = (b['timestamp'] as Timestamp?)?.toDate();
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      // Apply limit
      if (transactions.length > limit) {
        return transactions.take(limit).toList();
      }

      return transactions;
    } catch (e) {
      debugPrint('❌ Error getting today transactions: $e');
      return [];
    }
  }

  /// Get transactions for current month
  Future<List<Map<String, dynamic>>> getCurrentMonthTransactions({
    int limit = 500,
  }) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    return getToolHistoryForDateRange(
      startDate: firstDayOfMonth,
      endDate: lastDayOfMonth,
      limit: limit,
    );
  }

  /// Stream tool history for a specific date (real-time updates)
  Stream<List<Map<String, dynamic>>> streamDailyTransactions({
    DateTime? date,
    int limit = 100,
  }) {
    final targetDate = date ?? DateTime.now();
    final monthKey =
        '${targetDate.month.toString().padLeft(2, '0')}-${targetDate.year}';
    final dayKey = targetDate.day.toString().padLeft(2, '0');

    return _firestore
        .collection('tool_history')
        .doc(monthKey)
        .collection('days')
        .doc(dayKey)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return <Map<String, dynamic>>[];

          // Extract transactions array
          final transactions = List<Map<String, dynamic>>.from(
            snapshot.data()?['transactions'] ?? [],
          );

          // Sort by timestamp descending
          transactions.sort((a, b) {
            final aTime = (a['timestamp'] as Timestamp?)?.toDate();
            final bTime = (b['timestamp'] as Timestamp?)?.toDate();
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          // Apply limit
          if (transactions.length > limit) {
            return transactions.take(limit).toList();
          }

          return transactions;
        });
  }

  /// Get transaction statistics for a date range
  Future<Map<String, int>> getTransactionStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await getToolHistoryForDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    final checkouts = transactions
        .where((t) => t['action'] == 'checkout')
        .length;
    final checkins = transactions.where((t) => t['action'] == 'checkin').length;

    return {
      'total': transactions.length,
      'checkouts': checkouts,
      'checkins': checkins,
    };
  }

  /// Delete old transactions (for data cleanup/archival)
  Future<void> deleteTransactionsBefore(DateTime date) async {
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      // Note: This is a basic implementation
      // For production, consider using Cloud Functions for bulk deletion
      debugPrint('⚠️ Delete transactions before $year-$month-$day');
      debugPrint(
        '⚠️ Implement bulk deletion via Cloud Functions for efficiency',
      );
    } catch (e) {
      debugPrint('❌ Error deleting old transactions: $e');
      rethrow;
    }
  }

  /// Migrate old flat structure to new hierarchical structure
  /// Run this once to migrate existing data
  Future<void> migrateOldHistory() async {
    try {
      debugPrint('🔄 Starting migration of old tool history...');

      // Get old transactions from flat collection
      final oldSnapshot = await _firestore
          .collection('tool_history')
          .orderBy('timestamp')
          .get();

      int migrated = 0;
      int failed = 0;

      for (final doc in oldSnapshot.docs) {
        try {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

          if (timestamp == null) {
            failed++;
            continue;
          }

          final year = timestamp.year.toString();
          final month = timestamp.month.toString().padLeft(2, '0');
          final day = timestamp.day.toString().padLeft(2, '0');

          // Create in new structure
          await _firestore
              .collection('tool_history')
              .doc(year)
              .collection(month)
              .doc(day)
              .collection('transactions')
              .doc(doc.id)
              .set({
                ...data,
                'dateInfo': {
                  'year': year,
                  'month': month,
                  'day': day,
                  'yearMonth': '$year-$month',
                  'fullDate': '$year-$month-$day',
                },
                'migratedAt': FieldValue.serverTimestamp(),
              });

          migrated++;

          if (migrated % 100 == 0) {
            debugPrint('📊 Migrated $migrated transactions...');
          }
        } catch (e) {
          debugPrint('❌ Failed to migrate doc ${doc.id}: $e');
          failed++;
        }
      }

      debugPrint('✅ Migration complete: $migrated migrated, $failed failed');
    } catch (e) {
      debugPrint('❌ Error during migration: $e');
      rethrow;
    }
  }

  /// Get consumable transactions for current month (for audit screen)
  /// Consumable transactions are stored in consumable_transactions collection
  /// and have batch ID in their notes field
  Future<List<Map<String, dynamic>>>
  getCurrentMonthConsumableTransactions() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('consumable_transactions')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          )
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> transactions = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Extract batch ID from notes if present
        String? batchId;
        final notes = data['notes'] as String?;
        if (notes != null && notes.contains('Batch ID:')) {
          final batchIdMatch = RegExp(
            r'Batch ID:\s*(BATCH_\d+)',
          ).firstMatch(notes);
          if (batchIdMatch != null) {
            batchId = batchIdMatch.group(1);
          }
        }

        // Resolve references to get metadata
        final consumableRef = data['consumableRef'] as DocumentReference?;
        final usedByRef = data['usedBy'] as DocumentReference?;
        final assignedToRef = data['assignedTo'] as DocumentReference?;

        String? consumableName;
        String? staffName;
        String? assignedToName;

        if (consumableRef != null) {
          try {
            final consumableDoc = await consumableRef.get();
            final consumableData =
                consumableDoc.data() as Map<String, dynamic>?;
            consumableName = consumableData?['name'] as String?;
          } catch (e) {
            debugPrint('❌ Error fetching consumable: $e');
          }
        }

        if (usedByRef != null) {
          try {
            final staffDoc = await usedByRef.get();
            final staffData = staffDoc.data() as Map<String, dynamic>?;
            staffName = staffData?['name'] as String?;
          } catch (e) {
            debugPrint('❌ Error fetching staff: $e');
          }
        }

        if (assignedToRef != null) {
          try {
            final staffDoc = await assignedToRef.get();
            final staffData = staffDoc.data() as Map<String, dynamic>?;
            assignedToName = staffData?['name'] as String?;
          } catch (e) {
            debugPrint('❌ Error fetching assigned to staff: $e');
          }
        }

        transactions.add({
          'id': doc.id,
          'type': 'consumable', // Mark as consumable transaction
          'action': data['action'] ?? 'usage',
          'consumableRef': consumableRef,
          'consumableName': consumableName ?? 'Unknown Consumable',
          'quantity': data['quantityChange'] ?? 0.0,
          'usedBy': usedByRef,
          'usedByName': staffName ?? 'Unknown', // Admin who processed
          'assignedTo': assignedToRef,
          'assignedToName': assignedToName ?? 'Unknown', // Worker assigned to
          'batchId': batchId,
          'notes': notes,
          'timestamp': data['timestamp'],
          'metadata': {
            'consumableName': consumableName ?? 'Unknown Consumable',
            'staffName': assignedToName ?? 'Unknown', // Worker assigned to
            'adminName': staffName ?? 'Unknown', // Admin who processed
            'quantity': (data['quantityChange'] as num?)?.abs() ?? 0.0,
          },
        });
      }

      debugPrint(
        '✅ Fetched ${transactions.length} consumable transactions for current month',
      );
      return transactions;
    } catch (e) {
      debugPrint('❌ Error fetching consumable transactions: $e');
      return [];
    }
  }
}

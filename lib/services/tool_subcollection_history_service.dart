import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for reading tool history from per-tool subcollections
/// Structure: tools/{toolId}/history/{monthKey} with transactions array
/// This is more efficient for tool-specific history queries
class ToolSubcollectionHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get history for a specific tool from its subcollection
  /// This is much faster than querying global history filtered by tool
  Future<List<Map<String, dynamic>>> getToolHistory({
    required String toolId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 90));
      final end = endDate ?? DateTime.now();

      // Generate month keys to query
      final monthKeys = _generateMonthKeys(start, end);
      final List<Map<String, dynamic>> allTransactions = [];

      debugPrint(
        '📊 Querying tool $toolId history for ${monthKeys.length} months',
      );

      // Query each month's history document
      for (final monthKey in monthKeys) {
        final monthDoc = await _firestore
            .collection('tools')
            .doc(toolId)
            .collection('history')
            .doc(monthKey)
            .get();

        if (!monthDoc.exists) {
          debugPrint('  ⚠️ No history for month $monthKey');
          continue;
        }

        // Extract transactions array
        final transactions = List<Map<String, dynamic>>.from(
          monthDoc.data()?['transactions'] ?? [],
        );

        debugPrint(
          '  ✅ Found ${transactions.length} transactions for $monthKey',
        );

        // Filter by date range
        for (final transaction in transactions) {
          final timestamp = transaction['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final dateTime = timestamp.toDate();
            if (dateTime.isBefore(start) || dateTime.isAfter(end)) {
              continue; // Skip transactions outside date range
            }
          }

          allTransactions.add(transaction);
        }
      }

      // Sort by timestamp descending (newest first)
      allTransactions.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate();
        final bTime = (b['timestamp'] as Timestamp?)?.toDate();
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      // Apply limit
      if (allTransactions.length > limit) {
        debugPrint('📋 Limiting results to $limit transactions');
        return allTransactions.take(limit).toList();
      }

      debugPrint(
        '✅ Loaded ${allTransactions.length} transactions for tool $toolId',
      );
      return allTransactions;
    } catch (e) {
      debugPrint('❌ Error getting tool subcollection history: $e');
      return [];
    }
  }

  /// Stream real-time updates for a tool's current month history
  Stream<List<Map<String, dynamic>>> streamToolHistory({
    required String toolId,
    int limit = 100,
  }) {
    final now = DateTime.now();
    final monthKey = '${now.month.toString().padLeft(2, '0')}-${now.year}';

    return _firestore
        .collection('tools')
        .doc(toolId)
        .collection('history')
        .doc(monthKey)
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

  /// Get recent transactions for a tool (last 30 days)
  Future<List<Map<String, dynamic>>> getRecentToolHistory({
    required String toolId,
    int daysBack = 30,
    int limit = 50,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: daysBack));
    final endDate = DateTime.now();

    return getToolHistory(
      toolId: toolId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get tool statistics from its subcollection history
  Future<Map<String, dynamic>> getToolStats({
    required String toolId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getToolHistory(
      toolId: toolId,
      startDate: startDate,
      endDate: endDate,
      limit: 10000, // Get all for stats
    );

    final checkouts = transactions
        .where((t) => t['action'] == 'checkout')
        .length;
    final checkins = transactions.where((t) => t['action'] == 'checkin').length;

    // Calculate usage patterns
    final Map<String, int> userCounts = {};
    final Map<String, int> batchCounts = {};

    for (final transaction in transactions) {
      // Count by user
      final assignedTo = transaction['assignedToStaffUid'] as String?;
      if (assignedTo != null) {
        userCounts[assignedTo] = (userCounts[assignedTo] ?? 0) + 1;
      }

      // Count by batch
      final batchId = transaction['batchId'] as String?;
      if (batchId != null) {
        batchCounts[batchId] = (batchCounts[batchId] ?? 0) + 1;
      }
    }

    return {
      'total': transactions.length,
      'checkouts': checkouts,
      'checkins': checkins,
      'uniqueUsers': userCounts.length,
      'batchOperations': batchCounts.length,
      'mostActiveUser': userCounts.isNotEmpty
          ? userCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
    };
  }

  /// Generate list of month keys between start and end date
  /// Returns format: ["10-2025", "11-2025", ...]
  List<String> _generateMonthKeys(DateTime startDate, DateTime endDate) {
    final monthKeys = <String>[];
    var currentDate = DateTime(startDate.year, startDate.month, 1);
    final lastDate = DateTime(endDate.year, endDate.month, 1);

    while (currentDate.isBefore(lastDate) ||
        currentDate.isAtSameMomentAs(lastDate)) {
      final monthKey =
          '${currentDate.month.toString().padLeft(2, '0')}-${currentDate.year}';
      monthKeys.add(monthKey);

      // Move to next month
      if (currentDate.month == 12) {
        currentDate = DateTime(currentDate.year + 1, 1, 1);
      } else {
        currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
      }
    }

    return monthKeys;
  }

  /// Check if tool has any history
  Future<bool> hasHistory(String toolId) async {
    try {
      final historySnapshot = await _firestore
          .collection('tools')
          .doc(toolId)
          .collection('history')
          .limit(1)
          .get();

      return historySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking tool history: $e');
      return false;
    }
  }

  /// Get the most recent transaction for a tool
  Future<Map<String, dynamic>?> getLastTransaction(String toolId) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.month.toString().padLeft(2, '0')}-${now.year}';

      final monthDoc = await _firestore
          .collection('tools')
          .doc(toolId)
          .collection('history')
          .doc(monthKey)
          .get();

      if (!monthDoc.exists) {
        // Try previous month
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonthKey =
            '${prevMonth.toString().padLeft(2, '0')}-$prevYear';

        final prevMonthDoc = await _firestore
            .collection('tools')
            .doc(toolId)
            .collection('history')
            .doc(prevMonthKey)
            .get();

        if (!prevMonthDoc.exists) return null;

        final transactions = List<Map<String, dynamic>>.from(
          prevMonthDoc.data()?['transactions'] ?? [],
        );

        if (transactions.isEmpty) return null;

        // Sort and return latest
        transactions.sort((a, b) {
          final aTime = (a['timestamp'] as Timestamp?)?.toDate();
          final bTime = (b['timestamp'] as Timestamp?)?.toDate();
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return transactions.first;
      }

      final transactions = List<Map<String, dynamic>>.from(
        monthDoc.data()?['transactions'] ?? [],
      );

      if (transactions.isEmpty) return null;

      // Sort and return latest
      transactions.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp?)?.toDate();
        final bTime = (b['timestamp'] as Timestamp?)?.toDate();
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return transactions.first;
    } catch (e) {
      debugPrint('❌ Error getting last transaction: $e');
      return null;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tool.dart';
import '../models/staff.dart';
import '../services/tool_service.dart';
import '../services/staff_service.dart';
import '../services/id_mapping_service.dart';
import '../services/tool_history_service.dart';

/// Enhanced tool transaction service using readable IDs instead of UIDs
class SecureToolTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ToolService _toolService = ToolService();
  final StaffService _staffService = StaffService();
  final IdMappingService _idMapping = IdMappingService();
  final ToolHistoryService _historyService = ToolHistoryService();

  /// Check out a tool to a staff member using readable IDs
  Future<bool> checkOutTool({
    required String toolUniqueId,
    required String staffJobCode,
    String? notes,
    String? adminName,
    String? batchId, // Optional batch ID for grouped operations
  }) async {
    try {
      // Get the actual UIDs for database operations
      final toolUid = await _idMapping.getToolUidFromUniqueId(toolUniqueId);
      final staffUid = await _idMapping.getStaffUidFromJobCode(staffJobCode);

      if (toolUid == null) {
        throw Exception('Tool not found: $toolUniqueId');
      }

      if (staffUid == null) {
        throw Exception('Staff member not found: $staffJobCode');
      }

      // Get tool and staff data for validation
      final tool = await _toolService.getToolById(toolUid);
      final staff = await _staffService.getStaffById(staffUid);

      if (tool == null) {
        throw Exception('Tool data not found: $toolUniqueId');
      }

      if (staff == null) {
        throw Exception('Staff data not found: $staffJobCode');
      }

      if (!tool.isAvailable) {
        throw Exception('Tool is already checked out: $toolUniqueId');
      }

      final toolRef = _firestore.collection('tools').doc(toolUid);
      final now = DateTime.now();

      // Create transaction using UIDs internally (update tool + staff only)
      await _firestore.runTransaction((transaction) async {
        // Update tool status with last assignment data
        transaction.update(toolRef, {
          'status': 'checked_out',
          'currentHolder': _firestore.collection('staff').doc(staffUid),
          'lastAssignedToName': staff.fullName,
          'lastAssignedToJobCode': staffJobCode,
          'lastAssignedByName': adminName ?? 'Unknown',
          'lastAssignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update staff assigned tools with readable ID
        final staffRef = _firestore.collection('staff').doc(staffUid);
        transaction.update(staffRef, {
          'assignedToolIds': FieldValue.arrayUnion([
            toolUniqueId,
          ]), // Use readable ID
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Write to tool's history subcollection (AFTER transaction completes)
      final monthKey =
          '${now.month.toString().padLeft(2, '0')}-${now.year}'; // e.g., "10-2025"
      final historyRef = toolRef.collection('history').doc(monthKey);

      try {
        // Get existing month document or create new one
        final historyDoc = await historyRef.get();
        final transactions = List<Map<String, dynamic>>.from(
          historyDoc.data()?['transactions'] ?? [],
        );

        // Add new transaction to the month's transactions array
        final transactionData = {
          'id': '${now.millisecondsSinceEpoch}',
          'action': 'checkout',
          'timestamp': Timestamp.now(),
          'staffName': staff.fullName,
          'staffJobCode': staffJobCode,
          'staffUid': staffUid,
          'assignedByName': adminName ?? 'Unknown',
          'notes': notes,
        };

        // Add batch info if this is part of a batch operation
        if (batchId != null) {
          transactionData['batchId'] = batchId;
          transactionData['isBatch'] = true;
        }

        transactions.add(transactionData);

        // Write to subcollection
        await historyRef.set({
          'monthKey': monthKey,
          'toolId': toolUid,
          'toolUniqueId': toolUniqueId,
          'transactions': transactions,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '✅ Written to tool subcollection: tools/$toolUid/history/$monthKey${batchId != null ? " (batch: $batchId)" : ""}',
        );
      } catch (e) {
        debugPrint('⚠️ Error writing to tool subcollection: $e');
        // Continue anyway - tool checkout succeeded
      }

      // Create readable history entry using hierarchical structure (global history)
      try {
        await _historyService.createToolHistory(
          toolRef: toolRef,
          action: 'checkout',
          byStaffUid: staff.uid,
          assignedToStaffUid: staff.uid,
          notes: notes,
          metadata: {
            'staffName': staff.fullName,
            'staffJobCode': staffJobCode,
            'toolName': tool.displayName,
            'toolUniqueId': toolUniqueId,
            'toolBrand': tool.brand,
            'toolModel': tool.model,
            'adminName': adminName ?? 'Unknown',
          },
        );
        debugPrint('✅ Written to global history');
      } catch (e) {
        debugPrint('⚠️ Error writing to global history: $e');
        // Continue anyway - tool checkout succeeded
      }

      debugPrint(
        'Tool checked out: $toolUniqueId to $staffJobCode (${staff.fullName})',
      );
      return true;
    } catch (e) {
      debugPrint('Error checking out tool: $e');
      return false;
    }
  }

  /// Check in a tool using readable ID
  Future<bool> checkInTool({
    required String toolUniqueId,
    String? notes,
    String? adminName,
    String? batchId, // Optional batch ID for grouped operations
  }) async {
    try {
      // Get the actual UID for database operations
      final toolUid = await _idMapping.getToolUidFromUniqueId(toolUniqueId);

      if (toolUid == null) {
        throw Exception('Tool not found: $toolUniqueId');
      }

      // Get tool data
      final tool = await _toolService.getToolById(toolUid);
      if (tool == null) {
        throw Exception('Tool data not found: $toolUniqueId');
      }

      if (tool.isAvailable) {
        throw Exception('Tool is already available: $toolUniqueId');
      }

      // Get current holder information
      String? previousStaffJobCode;
      Staff? previousStaff;

      if (tool.currentHolder != null) {
        previousStaffJobCode = await _idMapping.getStaffJobCodeFromUid(
          tool.currentHolder!.id,
        );
        if (previousStaffJobCode != null) {
          final staffUid = await _idMapping.getStaffUidFromJobCode(
            previousStaffJobCode,
          );
          if (staffUid != null) {
            previousStaff = await _staffService.getStaffById(staffUid);
          }
        }
      }

      final toolRef = _firestore.collection('tools').doc(toolUid);
      final now = DateTime.now();

      // Create transaction (update tool + staff only)
      await _firestore.runTransaction((transaction) async {
        // Update tool status with checkin data
        transaction.update(toolRef, {
          'status': 'available',
          'currentHolder': null,
          'lastCheckinAt': FieldValue.serverTimestamp(),
          'lastCheckinByName': previousStaff?.fullName ?? 'Unknown',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update staff assigned tools if staff exists
        if (previousStaffJobCode != null) {
          final staffUid = await _idMapping.getStaffUidFromJobCode(
            previousStaffJobCode,
          );
          if (staffUid != null) {
            final staffRef = _firestore.collection('staff').doc(staffUid);
            transaction.update(staffRef, {
              'assignedToolIds': FieldValue.arrayRemove([
                toolUniqueId,
              ]), // Use readable ID
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      // Write to tool's history subcollection (AFTER transaction completes)
      final monthKey = '${now.month.toString().padLeft(2, '0')}-${now.year}';
      final historyRef = toolRef.collection('history').doc(monthKey);

      try {
        final historyDoc = await historyRef.get();
        final transactions = List<Map<String, dynamic>>.from(
          historyDoc.data()?['transactions'] ?? [],
        );

        final transactionData = {
          'id': '${now.millisecondsSinceEpoch}',
          'action': 'checkin',
          'timestamp': Timestamp.now(),
          'staffName': previousStaff?.fullName ?? 'Unknown',
          'staffJobCode': previousStaffJobCode ?? 'unknown',
          'staffUid': previousStaff?.uid ?? 'unknown',
          'returnedByName': adminName ?? 'Unknown',
          'notes': notes,
        };

        // Add batch info if this is part of a batch operation
        if (batchId != null) {
          transactionData['batchId'] = batchId;
          transactionData['isBatch'] = true;
        }

        transactions.add(transactionData);

        await historyRef.set({
          'monthKey': monthKey,
          'toolId': toolUid,
          'toolUniqueId': toolUniqueId,
          'transactions': transactions,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '✅ Written to tool subcollection: tools/$toolUid/history/$monthKey${batchId != null ? " (batch: $batchId)" : ""}',
        );
      } catch (e) {
        debugPrint('⚠️ Error writing to tool subcollection: $e');
        // Continue anyway - tool checkin succeeded
      }

      // Create readable history entry using hierarchical structure (global history)
      try {
        await _historyService.createToolHistory(
          toolRef: toolRef,
          action: 'checkin',
          byStaffUid: previousStaff?.uid ?? 'unknown',
          assignedToStaffUid: previousStaff?.uid,
          notes: notes,
          metadata: {
            'staffName': previousStaff?.fullName ?? 'Unknown',
            'staffJobCode': previousStaffJobCode ?? 'unknown',
            'toolName': tool.displayName,
            'toolUniqueId': toolUniqueId,
            'toolBrand': tool.brand,
            'toolModel': tool.model,
            'adminName': adminName ?? 'Unknown',
          },
        );
        debugPrint('✅ Written to global history');
      } catch (e) {
        debugPrint('⚠️ Error writing to global history: $e');
        // Continue anyway - tool checkin succeeded
      }

      debugPrint('Tool checked in: $toolUniqueId');
      return true;
    } catch (e) {
      debugPrint('Error checking in tool: $e');
      return false;
    }
  }

  /// Get tools assigned to a staff member using job code
  Future<List<Tool>> getToolsAssignedToStaff(String staffJobCode) async {
    try {
      final staffUid = await _idMapping.getStaffUidFromJobCode(staffJobCode);
      if (staffUid == null) {
        debugPrint('Staff not found: $staffJobCode');
        return [];
      }

      final staffRef = _firestore.collection('staff').doc(staffUid);
      final querySnapshot = await _firestore
          .collection('tools')
          .where('currentHolder', isEqualTo: staffRef)
          .where('status', isEqualTo: 'checked_out')
          .get();

      return querySnapshot.docs.map((doc) => Tool.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting assigned tools: $e');
      return [];
    }
  }

  /// Get readable tool history for a specific tool
  /// Returns last 90 days of history by default
  Future<List<Map<String, dynamic>>> getReadableToolHistory(
    String toolUniqueId, {
    int daysBack = 90,
    int limit = 50,
  }) async {
    try {
      final toolUid = await _idMapping.getToolUidFromUniqueId(toolUniqueId);
      if (toolUid == null) {
        debugPrint('Tool not found: $toolUniqueId');
        return [];
      }

      // Try to get from tool's subcollection first (faster, more efficient)
      final toolRef = _firestore.collection('tools').doc(toolUid);
      final history = await _getToolSubcollectionHistory(
        toolRef,
        daysBack: daysBack,
        limit: limit,
      );

      if (history.isNotEmpty) {
        debugPrint(
          '✅ Loaded ${history.length} history entries from tool subcollection',
        );
        return history;
      }

      // Fallback to global history if subcollection is empty (legacy tools)
      debugPrint('⚠️ Tool subcollection empty, falling back to global history');
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      final globalHistory = await _historyService.getToolHistoryForDateRange(
        toolId: toolUid,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      return globalHistory;
    } catch (e) {
      debugPrint('Error getting tool history: $e');
      return [];
    }
  }

  /// Get history from tool's subcollection (tools/{toolId}/history/{monthKey})
  Future<List<Map<String, dynamic>>> _getToolSubcollectionHistory(
    DocumentReference toolRef, {
    required int daysBack,
    required int limit,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysBack));

      // Generate month keys to query (e.g., ["10-2025", "09-2025", "08-2025"])
      final monthKeys = <String>[];
      var currentDate = now;
      while (currentDate.isAfter(startDate) ||
          currentDate.isAtSameMomentAs(startDate)) {
        final monthKey =
            '${currentDate.month.toString().padLeft(2, '0')}-${currentDate.year}';
        if (!monthKeys.contains(monthKey)) {
          monthKeys.add(monthKey);
        }
        currentDate = DateTime(currentDate.year, currentDate.month - 1, 1);

        // Safety limit: don't query more than 12 months
        if (monthKeys.length >= 12) break;
      }

      final allTransactions = <Map<String, dynamic>>[];

      // Query each month document
      for (final monthKey in monthKeys) {
        final monthDoc = await toolRef
            .collection('history')
            .doc(monthKey)
            .get();

        if (monthDoc.exists) {
          final data = monthDoc.data();
          final transactions = List<Map<String, dynamic>>.from(
            data?['transactions'] ?? [],
          );

          // Convert transactions to readable format
          for (final transaction in transactions) {
            final transactionData = {
              'id': transaction['id'],
              'action': transaction['action'],
              'timestamp': transaction['timestamp'],
              'notes': transaction['notes'] ?? '',
              'staffId': transaction['staffUid'],
              'metadata': {
                'staffName': transaction['staffName'],
                'staffJobCode': transaction['staffJobCode'],
                'adminName':
                    transaction['assignedByName'] ??
                    transaction['returnedByName'] ??
                    'System',
              },
            };

            // Include batch information if present
            if (transaction['batchId'] != null) {
              transactionData['batchId'] = transaction['batchId'];
              transactionData['isBatch'] = transaction['isBatch'] ?? true;
            }

            allTransactions.add(transactionData);
          }
        }
      }

      // Sort by timestamp (newest first) and apply limit
      allTransactions.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return allTransactions.take(limit).toList();
    } catch (e) {
      debugPrint('Error reading tool subcollection history: $e');
      return [];
    }
  }

  /// Get readable history for a staff member
  /// Returns last 90 days of history by default
  Future<List<Map<String, dynamic>>> getReadableStaffHistory(
    String staffJobCode, {
    int daysBack = 90,
    int limit = 50,
  }) async {
    try {
      final staffUid = await _idMapping.getStaffUidFromJobCode(staffJobCode);
      if (staffUid == null) {
        debugPrint('Staff not found: $staffJobCode');
        return [];
      }

      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      final history = await _historyService.getToolHistoryForDateRange(
        staffUid: staffUid,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      return history;
    } catch (e) {
      debugPrint('Error getting staff history: $e');
      return [];
    }
  }

  /// Get recent transactions with readable IDs
  /// Defaults to today's transactions
  Future<List<Map<String, dynamic>>> getRecentReadableTransactions({
    int limit = 20,
    int daysBack = 1,
  }) async {
    try {
      if (daysBack == 1) {
        // Optimize for today's transactions
        return await _historyService.getTodayTransactions(limit: limit);
      } else {
        // Query date range
        final endDate = DateTime.now();
        final startDate = endDate.subtract(Duration(days: daysBack));
        return await _historyService.getToolHistoryForDateRange(
          startDate: startDate,
          endDate: endDate,
          limit: limit,
        );
      }
    } catch (e) {
      debugPrint('Error getting recent transactions: $e');
      return [];
    }
  }

  /// Get tool status info using readable IDs
  Future<Map<String, dynamic>?> getReadableToolStatusInfo(
    String toolUniqueId,
  ) async {
    try {
      final toolUid = await _idMapping.getToolUidFromUniqueId(toolUniqueId);
      if (toolUid == null) return null;

      final tool = await _toolService.getToolById(toolUid);
      if (tool == null) return null;

      Staff? assignedStaff;
      String? assignedStaffJobCode;

      if (tool.currentHolder != null) {
        assignedStaffJobCode = await _idMapping.getStaffJobCodeFromUid(
          tool.currentHolder!.id,
        );
        if (assignedStaffJobCode != null) {
          final staffUid = await _idMapping.getStaffUidFromJobCode(
            assignedStaffJobCode,
          );
          if (staffUid != null) {
            assignedStaff = await _staffService.getStaffById(staffUid);
          }
        }
      }

      return {
        'tool': tool,
        'assignedStaff': assignedStaff,
        'assignedStaffJobCode': assignedStaffJobCode,
        'canCheckOut': tool.isAvailable,
        'canCheckIn': !tool.isAvailable,
        'toolUniqueId': toolUniqueId,
      };
    } catch (e) {
      debugPrint('Error getting tool status info: $e');
      return null;
    }
  }

  /// Batch operations using readable IDs
  Future<Map<String, bool>> batchCheckOutTools({
    required List<String> toolUniqueIds,
    required String staffJobCode,
    String? notes,
    String? adminName,
  }) async {
    final results = <String, bool>{};

    // Generate batch ID for grouping these operations
    final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';
    final batchNotes = notes != null
        ? 'BATCH: $notes'
        : 'Batch checkout ($batchId)';

    debugPrint(
      '🔄 Starting batch checkout: $batchId (${toolUniqueIds.length} tools)',
    );

    for (final toolUniqueId in toolUniqueIds) {
      final success = await checkOutTool(
        toolUniqueId: toolUniqueId,
        staffJobCode: staffJobCode,
        notes: batchNotes,
        adminName: adminName,
        batchId: batchId, // Pass batch ID to include in subcollection
      );
      results[toolUniqueId] = success;
    }

    debugPrint(
      '✅ Batch checkout complete: $batchId (${results.values.where((v) => v).length}/${toolUniqueIds.length} succeeded)',
    );

    return results;
  }

  /// Batch check in using readable IDs
  Future<Map<String, bool>> batchCheckInTools({
    required List<String> toolUniqueIds,
    String? notes,
    String? adminName,
  }) async {
    final results = <String, bool>{};

    // Generate batch ID for grouping these operations
    final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';
    final batchNotes = notes != null
        ? 'BATCH: $notes'
        : 'Batch checkin ($batchId)';

    debugPrint(
      '🔄 Starting batch checkin: $batchId (${toolUniqueIds.length} tools)',
    );

    for (final toolUniqueId in toolUniqueIds) {
      final success = await checkInTool(
        toolUniqueId: toolUniqueId,
        notes: batchNotes,
        adminName: adminName,
        batchId: batchId, // Pass batch ID to include in subcollection
      );
      results[toolUniqueId] = success;
    }

    debugPrint(
      '✅ Batch checkin complete: $batchId (${results.values.where((v) => v).length}/${toolUniqueIds.length} succeeded)',
    );

    return results;
  }

  /// Initialize the service
  Future<void> initialize() async {
    await _idMapping.initialize();
  }
}

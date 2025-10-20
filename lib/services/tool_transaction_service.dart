import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tool.dart';
import '../models/staff.dart';
import '../models/tool_history.dart';
import 'tool_service.dart';
import 'staff_service.dart';

/// Service for handling tool checkout/checkin transactions
class ToolTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ToolService _toolService = ToolService();
  final StaffService _staffService = StaffService();

  /// Check out a single tool to a staff member
  Future<bool> checkOutTool({
    required String toolId,
    required String staffId,
    String? notes,
  }) async {
    try {
      // Get tool and staff data
      final tool = await _toolService.getToolByUniqueId(toolId);
      final staff = await _staffService.getStaffById(staffId);

      if (tool == null) {
        throw Exception('Tool not found: $toolId');
      }

      if (staff == null) {
        throw Exception('Staff member not found: $staffId');
      }

      if (!tool.isAvailable) {
        throw Exception('Tool is already checked out: $toolId');
      }

      // Create transaction
      await _firestore.runTransaction((transaction) async {
        // Update tool status
        final toolRef = _firestore.collection('tools').doc(tool.id);
        transaction.update(toolRef, {
          'status': 'checked_out',
          'currentHolder': _firestore.collection('staff').doc(staffId),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update staff assigned tools
        final staffRef = _firestore.collection('staff').doc(staffId);
        transaction.update(staffRef, {
          'assignedToolIds': FieldValue.arrayUnion([toolId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create tool history entry
        final historyRef = _firestore.collection('tool_history').doc();
        transaction.set(
          historyRef,
          ToolHistory(
            id: historyRef.id,
            toolRef: _firestore.collection('tools').doc(tool.id),
            action: ToolAction.checkout,
            byRef: _firestore.collection('staff').doc(staffId),
            assignedToRef: _firestore.collection('staff').doc(staffId),
            timestamp: DateTime.now(),
            notes: notes,
            metadata: {
              'staffName': staff.fullName,
              'toolName': tool.displayName,
            },
          ).toFirestore(),
        );
      });

      debugPrint('Tool checked out successfully: $toolId to ${staff.fullName}');
      return true;
    } catch (e) {
      debugPrint('Error checking out tool: $e');
      return false;
    }
  }

  /// Check in a single tool
  Future<bool> checkInTool({required String toolId, String? notes}) async {
    try {
      // Get tool data
      final tool = await _toolService.getToolByUniqueId(toolId);

      if (tool == null) {
        throw Exception('Tool not found: $toolId');
      }

      if (tool.isAvailable) {
        throw Exception('Tool is already available: $toolId');
      }

      String? previousStaffId;
      if (tool.currentHolder != null) {
        previousStaffId = tool.currentHolder!.id;
      }

      Staff? staff;
      if (previousStaffId != null) {
        staff = await _staffService.getStaffById(previousStaffId);
      }

      // Create transaction
      await _firestore.runTransaction((transaction) async {
        // Update tool status
        final toolRef = _firestore.collection('tools').doc(tool.id);
        transaction.update(toolRef, {
          'status': 'available',
          'currentHolder': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update staff assigned tools if staff exists
        if (previousStaffId != null) {
          final staffRef = _firestore.collection('staff').doc(previousStaffId);
          transaction.update(staffRef, {
            'assignedToolIds': FieldValue.arrayRemove([toolId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Create tool history entry
        final historyRef = _firestore.collection('tool_history').doc();
        transaction.set(
          historyRef,
          ToolHistory(
            id: historyRef.id,
            toolRef: _firestore.collection('tools').doc(tool.id),
            action: ToolAction.checkin,
            byRef: previousStaffId != null
                ? _firestore.collection('staff').doc(previousStaffId)
                : _firestore.collection('staff').doc('system'),
            timestamp: DateTime.now(),
            notes: notes,
            metadata: {
              'staffName': staff?.fullName ?? 'Unknown',
              'toolName': tool.displayName,
            },
          ).toFirestore(),
        );
      });

      debugPrint('Tool checked in successfully: $toolId');
      return true;
    } catch (e) {
      debugPrint('Error checking in tool: $e');
      return false;
    }
  }

  /// Batch check out multiple tools to a staff member
  Future<Map<String, bool>> batchCheckOutTools({
    required List<String> toolIds,
    required String staffId,
    String? notes,
  }) async {
    final results = <String, bool>{};

    for (final toolId in toolIds) {
      final success = await checkOutTool(
        toolId: toolId,
        staffId: staffId,
        notes: notes,
      );
      results[toolId] = success;
    }

    return results;
  }

  /// Batch check in multiple tools
  Future<Map<String, bool>> batchCheckInTools({
    required List<String> toolIds,
    String? notes,
  }) async {
    final results = <String, bool>{};

    for (final toolId in toolIds) {
      final success = await checkInTool(toolId: toolId, notes: notes);
      results[toolId] = success;
    }

    return results;
  }

  /// Get tools assigned to a staff member
  Future<List<Tool>> getToolsAssignedToStaff(String staffId) async {
    try {
      final staffRef = _firestore.collection('staff').doc(staffId);
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

  /// Get tool history for a specific tool
  Future<List<ToolHistory>> getToolHistory(String toolId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tool_history')
          .where('toolId', isEqualTo: toolId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tool history: $e');
      return [];
    }
  }

  /// Get transaction history for a staff member
  Future<List<ToolHistory>> getStaffHistory(String staffId) async {
    try {
      final querySnapshot = await _firestore
          .collection('tool_history')
          .where('staffId', isEqualTo: staffId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting staff history: $e');
      return [];
    }
  }

  /// Get recent transactions (for dashboard)
  Future<List<ToolHistory>> getRecentTransactions({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('tool_history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ToolHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent transactions: $e');
      return [];
    }
  }

  /// Check if tool can be checked out
  Future<bool> canCheckOutTool(String toolId) async {
    try {
      final tool = await _toolService.getToolByUniqueId(toolId);
      return tool?.isAvailable ?? false;
    } catch (e) {
      debugPrint('Error checking tool availability: $e');
      return false;
    }
  }

  /// Check if tool can be checked in
  Future<bool> canCheckInTool(String toolId) async {
    try {
      final tool = await _toolService.getToolByUniqueId(toolId);
      return tool != null && !tool.isAvailable;
    } catch (e) {
      debugPrint('Error checking tool check-in status: $e');
      return false;
    }
  }

  /// Get tool status info for UI
  Future<Map<String, dynamic>?> getToolStatusInfo(String toolId) async {
    try {
      final tool = await _toolService.getToolByUniqueId(toolId);
      if (tool == null) return null;

      Staff? assignedStaff;
      if (tool.currentHolder != null) {
        assignedStaff = await _staffService.getStaffById(
          tool.currentHolder!.id,
        );
      }

      return {
        'tool': tool,
        'assignedStaff': assignedStaff,
        'canCheckOut': tool.isAvailable,
        'canCheckIn': !tool.isAvailable,
      };
    } catch (e) {
      debugPrint('Error getting tool status info: $e');
      return null;
    }
  }
}

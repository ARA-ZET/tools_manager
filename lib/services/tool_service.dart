import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tool.dart';

/// Service for managing tools in Firestore
class ToolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'tools';

  /// Get tools collection reference
  CollectionReference get _toolsCollection =>
      _firestore.collection(_collection);

  /// Create a new tool
  Future<String> createTool(Tool tool) async {
    try {
      final docRef = await _toolsCollection.add(tool.toFirestore());
      debugPrint('Tool created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating tool: $e');
      throw Exception('Failed to create tool: $e');
    }
  }

  /// Get tool by ID
  Future<Tool?> getToolById(String id) async {
    try {
      final doc = await _toolsCollection.doc(id).get();
      if (doc.exists) {
        return Tool.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tool by ID: $e');
      throw Exception('Failed to get tool: $e');
    }
  }

  /// Get tool by unique ID (for QR scanning)
  Future<Tool?> getToolByUniqueId(String uniqueId) async {
    try {
      final query = await _toolsCollection
          .where('uniqueId', isEqualTo: uniqueId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Tool.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tool by unique ID: $e');
      throw Exception('Failed to get tool: $e');
    }
  }

  /// Update tool
  Future<void> updateTool(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _toolsCollection.doc(id).update(updates);
      debugPrint('Tool updated: $id');
    } catch (e) {
      debugPrint('Error updating tool: $e');
      throw Exception('Failed to update tool: $e');
    }
  }

  /// Delete tool
  Future<void> deleteTool(String id) async {
    try {
      await _toolsCollection.doc(id).delete();
      debugPrint('Tool deleted: $id');
    } catch (e) {
      debugPrint('Error deleting tool: $e');
      throw Exception('Failed to delete tool: $e');
    }
  }

  /// Get all tools stream
  Stream<List<Tool>> getToolsStream() {
    return _toolsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Tool.fromFirestore(doc)).toList(),
        );
  }

  /// Get tools with pagination
  Future<List<Tool>> getToolsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      Query query = _toolsCollection.orderBy('updatedAt', descending: true);

      // Apply filters
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      var tools = snapshot.docs.map((doc) => Tool.fromFirestore(doc)).toList();

      // Apply search filter locally (Firestore doesn't support full-text search)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        tools = tools
            .where(
              (tool) =>
                  tool.name.toLowerCase().contains(lowerQuery) ||
                  tool.brand.toLowerCase().contains(lowerQuery) ||
                  tool.model.toLowerCase().contains(lowerQuery) ||
                  tool.uniqueId.toLowerCase().contains(lowerQuery),
            )
            .toList();
      }

      return tools;
    } catch (e) {
      debugPrint('Error getting paginated tools: $e');
      throw Exception('Failed to get tools: $e');
    }
  }

  /// Get available tools count
  Future<int> getAvailableToolsCount() async {
    try {
      final query = await _toolsCollection
          .where('status', isEqualTo: 'available')
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting available tools count: $e');
      return 0;
    }
  }

  /// Get checked out tools count
  Future<int> getCheckedOutToolsCount() async {
    try {
      final query = await _toolsCollection
          .where('status', isEqualTo: 'checked_out')
          .count()
          .get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting checked out tools count: $e');
      return 0;
    }
  }

  /// Get total tools count
  Future<int> getTotalToolsCount() async {
    try {
      final query = await _toolsCollection.count().get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting total tools count: $e');
      return 0;
    }
  }

  /// Check out tool to a staff member
  Future<void> checkOutTool(String toolId, String staffId) async {
    try {
      await _toolsCollection.doc(toolId).update({
        'status': 'checked_out',
        'currentHolder': _firestore.doc('staff/$staffId'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Tool checked out: $toolId to $staffId');
    } catch (e) {
      debugPrint('Error checking out tool: $e');
      throw Exception('Failed to check out tool: $e');
    }
  }

  /// Check in tool
  Future<void> checkInTool(String toolId) async {
    try {
      await _toolsCollection.doc(toolId).update({
        'status': 'available',
        'currentHolder': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Tool checked in: $toolId');
    } catch (e) {
      debugPrint('Error checking in tool: $e');
      throw Exception('Failed to check in tool: $e');
    }
  }

  /// Batch check out tools
  Future<void> batchCheckOutTools(List<String> toolIds, String staffId) async {
    final batch = _firestore.batch();

    try {
      for (final toolId in toolIds) {
        final toolRef = _toolsCollection.doc(toolId);
        batch.update(toolRef, {
          'status': 'checked_out',
          'currentHolder': _firestore.doc('staff/$staffId'),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Batch checked out ${toolIds.length} tools to $staffId');
    } catch (e) {
      debugPrint('Error batch checking out tools: $e');
      throw Exception('Failed to batch check out tools: $e');
    }
  }

  /// Batch check in tools
  Future<void> batchCheckInTools(List<String> toolIds) async {
    final batch = _firestore.batch();

    try {
      for (final toolId in toolIds) {
        final toolRef = _toolsCollection.doc(toolId);
        batch.update(toolRef, {
          'status': 'available',
          'currentHolder': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Batch checked in ${toolIds.length} tools');
    } catch (e) {
      debugPrint('Error batch checking in tools: $e');
      throw Exception('Failed to batch check in tools: $e');
    }
  }

  /// Get tools by status
  Stream<List<Tool>> getToolsByStatus(String status) {
    // Use simple query to avoid index issues
    return _toolsCollection.where('status', isEqualTo: status).snapshots().map((
      snapshot,
    ) {
      var toolsList = snapshot.docs
          .map((doc) => Tool.fromFirestore(doc))
          .toList();

      // Sort in memory
      toolsList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return toolsList;
    });
  }

  /// Get tools by status (simple version to avoid index issues)
  Stream<List<Tool>> getToolsByStatusSimple(String status) {
    return getToolsStream().map((toolsList) {
      return toolsList.where((tool) => tool.status == status).toList();
      // Already sorted by updatedAt from main stream
    });
  }

  /// Get tools assigned to a staff member
  Stream<List<Tool>> getToolsAssignedTo(String staffId) {
    // Use simple query to avoid index issues
    return _toolsCollection
        .where('currentHolder', isEqualTo: _firestore.doc('staff/$staffId'))
        .snapshots()
        .map((snapshot) {
          var toolsList = snapshot.docs
              .map((doc) => Tool.fromFirestore(doc))
              .toList();

          // Sort in memory
          toolsList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return toolsList;
        });
  }

  /// Get tools assigned to a staff member (simple version to avoid index issues)
  Stream<List<Tool>> getToolsAssignedToSimple(String staffId) {
    return getToolsStream().map((toolsList) {
      final staffRef = _firestore.doc('staff/$staffId');
      return toolsList
          .where((tool) => tool.currentHolder?.path == staffRef.path)
          .toList();
      // Already sorted by updatedAt from main stream
    });
  }

  /// Search tools by query
  Future<List<Tool>> searchTools(String query) async {
    try {
      // Get all tools and filter locally
      // TODO: Consider implementing proper full-text search with Algolia or similar
      final snapshot = await _toolsCollection.get();
      final tools = snapshot.docs
          .map((doc) => Tool.fromFirestore(doc))
          .toList();

      if (query.isEmpty) return tools;

      final lowerQuery = query.toLowerCase();
      return tools
          .where(
            (tool) =>
                tool.name.toLowerCase().contains(lowerQuery) ||
                tool.brand.toLowerCase().contains(lowerQuery) ||
                tool.model.toLowerCase().contains(lowerQuery) ||
                tool.uniqueId.toLowerCase().contains(lowerQuery) ||
                tool.num.toLowerCase().contains(lowerQuery),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching tools: $e');
      throw Exception('Failed to search tools: $e');
    }
  }

  /// Generate unique tool ID
  String generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'T$random';
  }

  /// Validate tool data before creation/update
  bool validateTool(Map<String, dynamic> toolData) {
    final requiredFields = ['uniqueId', 'name', 'brand', 'model'];

    for (final field in requiredFields) {
      if (!toolData.containsKey(field) ||
          toolData[field] == null ||
          toolData[field].toString().trim().isEmpty) {
        debugPrint('Validation failed: Missing or empty field: $field');
        return false;
      }
    }

    return true;
  }
}

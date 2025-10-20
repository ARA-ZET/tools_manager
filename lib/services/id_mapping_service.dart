import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing human-readable IDs instead of exposing Firebase UIDs
class IdMappingService {
  static final IdMappingService _instance = IdMappingService._internal();
  factory IdMappingService() => _instance;
  IdMappingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for ID mappings to improve performance
  final Map<String, String> _staffJobCodeToUid = {};
  final Map<String, String> _staffUidToJobCode = {};
  final Map<String, String> _toolUniqueIdToUid = {};
  final Map<String, String> _toolUidToUniqueId = {};

  /// Get staff UID from job code
  Future<String?> getStaffUidFromJobCode(String jobCode) async {
    // Check cache first
    if (_staffJobCodeToUid.containsKey(jobCode)) {
      return _staffJobCodeToUid[jobCode];
    }

    try {
      final query = await _firestore
          .collection('staff')
          .where('jobCode', isEqualTo: jobCode)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final uid = query.docs.first.id;
        // Cache the mapping
        _staffJobCodeToUid[jobCode] = uid;
        _staffUidToJobCode[uid] = jobCode;
        return uid;
      }
    } catch (e) {
      debugPrint('Error getting staff UID from job code: $e');
    }
    return null;
  }

  /// Get staff job code from UID
  Future<String?> getStaffJobCodeFromUid(String uid) async {
    // Check cache first
    if (_staffUidToJobCode.containsKey(uid)) {
      return _staffUidToJobCode[uid];
    }

    try {
      final doc = await _firestore.collection('staff').doc(uid).get();
      if (doc.exists) {
        final jobCode = doc.data()?['jobCode'] as String?;
        if (jobCode != null) {
          // Cache the mapping
          _staffUidToJobCode[uid] = jobCode;
          _staffJobCodeToUid[jobCode] = uid;
          return jobCode;
        }
      }
    } catch (e) {
      debugPrint('Error getting staff job code from UID: $e');
    }
    return null;
  }

  /// Get tool UID from unique ID
  Future<String?> getToolUidFromUniqueId(String uniqueId) async {
    // Check cache first
    if (_toolUniqueIdToUid.containsKey(uniqueId)) {
      return _toolUniqueIdToUid[uniqueId];
    }

    try {
      final query = await _firestore
          .collection('tools')
          .where('uniqueId', isEqualTo: uniqueId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final uid = query.docs.first.id;
        // Cache the mapping
        _toolUniqueIdToUid[uniqueId] = uid;
        _toolUidToUniqueId[uid] = uniqueId;
        return uid;
      }
    } catch (e) {
      debugPrint('Error getting tool UID from unique ID: $e');
    }
    return null;
  }

  /// Get tool unique ID from UID
  Future<String?> getToolUniqueIdFromUid(String uid) async {
    // Check cache first
    if (_toolUidToUniqueId.containsKey(uid)) {
      return _toolUidToUniqueId[uid];
    }

    try {
      final doc = await _firestore.collection('tools').doc(uid).get();
      if (doc.exists) {
        final uniqueId = doc.data()?['uniqueId'] as String?;
        if (uniqueId != null) {
          // Cache the mapping
          _toolUidToUniqueId[uid] = uniqueId;
          _toolUniqueIdToUid[uniqueId] = uid;
          return uniqueId;
        }
      }
    } catch (e) {
      debugPrint('Error getting tool unique ID from UID: $e');
    }
    return null;
  }

  /// Get staff document reference using job code
  DocumentReference getStaffReferenceFromJobCode(String jobCode) {
    return _firestore.collection('staff').doc('placeholder_$jobCode');
  }

  /// Get tool document reference using unique ID
  DocumentReference getToolReferenceFromUniqueId(String uniqueId) {
    return _firestore.collection('tools').doc('placeholder_$uniqueId');
  }

  /// Create readable assignment record
  Map<String, dynamic> createAssignmentRecord({
    required String toolUniqueId,
    required String staffJobCode,
    required String action, // 'checkout' or 'checkin'
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'toolId': toolUniqueId,
      'staffId': staffJobCode,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': notes,
      'metadata': metadata ?? {},
      'readableIds': true, // Flag to indicate this uses readable IDs
    };
  }

  /// Convert UID-based history to readable IDs
  Future<Map<String, dynamic>> convertHistoryToReadableIds(
    Map<String, dynamic> historyData,
  ) async {
    final converted = Map<String, dynamic>.from(historyData);

    // Convert tool reference if present
    if (historyData['toolRef'] is DocumentReference) {
      final toolRef = historyData['toolRef'] as DocumentReference;
      final toolUniqueId = await getToolUniqueIdFromUid(toolRef.id);
      if (toolUniqueId != null) {
        converted['toolId'] = toolUniqueId;
      }
    }

    // Convert staff reference if present
    if (historyData['byRef'] is DocumentReference) {
      final staffRef = historyData['byRef'] as DocumentReference;
      final staffJobCode = await getStaffJobCodeFromUid(staffRef.id);
      if (staffJobCode != null) {
        converted['staffId'] = staffJobCode;
      }
    }

    // Convert assigned to reference if present
    if (historyData['assignedToRef'] is DocumentReference) {
      final assignedRef = historyData['assignedToRef'] as DocumentReference;
      final assignedJobCode = await getStaffJobCodeFromUid(assignedRef.id);
      if (assignedJobCode != null) {
        converted['assignedToId'] = assignedJobCode;
      }
    }

    converted['readableIds'] = true;
    return converted;
  }

  /// Clear cache (useful for testing or memory management)
  void clearCache() {
    _staffJobCodeToUid.clear();
    _staffUidToJobCode.clear();
    _toolUniqueIdToUid.clear();
    _toolUidToUniqueId.clear();
  }

  /// Preload mappings for better performance
  Future<void> preloadStaffMappings() async {
    try {
      final staffQuery = await _firestore.collection('staff').get();
      for (final doc in staffQuery.docs) {
        final jobCode = doc.data()['jobCode'] as String?;
        if (jobCode != null) {
          _staffUidToJobCode[doc.id] = jobCode;
          _staffJobCodeToUid[jobCode] = doc.id;
        }
      }
      debugPrint('Preloaded ${_staffUidToJobCode.length} staff mappings');
    } catch (e) {
      debugPrint('Error preloading staff mappings: $e');
    }
  }

  /// Preload tool mappings for better performance
  Future<void> preloadToolMappings() async {
    try {
      final toolQuery = await _firestore.collection('tools').get();
      for (final doc in toolQuery.docs) {
        final uniqueId = doc.data()['uniqueId'] as String?;
        if (uniqueId != null) {
          _toolUidToUniqueId[doc.id] = uniqueId;
          _toolUniqueIdToUid[uniqueId] = doc.id;
        }
      }
      debugPrint('Preloaded ${_toolUidToUniqueId.length} tool mappings');
    } catch (e) {
      debugPrint('Error preloading tool mappings: $e');
    }
  }

  /// Initialize the service with preloaded mappings
  Future<void> initialize() async {
    await Future.wait([preloadStaffMappings(), preloadToolMappings()]);
  }
}

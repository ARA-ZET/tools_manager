import 'package:cloud_firestore/cloud_firestore.dart';

/// Tool action types
enum ToolAction {
  checkout,
  checkin;

  /// Convert action to string for Firestore
  String get value => name;

  /// Create action from string
  static ToolAction fromString(String action) {
    switch (action.toLowerCase()) {
      case 'checkout':
        return ToolAction.checkout;
      case 'checkin':
        return ToolAction.checkin;
      default:
        return ToolAction.checkout;
    }
  }

  /// Get display name for the action
  String get displayName {
    switch (this) {
      case ToolAction.checkout:
        return 'Check Out';
      case ToolAction.checkin:
        return 'Check In';
    }
  }

  /// Get icon name for the action
  String get iconName {
    switch (this) {
      case ToolAction.checkout:
        return 'checkout';
      case ToolAction.checkin:
        return 'checkin';
    }
  }
}

/// Tool history entry model
class ToolHistory {
  final String id;
  final DocumentReference toolRef; // Reference to tool document
  final ToolAction action; // checkout | checkin
  final DocumentReference byRef; // Staff member who performed action
  final DocumentReference?
  supervisorRef; // Supervisor who authorized (if applicable)
  final DocumentReference? assignedToRef; // Staff member or team assigned to
  final DateTime timestamp;
  final String? notes; // Optional notes
  final String? location; // GPS coordinates or text location
  final String? batchId; // For batch operations
  final Map<String, dynamic> metadata; // Additional metadata

  const ToolHistory({
    required this.id,
    required this.toolRef,
    required this.action,
    required this.byRef,
    this.supervisorRef,
    this.assignedToRef,
    required this.timestamp,
    this.notes,
    this.location,
    this.batchId,
    required this.metadata,
  });

  /// Create ToolHistory from Firestore document
  factory ToolHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ToolHistory(
      id: doc.id,
      toolRef: data['toolRef'] as DocumentReference,
      action: ToolAction.fromString(data['action'] ?? 'checkout'),
      byRef: data['by'] as DocumentReference,
      supervisorRef: data['supervisor'] as DocumentReference?,
      assignedToRef: data['assignedTo'] as DocumentReference?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      location: data['location'],
      batchId: data['batchId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert ToolHistory to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'toolRef': toolRef,
      'action': action.value,
      'by': byRef,
      'supervisor': supervisorRef,
      'assignedTo': assignedToRef,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
      'location': location,
      'batchId': batchId,
      'metadata': metadata,
    };
  }

  /// Create a copy with updated values
  ToolHistory copyWith({
    DocumentReference? toolRef,
    ToolAction? action,
    DocumentReference? byRef,
    DocumentReference? supervisorRef,
    DocumentReference? assignedToRef,
    DateTime? timestamp,
    String? notes,
    String? location,
    String? batchId,
    Map<String, dynamic>? metadata,
  }) {
    return ToolHistory(
      id: id,
      toolRef: toolRef ?? this.toolRef,
      action: action ?? this.action,
      byRef: byRef ?? this.byRef,
      supervisorRef: supervisorRef ?? this.supervisorRef,
      assignedToRef: assignedToRef ?? this.assignedToRef,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      batchId: batchId ?? this.batchId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get tool ID from reference
  String get toolId => toolRef.id;

  /// Get performer ID from reference
  String get byId => byRef.id;

  /// Get supervisor ID from reference
  String? get supervisorId => supervisorRef?.id;

  /// Get assigned to ID from reference
  String? get assignedToId => assignedToRef?.id;

  /// Check if this is a checkout action
  bool get isCheckout => action == ToolAction.checkout;

  /// Check if this is a checkin action
  bool get isCheckin => action == ToolAction.checkin;

  /// Check if this action was part of a batch
  bool get isBatchAction => batchId != null && batchId!.isNotEmpty;

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  String toString() =>
      'ToolHistory(id: $id, action: ${action.value}, toolId: $toolId, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolHistory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Batch operation model for grouping multiple tool actions
class ToolBatch {
  final String id;
  final String createdBy; // Staff UID who created the batch
  final DateTime createdAt;
  final List<String> toolIds; // List of tool IDs in this batch
  final DocumentReference? assignedToRef; // Who the tools are assigned to
  final String? notes; // Batch notes
  final ToolAction action; // Batch action type
  final Map<String, dynamic> metadata;

  const ToolBatch({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.toolIds,
    this.assignedToRef,
    this.notes,
    required this.action,
    required this.metadata,
  });

  /// Create ToolBatch from Firestore document
  factory ToolBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ToolBatch(
      id: doc.id,
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      toolIds: List<String>.from(data['toolIds'] ?? []),
      assignedToRef: data['assignedTo'] as DocumentReference?,
      notes: data['notes'],
      action: ToolAction.fromString(data['action'] ?? 'checkout'),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert ToolBatch to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'toolIds': toolIds,
      'assignedTo': assignedToRef,
      'notes': notes,
      'action': action.value,
      'metadata': metadata,
    };
  }

  /// Get number of tools in batch
  int get toolCount => toolIds.length;

  /// Get assigned to ID from reference
  String? get assignedToId => assignedToRef?.id;

  @override
  String toString() =>
      'ToolBatch(id: $id, toolCount: $toolCount, action: ${action.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolBatch && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

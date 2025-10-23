import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction record for consumable usage, restocking, and adjustments
class ConsumableTransaction {
  final String id;
  final DocumentReference consumableRef;
  final String action;
  final double quantityBefore;
  final double quantityChange;
  final double quantityAfter;
  final DocumentReference? usedBy;
  final DocumentReference? approvedBy;
  final DocumentReference? assignedTo;
  final String? projectName;
  final String? notes;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ConsumableTransaction({
    required this.id,
    required this.consumableRef,
    required this.action,
    required this.quantityBefore,
    required this.quantityChange,
    required this.quantityAfter,
    this.usedBy,
    this.approvedBy,
    this.assignedTo,
    this.projectName,
    this.notes,
    required this.timestamp,
    this.metadata,
  });

  /// Create ConsumableTransaction from Firestore document
  factory ConsumableTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ConsumableTransaction(
      id: doc.id,
      consumableRef: data['consumableRef'] as DocumentReference,
      action: data['action'] as String? ?? 'unknown',
      quantityBefore: (data['quantityBefore'] as num?)?.toDouble() ?? 0.0,
      quantityChange: (data['quantityChange'] as num?)?.toDouble() ?? 0.0,
      quantityAfter: (data['quantityAfter'] as num?)?.toDouble() ?? 0.0,
      usedBy: data['usedBy'] as DocumentReference?,
      approvedBy: data['approvedBy'] as DocumentReference?,
      assignedTo: data['assignedTo'] as DocumentReference?,
      projectName: data['projectName'] as String?,
      notes: data['notes'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert ConsumableTransaction to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'consumableRef': consumableRef,
      'action': action,
      'quantityBefore': quantityBefore,
      'quantityChange': quantityChange,
      'quantityAfter': quantityAfter,
      'usedBy': usedBy,
      'approvedBy': approvedBy,
      'assignedTo': assignedTo,
      'projectName': projectName,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  /// Get action type enum
  TransactionAction get actionType {
    switch (action.toLowerCase()) {
      case 'usage':
        return TransactionAction.usage;
      case 'restock':
        return TransactionAction.restock;
      case 'adjustment':
        return TransactionAction.adjustment;
      default:
        return TransactionAction.unknown;
    }
  }

  /// Check if transaction is a usage (decrease)
  bool get isUsage => quantityChange < 0;

  /// Check if transaction is a restock (increase)
  bool get isRestock => quantityChange > 0;

  /// Get absolute value of quantity change
  double get absoluteQuantityChange => quantityChange.abs();
}

/// Transaction action enum
enum TransactionAction { usage, restock, adjustment, unknown }

/// Extension for TransactionAction
extension TransactionActionExtension on TransactionAction {
  String get displayName {
    switch (this) {
      case TransactionAction.usage:
        return 'Usage';
      case TransactionAction.restock:
        return 'Restock';
      case TransactionAction.adjustment:
        return 'Adjustment';
      case TransactionAction.unknown:
        return 'Unknown';
    }
  }

  /// Get icon for transaction action
  int get iconCodePoint {
    switch (this) {
      case TransactionAction.usage:
        return 0xe15d; // Icons.remove_circle
      case TransactionAction.restock:
        return 0xe145; // Icons.add_circle
      case TransactionAction.adjustment:
        return 0xe3c9; // Icons.edit
      case TransactionAction.unknown:
        return 0xe88e; // Icons.help_outline
    }
  }

  /// Get color for transaction action
  int get colorValue {
    switch (this) {
      case TransactionAction.usage:
        return 0xFFF57C00; // Orange
      case TransactionAction.restock:
        return 0xFF388E3C; // Green
      case TransactionAction.adjustment:
        return 0xFF1976D2; // Blue
      case TransactionAction.unknown:
        return 0xFF757575; // Grey
    }
  }
}

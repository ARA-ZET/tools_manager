import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing consumable usage transactions
class ConsumableTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record consumable usage
  Future<String> recordUsage({
    required String consumableId,
    required double quantity,
    required String usedBy,
    String? assignedTo,
    String? notes,
  }) async {
    try {
      final consumableRef = _firestore
          .collection('consumables')
          .doc(consumableId);
      final staffRef = _firestore.collection('staff').doc(usedBy);

      // Get current consumable data to calculate before/after values
      final consumableDoc = await consumableRef.get();
      final currentQuantity =
          (consumableDoc.data()?['currentQuantity'] as num?)?.toDouble() ?? 0.0;

      final quantityBefore = currentQuantity;
      final quantityChange = -quantity; // Negative for usage
      final quantityAfter = currentQuantity - quantity;

      final data = {
        'consumableRef': consumableRef,
        'action': 'usage',
        'quantityBefore': quantityBefore,
        'quantityChange': quantityChange,
        'quantityAfter': quantityAfter,
        'usedBy': staffRef,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add assignedTo if provided
      if (assignedTo != null) {
        final assignedToRef = _firestore.collection('staff').doc(assignedTo);
        data['assignedTo'] = assignedToRef;
      }

      final transaction = await _firestore
          .collection('consumable_transactions')
          .add(data);

      return transaction.id;
    } catch (e) {
      throw Exception('Failed to record consumable usage: $e');
    }
  }

  /// Record consumable restock
  Future<String> recordRestock({
    required String consumableId,
    required double quantity,
    required String restockedBy,
    String? notes,
  }) async {
    try {
      final consumableRef = _firestore
          .collection('consumables')
          .doc(consumableId);
      final staffRef = _firestore.collection('staff').doc(restockedBy);

      // Get current consumable data to calculate before/after values
      final consumableDoc = await consumableRef.get();
      final currentQuantity =
          (consumableDoc.data()?['currentQuantity'] as num?)?.toDouble() ?? 0.0;

      final quantityBefore = currentQuantity;
      final quantityChange = quantity; // Positive for restock
      final quantityAfter = currentQuantity + quantity;

      final transaction = await _firestore
          .collection('consumable_transactions')
          .add({
            'consumableRef': consumableRef,
            'action': 'restock',
            'quantityBefore': quantityBefore,
            'quantityChange': quantityChange,
            'quantityAfter': quantityAfter,
            'approvedBy': staffRef,
            'notes': notes,
            'timestamp': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      return transaction.id;
    } catch (e) {
      throw Exception('Failed to record consumable restock: $e');
    }
  }

  /// Get usage history for a consumable
  Stream<QuerySnapshot> getConsumableHistory(String consumableId) {
    final consumableRef = _firestore
        .collection('consumables')
        .doc(consumableId);

    return _firestore
        .collection('consumable_transactions')
        .where('consumableRef', isEqualTo: consumableRef)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get usage history for a staff member
  Stream<QuerySnapshot> getStaffUsageHistory(String staffUid) {
    final staffRef = _firestore.collection('staff').doc(staffUid);

    return _firestore
        .collection('consumable_transactions')
        .where('usedBy', isEqualTo: staffRef)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

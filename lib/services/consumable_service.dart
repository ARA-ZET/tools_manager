import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consumable.dart';
import '../models/consumable_transaction.dart';

/// Service for managing consumables in Firestore
class ConsumableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get consumables collection reference
  CollectionReference get _consumablesCollection =>
      _firestore.collection('consumables');

  /// Get transactions collection reference
  CollectionReference get _transactionsCollection =>
      _firestore.collection('consumable_transactions');

  // ============ CREATE ============

  /// Create a new consumable
  Future<String> createConsumable(Consumable consumable) async {
    try {
      final docRef = await _consumablesCollection.add(consumable.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create consumable: $e');
    }
  }

  /// Generate unique consumable ID
  Future<String> generateUniqueId() async {
    try {
      // Query for the highest existing C# ID
      final querySnapshot = await _consumablesCollection
          .where('uniqueId', isGreaterThanOrEqualTo: 'C')
          .where('uniqueId', isLessThan: 'D')
          .orderBy('uniqueId', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'C0001'; // First consumable
      }

      final lastId = querySnapshot.docs.first.data() as Map<String, dynamic>;
      final lastUniqueId = lastId['uniqueId'] as String;

      // Extract number and increment
      final numberPart = lastUniqueId.substring(1); // Remove 'C' prefix
      final nextNumber = int.parse(numberPart) + 1;

      return 'C${nextNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      // Fallback: generate random ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'C${timestamp.toString().substring(8)}';
    }
  }

  // ============ READ ============

  /// Get all consumables as a stream
  Stream<List<Consumable>> getConsumablesStream() {
    return _consumablesCollection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consumable.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get active consumables only
  Stream<List<Consumable>> getActiveConsumablesStream() {
    return _consumablesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final consumables = snapshot.docs
              .map((doc) => Consumable.fromFirestore(doc))
              .toList();
          // Sort in-memory to avoid needing composite index
          consumables.sort((a, b) => a.name.compareTo(b.name));
          return consumables;
        });
  }

  /// Get consumables by category
  Stream<List<Consumable>> getConsumablesByCategory(String category) {
    return _consumablesCollection
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final consumables = snapshot.docs
              .map((doc) => Consumable.fromFirestore(doc))
              .toList();
          // Sort in-memory to avoid needing composite index
          consumables.sort((a, b) => a.name.compareTo(b.name));
          return consumables;
        });
  }

  /// Get low stock consumables
  Stream<List<Consumable>> getLowStockConsumables() {
    return _consumablesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final consumables = snapshot.docs
              .map((doc) => Consumable.fromFirestore(doc))
              .where((consumable) => consumable.isLowStock)
              .toList();
          // Sort by name for consistency
          consumables.sort((a, b) => a.name.compareTo(b.name));
          return consumables;
        });
  }

  /// Get consumable by ID
  Future<Consumable?> getConsumableById(String id) async {
    try {
      final doc = await _consumablesCollection.doc(id).get();
      if (doc.exists) {
        return Consumable.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get consumable: $e');
    }
  }

  /// Find consumable by unique ID (C#)
  Future<Consumable?> findConsumableByUniqueId(String uniqueId) async {
    try {
      final querySnapshot = await _consumablesCollection
          .where('uniqueId', isEqualTo: uniqueId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Consumable.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find consumable: $e');
    }
  }

  /// Find consumable by QR payload
  Future<Consumable?> findConsumableByQRCode(String qrPayload) async {
    try {
      // Try direct QR payload match
      final querySnapshot = await _consumablesCollection
          .where('qrPayload', isEqualTo: qrPayload)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Consumable.fromFirestore(querySnapshot.docs.first);
      }

      // Try extracting unique ID from payload (e.g., "CONSUMABLE#C0001" -> "C0001")
      if (qrPayload.contains('#')) {
        final uniqueId = qrPayload.split('#').last;
        return await findConsumableByUniqueId(uniqueId);
      }

      // Try using the payload as unique ID directly
      return await findConsumableByUniqueId(qrPayload);
    } catch (e) {
      throw Exception('Failed to find consumable by QR code: $e');
    }
  }

  /// Get all unique categories
  Future<List<String>> getCategories() async {
    try {
      final querySnapshot = await _consumablesCollection
          .where('isActive', isEqualTo: true)
          .get();

      final categories = querySnapshot.docs
          .map(
            (doc) => (doc.data() as Map<String, dynamic>)['category'] as String,
          )
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }

  // ============ UPDATE ============

  /// Update consumable
  Future<void> updateConsumable(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _consumablesCollection.doc(id).update(updates);
    } catch (e) {
      throw Exception('Failed to update consumable: $e');
    }
  }

  /// Update consumable quantity and create transaction
  Future<void> updateQuantity({
    required String consumableId,
    required double quantityChange,
    required String action,
    String? staffUid,
    String? approvedByUid,
    String? projectName,
    String? notes,
  }) async {
    try {
      // Get current consumable
      final consumable = await getConsumableById(consumableId);
      if (consumable == null) {
        throw Exception('Consumable not found');
      }

      final quantityBefore = consumable.currentQuantity;
      final quantityAfter = quantityBefore + quantityChange;

      // Validate quantity
      if (quantityAfter < 0) {
        throw Exception('Insufficient quantity available');
      }

      // Update consumable quantity
      await updateConsumable(consumableId, {'currentQuantity': quantityAfter});

      // Create transaction record
      await createTransaction(
        consumableId: consumableId,
        action: action,
        quantityBefore: quantityBefore,
        quantityChange: quantityChange,
        quantityAfter: quantityAfter,
        staffUid: staffUid,
        approvedByUid: approvedByUid,
        projectName: projectName,
        notes: notes,
      );
    } catch (e) {
      throw Exception('Failed to update quantity: $e');
    }
  }

  /// Soft delete consumable (set isActive to false)
  Future<void> deleteConsumable(String id) async {
    try {
      await updateConsumable(id, {'isActive': false});
    } catch (e) {
      throw Exception('Failed to delete consumable: $e');
    }
  }

  // ============ TRANSACTIONS ============

  /// Create a transaction record
  Future<String> createTransaction({
    required String consumableId,
    required String action,
    required double quantityBefore,
    required double quantityChange,
    required double quantityAfter,
    String? staffUid,
    String? approvedByUid,
    String? projectName,
    String? notes,
  }) async {
    try {
      final transaction = ConsumableTransaction(
        id: '',
        consumableRef: _consumablesCollection.doc(consumableId),
        action: action,
        quantityBefore: quantityBefore,
        quantityChange: quantityChange,
        quantityAfter: quantityAfter,
        usedBy: staffUid != null
            ? _firestore.collection('staff').doc(staffUid)
            : null,
        approvedBy: approvedByUid != null
            ? _firestore.collection('staff').doc(approvedByUid)
            : null,
        projectName: projectName,
        notes: notes,
        timestamp: DateTime.now(),
      );

      final docRef = await _transactionsCollection.add(
        transaction.toFirestore(),
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  /// Get transactions for a consumable
  Stream<List<ConsumableTransaction>> getTransactionsForConsumable(
    String consumableId,
  ) {
    return _transactionsCollection
        .where(
          'consumableRef',
          isEqualTo: _consumablesCollection.doc(consumableId),
        )
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map((doc) => ConsumableTransaction.fromFirestore(doc))
              .toList();
          // Sort in-memory to avoid composite index
          transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return transactions;
        });
  }

  /// Get all transactions (for audit screen)
  Stream<List<ConsumableTransaction>> getAllTransactionsStream() {
    return _transactionsCollection
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConsumableTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get transactions by staff member
  Stream<List<ConsumableTransaction>> getTransactionsByStaff(String staffUid) {
    final staffRef = _firestore.collection('staff').doc(staffUid);
    return _transactionsCollection
        .where('usedBy', isEqualTo: staffRef)
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map((doc) => ConsumableTransaction.fromFirestore(doc))
              .toList();
          // Sort in-memory to avoid composite index
          transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return transactions;
        });
  }

  // ============ BATCH OPERATIONS ============

  /// Restock multiple consumables
  Future<void> batchRestock(
    List<Map<String, dynamic>> items,
    String? approvedByUid,
  ) async {
    final batch = _firestore.batch();

    try {
      for (final item in items) {
        final consumableId = item['consumableId'] as String;
        final quantityToAdd = item['quantity'] as double;

        final consumable = await getConsumableById(consumableId);
        if (consumable == null) continue;

        final quantityBefore = consumable.currentQuantity;
        final quantityAfter = quantityBefore + quantityToAdd;

        // Update consumable
        batch.update(_consumablesCollection.doc(consumableId), {
          'currentQuantity': quantityAfter,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // Create transaction
        final transactionRef = _transactionsCollection.doc();
        batch.set(transactionRef, {
          'consumableRef': _consumablesCollection.doc(consumableId),
          'action': 'restock',
          'quantityBefore': quantityBefore,
          'quantityChange': quantityToAdd,
          'quantityAfter': quantityAfter,
          'approvedBy': approvedByUid != null
              ? _firestore.collection('staff').doc(approvedByUid)
              : null,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch restock: $e');
    }
  }
}

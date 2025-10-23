import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumable.dart';
import '../models/consumable_transaction.dart';
import '../models/measurement_unit.dart';
import '../services/consumable_service.dart';

/// Provider for managing consumables state
class ConsumablesProvider with ChangeNotifier {
  final ConsumableService _consumableService = ConsumableService();

  // State
  List<Consumable> _consumables = [];
  List<Consumable> _lowStockConsumables = [];
  List<ConsumableTransaction> _recentTransactions = [];
  Map<String, Consumable> _consumablesById = {};
  Map<String, Consumable> _consumablesByUniqueId = {};
  List<String> _categories = [];

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  StreamSubscription? _consumablesSubscription;
  StreamSubscription? _lowStockSubscription;
  StreamSubscription? _transactionsSubscription;

  // Getters
  List<Consumable> get consumables => _consumables;
  List<Consumable> get activeConsumables =>
      _consumables.where((c) => c.isActive).toList();
  List<Consumable> get lowStockConsumables => _lowStockConsumables;
  List<ConsumableTransaction> get recentTransactions => _recentTransactions;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  /// Get consumable by ID from cache
  Consumable? getConsumableById(String id) {
    try {
      return _consumablesById[id];
    } catch (e) {
      debugPrint('❌ Error in getConsumableById: $e');
      return null;
    }
  }

  /// Get consumable by unique ID from cache (for QR scanning - fast O(1) lookup)
  Consumable? getConsumableByUniqueId(String uniqueId) {
    try {
      return _consumablesByUniqueId[uniqueId];
    } catch (e) {
      debugPrint('❌ Error in getConsumableByUniqueId: $e');
      return null;
    }
  }

  /// Get consumables by category
  List<Consumable> getConsumablesByCategory(String category) {
    return _consumables
        .where((c) => c.category == category && c.isActive)
        .toList();
  }

  /// Get consumables by stock level
  List<Consumable> getConsumablesByStockLevel(StockLevel level) {
    return _consumables
        .where((c) => c.stockLevel == level && c.isActive)
        .toList();
  }

  /// Get count of low stock items
  int get lowStockCount => _lowStockConsumables.length;

  /// Get count of out of stock items
  int get outOfStockCount =>
      _consumables.where((c) => c.isOutOfStock && c.isActive).length;

  // ============ INITIALIZATION ============

  /// Initialize provider and start listening to streams
  Future<void> initialize() async {
    if (_consumablesSubscription != null) {
      return; // Already initialized
    }

    _setLoading(true);

    try {
      // Listen to all consumables
      _consumablesSubscription = _consumableService
          .getActiveConsumablesStream()
          .listen(_onConsumablesUpdated, onError: _onError);

      // Listen to low stock consumables
      _lowStockSubscription = _consumableService
          .getLowStockConsumables()
          .listen(_onLowStockUpdated, onError: _onError);

      // Listen to recent transactions
      _transactionsSubscription = _consumableService
          .getAllTransactionsStream()
          .listen(_onTransactionsUpdated, onError: _onError);

      // Load categories
      await _loadCategories();

      _setLoading(false);
    } catch (e) {
      _setError('Failed to initialize: $e');
    }
  }

  /// Dispose of subscriptions
  @override
  void dispose() {
    _consumablesSubscription?.cancel();
    _lowStockSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  // ============ STREAM HANDLERS ============

  void _onConsumablesUpdated(List<Consumable> consumables) {
    _consumables = consumables;
    _consumablesById = {for (var c in consumables) c.id: c};
    _consumablesByUniqueId = {for (var c in consumables) c.uniqueId: c};
    _hasError = false;
    _isLoading = false;
    notifyListeners();
  }

  void _onLowStockUpdated(List<Consumable> lowStock) {
    _lowStockConsumables = lowStock;
    notifyListeners();
  }

  void _onTransactionsUpdated(List<ConsumableTransaction> transactions) {
    _recentTransactions = transactions;
    notifyListeners();
  }

  void _onError(error) {
    _setError('Error loading data: $error');
  }

  // ============ CRUD OPERATIONS ============

  /// Create a new consumable
  Future<String?> addConsumable({
    required String name,
    required String category,
    required String unit,
    required double initialQuantity,
    required double minQuantity,
    required double maxQuantity,
    List<String> images = const [],
    String? notes,
  }) async {
    try {
      _setLoading(true);

      // Generate unique ID
      final uniqueId = await _consumableService.generateUniqueId();

      // Create QR payload
      final qrPayload = 'CONSUMABLE#$uniqueId';

      // Create consumable object
      final consumable = Consumable(
        id: '',
        uniqueId: uniqueId,
        name: name,
        category: category,
        unit: unit == 'liters'
            ? MeasurementUnit.liters
            : unit == 'meters'
            ? MeasurementUnit.meters
            : unit == 'sheets'
            ? MeasurementUnit.sheets
            : unit == 'rolls'
            ? MeasurementUnit.rolls
            : MeasurementUnit.pieces,
        currentQuantity: initialQuantity,
        minQuantity: minQuantity,
        maxQuantity: maxQuantity,
        images: images,
        qrPayload: qrPayload,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _consumableService.createConsumable(consumable);

      // Create initial transaction if quantity > 0
      if (initialQuantity > 0) {
        await _consumableService.createTransaction(
          consumableId: id,
          action: 'restock',
          quantityBefore: 0,
          quantityChange: initialQuantity,
          quantityAfter: initialQuantity,
          notes: 'Initial stock',
        );
      }

      _setLoading(false);
      return id;
    } catch (e) {
      _setError('Failed to create consumable: $e');
      return null;
    }
  }

  /// Update consumable details
  Future<bool> updateConsumable(String id, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);
      await _consumableService.updateConsumable(id, updates);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update consumable: $e');
      return false;
    }
  }

  /// Update quantity (usage or restock)
  Future<bool> updateQuantity({
    required String consumableId,
    required double quantityChange,
    required String action,
    String? staffUid,
    String? approvedByUid,
    String? projectName,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      await _consumableService.updateQuantity(
        consumableId: consumableId,
        quantityChange: quantityChange,
        action: action,
        staffUid: staffUid,
        approvedByUid: approvedByUid,
        projectName: projectName,
        notes: notes,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update quantity: $e');
      return false;
    }
  }

  /// Delete consumable (soft delete)
  Future<bool> deleteConsumable(String id) async {
    try {
      _setLoading(true);
      await _consumableService.deleteConsumable(id);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete consumable: $e');
      return false;
    }
  }

  // ============ SEARCH & LOOKUP ============

  /// Find consumable by QR code
  Future<Consumable?> findByQRCode(String qrPayload) async {
    try {
      return await _consumableService.findConsumableByQRCode(qrPayload);
    } catch (e) {
      _setError('Failed to find consumable: $e');
      return null;
    }
  }

  /// Find consumable by unique ID (from cache - instant lookup)
  Consumable? findByUniqueId(String uniqueId) {
    return _consumablesByUniqueId[uniqueId];
  }

  /// Search consumables by name
  List<Consumable> searchByName(String query) {
    if (query.isEmpty) return activeConsumables;

    final lowerQuery = query.toLowerCase();
    return activeConsumables.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          c.category.toLowerCase().contains(lowerQuery) ||
          c.uniqueId.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ============ CATEGORIES ============

  Future<void> _loadCategories() async {
    try {
      _categories = await _consumableService.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  /// Refresh categories
  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  // ============ HELPERS ============

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _hasError = false;
      _errorMessage = '';
    }
    notifyListeners();
  }

  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Retry after error
  Future<void> retry() async {
    await initialize();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await _loadCategories();
    // Streams will automatically refresh
  }

  /// Get transactions for a specific consumable
  Stream<List<ConsumableTransaction>> getTransactionsForConsumable(
    String consumableId,
  ) {
    return _consumableService.getTransactionsForConsumable(consumableId);
  }
}

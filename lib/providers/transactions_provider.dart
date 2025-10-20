import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/tool_history_service.dart';

enum TransactionsLoadingState {
  loading,
  loaded,
  error,
  unauthorized, // For non-admin users
}

class TransactionsProvider extends ChangeNotifier {
  final ToolHistoryService _historyService = ToolHistoryService();

  // State
  TransactionsLoadingState _loadingState = TransactionsLoadingState.loading;
  List<Map<String, dynamic>> _allTransactions = [];
  String? _errorMessage;
  StreamSubscription<List<Map<String, dynamic>>>? _transactionsSubscription;
  bool _isAuthorized = false;

  // Cached filtered lists for performance (today's transactions only)
  List<Map<String, dynamic>> _checkoutTransactions = [];
  List<Map<String, dynamic>> _checkinTransactions = [];
  final Map<String, List<Map<String, dynamic>>> _transactionsByTool = {};
  final Map<String, List<Map<String, dynamic>>> _transactionsByStaff = {};

  // Getters
  TransactionsLoadingState get loadingState => _loadingState;
  List<Map<String, dynamic>> get allTransactions =>
      List.unmodifiable(_allTransactions);
  List<Map<String, dynamic>> get checkoutTransactions =>
      List.unmodifiable(_checkoutTransactions);
  List<Map<String, dynamic>> get checkinTransactions =>
      List.unmodifiable(_checkinTransactions);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == TransactionsLoadingState.loading;
  bool get hasError => _loadingState == TransactionsLoadingState.error;
  bool get isLoaded => _loadingState == TransactionsLoadingState.loaded;
  bool get isUnauthorized =>
      _loadingState == TransactionsLoadingState.unauthorized;
  bool get isAuthorized => _isAuthorized;

  // Statistics
  int get totalTransactionsCount => _allTransactions.length;
  int get checkoutTransactionsCount => _checkoutTransactions.length;
  int get checkinTransactionsCount => _checkinTransactions.length;

  TransactionsProvider();

  /// Initialize transactions data loading with authorization check
  void initialize(bool isUserAdmin) {
    _isAuthorized = isUserAdmin;

    if (!_isAuthorized) {
      _loadingState = TransactionsLoadingState.unauthorized;
      notifyListeners();
      return;
    }

    _initializeListener();
  }

  /// Initialize real-time listener for transactions collection (admin only)
  /// Now uses hierarchical structure for cost-effective queries
  void _initializeListener() {
    if (!_isAuthorized) return;

    // Stream today's transactions by default
    _transactionsSubscription = _historyService
        .streamDailyTransactions(limit: 1000)
        .listen(_handleTransactionsSnapshot, onError: _handleError);

    debugPrint(
      '📊 Transactions provider initialized with hierarchical structure',
    );
  }

  /// Handle stream updates from hierarchical structure
  void _handleTransactionsSnapshot(List<Map<String, dynamic>> transactions) {
    try {
      _allTransactions = transactions;

      _buildCachedLists();
      _loadingState = TransactionsLoadingState.loaded;
      _errorMessage = null;

      debugPrint(
        'Transactions updated: ${_allTransactions.length} total transactions loaded',
      );
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Build cached filtered lists and lookup maps for performance
  void _buildCachedLists() {
    _checkoutTransactions = _allTransactions
        .where((transaction) => transaction['action'] == 'checkout')
        .toList();

    _checkinTransactions = _allTransactions
        .where((transaction) => transaction['action'] == 'checkin')
        .toList();

    // Build lookup maps for fast access
    _transactionsByTool.clear();
    _transactionsByStaff.clear();

    for (final transaction in _allTransactions) {
      final toolId = transaction['toolId'] as String?;
      final staffId = transaction['staffId'] as String?;

      if (toolId != null) {
        _transactionsByTool.putIfAbsent(toolId, () => []).add(transaction);
      }

      if (staffId != null) {
        _transactionsByStaff.putIfAbsent(staffId, () => []).add(transaction);
      }
    }
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _loadingState = TransactionsLoadingState.error;
    _errorMessage = error.toString();
    debugPrint('Transactions provider error: $error');
    notifyListeners();
  }

  /// Get recent transactions with limit
  List<Map<String, dynamic>> getRecentTransactions({int limit = 20}) {
    if (!_isAuthorized) return [];
    return _allTransactions.take(limit).toList();
  }

  /// Load transactions for a specific date range
  Future<List<Map<String, dynamic>>> loadTransactionsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? toolId,
    String? staffUid,
    String? action,
    int? limit,
  }) async {
    if (!_isAuthorized) return [];

    try {
      return await _historyService.getToolHistoryForDateRange(
        startDate: startDate,
        endDate: endDate,
        toolId: toolId,
        staffUid: staffUid,
        action: action,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error loading transactions for date range: $e');
      return [];
    }
  }

  /// Load today's transactions
  Future<void> loadTodayTransactions() async {
    if (!_isAuthorized) return;

    try {
      _loadingState = TransactionsLoadingState.loading;
      notifyListeners();

      _allTransactions = await _historyService.getTodayTransactions(
        limit: 1000,
      );

      _buildCachedLists();
      _loadingState = TransactionsLoadingState.loaded;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Load current month's transactions
  Future<void> loadCurrentMonthTransactions() async {
    if (!_isAuthorized) return;

    try {
      _loadingState = TransactionsLoadingState.loading;
      notifyListeners();

      _allTransactions = await _historyService.getCurrentMonthTransactions(
        limit: 5000,
      );

      _buildCachedLists();
      _loadingState = TransactionsLoadingState.loaded;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Get transactions for a specific tool
  /// Returns last 90 days by default
  Future<List<Map<String, dynamic>>> getToolTransactions(
    String toolId, {
    int daysBack = 90,
    int limit = 100,
  }) async {
    if (!_isAuthorized) return [];

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      return await _historyService.getToolHistoryForDateRange(
        toolId: toolId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting tool transactions: $e');
      return [];
    }
  }

  /// Get transactions for a specific staff member
  /// Returns last 90 days by default
  Future<List<Map<String, dynamic>>> getStaffTransactions(
    String staffUid, {
    int daysBack = 90,
    int limit = 100,
  }) async {
    if (!_isAuthorized) return [];

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      return await _historyService.getToolHistoryForDateRange(
        staffUid: staffUid,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting staff transactions: $e');
      return [];
    }
  }

  /// Get filtered transactions from hierarchical structure
  Future<List<Map<String, dynamic>>> getFilteredTransactions({
    String? action, // 'checkout' or 'checkin'
    String? toolId,
    String? staffUid,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (!_isAuthorized) return [];

    try {
      // Default to last 30 days if no date range provided
      final effectiveStartDate =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final effectiveEndDate = endDate ?? DateTime.now();

      return await _historyService.getToolHistoryForDateRange(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
        toolId: toolId,
        staffUid: staffUid,
        action: action,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting filtered transactions: $e');
      return [];
    }
  }

  /// Search transactions by query (searches tool name, staff name, notes)
  List<Map<String, dynamic>> searchTransactions(String query) {
    if (!_isAuthorized) return [];
    if (query.isEmpty) return _allTransactions;

    final lowerQuery = query.toLowerCase();
    return _allTransactions.where((transaction) {
      final metadata = transaction['metadata'] as Map<String, dynamic>?;
      final toolName = metadata?['toolName'] as String? ?? '';
      final staffName = metadata?['staffName'] as String? ?? '';
      final notes = transaction['notes'] as String? ?? '';

      return toolName.toLowerCase().contains(lowerQuery) ||
          staffName.toLowerCase().contains(lowerQuery) ||
          notes.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get transaction statistics for a date range
  Future<Map<String, int>> getTransactionStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isAuthorized) {
      return {'totalTransactions': 0, 'checkouts': 0, 'checkins': 0};
    }

    try {
      // Default to last 30 days if no date range provided
      final effectiveStartDate =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final effectiveEndDate = endDate ?? DateTime.now();

      final transactions = await _historyService.getToolHistoryForDateRange(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );

      final checkouts = transactions
          .where((t) => t['action'] == 'checkout')
          .length;
      final checkins = transactions
          .where((t) => t['action'] == 'checkin')
          .length;

      return {
        'totalTransactions': transactions.length,
        'checkouts': checkouts,
        'checkins': checkins,
      };
    } catch (e) {
      debugPrint('Error getting transaction stats: $e');
      return {'totalTransactions': 0, 'checkouts': 0, 'checkins': 0};
    }
  }

  /// Get tool status info from recent transactions
  Future<Map<String, dynamic>?> getToolStatusFromCache(
    String toolId, {
    int daysBack = 30,
  }) async {
    if (!_isAuthorized) return null;

    final toolTransactions = await getToolTransactions(
      toolId,
      daysBack: daysBack,
      limit: 1,
    );
    if (toolTransactions.isEmpty) return null;

    // Get the latest transaction for this tool
    final latestTransaction = toolTransactions.first;

    return {
      'currentStatus': latestTransaction['action'] == 'checkout'
          ? 'checked_out'
          : 'available',
      'lastAction': latestTransaction['action'],
      'lastActionDate': latestTransaction['timestamp'],
      'assignedStaff': latestTransaction['action'] == 'checkout'
          ? latestTransaction['metadata']
          : null,
    };
  }

  /// Update authorization status (called when user auth changes)
  void updateAuthorization(bool isUserAdmin) {
    final wasAuthorized = _isAuthorized;
    _isAuthorized = isUserAdmin;

    if (_isAuthorized && !wasAuthorized) {
      // User gained admin access, start loading
      _loadingState = TransactionsLoadingState.loading;
      _initializeListener();
    } else if (!_isAuthorized && wasAuthorized) {
      // User lost admin access, clear data
      _loadingState = TransactionsLoadingState.unauthorized;
      _allTransactions.clear();
      _buildCachedLists();
      _transactionsSubscription?.cancel();
    }

    notifyListeners();
  }

  /// Retry loading after error
  void retry() {
    if (_loadingState == TransactionsLoadingState.error && _isAuthorized) {
      _loadingState = TransactionsLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      // Restart listener
      _transactionsSubscription?.cancel();
      _initializeListener();
    }
  }

  /// Clear error state
  void clearError() {
    if (_loadingState == TransactionsLoadingState.error) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Refresh data by restarting listener
  void refresh() {
    if (_isAuthorized) {
      _transactionsSubscription?.cancel();
      _loadingState = TransactionsLoadingState.loading;
      notifyListeners();
      _initializeListener();
    }
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

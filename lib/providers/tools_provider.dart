import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';

enum ToolsLoadingState { loading, loaded, error }

class ToolsProvider extends ChangeNotifier {
  final ToolService _toolService = ToolService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  ToolsLoadingState _loadingState = ToolsLoadingState.loading;
  List<Tool> _allTools = [];
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _toolsSubscription;

  // Cached filtered lists for performance
  List<Tool> _availableTools = [];
  List<Tool> _checkedOutTools = [];
  final Map<String, Tool> _toolsById = {};
  final Map<String, Tool> _toolsByUniqueId = {};

  // Getters
  ToolsLoadingState get loadingState => _loadingState;
  List<Tool> get allTools => List.unmodifiable(_allTools);
  List<Tool> get availableTools => List.unmodifiable(_availableTools);
  List<Tool> get checkedOutTools => List.unmodifiable(_checkedOutTools);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == ToolsLoadingState.loading;
  bool get hasError => _loadingState == ToolsLoadingState.error;
  bool get isLoaded => _loadingState == ToolsLoadingState.loaded;

  // Statistics
  int get totalToolsCount => _allTools.length;
  int get availableToolsCount => _availableTools.length;
  int get checkedOutToolsCount => _checkedOutTools.length;

  ToolsProvider() {
    _initializeListener();
  }

  /// Initialize real-time listener for tools collection
  void _initializeListener() {
    _toolsSubscription = _firestore
        .collection('tools')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(_handleToolsSnapshot, onError: _handleError);
  }

  /// Handle Firestore snapshot updates
  void _handleToolsSnapshot(QuerySnapshot snapshot) {
    try {
      _allTools = snapshot.docs.map((doc) => Tool.fromFirestore(doc)).toList();

      _buildCachedLists();
      _loadingState = ToolsLoadingState.loaded;
      _errorMessage = null;

      debugPrint('Tools updated: ${_allTools.length} total tools loaded');
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Build cached filtered lists and lookup maps for performance
  void _buildCachedLists() {
    _availableTools = _allTools.where((tool) => tool.isAvailable).toList();
    _checkedOutTools = _allTools.where((tool) => !tool.isAvailable).toList();

    // Build lookup maps for fast access
    _toolsById.clear();
    _toolsByUniqueId.clear();

    for (final tool in _allTools) {
      _toolsById[tool.id] = tool;
      _toolsByUniqueId[tool.uniqueId] = tool;
    }
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _loadingState = ToolsLoadingState.error;
    _errorMessage = error.toString();
    debugPrint('Tools provider error: $error');
    notifyListeners();
  }

  /// Get tool by ID from cache
  Tool? getToolById(String id) {
    return _toolsById[id];
  }

  /// Get tool by unique ID from cache (for QR scanning)
  Tool? getToolByUniqueId(String uniqueId) {
    return _toolsByUniqueId[uniqueId];
  }

  /// Get fresh tool status from cache (uses real-time subscription data)
  /// This is useful after transactions to ensure status is up-to-date
  Tool? getToolWithLatestStatus(String uniqueId) {
    // The real-time subscription keeps the cache updated automatically
    // This method is for explicit status checks after transactions
    final tool = _toolsByUniqueId[uniqueId];
    if (tool != null) {
      debugPrint(
        '📊 Tool ${tool.uniqueId} current status: ${tool.status} (from real-time cache)',
      );
    }
    return tool;
  }

  /// Validate if a tool can be checked out (is available)
  bool canCheckOut(String uniqueId) {
    final tool = _toolsByUniqueId[uniqueId];
    return tool?.isAvailable ?? false;
  }

  /// Validate if a tool can be checked in (is checked out)
  bool canCheckIn(String uniqueId) {
    final tool = _toolsByUniqueId[uniqueId];
    return tool != null && !tool.isAvailable;
  }

  /// Search tools by query (searches name, brand, model, uniqueId, num)
  List<Tool> searchTools(String query) {
    if (query.isEmpty) return _allTools;

    final lowerQuery = query.toLowerCase();
    return _allTools.where((tool) {
      return tool.name.toLowerCase().contains(lowerQuery) ||
          tool.brand.toLowerCase().contains(lowerQuery) ||
          tool.model.toLowerCase().contains(lowerQuery) ||
          tool.uniqueId.toLowerCase().contains(lowerQuery) ||
          tool.num.toLowerCase().contains(lowerQuery) ||
          tool.displayName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get filtered tools by status
  List<Tool> getToolsByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return _availableTools;
      case 'checked_out':
        return _checkedOutTools;
      default:
        return _allTools;
    }
  }

  /// Get tools with combined filters
  List<Tool> getFilteredTools({
    String? status,
    String? searchQuery,
    String? brand,
    String? model,
  }) {
    List<Tool> filtered = _allTools;

    // Apply status filter
    if (status != null && status != 'all') {
      filtered = getToolsByStatus(status);
    }

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered.where((tool) {
        return tool.name.toLowerCase().contains(lowerQuery) ||
            tool.brand.toLowerCase().contains(lowerQuery) ||
            tool.model.toLowerCase().contains(lowerQuery) ||
            tool.uniqueId.toLowerCase().contains(lowerQuery) ||
            tool.num.toLowerCase().contains(lowerQuery) ||
            tool.displayName.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    // Apply brand filter
    if (brand != null && brand.isNotEmpty) {
      filtered = filtered
          .where((tool) => tool.brand.toLowerCase() == brand.toLowerCase())
          .toList();
    }

    // Apply model filter
    if (model != null && model.isNotEmpty) {
      filtered = filtered
          .where((tool) => tool.model.toLowerCase() == model.toLowerCase())
          .toList();
    }

    return filtered;
  }

  /// Get unique brands from all tools
  List<String> getAllBrands() {
    final brands = _allTools.map((tool) => tool.brand).toSet().toList();
    // Create a new modifiable list to avoid sort() errors
    final sortableBrands = List<String>.from(brands);
    sortableBrands.sort();
    return sortableBrands;
  }

  /// Get unique models from all tools
  List<String> getAllModels() {
    final models = _allTools.map((tool) => tool.model).toSet().toList();
    // Create a new modifiable list to avoid sort() errors
    final sortableModels = List<String>.from(models);
    sortableModels.sort();
    return sortableModels;
  }

  /// Get models for a specific brand
  List<String> getModelsForBrand(String brand) {
    final models = _allTools
        .where((tool) => tool.brand.toLowerCase() == brand.toLowerCase())
        .map((tool) => tool.model)
        .toSet()
        .toList();
    // Create a new modifiable list to avoid sort() errors
    final sortableModels = List<String>.from(models);
    sortableModels.sort();
    return sortableModels;
  }

  /// Create new tool (delegates to service)
  Future<String> createTool(Tool tool) async {
    try {
      final id = await _toolService.createTool(tool);
      // Real-time listener will automatically update the provider
      return id;
    } catch (e) {
      debugPrint('Error creating tool: $e');
      rethrow;
    }
  }

  /// Update tool (delegates to service)
  Future<void> updateTool(Tool tool) async {
    try {
      await _toolService.updateTool(tool.id, tool.toFirestore());
      // Real-time listener will automatically update the provider
    } catch (e) {
      debugPrint('Error updating tool: $e');
      rethrow;
    }
  }

  /// Delete tool (delegates to service)
  Future<void> deleteTool(String toolId) async {
    try {
      await _toolService.deleteTool(toolId);
      // Real-time listener will automatically update the provider
    } catch (e) {
      debugPrint('Error deleting tool: $e');
      rethrow;
    }
  }

  /// Retry loading after error
  void retry() {
    if (_loadingState == ToolsLoadingState.error) {
      _loadingState = ToolsLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      // Restart listener
      _toolsSubscription?.cancel();
      _initializeListener();
    }
  }

  /// Clear error state
  void clearError() {
    if (_loadingState == ToolsLoadingState.error) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _toolsSubscription?.cancel();
    super.dispose();
  }
}

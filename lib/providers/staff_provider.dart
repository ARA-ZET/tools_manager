import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';

enum StaffLoadingState {
  loading,
  loaded,
  error,
  unauthorized, // For non-admin users
}

class StaffProvider extends ChangeNotifier {
  final StaffService _staffService = StaffService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  StaffLoadingState _loadingState = StaffLoadingState.loading;
  List<Staff> _allStaff = [];
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _staffSubscription;
  bool _isAuthorized = false;

  // Cached filtered lists for performance
  List<Staff> _activeStaff = [];
  List<Staff> _inactiveStaff = [];
  List<Staff> _adminStaff = [];
  List<Staff> _supervisorStaff = [];
  final Map<String, Staff> _staffById = {};
  final Map<String, Staff> _staffByAuthUid = {};
  final Map<String, Staff> _staffByJobCode = {};
  final Map<String, Staff> _staffByEmail = {};

  // Getters
  StaffLoadingState get loadingState => _loadingState;
  List<Staff> get allStaff => List.unmodifiable(_allStaff);
  List<Staff> get activeStaff => List.unmodifiable(_activeStaff);
  List<Staff> get inactiveStaff => List.unmodifiable(_inactiveStaff);
  List<Staff> get adminStaff => List.unmodifiable(_adminStaff);
  List<Staff> get supervisorStaff => List.unmodifiable(_supervisorStaff);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == StaffLoadingState.loading;
  bool get hasError => _loadingState == StaffLoadingState.error;
  bool get isLoaded => _loadingState == StaffLoadingState.loaded;
  bool get isUnauthorized => _loadingState == StaffLoadingState.unauthorized;
  bool get isAuthorized => _isAuthorized;

  // Statistics
  int get totalStaffCount => _allStaff.length;
  int get activeStaffCount => _activeStaff.length;
  int get inactiveStaffCount => _inactiveStaff.length;
  int get adminStaffCount => _adminStaff.length;

  StaffProvider();

  /// Initialize staff data loading with authorization check
  void initialize(bool isUserAdmin) {
    debugPrint(
      'StaffProvider.initialize called with isUserAdmin: $isUserAdmin',
    );
    _isAuthorized = isUserAdmin;

    if (!_isAuthorized) {
      debugPrint(
        'StaffProvider: User not authorized, setting state to unauthorized',
      );
      _loadingState = StaffLoadingState.unauthorized;
      notifyListeners();
      return;
    }

    debugPrint('StaffProvider: User authorized, initializing listener');
    _initializeListener();
  }

  /// Initialize real-time listener for staff collection (admin only)
  void _initializeListener() {
    if (!_isAuthorized) {
      debugPrint(
        'StaffProvider._initializeListener: Not authorized, returning',
      );
      return;
    }

    debugPrint(
      'StaffProvider._initializeListener: Setting up Firestore listener',
    );
    _staffSubscription = _firestore
        .collection('staff')
        .orderBy('fullName')
        .snapshots()
        .listen(_handleStaffSnapshot, onError: _handleError);
  }

  /// Handle Firestore snapshot updates
  void _handleStaffSnapshot(QuerySnapshot snapshot) {
    try {
      debugPrint(
        'StaffProvider._handleStaffSnapshot: Received snapshot with ${snapshot.docs.length} documents',
      );
      _allStaff = snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();

      _buildCachedLists();
      _loadingState = StaffLoadingState.loaded;
      _errorMessage = null;

      debugPrint('Staff updated: ${_allStaff.length} total staff loaded');
      debugPrint(
        'Active staff: ${_activeStaff.length}, Admin staff: ${_adminStaff.length}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('StaffProvider._handleStaffSnapshot: Error - $e');
      _handleError(e);
    }
  }

  /// Build cached filtered lists and lookup maps for performance
  void _buildCachedLists() {
    _activeStaff = _allStaff.where((staff) => staff.isActive).toList();
    _inactiveStaff = _allStaff.where((staff) => !staff.isActive).toList();
    _adminStaff = _allStaff.where((staff) => staff.role.isAdmin).toList();
    _supervisorStaff = _allStaff
        .where((staff) => staff.role.isSupervisor)
        .toList();

    // Build lookup maps for fast access
    _staffById.clear();
    _staffByAuthUid.clear();
    _staffByJobCode.clear();
    _staffByEmail.clear();

    for (final staff in _allStaff) {
      _staffById[staff.uid] = staff;
      if (staff.firebaseAuthUid != null) {
        _staffByAuthUid[staff.firebaseAuthUid!] = staff;
      }
      _staffByJobCode[staff.jobCode] = staff;
      _staffByEmail[staff.email] = staff;
    }
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _loadingState = StaffLoadingState.error;
    _errorMessage = error.toString();
    debugPrint('Staff provider error: $error');
    notifyListeners();
  }

  /// Get staff by ID from cache
  Staff? getStaffById(String id) {
    return _staffById[id];
  }

  /// Get staff by auth UID from cache
  Staff? getStaffByAuthUid(String authUid) {
    return _staffByAuthUid[authUid];
  }

  /// Get staff by job code from cache
  Staff? getStaffByJobCode(String jobCode) {
    return _staffByJobCode[jobCode];
  }

  /// Get staff by email from cache
  Staff? getStaffByEmail(String email) {
    return _staffByEmail[email];
  }

  /// Search staff by query (searches name, email, jobCode)
  List<Staff> searchStaff(String query) {
    if (!_isAuthorized) return [];
    if (query.isEmpty) return _allStaff;

    final lowerQuery = query.toLowerCase();
    return _allStaff.where((staff) {
      return staff.fullName.toLowerCase().contains(lowerQuery) ||
          staff.email.toLowerCase().contains(lowerQuery) ||
          staff.jobCode.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get filtered staff by status and role
  List<Staff> getFilteredStaff({
    bool? isActive,
    StaffRole? role,
    String? searchQuery,
  }) {
    if (!_isAuthorized) return [];

    List<Staff> filtered = _allStaff;

    // Apply active status filter
    if (isActive != null) {
      filtered = isActive ? _activeStaff : _inactiveStaff;
    }

    // Apply role filter
    if (role != null) {
      filtered = filtered.where((staff) => staff.role == role).toList();
    }

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      filtered = filtered.where((staff) {
        return staff.fullName.toLowerCase().contains(lowerQuery) ||
            staff.email.toLowerCase().contains(lowerQuery) ||
            staff.jobCode.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    return filtered;
  }

  /// Get staff by role type
  List<Staff> getStaffByRole(StaffRole role) {
    if (!_isAuthorized) return [];
    return _allStaff.where((staff) => staff.role == role).toList();
  }

  /// Get all unique teams
  List<String> getAllTeams() {
    if (!_isAuthorized) return [];
    final teams = _allStaff
        .where((staff) => staff.teamId != null)
        .map((staff) => staff.teamId!)
        .toSet()
        .toList();
    // Create a new modifiable list to avoid sort() errors
    final sortableTeams = List<String>.from(teams);
    sortableTeams.sort();
    return sortableTeams;
  }

  /// Get staff by team
  List<Staff> getStaffByTeam(String teamId) {
    if (!_isAuthorized) return [];
    return _allStaff.where((staff) => staff.teamId == teamId).toList();
  }

  /// Create new staff member (delegates to service)
  Future<String> createStaff({
    required String fullName,
    required String email,
    required String jobCode,
    required StaffRole role,
    String? teamId,
    String? photoUrl,
  }) async {
    if (!_isAuthorized) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      final id = await _staffService.createStaffWithData(
        fullName: fullName,
        email: email,
        jobCode: jobCode,
        role: role,
        teamId: teamId,
        photoUrl: photoUrl,
      );
      // Real-time listener will automatically update the provider
      return id;
    } catch (e) {
      debugPrint('Error creating staff: $e');
      rethrow;
    }
  }

  /// Update staff member (delegates to service)
  Future<void> updateStaff(Staff staff) async {
    if (!_isAuthorized) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      await _staffService.updateStaff(staff.uid, staff.toFirestore());
      // Real-time listener will automatically update the provider
    } catch (e) {
      debugPrint('Error updating staff: $e');
      rethrow;
    }
  }

  /// Deactivate staff member (soft delete)
  Future<void> deactivateStaffMember(String staffId) async {
    if (!_isAuthorized) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      await _staffService.deactivateStaff(staffId);
      // Real-time listener will automatically update the provider
    } catch (e) {
      debugPrint('Error deactivating staff: $e');
      rethrow;
    }
  }

  /// Reactivate staff member
  Future<void> reactivateStaffMember(String staffId) async {
    if (!_isAuthorized) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      await _staffService.reactivateStaff(staffId);
      // Real-time listener will automatically update the provider
    } catch (e) {
      debugPrint('Error reactivating staff: $e');
      rethrow;
    }
  }

  /// Update authorization status (called when user auth changes)
  void updateAuthorization(bool isUserAdmin) {
    final wasAuthorized = _isAuthorized;
    _isAuthorized = isUserAdmin;

    if (_isAuthorized && !wasAuthorized) {
      // User gained admin access, start loading
      _loadingState = StaffLoadingState.loading;
      _initializeListener();
    } else if (!_isAuthorized && wasAuthorized) {
      // User lost admin access, clear data
      _loadingState = StaffLoadingState.unauthorized;
      _allStaff.clear();
      _buildCachedLists();
      _staffSubscription?.cancel();
    }

    notifyListeners();
  }

  /// Retry loading after error
  void retry() {
    if (_loadingState == StaffLoadingState.error && _isAuthorized) {
      _loadingState = StaffLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      // Restart listener
      _staffSubscription?.cancel();
      _initializeListener();
    }
  }

  /// Clear error state
  void clearError() {
    if (_loadingState == StaffLoadingState.error) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _staffSubscription?.cancel();
    super.dispose();
  }
}

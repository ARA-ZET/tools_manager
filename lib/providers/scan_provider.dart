import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/staff.dart';
import '../services/secure_tool_transaction_service.dart';
import '../services/staff_service.dart';
import '../services/id_mapping_service.dart';

enum ScanMode { single, batch }

enum ScanState { idle, processing, debounced }

enum BatchType { checkout, checkin }

enum BatchScanResult {
  success, // Tool added to batch successfully
  alreadyInBatch, // Tool already exists in batch
  debounced, // Duplicate scan ignored
  toolNotFound, // Tool doesn't exist in database
}

class ScanProvider extends ChangeNotifier {
  // Services
  final SecureToolTransactionService _secureTransactionService =
      SecureToolTransactionService();
  final StaffService _staffService = StaffService();
  final IdMappingService _idMappingService = IdMappingService();

  // State
  ScanMode _scanMode = ScanMode.single;
  ScanState _scanState = ScanState.idle;
  BatchType? _batchType; // null = not set yet, determined by first scan
  final List<String> _scannedTools = [];
  String _searchQuery = '';
  String _selectedFilter = 'all';
  Staff? _currentStaff;
  String? _errorMessage;

  // Debounce mechanism
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  Timer? _debounceTimer;

  // Getters
  ScanMode get scanMode => _scanMode;
  ScanState get scanState => _scanState;
  BatchType? get batchType => _batchType;
  List<String> get scannedTools => List.unmodifiable(_scannedTools);
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  Staff? get currentStaff => _currentStaff;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _scanState == ScanState.processing;
  bool get isDebounced => _scanState == ScanState.debounced;
  bool get isBatchMode => _scanMode == ScanMode.batch;
  bool get hasBatchItems => _scannedTools.isNotEmpty;
  int get batchCount => _scannedTools.length;
  bool get isBatchTypeSet => _batchType != null;

  // Initialize scan provider
  void initialize() {
    _loadCurrentStaff();
  }

  // Load current staff member
  Future<void> _loadCurrentStaff() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staff = await _staffService.getStaffByAuthUid(user.uid);
        _currentStaff = staff;
        _errorMessage = null;
      } else {
        _currentStaff = null;
        _errorMessage = 'User not authenticated';
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading user data: $e';
      _currentStaff = null;
      notifyListeners();
    }
  }

  // Toggle scan mode
  void toggleScanMode() {
    _scanMode = _scanMode == ScanMode.single ? ScanMode.batch : ScanMode.single;
    if (_scanMode == ScanMode.single) {
      clearBatch();
    }
    notifyListeners();
  }

  // Set scan mode explicitly
  void setScanMode(ScanMode mode) {
    if (_scanMode != mode) {
      _scanMode = mode;
      if (_scanMode == ScanMode.single) {
        clearBatch();
      }
      notifyListeners();
    }
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Update filter
  void updateFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  // Handle scanned code
  Future<bool> handleScannedCode(String code) async {
    debugPrint('🔍 ScanProvider: handleScannedCode($code)');

    // Extract tool ID from QR code
    String toolId = code;
    if (code.startsWith('TOOL#')) {
      toolId = code.substring(5);
    }
    debugPrint('🔧 Extracted toolId: $toolId');

    // Check debounce
    if (_shouldDebounce(toolId)) {
      debugPrint('⏱️ Debounced - ignoring duplicate scan');
      return false; // Return false to indicate scan was not processed
    }

    // Update debounce tracking
    _updateDebounce(toolId);

    if (_scanMode == ScanMode.batch) {
      debugPrint(
        '📦 Batch mode - scan validated, letting screen handle dialogs',
      );
      return true; // Return true to indicate scan should be processed by screen
    } else {
      // Single scan mode - trigger callback for dialog
      debugPrint('📱 Single scan mode - setting processing state');
      _scanState = ScanState.processing;
      notifyListeners();

      // The scan screen will listen to this and show dialog
      // Reset processing state after a delay if no one handles it
      Timer(const Duration(seconds: 3), () {
        if (_scanState == ScanState.processing) {
          debugPrint('⏰ Auto-resetting processing state after timeout');
          _scanState = ScanState.idle;
          notifyListeners();
        }
      });
      return true; // Return true to indicate scan was processed
    }
  }

  // Check if should debounce
  bool _shouldDebounce(String toolId) {
    final now = DateTime.now();
    if (_lastScannedCode == toolId &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) {
      return true;
    }
    return false;
  }

  // Update debounce tracking
  void _updateDebounce(String toolId) {
    _lastScannedCode = toolId;
    _lastScanTime = DateTime.now();

    // Set debounced state briefly
    _scanState = ScanState.debounced;
    notifyListeners();

    // Clear debounced state after a short delay
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_scanState == ScanState.debounced) {
        _scanState = ScanState.idle;
        notifyListeners();
      }
    });
  }

  // Add tool to batch
  bool _addToBatch(String toolId) {
    if (!_scannedTools.contains(toolId)) {
      _scannedTools.add(toolId);
      debugPrint('✅ Added $toolId to batch (${_scannedTools.length} tools)');
      notifyListeners();
      return true;
    } else {
      debugPrint('⚠️ Tool $toolId already in batch');
      return false;
    }
  }

  // Add tool to batch (public method for manual addition)
  void addToBatch(String toolId) {
    _addToBatch(toolId);
  }

  // Set batch type based on first tool scanned
  void setBatchType(BatchType type) {
    if (_batchType == null) {
      _batchType = type;
      debugPrint('📋 Batch type set to: $type');
      notifyListeners();
    }
  }

  // Check if a tool can be added to current batch
  bool canAddToBatch(bool isToolAvailable) {
    // If batch type not set, any tool can start the batch
    if (_batchType == null) return true;

    // If batch is for checkout, only available tools allowed
    if (_batchType == BatchType.checkout && !isToolAvailable) {
      return false;
    }

    // If batch is for checkin, only checked out tools allowed
    if (_batchType == BatchType.checkin && isToolAvailable) {
      return false;
    }

    return true;
  }

  // Remove from batch
  void removeFromBatch(String toolId) {
    _scannedTools.remove(toolId);
    notifyListeners();
  }

  // Clear batch
  void clearBatch() {
    _scannedTools.clear();
    _batchType = null; // Reset batch type when clearing
    notifyListeners();
  }

  // Reset scan debounce
  void resetDebounce() {
    _lastScannedCode = null;
    _lastScanTime = null;
    _debounceTimer?.cancel();
    _scanState = ScanState.idle;
    notifyListeners();
  }

  // Set processing state
  void setProcessing(bool processing) {
    _scanState = processing ? ScanState.processing : ScanState.idle;
    notifyListeners();
  }

  // Refresh current staff
  Future<void> refreshStaff() async {
    await _loadCurrentStaff();
  }

  // Handle batch checkout
  Future<Map<String, dynamic>> processBatchCheckout() async {
    if (_scannedTools.isEmpty || _currentStaff == null) {
      return {'success': false, 'message': 'No tools or invalid user'};
    }

    _scanState = ScanState.processing;
    notifyListeners();

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (final toolId in _scannedTools) {
        try {
          final staffJobCode = await _idMappingService.getStaffJobCodeFromUid(
            _currentStaff!.uid,
          );
          if (staffJobCode == null) {
            throw Exception('Staff job code not found');
          }

          final success = await _secureTransactionService.checkOutTool(
            toolUniqueId: toolId,
            staffJobCode: staffJobCode,
            adminName: _currentStaff?.fullName,
          );

          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          errors.add(
            '$toolId: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }

      // Clear batch if all successful
      if (failCount == 0) {
        clearBatch();
      }

      return {
        'success': successCount > 0,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': successCount > 0
            ? 'Batch checkout completed: $successCount success${failCount > 0 ? ', $failCount failed' : ''}'
            : 'Batch checkout failed: $failCount tools could not be checked out',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Batch checkout failed: ${e.toString()}',
      };
    } finally {
      _scanState = ScanState.idle;
      notifyListeners();
    }
  }

  // Handle batch checkin
  Future<Map<String, dynamic>> processBatchCheckin() async {
    if (_scannedTools.isEmpty || _currentStaff == null) {
      return {'success': false, 'message': 'No tools or invalid user'};
    }

    _scanState = ScanState.processing;
    notifyListeners();

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      for (final toolId in _scannedTools) {
        try {
          final success = await _secureTransactionService.checkInTool(
            toolUniqueId: toolId,
            adminName: _currentStaff?.fullName,
          );

          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          errors.add(
            '$toolId: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }

      // Clear batch if all successful
      if (failCount == 0) {
        clearBatch();
      }

      return {
        'success': successCount > 0,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': successCount > 0
            ? 'Batch checkin completed: $successCount success${failCount > 0 ? ', $failCount failed' : ''}'
            : 'Batch checkin failed: $failCount tools could not be checked in',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Batch checkin failed: ${e.toString()}',
      };
    } finally {
      _scanState = ScanState.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

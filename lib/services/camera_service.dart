import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera service for QR scanning across platforms
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  MobileScannerController? _controller;
  bool _isInitialized = false;
  bool _hasPermission = false;

  /// Initialize camera controller
  Future<bool> initialize() async {
    try {
      if (_controller != null) {
        await _controller!.dispose();
      }

      _controller = MobileScannerController(
        formats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
        ],
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        detectionTimeoutMs: 1000,
      );

      _isInitialized = true;
      _hasPermission = true;
      return true;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _isInitialized = false;
      _hasPermission = false;
      return false;
    }
  }

  /// Check if camera is available
  bool get isAvailable => _isInitialized && _hasPermission;

  /// Get camera controller
  MobileScannerController? get controller => _controller;

  /// Check camera permission
  Future<bool> checkPermission() async {
    try {
      if (kIsWeb) {
        // For web, permission is checked during initialization
        return _hasPermission;
      }

      // For mobile platforms, you might want to add permission_handler
      return true;
    } catch (e) {
      debugPrint('Permission check failed: $e');
      return false;
    }
  }

  /// Request camera permission
  Future<bool> requestPermission() async {
    try {
      final hasPermission = await checkPermission();
      if (hasPermission) {
        return await initialize();
      }
      return false;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  /// Start scanning
  Future<void> startScanning() async {
    if (_controller != null && _isInitialized) {
      await _controller!.start();
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (_controller != null && _isInitialized) {
      await _controller!.stop();
    }
  }

  /// Toggle torch/flashlight
  Future<void> toggleTorch() async {
    if (_controller != null && _isInitialized) {
      await _controller!.toggleTorch();
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_controller != null && _isInitialized) {
      await _controller!.switchCamera();
    }
  }

  /// Extract tool ID from scanned code
  String extractToolId(String scannedCode) {
    // Handle different QR code formats
    if (scannedCode.startsWith('TOOL#')) {
      return scannedCode.substring(5);
    } else if (scannedCode.startsWith('T') && scannedCode.length > 1) {
      return scannedCode;
    } else {
      // Assume it's already a tool ID
      return scannedCode.toUpperCase();
    }
  }

  /// Validate tool ID format
  bool isValidToolId(String toolId) {
    // Tool ID should start with T followed by numbers
    final regex = RegExp(r'^T\d+$');
    return regex.hasMatch(toolId.toUpperCase());
  }

  /// Dispose camera resources
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    _hasPermission = false;
  }

  /// Get camera capabilities
  Map<String, dynamic> getCameraCapabilities() {
    return {
      'isInitialized': _isInitialized,
      'hasPermission': _hasPermission,
      'isWeb': kIsWeb,
      'supportsTorch': !kIsWeb,
      'supportsCameraSwitch': !kIsWeb,
    };
  }
}

/// Camera state for UI updates
class CameraState {
  final bool isInitialized;
  final bool hasPermission;
  final bool isScanning;
  final bool torchEnabled;
  final String? error;

  const CameraState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.isScanning = false,
    this.torchEnabled = false,
    this.error,
  });

  CameraState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    bool? isScanning,
    bool? torchEnabled,
    String? error,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      isScanning: isScanning ?? this.isScanning,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      error: error ?? this.error,
    );
  }
}

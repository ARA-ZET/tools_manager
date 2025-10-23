import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Provider for managing camera controller lifecycle across the app
/// Ensures camera persists when switching tabs, batch/single mode, or screens
class CameraProvider with ChangeNotifier {
  MobileScannerController? _controller;
  bool _isInitialized = false;
  bool _isStarted = false;
  bool _torchEnabled = false;
  String? _errorMessage;
  bool _isPaused = false;

  // Getters
  MobileScannerController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStarted => _isStarted;
  bool get torchEnabled => _torchEnabled;
  String? get errorMessage => _errorMessage;
  bool get isPaused => _isPaused;
  bool get hasError => _errorMessage != null;

  /// Initialize camera controller (only once)
  Future<void> initialize() async {
    if (_isInitialized && _controller != null) {
      debugPrint('📷 Camera already initialized');
      return;
    }

    debugPrint('📷 Initializing camera controller...');

    try {
      _controller = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );

      _isInitialized = true;
      _errorMessage = null;
      debugPrint('✅ Camera controller created successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize camera: $e');
      _errorMessage = 'Failed to initialize camera: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Start camera (separate from initialization for lifecycle management)
  Future<void> start() async {
    if (!_isInitialized || _controller == null) {
      debugPrint('⚠️ Camera not initialized, initializing first...');
      await initialize();
    }

    if (_isStarted) {
      debugPrint('📷 Camera already started');
      return;
    }

    try {
      debugPrint('📷 Starting camera...');
      await _controller!.start();
      _isStarted = true;
      _isPaused = false;
      _errorMessage = null;
      debugPrint('✅ Camera started successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to start camera: $e');
      _errorMessage = 'Failed to start camera: $e';
      notifyListeners();
    }
  }

  /// Stop camera (keeps controller alive for quick restart)
  Future<void> stop() async {
    if (_controller == null || !_isStarted) {
      debugPrint('📷 Camera not running, nothing to stop');
      return;
    }

    try {
      debugPrint('📷 Stopping camera...');
      await _controller!.stop();
      _isStarted = false;
      _isPaused = false;
      if (_torchEnabled) {
        _torchEnabled = false; // Torch turns off when camera stops
      }
      debugPrint('✅ Camera stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to stop camera: $e');
      _errorMessage = 'Failed to stop camera: $e';
      notifyListeners();
    }
  }

  /// Pause camera (for tab switches - lighter than stop)
  Future<void> pause() async {
    if (_controller == null || !_isStarted || _isPaused) {
      return;
    }

    try {
      debugPrint('⏸️ Pausing camera...');
      await _controller!.stop();
      _isPaused = true;
      debugPrint('✅ Camera paused');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to pause camera: $e');
    }
  }

  /// Resume camera (after pause)
  Future<void> resume() async {
    if (_controller == null || !_isPaused) {
      return;
    }

    try {
      debugPrint('▶️ Resuming camera...');
      await _controller!.start();
      _isPaused = false;
      debugPrint('✅ Camera resumed');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to resume camera: $e');
      _errorMessage = 'Failed to resume camera: $e';
      notifyListeners();
    }
  }

  /// Toggle torch
  Future<void> toggleTorch() async {
    if (_controller == null || !_isStarted) {
      debugPrint('⚠️ Camera not running, cannot toggle torch');
      return;
    }

    try {
      await _controller!.toggleTorch();
      _torchEnabled = !_torchEnabled;
      debugPrint('💡 Torch ${_torchEnabled ? "ON" : "OFF"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle torch: $e');
      _errorMessage = 'Failed to toggle torch: $e';
      notifyListeners();
    }
  }

  /// Reset camera (full restart)
  Future<void> reset() async {
    debugPrint('🔄 Resetting camera...');
    await dispose();
    await initialize();
    await start();
  }

  /// Dispose camera controller (only when provider is disposed)
  @override
  Future<void> dispose() async {
    debugPrint('🗑️ Disposing camera controller...');
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing controller: $e');
      }
      _controller = null;
    }
    _isInitialized = false;
    _isStarted = false;
    _torchEnabled = false;
    _isPaused = false;
    super.dispose();
    debugPrint('✅ Camera controller disposed');
  }

  /// Handle app lifecycle changes
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - starting camera');
        if (_isInitialized && !_isStarted) {
          await start();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        debugPrint('📱 App ${state.name} - stopping camera');
        await stop();
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden - stopping camera');
        await stop();
        break;
    }
  }
}

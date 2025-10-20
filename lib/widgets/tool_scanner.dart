import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/mallon_theme.dart';
import '../services/camera_service.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';

/// Enhanced tool scanner with camera support for all platforms
class ToolScanner extends StatefulWidget {
  final Function(String toolId) onToolScanned;
  final bool batchMode;

  const ToolScanner({
    super.key,
    required this.onToolScanned,
    this.batchMode = false,
  });

  @override
  State<ToolScanner> createState() => _ToolScannerState();
}

class _ToolScannerState extends State<ToolScanner> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final TextEditingController _manualController = TextEditingController();
  final ToolService _toolService = ToolService();

  bool _isInitializing = true;
  bool _hasPermission = false;
  bool _torchEnabled = false;
  String? _errorMessage;
  List<Tool> _allTools = [];
  StreamSubscription<List<Tool>>? _toolsSubscription;

  // Debouncing for scanner
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const Duration _scanDebounce = Duration(seconds: 2);

  // Visual feedback state
  bool _showScanFeedback = false;
  String? _lastScannedToolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadTools();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toolsSubscription?.cancel();
    _cameraService.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cameraService.startScanning();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cameraService.stopScanning();
        break;
      default:
        break;
    }
  }

  void _loadTools() {
    _toolsSubscription = _toolService.getToolsStream().listen((tools) {
      if (mounted) {
        setState(() {
          _allTools = tools;
        });
      }
    });
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final success = await _cameraService.initialize();
      if (mounted) {
        setState(() {
          _hasPermission = success;
          _isInitializing = false;
          if (!success) {
            _errorMessage = 'Camera access denied or unavailable';
          }
        });
      }

      if (success) {
        await _cameraService.startScanning();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasPermission = false;
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MallonColors.outline),
      ),
      child: Column(
        children: [
          // Camera View
          Expanded(
            flex: 3,
            child: _ScannerCameraView(
              isInitializing: _isInitializing,
              hasPermission: _hasPermission,
              errorMessage: _errorMessage,
              cameraService: _cameraService,
              onBarcodeDetected: _onBarcodeDetected,
              onRetry: _initializeCamera,
              batchMode: widget.batchMode,
              showScanFeedback: _showScanFeedback,
              lastScannedToolId: _lastScannedToolId,
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MallonColors.lightGrey,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // Camera Controls
                if (_hasPermission)
                  _ScannerCameraControls(
                    torchEnabled: _torchEnabled,
                    onToggleTorch: _toggleTorch,
                    onSwitchCamera: () => _cameraService.switchCamera(),
                    onRefresh: _initializeCamera,
                  ),

                const SizedBox(height: 16),

                // Manual Input
                _ScannerManualInput(
                  controller: _manualController,
                  onSubmit: _handleManualInput,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        final toolId = _cameraService.extractToolId(code);
        _handleScannedTool(toolId);
      }
    }
  }

  void _handleManualInput(String input) {
    if (input.trim().isEmpty) return;

    final toolId = _cameraService.extractToolId(input.trim());
    _manualController.clear();
    _handleScannedTool(toolId);
  }

  void _handleScannedTool(String toolId) {
    debugPrint('🎯 ToolScanner: _handleScannedTool($toolId)');

    // Check debouncing at the scanner level
    final now = DateTime.now();
    if (_lastScannedCode == toolId &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanDebounce) {
      debugPrint('🛑 ToolScanner: Debouncing duplicate scan of $toolId');
      return;
    }

    // Update debounce tracking
    _lastScannedCode = toolId;
    _lastScanTime = now;

    // Validate tool ID format first
    if (!_cameraService.isValidToolId(toolId)) {
      debugPrint('❌ Invalid tool ID format: $toolId');
      _showMessage('Invalid tool ID format: $toolId', isError: true);
      return;
    }

    // Check if tool exists in our local list
    final tool = _allTools
        .where((t) => t.uniqueId.toUpperCase() == toolId.toUpperCase())
        .firstOrNull;

    debugPrint('🔍 Tool found in local list: ${tool != null}');
    debugPrint('📊 Total tools in local list: ${_allTools.length}');

    if (tool == null) {
      debugPrint(
        '⚠️ Tool not found in ToolScanner local list, but proceeding anyway',
      );
      // Don't return here - let the scan screen handle validation
    } else {
      debugPrint('✅ Tool found in local list - ${tool.displayName}');
    }

    // Show immediate visual feedback
    setState(() {
      _showScanFeedback = true;
      _lastScannedToolId = toolId;
    });

    // Hide feedback after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showScanFeedback = false;
        });
      }
    });

    // Always trigger callback - let scan screen handle validation
    debugPrint('📞 Calling onToolScanned callback');
    widget.onToolScanned(toolId);
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? MallonColors.error
              : MallonColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _cameraService.toggleTorch();
      if (mounted) {
        setState(() {
          _torchEnabled = !_torchEnabled;
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to toggle flashlight', isError: true);
      }
    }
  }
}

/// Camera view widget with scanner overlay
class _ScannerCameraView extends StatelessWidget {
  final bool isInitializing;
  final bool hasPermission;
  final String? errorMessage;
  final CameraService cameraService;
  final Function(BarcodeCapture) onBarcodeDetected;
  final VoidCallback onRetry;
  final bool batchMode;
  final bool showScanFeedback;
  final String? lastScannedToolId;

  const _ScannerCameraView({
    required this.isInitializing,
    required this.hasPermission,
    required this.errorMessage,
    required this.cameraService,
    required this.onBarcodeDetected,
    required this.onRetry,
    required this.batchMode,
    required this.showScanFeedback,
    required this.lastScannedToolId,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return const _ScannerLoadingView();
    }

    if (!hasPermission || errorMessage != null) {
      return _ScannerErrorView(errorMessage: errorMessage, onRetry: onRetry);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: Stack(
        children: [
          MobileScanner(
            controller: cameraService.controller!,
            onDetect: onBarcodeDetected,
            errorBuilder: (context, error, child) =>
                _ScannerErrorView(errorMessage: errorMessage, onRetry: onRetry),
          ),

          // Scanner Overlay
          const _ScannerOverlay(),

          // Batch Mode Indicator
          if (batchMode) const _BatchModeIndicator(),

          // Scan Success Feedback
          if (showScanFeedback) _ScanSuccessFeedback(toolId: lastScannedToolId),
        ],
      ),
    );
  }
}

/// Loading view while camera initializes
class _ScannerLoadingView extends StatelessWidget {
  const _ScannerLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MallonColors.lightGrey,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Starting camera...'),
        ],
      ),
    );
  }
}

/// Error view when camera fails
class _ScannerErrorView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;

  const _ScannerErrorView({required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MallonColors.lightGrey,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: MallonColors.mediumGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Unavailable',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: MallonColors.mediumGrey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage ??
                  'Please allow camera access and ensure HTTPS for web',
              textAlign: TextAlign.center,
              style: TextStyle(color: MallonColors.secondaryText),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scanner overlay with QR frame
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: MallonColors.primaryGreen,
          borderRadius: 12,
          borderLength: 30,
          borderWidth: 4,
          cutOutSize: 250,
        ),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 300),
          child: Text(
            'Point camera at tool QR code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Batch mode indicator badge
class _BatchModeIndicator extends StatelessWidget {
  const _BatchModeIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: MallonColors.primaryGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Batch Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scan success feedback overlay
class _ScanSuccessFeedback extends StatelessWidget {
  final String? toolId;

  const _ScanSuccessFeedback({required this.toolId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MallonColors.primaryGreen.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Scanned!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (toolId != null) ...[
                const SizedBox(height: 8),
                Text(
                  toolId!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: MallonColors.primaryGreen,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Processing...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera control buttons
class _ScannerCameraControls extends StatelessWidget {
  final bool torchEnabled;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback onRefresh;

  const _ScannerCameraControls({
    required this.torchEnabled,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Toggle Torch
        IconButton(
          onPressed: onToggleTorch,
          icon: Icon(
            torchEnabled ? Icons.flash_on : Icons.flash_off,
            color: torchEnabled
                ? MallonColors.primaryGreen
                : MallonColors.mediumGrey,
          ),
          tooltip: 'Toggle flashlight',
        ),

        // Switch Camera
        IconButton(
          onPressed: onSwitchCamera,
          icon: Icon(Icons.cameraswitch, color: MallonColors.mediumGrey),
          tooltip: 'Switch camera',
        ),

        // Refresh Camera
        IconButton(
          onPressed: onRefresh,
          icon: Icon(Icons.refresh, color: MallonColors.mediumGrey),
          tooltip: 'Refresh camera',
        ),
      ],
    );
  }
}

/// Manual tool ID input widget
class _ScannerManualInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmit;

  const _ScannerManualInput({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual Entry',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter tool ID (e.g., T1234)',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onFieldSubmitted: onSubmit,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => onSubmit(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: MallonColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom scanner overlay shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    Path cutOut = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          Radius.circular(borderRadius),
        ),
      );
    return Path.combine(PathOperation.difference, path, cutOut);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cutOutWidth = cutOutSize;
    final cutOutHeight = cutOutSize;

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutWidth,
            height: cutOutHeight,
          ),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, paint);

    // Draw border corners
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutWidth,
      height: cutOutHeight,
    );

    // Draw corner brackets
    _drawCorner(canvas, borderPaint, cutOutRect.topLeft, true, true);
    _drawCorner(canvas, borderPaint, cutOutRect.topRight, false, true);
    _drawCorner(canvas, borderPaint, cutOutRect.bottomLeft, true, false);
    _drawCorner(canvas, borderPaint, cutOutRect.bottomRight, false, false);
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset corner,
    bool isLeft,
    bool isTop,
  ) {
    final path = Path();
    if (isLeft && isTop) {
      // Top-left
      path.moveTo(corner.dx, corner.dy + borderLength);
      path.lineTo(corner.dx, corner.dy + borderRadius);
      path.quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx + borderRadius,
        corner.dy,
      );
      path.lineTo(corner.dx + borderLength, corner.dy);
    } else if (!isLeft && isTop) {
      // Top-right
      path.moveTo(corner.dx - borderLength, corner.dy);
      path.lineTo(corner.dx - borderRadius, corner.dy);
      path.quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx,
        corner.dy + borderRadius,
      );
      path.lineTo(corner.dx, corner.dy + borderLength);
    } else if (isLeft && !isTop) {
      // Bottom-left
      path.moveTo(corner.dx + borderLength, corner.dy);
      path.lineTo(corner.dx + borderRadius, corner.dy);
      path.quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx,
        corner.dy - borderRadius,
      );
      path.lineTo(corner.dx, corner.dy - borderLength);
    } else {
      // Bottom-right
      path.moveTo(corner.dx, corner.dy - borderLength);
      path.lineTo(corner.dx, corner.dy - borderRadius);
      path.quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx - borderRadius,
        corner.dy,
      );
      path.lineTo(corner.dx - borderLength, corner.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
      borderRadius: borderRadius,
      borderLength: borderLength,
      cutOutSize: cutOutSize,
    );
  }
}

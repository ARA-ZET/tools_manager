import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/mallon_theme.dart';

/// QR Scanner provider for managing scan state
class ScannerProvider extends ChangeNotifier {
  final List<String> _scannedTools = [];
  bool _isBatchMode = false;
  bool _isScanning = true;
  String? _lastScannedCode;

  List<String> get scannedTools => List.unmodifiable(_scannedTools);
  bool get isBatchMode => _isBatchMode;
  bool get isScanning => _isScanning;
  String? get lastScannedCode => _lastScannedCode;
  int get scannedCount => _scannedTools.length;

  void toggleBatchMode() {
    _isBatchMode = !_isBatchMode;
    if (!_isBatchMode) {
      _scannedTools.clear();
    }
    notifyListeners();
  }

  void addScannedTool(String toolId) {
    if (!_scannedTools.contains(toolId)) {
      _scannedTools.add(toolId);
      _lastScannedCode = toolId;
      notifyListeners();
    }
  }

  void removeScannedTool(String toolId) {
    _scannedTools.remove(toolId);
    notifyListeners();
  }

  void clearScannedTools() {
    _scannedTools.clear();
    _lastScannedCode = null;
    notifyListeners();
  }

  void pauseScanning() {
    _isScanning = false;
    notifyListeners();
  }

  void resumeScanning() {
    _isScanning = true;
    notifyListeners();
  }
}

/// QR Scanner widget with mobile and web support
class QRScanner extends StatefulWidget {
  final Function(String) onCodeScanned;
  final bool enabled;

  const QRScanner({
    super.key,
    required this.onCodeScanned,
    this.enabled = true,
  });

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  MobileScannerController? _controller;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeScanner();
    }
  }

  void _initializeScanner() {
    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebScanner();
    } else {
      return _buildMobileScanner();
    }
  }

  Widget _buildMobileScanner() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: widget.enabled ? _onBarcodeDetected : null,
        ),

        // Scanner Overlay
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: MallonColors.primaryGreen,
              borderRadius: 12,
              borderLength: 30,
              borderWidth: 4,
              cutOutSize: 250,
            ),
          ),
        ),

        // Manual Input Button
        Positioned(
          bottom: 80,
          left: 20,
          right: 20,
          child: MallonWidgets.actionButton(
            label: 'Enter Manually',
            icon: Icons.keyboard,
            onPressed: _showManualInputDialog,
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildWebScanner() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MallonColors.outline, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Try to show camera on web
          Expanded(flex: 3, child: _buildWebCameraView()),

          const SizedBox(height: 16),

          // Manual Input for Web
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    controller: _manualInputController,
                    decoration: const InputDecoration(
                      labelText: 'Enter QR Code',
                      hintText: 'TOOL#T1234 or paste QR content',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty) {
                        widget.onCodeScanned(value);
                        _manualInputController.clear();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final value = _manualInputController.text.trim();
                            if (value.isNotEmpty) {
                              widget.onCodeScanned(value);
                              _manualInputController.clear();
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Submit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _initializeWebCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MallonColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCameraView() {
    // Try to use mobile_scanner on web for camera access
    _controller ??= MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MallonColors.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MobileScanner(
          controller: _controller!,
          onDetect: widget.enabled ? _onBarcodeDetected : null,
          errorBuilder: (context, error, child) {
            return _buildCameraErrorView();
          },
          placeholderBuilder: (context, child) {
            return _buildCameraPlaceholder();
          },
        ),
      ),
    );
  }

  Widget _buildCameraErrorView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: MallonColors.mediumGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Access Required',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: MallonColors.mediumGrey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please allow camera access for QR scanning',
            textAlign: TextAlign.center,
            style: TextStyle(color: MallonColors.secondaryText),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeWebCamera,
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

  Widget _buildCameraPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we access your camera',
            textAlign: TextAlign.center,
            style: TextStyle(color: MallonColors.secondaryText),
          ),
        ],
      ),
    );
  }

  void _initializeWebCamera() {
    if (_controller != null) {
      _controller!.dispose();
    }

    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    setState(() {});
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        widget.onCodeScanned(code);
      }
    }
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Tool Code'),
        content: TextFormField(
          controller: _manualInputController,
          decoration: const InputDecoration(
            labelText: 'Tool Code',
            hintText: 'TOOL#T1234',
            prefixIcon: Icon(Icons.qr_code),
          ),
          autofocus: true,
          onFieldSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onCodeScanned(value);
              _manualInputController.clear();
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _manualInputController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = _manualInputController.text.trim();
              if (value.isNotEmpty) {
                widget.onCodeScanned(value);
                _manualInputController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
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

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + borderRadius,
          cutOutRect.top,
        )
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.top),
      borderPaint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - borderLength, cutOutRect.top)
        ..lineTo(cutOutRect.right - borderRadius, cutOutRect.top)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.top,
          cutOutRect.right,
          cutOutRect.top + borderRadius,
        )
        ..lineTo(cutOutRect.right, cutOutRect.top + borderLength),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.bottom - borderLength)
        ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.bottom,
          cutOutRect.right - borderRadius,
          cutOutRect.bottom,
        )
        ..lineTo(cutOutRect.right - borderLength, cutOutRect.bottom),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left + borderLength, cutOutRect.bottom)
        ..lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.bottom,
          cutOutRect.left,
          cutOutRect.bottom - borderRadius,
        )
        ..lineTo(cutOutRect.left, cutOutRect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}

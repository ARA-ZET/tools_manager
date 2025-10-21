import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../services/camera_service.dart';
import '../models/tool.dart';
import '../models/consumable.dart';
import '../providers/tools_provider.dart';
import '../providers/consumables_provider.dart';

/// Scanned item type
enum ScannedItemType { tool, consumable, unknown }

/// Scanned item result
class ScannedItem {
  final ScannedItemType type;
  final String id;
  final dynamic item; // Tool or Consumable

  ScannedItem({required this.type, required this.id, this.item});

  String get displayName {
    if (item is Tool) {
      return (item as Tool).name;
    } else if (item is Consumable) {
      return (item as Consumable).name;
    }
    return id;
  }

  String get typeLabel {
    switch (type) {
      case ScannedItemType.tool:
        return 'Tool';
      case ScannedItemType.consumable:
        return 'Consumable';
      case ScannedItemType.unknown:
        return 'Unknown';
    }
  }
}

/// Universal scanner for both tools and consumables
class UniversalScanner extends StatefulWidget {
  final Function(ScannedItem item) onItemScanned;
  final bool allowTools;
  final bool allowConsumables;
  final bool batchMode;
  final String? lastScannedId;
  final String? lastScannedType;
  final bool isProcessing;

  const UniversalScanner({
    super.key,
    required this.onItemScanned,
    this.allowTools = true,
    this.allowConsumables = true,
    this.batchMode = false,
    this.lastScannedId,
    this.lastScannedType,
    this.isProcessing = false,
  });

  @override
  State<UniversalScanner> createState() => _UniversalScannerState();
}

class _UniversalScannerState extends State<UniversalScanner>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final TextEditingController _manualController = TextEditingController();

  bool _isInitializing = true;
  bool _hasPermission = false;
  bool _torchEnabled = false;
  String? _errorMessage;

  // Debouncing for scanner
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const Duration _scanDebounce = Duration(milliseconds: 500); // Reduced from 2 seconds

  // Visual feedback state
  bool _showScanFeedback = false;
  String _feedbackMessage = '';
  Color _feedbackColor = MallonColors.primaryGreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            _errorMessage = 'Camera permission denied';
          }
        });
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

  Future<void> _toggleTorch() async {
    try {
      await _cameraService.toggleTorch();
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } catch (e) {
      _showError('Failed to toggle torch: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _handleScan(String scannedCode) {
    // Debouncing
    final now = DateTime.now();
    if (_lastScannedCode == scannedCode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanDebounce) {
      return;
    }

    _lastScannedCode = scannedCode;
    _lastScanTime = now;

    // Parse the scanned code (instant lookup from cache!)
    final result = _parseScannedCode(scannedCode);

    if (result == null) {
      _showError('Invalid QR code: $scannedCode');
      return;
    }

    // Check if item type is allowed
    if (result.type == ScannedItemType.tool && !widget.allowTools) {
      _showError('Tool scanning is not enabled');
      return;
    }

    if (result.type == ScannedItemType.consumable && !widget.allowConsumables) {
      _showError('Consumable scanning is not enabled');
      return;
    }

    // Show visual feedback
    setState(() {
      _showScanFeedback = true;
      _feedbackMessage = 'Scanned: ${result.displayName}';
      _feedbackColor = MallonColors.primaryGreen;
    });

    // Hide feedback after delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showScanFeedback = false);
      }
    });

    // Call callback
    widget.onItemScanned(result);
  }

  /// Parse scanned code and lookup item (using cached providers - instant!)
  ScannedItem? _parseScannedCode(String code) {
    try {
      // Get providers for instant cached lookups
      if (!mounted) {
        debugPrint('❌ Widget not mounted, cannot access providers');
        return null;
      }

      final toolsProvider = context.read<ToolsProvider>();
      final consumablesProvider = context.read<ConsumablesProvider>();

      // Try to extract ID from code
      String extractedId = code;

      // Handle formats like "TOOL#T1234" or "CONSUMABLE#C0001"
      if (code.contains('#')) {
        extractedId = code.split('#').last;
      }

      // Determine type based on prefix
      if (extractedId.startsWith('T') && widget.allowTools) {
        // Tool - instant lookup from cache
        final tool = toolsProvider.getToolByUniqueId(extractedId);
        if (tool != null) {
          return ScannedItem(
            type: ScannedItemType.tool,
            id: extractedId,
            item: tool,
          );
        }
      } else if (extractedId.startsWith('C') && widget.allowConsumables) {
        // Consumable - instant lookup from cache
        final consumable = consumablesProvider.getConsumableByUniqueId(
          extractedId,
        );
        if (consumable != null) {
          return ScannedItem(
            type: ScannedItemType.consumable,
            id: extractedId,
            item: consumable,
          );
        }
      }

      // Try as raw tool ID if no prefix
      if (widget.allowTools) {
        final tool = toolsProvider.getToolByUniqueId(code);
        if (tool != null) {
          return ScannedItem(type: ScannedItemType.tool, id: code, item: tool);
        }
      }

      // Try as raw consumable ID if no prefix
      if (widget.allowConsumables) {
        final consumable = consumablesProvider.getConsumableByUniqueId(code);
        if (consumable != null) {
          return ScannedItem(
            type: ScannedItemType.consumable,
            id: code,
            item: consumable,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error accessing provider in _parseScannedCode: $e');
      return null;
    }
  }

  Future<void> _handleManualEntry() async {
    final code = _manualController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter a code');
      return;
    }

    _handleScan(code);
    _manualController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildScannerView()),
        _buildManualEntry(),
        if (_showScanFeedback) _buildScanFeedback(),
      ],
    );
  }

  Widget _buildScannerView() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    if (!_hasPermission || _errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera permission required',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _cameraService.controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _handleScan(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        _ScannerOverlay(
          lastScannedId: widget.lastScannedId,
          lastScannedType: widget.lastScannedType,
          isProcessing: widget.isProcessing,
          allowTools: widget.allowTools,
          allowConsumables: widget.allowConsumables,
          batchMode: widget.batchMode,
        ),
        _CameraControlButtons(
          torchEnabled: _torchEnabled,
          onToggleTorch: _toggleTorch,
        ),
      ],
    );
  }
}

/// Scanner overlay widget showing QR frame and instructions/feedback
class _ScannerOverlay extends StatelessWidget {
  final String? lastScannedId;
  final String? lastScannedType;
  final bool isProcessing;
  final bool allowTools;
  final bool allowConsumables;
  final bool batchMode;

  const _ScannerOverlay({
    this.lastScannedId,
    this.lastScannedType,
    this.isProcessing = false,
    required this.allowTools,
    required this.allowConsumables,
    required this.batchMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: MallonColors.primaryGreen, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: MallonColors.primaryGreen,
              ),
              const SizedBox(height: 16),
              // Show scan feedback if available, otherwise show default instructions
              if (lastScannedId != null)
                _ScanFeedbackContent(
                  scannedId: lastScannedId!,
                  scannedType: lastScannedType,
                  isProcessing: isProcessing,
                )
              else
                _ScanInstructions(
                  allowTools: allowTools,
                  allowConsumables: allowConsumables,
                  batchMode: batchMode,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scan feedback content widget
class _ScanFeedbackContent extends StatelessWidget {
  final String scannedId;
  final String? scannedType;
  final bool isProcessing;

  const _ScanFeedbackContent({
    required this.scannedId,
    this.scannedType,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              color: MallonColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Scanned: $scannedId',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (scannedType != null) ...[
          const SizedBox(height: 8),
          Text(
            scannedType!,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
        if (isProcessing) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MallonColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Processing...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Scan instructions widget
class _ScanInstructions extends StatelessWidget {
  final bool allowTools;
  final bool allowConsumables;
  final bool batchMode;

  const _ScanInstructions({
    required this.allowTools,
    required this.allowConsumables,
    required this.batchMode,
  });

  String get _scanningHint {
    if (allowTools && allowConsumables) {
      return 'Tools (T#) or Consumables (C#)';
    } else if (allowTools) {
      return 'Tools only (T#)';
    } else if (allowConsumables) {
      return 'Consumables only (C#)';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          batchMode ? 'Scan multiple items' : 'Scan QR code',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _scanningHint,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Camera control buttons widget
class _CameraControlButtons extends StatelessWidget {
  final bool torchEnabled;
  final VoidCallback onToggleTorch;

  const _CameraControlButtons({
    required this.torchEnabled,
    required this.onToggleTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'torch',
            mini: true,
            onPressed: onToggleTorch,
            backgroundColor: torchEnabled
                ? MallonColors.primaryGreen
                : Colors.white,
            child: Icon(
              torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: torchEnabled ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual entry widget
class _ManualEntry extends StatelessWidget {
  final TextEditingController controller;
  final bool allowTools;
  final bool allowConsumables;
  final VoidCallback onSubmit;

  const _ManualEntry({
    required this.controller,
    required this.allowTools,
    required this.allowConsumables,
    required this.onSubmit,
  });

  String get _hintText {
    if (allowTools && allowConsumables) {
      return 'Enter T# or C#';
    } else if (allowTools) {
      return 'Enter T#';
    } else {
      return 'Enter C#';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Manual Entry',
                hintText: _hintText,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.keyboard),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: MallonColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

/// Scan feedback banner widget
class _ScanFeedbackBanner extends StatelessWidget {
  final String message;
  final Color backgroundColor;

  const _ScanFeedbackBanner({
    required this.message,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: backgroundColor,
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the state class methods that use these widgets
extension _UniversalScannerStateWidgets on _UniversalScannerState {
  Widget _buildManualEntry() {
    return _ManualEntry(
      controller: _manualController,
      allowTools: widget.allowTools,
      allowConsumables: widget.allowConsumables,
      onSubmit: _handleManualEntry,
    );
  }

  Widget _buildScanFeedback() {
    return _ScanFeedbackBanner(
      message: _feedbackMessage,
      backgroundColor: _feedbackColor,
    );
  }
}

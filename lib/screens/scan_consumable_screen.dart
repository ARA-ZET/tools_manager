import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/universal_scanner.dart';
import '../providers/auth_provider.dart';
import '../core/theme/mallon_theme.dart';
import 'record_consumable_usage_screen.dart';
import 'tool_detail_screen.dart';

/// Screen for scanning consumables and tools
class ScanConsumableScreen extends StatefulWidget {
  const ScanConsumableScreen({super.key});

  @override
  State<ScanConsumableScreen> createState() => _ScanConsumableScreenState();
}

class _ScanConsumableScreenState extends State<ScanConsumableScreen> {
  final List<ScannedItem> _scannedItems = [];
  bool _batchMode = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Items'),
        actions: [
          if (_scannedItems.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_scannedItems.length}'),
                child: const Icon(Icons.list),
              ),
              onPressed: _showScannedItems,
              tooltip: 'View Scanned Items',
            ),
          IconButton(
            icon: Icon(_batchMode ? Icons.qr_code : Icons.qr_code_scanner),
            onPressed: () {
              setState(() => _batchMode = !_batchMode);
            },
            tooltip: _batchMode ? 'Single Mode' : 'Batch Mode',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_batchMode) _buildBatchModeHeader(),
          Expanded(
            child: UniversalScanner(
              onItemScanned: _handleItemScanned,
              allowTools: true,
              allowConsumables: true,
              batchMode: _batchMode,
            ),
          ),
        ],
      ),
      floatingActionButton:
          _scannedItems.isNotEmpty && authProvider.canAuthorizeCheckouts
          ? FloatingActionButton.extended(
              onPressed: _processScannedItems,
              icon: const Icon(Icons.check),
              label: Text('Process ${_scannedItems.length} items'),
              backgroundColor: MallonColors.primaryGreen,
            )
          : null,
    );
  }

  Widget _buildBatchModeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: MallonColors.primaryGreen.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.qr_code_scanner, color: MallonColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch Scanning Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MallonColors.primaryGreen,
                  ),
                ),
                Text(
                  'Scanned: ${_scannedItems.length} items',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (_scannedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.red),
              onPressed: () {
                setState(() => _scannedItems.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleared all scanned items')),
                );
              },
              tooltip: 'Clear All',
            ),
        ],
      ),
    );
  }

  void _handleItemScanned(ScannedItem item) {
    if (_batchMode) {
      // Add to batch
      setState(() {
        // Avoid duplicates
        if (!_scannedItems.any((i) => i.id == item.id)) {
          _scannedItems.add(item);
        }
      });
    } else {
      // Navigate immediately
      _navigateToDetail(item);
    }
  }

  void _navigateToDetail(ScannedItem item) {
    if (item.type == ScannedItemType.consumable && item.item != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RecordConsumableUsageScreen(consumable: item.item),
        ),
      );
    } else if (item.type == ScannedItemType.tool && item.item != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ToolDetailScreen(tool: item.item),
        ),
      );
    }
  }

  void _showScannedItems() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scanned Items (${_scannedItems.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  final item = _scannedItems[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.type == ScannedItemType.tool
                          ? Colors.blue.withOpacity(0.2)
                          : MallonColors.primaryGreen.withOpacity(0.2),
                      child: Icon(
                        item.type == ScannedItemType.tool
                            ? Icons.build
                            : Icons.inventory_2,
                        color: item.type == ScannedItemType.tool
                            ? Colors.blue
                            : MallonColors.primaryGreen,
                      ),
                    ),
                    title: Text(item.displayName),
                    subtitle: Text('${item.typeLabel} • ${item.id}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() => _scannedItems.removeAt(index));
                        Navigator.pop(context);
                        if (_scannedItems.isNotEmpty) {
                          _showScannedItems();
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToDetail(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processScannedItems() {
    // TODO: Implement batch processing logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing ${_scannedItems.length} items...'),
        backgroundColor: MallonColors.primaryGreen,
      ),
    );

    // For now, just show the items
    _showScannedItems();
  }
}

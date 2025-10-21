import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/consumable.dart';
import '../models/consumable_transaction.dart';
import '../models/measurement_unit.dart';
import '../providers/consumables_provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/mallon_theme.dart';
import '../widgets/consumable_qr_code_widget.dart';
import 'package:intl/intl.dart';

/// Detail screen for viewing and managing a consumable
class ConsumableDetailScreen extends StatefulWidget {
  final Consumable consumable;

  const ConsumableDetailScreen({super.key, required this.consumable});

  @override
  State<ConsumableDetailScreen> createState() => _ConsumableDetailScreenState();
}

class _ConsumableDetailScreenState extends State<ConsumableDetailScreen> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _projectNameController = TextEditingController();
  String _selectedAction = 'usage';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final consumablesProvider = context.watch<ConsumablesProvider>();

    // Get fresh consumable data from provider
    final currentConsumable =
        consumablesProvider.getConsumableById(widget.consumable.id) ??
        widget.consumable;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentConsumable.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showQRCode(context, currentConsumable),
            tooltip: 'Show QR Code',
          ),
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(context, currentConsumable),
              tooltip: 'Edit Consumable',
            ),
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
              tooltip: 'Delete Consumable',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => consumablesProvider.refresh(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(currentConsumable),
              const SizedBox(height: 16),
              _buildStockCard(currentConsumable),
              const SizedBox(height: 16),
              if (authProvider.canAuthorizeCheckouts)
                _buildQuantityUpdateCard(currentConsumable, authProvider),
              const SizedBox(height: 16),
              _buildInfoCard(currentConsumable),
              const SizedBox(height: 16),
              _buildTransactionHistory(currentConsumable),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Consumable consumable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  consumable.unit.icon,
                  size: 48,
                  color: MallonColors.primaryGreen,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consumable.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consumable.brand,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    consumable.stockLevel.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Color(
                    consumable.stockLevel.colorValue,
                  ).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: Color(consumable.stockLevel.colorValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.category,
                  consumable.category,
                  MallonColors.primaryGreen,
                ),
                _buildInfoChip(Icons.qr_code, consumable.uniqueId, Colors.blue),
                if (consumable.sku != null)
                  _buildInfoChip(
                    Icons.label,
                    'SKU: ${consumable.sku}',
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildStockCard(Consumable consumable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStockRow(
              'Current Stock',
              consumable.formattedCurrentQuantity,
              Color(consumable.stockLevel.colorValue),
              fontSize: 24,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: consumable.stockPercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(consumable.stockLevel.colorValue),
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStockRow(
                    'Min',
                    MeasurementUnitHelper.formatQuantity(
                      consumable.minQuantity,
                      consumable.unit,
                    ),
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStockRow(
                    'Max',
                    MeasurementUnitHelper.formatQuantity(
                      consumable.maxQuantity,
                      consumable.unit,
                    ),
                    Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildStockRow(
                    'Unit Price',
                    'R${consumable.unitPrice.toStringAsFixed(2)}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStockRow(
                    'Total Value',
                    'R${consumable.totalValue.toStringAsFixed(2)}',
                    MallonColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockRow(
    String label,
    String value,
    Color color, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 16,
            fontWeight: fontWeight ?? FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityUpdateCard(
    Consumable consumable,
    AuthProvider authProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Quantity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'usage',
                        label: Text('Usage'),
                        icon: Icon(Icons.remove_circle),
                      ),
                      ButtonSegment(
                        value: 'restock',
                        label: Text('Restock'),
                        icon: Icon(Icons.add_circle),
                      ),
                    ],
                    selected: {_selectedAction},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedAction = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity (${consumable.unit.abbreviation})',
                hintText: 'Enter quantity',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _selectedAction == 'usage' ? Icons.remove : Icons.add,
                ),
              ),
              keyboardType: consumable.unit.allowsDecimals
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
            ),
            const SizedBox(height: 12),
            if (_selectedAction == 'usage')
              TextField(
                controller: _projectNameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name (Optional)',
                  hintText: 'Enter project name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
              ),
            if (_selectedAction == 'usage') const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Enter notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _submitQuantityUpdate(consumable, authProvider),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _selectedAction == 'usage' ? Icons.remove : Icons.add,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : _selectedAction == 'usage'
                      ? 'Record Usage'
                      : 'Restock',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'usage'
                      ? Colors.orange
                      : MallonColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Consumable consumable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Additional Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showQRCode(context, consumable),
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text('View QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MallonColors.primaryGreen,
                    side: BorderSide(color: MallonColors.primaryGreen),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // QR Code Preview
            Center(
              child: GestureDetector(
                onTap: () => _showQRCode(context, consumable),
                child: ConsumableQRCodeWidget(
                  consumable: consumable,
                  size: 150,
                  showLabel: false,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('QR Code', consumable.qrPayload),
            _buildInfoRow(
              'Created',
              DateFormat('MMM d, y').format(consumable.createdAt),
            ),
            _buildInfoRow(
              'Last Updated',
              DateFormat('MMM d, y HH:mm').format(consumable.updatedAt),
            ),
            if (consumable.notes != null) ...[
              const Divider(height: 24),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(consumable.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(Consumable consumable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<ConsumableTransaction>>(
              stream: context
                  .read<ConsumablesProvider>()
                  .getTransactionsForConsumable(consumable.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No transaction history'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length > 10
                      ? 10
                      : transactions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionItem(transaction, consumable);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    ConsumableTransaction transaction,
    Consumable consumable,
  ) {
    final isUsage = transaction.isUsage;
    final color = Color(transaction.actionType.colorValue);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(
          IconData(
            transaction.actionType.iconCodePoint,
            fontFamily: 'MaterialIcons',
          ),
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        transaction.actionType.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isUsage ? '-' : '+'}${MeasurementUnitHelper.formatQuantity(transaction.absoluteQuantityChange, consumable.unit)}',
            style: TextStyle(color: color),
          ),
          Text(
            DateFormat('MMM d, y HH:mm').format(transaction.timestamp),
            style: const TextStyle(fontSize: 12),
          ),
          if (transaction.projectName != null)
            Text(
              'Project: ${transaction.projectName}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          if (transaction.notes != null)
            Text(
              transaction.notes!,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            MeasurementUnitHelper.formatQuantity(
              transaction.quantityAfter,
              consumable.unit,
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'After',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuantityUpdate(
    Consumable consumable,
    AuthProvider authProvider,
  ) async {
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a quantity')));
      return;
    }

    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final quantityChange = _selectedAction == 'usage' ? -quantity : quantity;

    final success = await context.read<ConsumablesProvider>().updateQuantity(
      consumableId: consumable.id,
      quantityChange: quantityChange,
      action: _selectedAction,
      staffUid: authProvider.user?.uid,
      approvedByUid: authProvider.isSupervisor ? authProvider.user?.uid : null,
      projectName: _projectNameController.text.trim().isEmpty
          ? null
          : _projectNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (success) {
      _quantityController.clear();
      _notesController.clear();
      _projectNameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedAction == 'usage' ? 'Usage recorded' : 'Restocked'} successfully',
            ),
            backgroundColor: MallonColors.primaryGreen,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<ConsumablesProvider>().errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context, Consumable consumable) {
    // TODO: Implement edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _showQRCode(BuildContext context, Consumable consumable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsumableQRCodeScreen(consumable: consumable),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Consumable'),
        content: const Text(
          'Are you sure you want to delete this consumable? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context
          .read<ConsumablesProvider>()
          .deleteConsumable(widget.consumable.id);

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consumable deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

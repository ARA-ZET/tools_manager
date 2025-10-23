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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Get fresh consumable data from provider
    final currentConsumable =
        consumablesProvider.getConsumableById(widget.consumable.id) ??
        widget.consumable;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentConsumable.name,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, size: 20),
            onPressed: () => _showQRCode(context, currentConsumable),
            tooltip: 'QR Code',
          ),
          if (authProvider.isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(context, currentConsumable);
                } else if (value == 'delete') {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => consumablesProvider.refresh(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header with stock info combined
              _buildCompactHeaderCard(currentConsumable, isMobile),
              SizedBox(height: isMobile ? 8 : 12),
              // Quick action card
              if (authProvider.canAuthorizeCheckouts)
                _buildQuantityUpdateCard(
                  currentConsumable,
                  authProvider,
                  isMobile,
                ),
              SizedBox(height: isMobile ? 8 : 12),
              // Recent transactions (limited to 5)
              _buildCompactTransactionHistory(currentConsumable, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeaderCard(Consumable consumable, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon and status
            Row(
              children: [
                Icon(
                  consumable.unit.icon,
                  size: isMobile ? 32 : 40,
                  color: MallonColors.primaryGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consumable.name,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        consumable.category,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    consumable.stockLevel.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                  backgroundColor: Color(
                    consumable.stockLevel.colorValue,
                  ).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: Color(consumable.stockLevel.colorValue),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            // Stock progress bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Stock',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            consumable.formattedCurrentQuantity,
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: Color(consumable.stockLevel.colorValue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: consumable.stockPercentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(consumable.stockLevel.colorValue),
                          ),
                          minHeight: isMobile ? 6 : 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Min: ${MeasurementUnitHelper.formatQuantity(consumable.minQuantity, consumable.unit)}',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Max: ${MeasurementUnitHelper.formatQuantity(consumable.maxQuantity, consumable.unit)}',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 12),
            const Divider(height: 1),
            SizedBox(height: isMobile ? 8 : 12),
            // Quick info row
            Row(
              children: [
                Expanded(
                  child: _buildQuickInfoItem(
                    Icons.qr_code,
                    consumable.uniqueId,
                    isMobile,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                Expanded(
                  child: _buildQuickInfoItem(
                    Icons.access_time,
                    DateFormat('MMM d, y').format(consumable.updatedAt),
                    isMobile,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String text, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityUpdateCard(
    Consumable consumable,
    AuthProvider authProvider,
    bool isMobile,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(
                  value: 'usage',
                  label: Text('Usage'),
                  icon: Icon(Icons.remove_circle, size: 18),
                ),
                if (authProvider.isAdmin)
                  const ButtonSegment(
                    value: 'restock',
                    label: Text('Restock'),
                    icon: Icon(Icons.add_circle, size: 18),
                  ),
              ],
              selected: {_selectedAction},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _selectedAction = selection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Qty (${consumable.unit.abbreviation})',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _selectedAction == 'usage' ? Icons.remove : Icons.add,
                        size: 18,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 12 : 14,
                      ),
                      isDense: true,
                    ),
                    keyboardType: consumable.unit.allowsDecimals
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    style: TextStyle(fontSize: isMobile ? 14 : 15),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.notes, size: 18),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 12 : 14,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: isMobile ? 14 : 15),
                  ),
                ),
              ],
            ),
            if (_selectedAction == 'usage') ...[
              SizedBox(height: isMobile ? 8 : 12),
              TextField(
                controller: _projectNameController,
                decoration: InputDecoration(
                  labelText: 'Project',
                  hintText: 'Optional',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.work, size: 18),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 12 : 14,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: isMobile ? 14 : 15),
              ),
            ],
            SizedBox(height: isMobile ? 10 : 12),
            SizedBox(
              width: double.infinity,
              height: isMobile ? 44 : 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _submitQuantityUpdate(consumable, authProvider),
                icon: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _selectedAction == 'usage' ? Icons.remove : Icons.add,
                        size: 18,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : _selectedAction == 'usage'
                      ? 'Record Usage'
                      : 'Restock',
                  style: TextStyle(fontSize: isMobile ? 14 : 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'usage'
                      ? Colors.orange
                      : MallonColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTransactionHistory(Consumable consumable, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Show full transaction history in a dialog or new screen
                    _showFullHistory(consumable);
                  },
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('View All', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 12),
            StreamBuilder<List<ConsumableTransaction>>(
              stream: context
                  .read<ConsumablesProvider>()
                  .getTransactionsForConsumable(consumable.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading history',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No recent activity',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                    ),
                  );
                }

                // Show only latest 5 transactions
                final recentTransactions = transactions.take(5).toList();

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: isMobile ? 8 : 12),
                  itemBuilder: (context, index) {
                    final transaction = recentTransactions[index];
                    return _buildCompactTransactionItem(
                      transaction,
                      consumable,
                      isMobile,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTransactionItem(
    ConsumableTransaction transaction,
    Consumable consumable,
    bool isMobile,
  ) {
    final isUsage = transaction.isUsage;
    final color = Color(transaction.actionType.colorValue);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: Row(
        children: [
          Container(
            width: isMobile ? 32 : 36,
            height: isMobile ? 32 : 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              IconData(
                transaction.actionType.iconCodePoint,
                fontFamily: 'MaterialIcons',
              ),
              color: color,
              size: isMobile ? 16 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction.actionType.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    Text(
                      '${isUsage ? '-' : '+'}${MeasurementUnitHelper.formatQuantity(transaction.absoluteQuantityChange, consumable.unit)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat(
                          'MMM d, HH:mm',
                        ).format(transaction.timestamp),
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Text(
                      'After: ${MeasurementUnitHelper.formatQuantity(transaction.quantityAfter, consumable.unit)}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (transaction.projectName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '📁 ${transaction.projectName}',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullHistory(Consumable consumable) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ConsumableTransaction>>(
                  stream: context
                      .read<ConsumablesProvider>()
                      .getTransactionsForConsumable(consumable.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final transactions = snapshot.data ?? [];

                    if (transactions.isEmpty) {
                      return const Center(child: Text('No transactions'));
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return _buildFullTransactionItem(
                          transaction,
                          consumable,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFullTransactionItem(
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

    // Check permissions: only admins can restock
    if (_selectedAction == 'restock' && !authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can restock consumables'),
          backgroundColor: Colors.red,
        ),
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

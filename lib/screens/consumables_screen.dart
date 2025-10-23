import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consumable.dart';
import '../models/consumable_transaction.dart';
import '../models/measurement_unit.dart';
import '../providers/consumables_provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/mallon_theme.dart';
import 'add_consumable_screen.dart';
import 'consumable_detail_screen.dart';
import 'scan_consumable_screen.dart';

/// Screen for managing consumables inventory
class ConsumablesScreen extends StatefulWidget {
  const ConsumablesScreen({super.key});

  @override
  State<ConsumablesScreen> createState() => _ConsumablesScreenState();
}

class _ConsumablesScreenState extends State<ConsumablesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  StockLevel? _selectedStockLevel;
  String? _expandedTransactionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final consumablesProvider = context.watch<ConsumablesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _navigateToScanner(context),
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter',
          ),
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _navigateToAddConsumable(context),
              tooltip: 'Add Consumable',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.grid_view), text: 'All'),
            Tab(
              icon: Badge(
                label: Text('${consumablesProvider.lowStockCount}'),
                isLabelVisible: consumablesProvider.lowStockCount > 0,
                child: const Icon(Icons.warning_amber),
              ),
              text: 'Low Stock',
            ),
            Tab(icon: const Icon(Icons.category), text: 'Categories'),
            Tab(icon: const Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllConsumablesTab(consumablesProvider),
                _buildLowStockTab(consumablesProvider),
                _buildCategoriesTab(consumablesProvider),
                _buildAnalyticsTab(consumablesProvider),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: authProvider.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToAddConsumable(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Consumable'),
              backgroundColor: MallonColors.primaryGreen,
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search consumables...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildAllConsumablesTab(ConsumablesProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(provider.errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final consumables = _getFilteredConsumables(provider);

    if (consumables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No consumables yet'
                  : 'No consumables found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: consumables.length,
        itemBuilder: (context, index) {
          final consumable = consumables[index];
          return _buildConsumableCard(consumable);
        },
      ),
    );
  }

  Widget _buildLowStockTab(ConsumablesProvider provider) {
    final lowStockItems = provider.lowStockConsumables;

    if (lowStockItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: MallonColors.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'All stock levels are good!',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lowStockItems.length,
        itemBuilder: (context, index) {
          final consumable = lowStockItems[index];
          return _buildConsumableCard(consumable, showWarning: true);
        },
      ),
    );
  }

  Widget _buildCategoriesTab(ConsumablesProvider provider) {
    final categories = provider.categories;

    if (categories.isEmpty) {
      return const Center(child: Text('No categories yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = provider.getConsumablesByCategory(category);
        final lowStockCount = items.where((c) => c.isLowStock).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: MallonColors.primaryGreen.withOpacity(0.2),
              child: Icon(Icons.category, color: MallonColors.primaryGreen),
            ),
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${items.length} items'),
            trailing: lowStockCount > 0
                ? Badge(
                    label: Text('$lowStockCount'),
                    backgroundColor: Colors.orange,
                    child: const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _tabController.animateTo(0);
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(ConsumablesProvider provider) {
    final totalItems = provider.activeConsumables.length;
    final lowStockCount = provider.lowStockCount;
    final outOfStockCount = provider.outOfStockCount;
    final totalTransactions = provider.recentTransactions.length;
    final usageTransactions = provider.recentTransactions
        .where((t) => t.action == 'usage')
        .length;
    final restockTransactions = provider.recentTransactions
        .where((t) => t.action == 'restock')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inventory Overview
          const Text(
            'Inventory Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Determine number of columns based on width
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1200
                  ? 4
                  : width > 800
                  ? 3
                  : width > 500
                  ? 2
                  : 2;
              final aspectRatio = width > 1200
                  ? 3.0
                  : width > 800
                  ? 2.8
                  : width > 500
                  ? 2.4
                  : 2.2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspectRatio,
                children: [
                  _buildAnalyticsCard(
                    'Total Items',
                    '$totalItems',
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildAnalyticsCard(
                    'Categories',
                    '${provider.categories.length}',
                    Icons.category,
                    Colors.purple,
                  ),
                  _buildAnalyticsCard(
                    'Low Stock',
                    '$lowStockCount',
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                  _buildAnalyticsCard(
                    'Out of Stock',
                    '$outOfStockCount',
                    Icons.error,
                    Colors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Transaction Analytics
          const Text(
            'Transaction Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Determine number of columns based on width
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1200
                  ? 4
                  : width > 800
                  ? 3
                  : width > 500
                  ? 2
                  : 1;
              final aspectRatio = width > 1200
                  ? 3.0
                  : width > 800
                  ? 2.8
                  : width > 500
                  ? 2.4
                  : 2.2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspectRatio,
                children: [
                  _buildAnalyticsCard(
                    'Total Transactions',
                    '$totalTransactions',
                    Icons.history,
                    MallonColors.primaryGreen,
                  ),
                  _buildAnalyticsCard(
                    'Usage Records',
                    '$usageTransactions',
                    Icons.remove_circle,
                    Colors.orange,
                  ),
                  _buildAnalyticsCard(
                    'Restock Records',
                    '$restockTransactions',
                    Icons.add_circle,
                    Colors.green,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (provider.recentTransactions.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllTransactions(context, provider),
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.recentTransactions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No transactions yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...provider.recentTransactions
                .take(5)
                .map(
                  (transaction) => _buildTransactionCard(transaction, provider),
                ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumableCard(
    Consumable consumable, {
    bool showWarning = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(consumable),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(
                      consumable.stockLevel.colorValue,
                    ).withOpacity(0.2),
                    child: Icon(
                      consumable.unit.icon,
                      color: Color(consumable.stockLevel.colorValue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consumable.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          consumable.category,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      consumable.stockLevel.displayName,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Color(
                      consumable.stockLevel.colorValue,
                    ).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: Color(consumable.stockLevel.colorValue),
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consumable.formattedCurrentQuantity,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(consumable.stockLevel.colorValue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Min Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consumable.formattedCurrentQuantity.replaceAll(
                            consumable.currentQuantity.toString(),
                            consumable.minQuantity.toString(),
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: consumable.stockPercentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(consumable.stockLevel.colorValue),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(consumable.category),
                    avatar: const Icon(Icons.category, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(consumable.uniqueId),
                    avatar: const Icon(Icons.qr_code, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    ConsumableTransaction transaction,
    ConsumablesProvider provider,
  ) {
    final actionType = transaction.actionType;
    final isUsage = transaction.action == 'usage';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(
            '${transaction.id}_${_expandedTransactionId == transaction.id}',
          ),
          initiallyExpanded: _expandedTransactionId == transaction.id,
          onExpansionChanged: (isExpanded) {
            setState(() {
              if (isExpanded) {
                _expandedTransactionId = transaction.id;
              } else {
                _expandedTransactionId = null;
              }
            });
          },
          leading: CircleAvatar(
            backgroundColor: Color(actionType.colorValue).withOpacity(0.2),
            child: Icon(
              IconData(actionType.iconCodePoint, fontFamily: 'MaterialIcons'),
              color: Color(actionType.colorValue),
              size: 20,
            ),
          ),
          title: FutureBuilder<String>(
            future: _getConsumableName(transaction.consumableRef),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Loading...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isUsage ? '-' : '+'}${transaction.absoluteQuantityChange.toStringAsFixed(1)} units',
                style: TextStyle(
                  color: Color(actionType.colorValue),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTransactionTime(transaction.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: Chip(
            label: Text(
              actionType.displayName,
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: Color(actionType.colorValue).withOpacity(0.2),
            labelStyle: TextStyle(
              color: Color(actionType.colorValue),
              fontWeight: FontWeight.bold,
            ),
            visualDensity: VisualDensity.compact,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildTransactionDetailRow(
                    'Before',
                    '${transaction.quantityBefore.toStringAsFixed(1)} units',
                    Icons.inventory_2,
                  ),
                  const SizedBox(height: 8),
                  _buildTransactionDetailRow(
                    'Change',
                    '${isUsage ? '-' : '+'}${transaction.absoluteQuantityChange.toStringAsFixed(1)} units',
                    isUsage ? Icons.remove_circle : Icons.add_circle,
                    color: Color(actionType.colorValue),
                  ),
                  const SizedBox(height: 8),
                  _buildTransactionDetailRow(
                    'After',
                    '${transaction.quantityAfter.toStringAsFixed(1)} units',
                    Icons.inventory,
                  ),
                  if (transaction.usedBy != null) ...[
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _getStaffName(transaction.usedBy!),
                      builder: (context, snapshot) {
                        return _buildTransactionDetailRow(
                          isUsage ? 'Recorded By' : 'Restocked By',
                          snapshot.data ?? 'Loading...',
                          Icons.person,
                        );
                      },
                    ),
                  ],
                  if (transaction.assignedTo != null) ...[
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _getStaffName(transaction.assignedTo!),
                      builder: (context, snapshot) {
                        return _buildTransactionDetailRow(
                          'Given To',
                          snapshot.data ?? 'Loading...',
                          Icons.person_outline,
                          color: MallonColors.primaryGreen,
                        );
                      },
                    ),
                  ],
                  if (transaction.approvedBy != null) ...[
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _getStaffName(transaction.approvedBy!),
                      builder: (context, snapshot) {
                        return _buildTransactionDetailRow(
                          'Approved By',
                          snapshot.data ?? 'Loading...',
                          Icons.verified_user,
                        );
                      },
                    ),
                  ],
                  if (transaction.projectName != null) ...[
                    const SizedBox(height: 8),
                    _buildTransactionDetailRow(
                      'Project',
                      transaction.projectName!,
                      Icons.work,
                    ),
                  ],
                  if (transaction.notes != null) ...[
                    const SizedBox(height: 8),
                    _buildTransactionDetailRow(
                      'Notes',
                      transaction.notes!,
                      Icons.note,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildTransactionDetailRow(
                    'Date & Time',
                    _formatFullDateTime(transaction.timestamp),
                    Icons.access_time,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: color ?? Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Future<String> _getStaffName(DocumentReference ref) async {
    try {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['fullName'] as String? ??
            data['name'] as String? ??
            'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFullDateTime(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _getConsumableName(DocumentReference ref) async {
    try {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] as String? ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatTransactionTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showAllTransactions(
    BuildContext context,
    ConsumablesProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Transactions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: provider.recentTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: provider.recentTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction =
                              provider.recentTransactions[index];
                          return _buildTransactionCard(transaction, provider);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Consumable> _getFilteredConsumables(ConsumablesProvider provider) {
    var consumables = provider.activeConsumables;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      consumables = provider.searchByName(_searchQuery);
    }

    // Apply category filter
    if (_selectedCategory != null) {
      consumables = consumables
          .where((c) => c.category == _selectedCategory)
          .toList();
    }

    // Apply stock level filter
    if (_selectedStockLevel != null) {
      consumables = consumables
          .where((c) => c.stockLevel == _selectedStockLevel)
          .toList();
    }

    return consumables;
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Consumables'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category'),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: _selectedCategory,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...context.read<ConsumablesProvider>().categories.map((
                    category,
                  ) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),
              const Text('Stock Level'),
              const SizedBox(height: 8),
              DropdownButton<StockLevel?>(
                value: _selectedStockLevel,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Levels')),
                  DropdownMenuItem(
                    value: StockLevel.outOfStock,
                    child: Text('Out of Stock'),
                  ),
                  DropdownMenuItem(
                    value: StockLevel.low,
                    child: Text('Low Stock'),
                  ),
                  DropdownMenuItem(
                    value: StockLevel.normal,
                    child: Text('Normal'),
                  ),
                  DropdownMenuItem(
                    value: StockLevel.overstocked,
                    child: Text('Overstocked'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedStockLevel = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedStockLevel = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // Refresh the main screen
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddConsumable(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddConsumableScreen()),
    );

    if (result == true && mounted) {
      // Refresh handled by provider streams
    }
  }

  void _navigateToScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanConsumableScreen()),
    );
  }

  void _navigateToDetail(Consumable consumable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsumableDetailScreen(consumable: consumable),
      ),
    );
  }
}

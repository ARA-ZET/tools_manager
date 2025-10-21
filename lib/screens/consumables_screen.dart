import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/consumable.dart';
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
    final totalValue = provider.totalInventoryValue;
    final totalItems = provider.activeConsumables.length;
    final lowStockCount = provider.lowStockCount;
    final outOfStockCount = provider.outOfStockCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAnalyticsCard(
            'Total Inventory Value',
            'R${totalValue.toStringAsFixed(2)}',
            Icons.attach_money,
            MallonColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Total Items',
                  '$totalItems',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  'Categories',
                  '${provider.categories.length}',
                  Icons.category,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Low Stock',
                  '$lowStockCount',
                  Icons.warning_amber,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  'Out of Stock',
                  '$outOfStockCount',
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
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
                          consumable.brand,
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
                          'Value',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R${consumable.totalValue.toStringAsFixed(2)}',
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

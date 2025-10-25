import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../providers/transactions_provider.dart';

/// Audit screen for viewing activity logs
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedDateFilter =
      'custom'; // 'today', 'yesterday', 'week', 'month', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;
  String? _expandedItemId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsProvider>(
      builder: (context, transactionsProvider, child) {
        // Check authorization
        if (transactionsProvider.isUnauthorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Audit Log')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: MallonColors.secondaryText),
                  SizedBox(height: 16),
                  Text(
                    'Unauthorized Access',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Only administrators can view audit logs',
                    style: TextStyle(color: MallonColors.secondaryText),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: MallonColors.primaryGreen.withAlpha(30),
          appBar: AppBar(
            title: const Text('Audit Log'),
            actions: [
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  // Reload current month's data from database
                  await transactionsProvider.refresh();
                },
              ),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () {
                  _showDatePicker();
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  _showFilterDialog();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Search and Filters
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search activity...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {}); // Trigger rebuild for search filter
                        },
                      ),
                    ),

                    const SizedBox(width: 12),
                    Expanded(
                      child: _startDate != null || _endDate != null
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: MallonColors.lightGreen,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: MallonColors.primaryGreen,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: MallonColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getDateRangeText(),
                                      style: const TextStyle(
                                        color: MallonColors.primaryGreen,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _startDate = null;
                                        _endDate = null;
                                        _selectedDateFilter = 'custom';
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: MallonColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox.shrink(),
                    ),

                    // Date Range Display
                  ],
                ),
              ),

              // Filter Chips
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedFilter == 'all',
                          onTap: () => _updateFilter('all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Check Out',
                          isSelected: _selectedFilter == 'checkout',
                          onTap: () => _updateFilter('checkout'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Check In',
                          isSelected: _selectedFilter == 'checkin',
                          onTap: () => _updateFilter('checkin'),
                        ),
                        const SizedBox(width: 8, height: 40),
                        _FilterChip(
                          label: 'Batch',
                          isSelected: _selectedFilter == 'batch',
                          onTap: () => _updateFilter('batch'),
                        ),
                        Container(
                          width: 4,
                          height: 36,
                          color: MallonColors.primaryGreen,
                          margin: EdgeInsets.symmetric(horizontal: 8),
                        ),

                        _FilterChip(
                          label: 'Today',
                          isSelected: _selectedDateFilter == 'today',
                          onTap: () => _applyDateQuickFilter('today'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Yesterday',
                          isSelected: _selectedDateFilter == 'yesterday',
                          onTap: () => _applyDateQuickFilter('yesterday'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'This Week',
                          isSelected: _selectedDateFilter == 'week',
                          onTap: () => _applyDateQuickFilter('week'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'This Month',
                          isSelected: _selectedDateFilter == 'month',
                          onTap: () => _applyDateQuickFilter('month'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showDatePicker(),
                          icon: const Icon(
                            Icons.date_range,
                            color: MallonColors.primaryGreen,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

              const SizedBox(height: 16),

              // Stats Summary Card
              _buildStatsCard(transactionsProvider),

              const SizedBox(height: 8),

              // Activity List
              Expanded(child: _buildActivityList(transactionsProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(TransactionsProvider transactionsProvider) {
    // Start with all transactions from provider
    List<Map<String, dynamic>> transactions =
        transactionsProvider.allTransactions;

    // Apply date filter if set
    if (_startDate != null && _endDate != null) {
      transactions = transactions.where((t) {
        final timestamp = (t['timestamp'] as dynamic)?.toDate();
        if (timestamp == null) return false;
        return timestamp.isAfter(
              _startDate!.subtract(const Duration(seconds: 1)),
            ) &&
            timestamp.isBefore(_endDate!.add(const Duration(seconds: 1)));
      }).toList();
    }

    // Apply action filter
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'batch') {
        // Filter for batch operations by checking notes field
        transactions = transactions.where((t) {
          final notes = t['notes'] as String?;
          return notes != null && notes.contains('Batch operation:');
        }).toList();
      } else {
        transactions = transactions
            .where((t) => t['action'] == _selectedFilter)
            .toList();
      }
    }

    final checkouts = transactions
        .where((t) => t['action'] == 'checkout')
        .length;
    final checkins = transactions.where((t) => t['action'] == 'checkin').length;

    // Count unique batch operations (not individual transactions)
    final uniqueBatchIds = <String>{};
    for (final t in transactions) {
      final notes = t['notes'] as String?;
      if (notes != null && notes.contains('Batch operation:')) {
        final batchIdMatch = RegExp(
          r'Batch operation: (BATCH_\d+)',
        ).firstMatch(notes);
        if (batchIdMatch != null) {
          uniqueBatchIds.add(batchIdMatch.group(1)!);
        }
      }
    }
    final batchOps = uniqueBatchIds.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MallonColors.primaryGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.list_alt,
            label: 'Total',
            value: transactions.length.toString(),
            color: MallonColors.primaryGreen,
          ),
          _StatItem(
            icon: Icons.output,
            label: 'Check Out',
            value: checkouts.toString(),
            color: MallonColors.checkedOut,
          ),
          _StatItem(
            icon: Icons.input,
            label: 'Check In',
            value: checkins.toString(),
            color: MallonColors.available,
          ),
          _StatItem(
            icon: Icons.layers,
            label: 'Batch',
            value: batchOps.toString(),
            color: MallonColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(TransactionsProvider transactionsProvider) {
    // Start with all transactions from provider
    List<Map<String, dynamic>> transactions =
        transactionsProvider.allTransactions;

    // Apply date filter if set
    if (_startDate != null && _endDate != null) {
      transactions = transactions.where((t) {
        final timestamp = (t['timestamp'] as dynamic)?.toDate();
        if (timestamp == null) return false;
        return timestamp.isAfter(
              _startDate!.subtract(const Duration(seconds: 1)),
            ) &&
            timestamp.isBefore(_endDate!.add(const Duration(seconds: 1)));
      }).toList();
    }

    // Apply action filter
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'batch') {
        // Filter for batch operations by checking notes field
        transactions = transactions.where((t) {
          final notes = t['notes'] as String?;
          return notes != null && notes.contains('Batch operation:');
        }).toList();
      } else {
        transactions = transactions
            .where((t) => t['action'] == _selectedFilter)
            .toList();
      }
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      transactions = transactions.where((transaction) {
        final metadata = transaction['metadata'] as Map<String, dynamic>?;
        final toolName = (metadata?['toolName'] as String? ?? '').toLowerCase();
        final staffName = (metadata?['staffName'] as String? ?? '')
            .toLowerCase();
        final notes = (transaction['notes'] as String? ?? '').toLowerCase();

        return toolName.contains(searchQuery) ||
            staffName.contains(searchQuery) ||
            notes.contains(searchQuery);
      }).toList();
    }

    // Show empty state
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: MallonColors.secondaryText.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _startDate != null || _endDate != null
                  ? 'No transactions in selected date range'
                  : 'No transactions today',
              style: const TextStyle(
                fontSize: 16,
                color: MallonColors.secondaryText,
              ),
            ),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: TextStyle(
                  fontSize: 14,
                  color: MallonColors.secondaryText.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group transactions by batch ID
    final groupedItems = _groupTransactions(transactions);

    // Show transaction list (grouped by batch)
    return ListView.builder(
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final item = groupedItems[index];

        if (item['isBatchGroup'] == true) {
          // Show batch group
          final batchId = item['batchId'] as String;
          return _BatchGroupItem(
            key: ValueKey('batch_$batchId'),
            batchId: batchId,
            transactions: item['transactions'] as List<Map<String, dynamic>>,
            toolTransactions:
                item['toolTransactions'] as List<Map<String, dynamic>>? ?? [],
            consumableTransactions:
                item['consumableTransactions'] as List<Map<String, dynamic>>? ??
                [],
            action: item['action'] as String,
            staffName: item['staffName'] as String,
            processedBy: item['processedBy'] as String? ?? 'Unknown',
            timestamp: item['timestamp'] as DateTime,
            isExpanded: _expandedItemId == 'batch_$batchId',
            onExpansionChanged: (isExpanded) {
              setState(() {
                _expandedItemId = isExpanded ? 'batch_$batchId' : null;
              });
            },
          );
        } else {
          // Show individual transaction
          final transaction = item['transaction'] as Map<String, dynamic>;
          final metadata = transaction['metadata'] as Map<String, dynamic>?;
          final notes = transaction['notes'] as String?;
          final batchId = transaction['batchId'] as String?;
          final isBatch =
              batchId != null ||
              (notes != null && notes.contains('Batch operation:'));
          final transactionId = transaction['id'] as String? ?? 'item_$index';

          return _ActivityItem(
            key: ValueKey(transactionId),
            action: transaction['action'] as String? ?? 'unknown',
            toolName: metadata?['toolName'] as String? ?? 'Unknown Tool',
            staffName: metadata?['staffName'] as String? ?? 'Unknown Staff',
            timestamp:
                (transaction['timestamp'] as dynamic)?.toDate() ??
                DateTime.now(),
            notes: notes,
            isBatch: isBatch,
            batchId: batchId,
            toolBrand: metadata?['toolBrand'] as String?,
            toolModel: metadata?['toolModel'] as String?,
            isExpanded: _expandedItemId == transactionId,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _expandedItemId = isExpanded ? transactionId : null;
              });
            },
          );
        }
      },
    );
  }

  /// Group transactions - batch operations are grouped together, individual transactions remain separate
  /// Now supports both tool and consumable transactions in same batch
  List<Map<String, dynamic>> _groupTransactions(
    List<Map<String, dynamic>> transactions,
  ) {
    final Map<String, List<Map<String, dynamic>>> batchGroups = {};
    final List<Map<String, dynamic>> individualItems = [];

    for (final transaction in transactions) {
      final notes = transaction['notes'] as String?;
      final batchId = transaction['batchId'] as String?;

      // Check for batch ID in notes or batchId field
      String? extractedBatchId;

      // Try to extract from notes (works for both tool and consumable transactions)
      if (notes != null && notes.contains('Batch operation:')) {
        final batchIdMatch = RegExp(
          r'Batch operation: (BATCH_\d+)',
        ).firstMatch(notes);
        if (batchIdMatch != null) {
          extractedBatchId = batchIdMatch.group(1)!;
        }
      } else if (notes != null && notes.contains('Batch ID:')) {
        // Consumable transactions have: 'Batch assignment (Batch ID: BATCH_XXX)'
        final batchIdMatch = RegExp(
          r'Batch ID:\s*(BATCH_\d+)',
        ).firstMatch(notes);
        if (batchIdMatch != null) {
          extractedBatchId = batchIdMatch.group(1)!;
        }
      }

      // Also check direct batchId field
      if (extractedBatchId == null && batchId != null) {
        extractedBatchId = batchId;
      }

      if (extractedBatchId != null) {
        // Add to batch group
        batchGroups.putIfAbsent(extractedBatchId, () => []);
        batchGroups[extractedBatchId]!.add(transaction);
      } else {
        // Non-batch transaction
        individualItems.add({
          'transaction': transaction,
          'isBatchGroup': false,
        });
      }
    }

    // Convert batch groups to list items
    final List<Map<String, dynamic>> result = [];

    for (final entry in batchGroups.entries) {
      final batchTransactions = entry.value;
      if (batchTransactions.isNotEmpty) {
        // Separate tools and consumables
        final toolTransactions = batchTransactions
            .where((t) => t['type'] != 'consumable')
            .toList();
        final consumableTransactions = batchTransactions
            .where((t) => t['type'] == 'consumable')
            .toList();

        // Extract staff names from any transaction that has the metadata
        // Try to get from the first tool transaction, then first consumable
        String staffName = 'Unknown';
        String processedBy = 'Unknown';

        // Try tool transactions first
        if (toolTransactions.isNotEmpty) {
          final toolMetadata =
              toolTransactions.first['metadata'] as Map<String, dynamic>?;
          if (toolMetadata?['staffName'] != null) {
            staffName = toolMetadata!['staffName'] as String;
          }
          if (toolMetadata?['adminName'] != null) {
            processedBy = toolMetadata!['adminName'] as String;
          }
        }

        // If still unknown, try consumable transactions
        if ((staffName == 'Unknown' || processedBy == 'Unknown') &&
            consumableTransactions.isNotEmpty) {
          final consumableMetadata =
              consumableTransactions.first['metadata'] as Map<String, dynamic>?;
          if (staffName == 'Unknown' &&
              consumableMetadata?['staffName'] != null) {
            staffName = consumableMetadata!['staffName'] as String;
          }
          if (processedBy == 'Unknown' &&
              consumableMetadata?['adminName'] != null) {
            processedBy = consumableMetadata!['adminName'] as String;
          }
        }

        result.add({
          'isBatchGroup': true,
          'batchId': entry.key,
          'transactions': batchTransactions,
          'toolTransactions': toolTransactions,
          'consumableTransactions': consumableTransactions,
          'action': batchTransactions.first['action'],
          'staffName': staffName,
          'processedBy': processedBy,
          'timestamp':
              (batchTransactions.first['timestamp'] as dynamic)?.toDate() ??
              DateTime.now(),
        });
      }
    }

    // Add individual items
    result.addAll(individualItems);

    // Sort by timestamp (most recent first)
    result.sort((a, b) {
      final aTime =
          a['timestamp'] as DateTime? ??
          ((a['transaction'] as Map<String, dynamic>?)?['timestamp'] as dynamic)
              ?.toDate() ??
          DateTime.now();
      final bTime =
          b['timestamp'] as DateTime? ??
          ((b['transaction'] as Map<String, dynamic>?)?['timestamp'] as dynamic)
              ?.toDate() ??
          DateTime.now();
      return bTime.compareTo(aTime);
    });

    return result;
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    // Data filtering happens in _buildActivityList, no need to reload
  }

  /// Apply date quick filter
  void _applyDateQuickFilter(String filter) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (filter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case 'week':
        // Start of week (Monday)
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day,
          0,
          0,
          0,
        );
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        return;
    }

    setState(() {
      _selectedDateFilter = filter;
      _startDate = startDate;
      _endDate = endDate;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Activity'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  _updateFilter(value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Check Out'),
              leading: Radio<String>(
                value: 'checkout',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  _updateFilter(value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Check In'),
              leading: Radio<String>(
                value: 'checkin',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  _updateFilter(value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Batch Operations'),
              leading: Radio<String>(
                value: 'batch',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  _updateFilter(value!);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedDateFilter = 'custom';
        // Set start date to beginning of day (00:00:00)
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
          0,
          0,
          0,
        );
        // Set end date to end of day (23:59:59)
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  String _getDateRangeText() {
    // Show quick filter name if it's not custom
    if (_selectedDateFilter != 'custom') {
      switch (_selectedDateFilter) {
        case 'today':
          return 'Today (${_startDate!.day}/${_startDate!.month}/${_startDate!.year})';
        case 'yesterday':
          return 'Yesterday (${_startDate!.day}/${_startDate!.month}/${_startDate!.year})';
        case 'week':
          return 'This Week (${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month})';
        case 'month':
          return 'This Month (${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month})';
      }
    }

    // Show custom date range
    if (_startDate != null && _endDate != null) {
      return '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
    } else if (_startDate != null) {
      return 'From ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}';
    } else if (_endDate != null) {
      return 'Until ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
    }
    return '';
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: MallonColors.warning.withAlpha(125),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? MallonColors.warning
              : MallonColors.primaryGreen.withOpacity(0.3),
        ),
      ),
      checkmarkColor: MallonColors.primaryGreen,
    );
  }
}

/// Activity item widget
class _ActivityItem extends StatelessWidget {
  final String action;
  final String toolName;
  final String staffName;
  final DateTime timestamp;
  final String? notes;
  final bool isBatch;
  final String? batchId;
  final String? toolBrand;
  final String? toolModel;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const _ActivityItem({
    super.key,
    required this.action,
    required this.toolName,
    required this.staffName,
    required this.timestamp,
    this.notes,
    this.isBatch = false,
    this.batchId,
    this.toolBrand,
    this.toolModel,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckout = action.toLowerCase() == 'checkout';
    final actionColor = isCheckout
        ? MallonColors.checkedOut
        : MallonColors.available;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isCheckout ? Icons.output : Icons.input,
                color: actionColor,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${action.toUpperCase()} - $toolName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isBatch)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MallonColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MallonColors.primaryGreen),
                    ),
                    child: const Text(
                      'BATCH',
                      style: TextStyle(
                        color: MallonColors.primaryGreen,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tool name section
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 4,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.build_outlined,
                              size: 14,
                              color: MallonColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                toolName,
                                style: const TextStyle(
                                  color: MallonColors.primaryText,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        Row(
                          children: [
                            const Icon(
                              Icons.av_timer_rounded,
                              size: 14,
                              color: MallonColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MallonColors.mediumGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Staff name and notes section in Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Staff name section
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: MallonColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isCheckout
                                    ? "Assigned to: $staffName"
                                    : "Returned by: $staffName",
                                style: const TextStyle(
                                  color: MallonColors.secondaryText,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Notes section (conditional)
                        if (notes != null &&
                            notes!.isNotEmpty &&
                            !isExpanded) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.note_outlined,
                                size: 14,
                                color: MallonColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  notes!,
                                  style: const TextStyle(
                                    color: MallonColors.secondaryText,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: actionColor,
                  ),
                  onPressed: () => onExpansionChanged(!isExpanded),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              color: actionColor.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Details Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actionColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: actionColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Transaction Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.build,
                          label: 'Tool',
                          value: toolName,
                          color: actionColor,
                        ),
                        if (toolBrand != null || toolModel != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.label,
                            label: 'Brand & Model',
                            value: '${toolBrand ?? ''} ${toolModel ?? ''}'
                                .trim(),
                            color: actionColor,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: isCheckout ? 'Assigned To' : 'Returned By',
                          value: staffName,
                          color: actionColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.swap_horiz,
                          label: 'Action',
                          value: action.toUpperCase(),
                          color: actionColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Timestamp',
                          value:
                              '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                          color: actionColor,
                        ),
                        if (isBatch && batchId != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.tag,
                            label: 'Batch ID',
                            value: batchId!,
                            color: actionColor,
                          ),
                        ],
                        if (notes != null && notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.notes,
                            label: 'Notes',
                            value: notes!,
                            color: actionColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Stat item widget for summary card
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: MallonColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// Batch group item widget - shows multiple tools and consumables processed in a batch
class _BatchGroupItem extends StatelessWidget {
  final String batchId;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> toolTransactions;
  final List<Map<String, dynamic>> consumableTransactions;
  final String action;
  final String staffName;
  final String processedBy;
  final DateTime timestamp;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const _BatchGroupItem({
    super.key,
    required this.batchId,
    required this.transactions,
    required this.toolTransactions,
    required this.consumableTransactions,
    required this.action,
    required this.staffName,
    required this.processedBy,
    required this.timestamp,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckout = action.toLowerCase() == 'checkout';
    final toolCount = toolTransactions.length;
    final consumableCount = consumableTransactions.length;
    final totalCount = toolCount + consumableCount;

    // Different colors for checkout vs checkin batches
    final batchColor = isCheckout
        ? MallonColors.checkedOut
        : MallonColors.available;
    final batchBgColor = isCheckout
        ? MallonColors.checkedOut.withOpacity(0.1)
        : MallonColors.available.withOpacity(0.1);

    // Build title string
    String titleText = 'BATCH ${action.toUpperCase()} - ';
    if (toolCount > 0 && consumableCount > 0) {
      titleText +=
          '$toolCount tool${toolCount != 1 ? 's' : ''} and $consumableCount consumable${consumableCount != 1 ? 's' : ''}';
    } else if (toolCount > 0) {
      titleText += '$toolCount tool${toolCount != 1 ? 's' : ''}';
    } else if (consumableCount > 0) {
      titleText +=
          '$consumableCount consumable${consumableCount != 1 ? 's' : ''}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: batchBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.layers, color: batchColor, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: batchColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Tools, Consumables and Time
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 4,
                      children: [
                        if (toolCount > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.build,
                                size: 14,
                                color: MallonColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$toolCount tool${toolCount != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: MallonColors.primaryText,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (consumableCount > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2,
                                size: 14,
                                color: MallonColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$consumableCount consumable${consumableCount != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: MallonColors.primaryText,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            const Icon(
                              Icons.av_timer_rounded,
                              size: 14,
                              color: MallonColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MallonColors.mediumGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right column - Staff and Processor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Staff member (assigned to/returned by)
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: MallonColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isCheckout
                                    ? "Assigned to: $staffName"
                                    : "Returned by: $staffName",
                                style: const TextStyle(
                                  color: MallonColors.secondaryText,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Processor (admin/supervisor)
                        Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              size: 14,
                              color: MallonColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Processed by: $processedBy",
                                style: const TextStyle(
                                  color: MallonColors.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: batchColor,
              ),
              onPressed: () => onExpansionChanged(!isExpanded),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              color: batchBgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Batch Details Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: batchColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: batchColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Batch Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.tag,
                          label: 'Batch ID',
                          value: batchId,
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.layers,
                          label: 'Action',
                          value: action.toUpperCase(),
                          color: batchColor,
                        ),
                        if (toolCount > 0) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.build,
                            label: 'Tools Count',
                            value:
                                '$toolCount tool${toolCount != 1 ? 's' : ''}',
                            color: batchColor,
                          ),
                        ],
                        if (consumableCount > 0) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.inventory_2,
                            label: 'Consumables Count',
                            value:
                                '$consumableCount consumable${consumableCount != 1 ? 's' : ''}',
                            color: batchColor,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: isCheckout ? 'Assigned To' : 'Returned By',
                          value: staffName,
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.admin_panel_settings,
                          label: 'Processed By',
                          value: processedBy,
                          color: MallonColors.primaryGreen,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Timestamp',
                          value:
                              '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                          color: batchColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tools List Section
                  if (toolCount > 0) ...[
                    Row(
                      children: [
                        Icon(Icons.build, size: 18, color: batchColor),
                        const SizedBox(width: 8),
                        Text(
                          'Tools in This Batch ($toolCount)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...toolTransactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final transaction = entry.value;
                      final metadata =
                          transaction['metadata'] as Map<String, dynamic>?;
                      final toolName =
                          metadata?['toolName'] as String? ?? 'Unknown Tool';
                      final toolBrand = metadata?['toolBrand'] as String?;
                      final toolModel = metadata?['toolModel'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: batchColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: batchColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    toolName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (toolBrand != null || toolModel != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '${toolBrand ?? ''} ${toolModel ?? ''}'
                                            .trim(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              isCheckout ? Icons.output : Icons.input,
                              size: 16,
                              color: batchColor,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Consumables List Section
                  if (consumableCount > 0) ...[
                    if (toolCount > 0) const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 18,
                          color: MallonColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Consumables in This Batch ($consumableCount)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...consumableTransactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final transaction = entry.value;
                      final consumableName =
                          transaction['consumableName'] as String? ??
                          'Unknown Consumable';
                      final quantity =
                          (transaction['quantity'] as num?)?.abs() ?? 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: MallonColors.primaryGreen.withOpacity(
                                  0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: MallonColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    consumableName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Quantity: $quantity',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.remove_circle_outline,
                              size: 16,
                              color: MallonColors.primaryGreen,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

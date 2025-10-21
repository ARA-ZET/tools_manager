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
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoadingFiltered = false;

  @override
  void initState() {
    super.initState();
    // Load filtered data when date range or filter changes
    _loadFilteredData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load filtered transactions based on current filters
  Future<void> _loadFilteredData() async {
    if (_startDate == null && _endDate == null) {
      // No date filter - use real-time today's data
      setState(() {
        _filteredTransactions = [];
        _isLoadingFiltered = false;
      });
      return;
    }

    setState(() {
      _isLoadingFiltered = true;
    });

    final transactionsProvider = context.read<TransactionsProvider>();

    try {
      final transactions = await transactionsProvider.getFilteredTransactions(
        startDate: _startDate,
        endDate: _endDate,
        action: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _filteredTransactions = transactions;
        _isLoadingFiltered = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFiltered = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
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
          appBar: AppBar(
            title: const Text('Audit Log'),
            actions: [
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (_startDate != null || _endDate != null) {
                    _loadFilteredData();
                  }
                  // Real-time data refreshes automatically
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
                child: Column(
                  children: [
                    // Search Bar
                    TextFormField(
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

                    const SizedBox(height: 12),

                    // Date Range Display
                    if (_startDate != null || _endDate != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MallonColors.lightGreen,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MallonColors.primaryGreen),
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
                                });
                                _loadFilteredData();
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: MallonColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Filter Chips
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
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Batch',
                      isSelected: _selectedFilter == 'batch',
                      onTap: () => _updateFilter('batch'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats Summary Card
              if (!_isLoadingFiltered) _buildStatsCard(transactionsProvider),

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
    // Determine which transactions to count
    List<Map<String, dynamic>> transactions;
    if (_startDate != null || _endDate != null) {
      transactions = _filteredTransactions;
    } else {
      transactions = transactionsProvider.allTransactions;
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
      padding: const EdgeInsets.all(16),
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
    // Show loading state
    if (_isLoadingFiltered) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determine which transactions to show
    List<Map<String, dynamic>> transactions;
    if (_startDate != null || _endDate != null) {
      // Use filtered data from date range query
      transactions = _filteredTransactions;
    } else {
      // Use real-time today's data from provider
      transactions = transactionsProvider.allTransactions;
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
          return _BatchGroupItem(
            batchId: item['batchId'] as String,
            transactions: item['transactions'] as List<Map<String, dynamic>>,
            action: item['action'] as String,
            staffName: item['staffName'] as String,
            timestamp: item['timestamp'] as DateTime,
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

          return _ActivityItem(
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
          );
        }
      },
    );
  }

  /// Group transactions - batch operations are grouped together, individual transactions remain separate
  List<Map<String, dynamic>> _groupTransactions(
    List<Map<String, dynamic>> transactions,
  ) {
    final Map<String, List<Map<String, dynamic>>> batchGroups = {};
    final List<Map<String, dynamic>> individualItems = [];

    for (final transaction in transactions) {
      final notes = transaction['notes'] as String?;

      if (notes != null && notes.contains('Batch operation:')) {
        // Extract batch ID from notes
        final batchIdMatch = RegExp(
          r'Batch operation: (BATCH_\d+)',
        ).firstMatch(notes);
        if (batchIdMatch != null) {
          final batchId = batchIdMatch.group(1)!;
          batchGroups.putIfAbsent(batchId, () => []);
          batchGroups[batchId]!.add(transaction);
        } else {
          // If we can't extract batch ID, show as individual
          individualItems.add({
            'transaction': transaction,
            'isBatchGroup': false,
          });
        }
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
        final firstTransaction = batchTransactions.first;
        result.add({
          'isBatchGroup': true,
          'batchId': entry.key,
          'transactions': batchTransactions,
          'action': firstTransaction['action'],
          'staffName':
              (firstTransaction['metadata']
                  as Map<String, dynamic>?)?['staffName'] ??
              'Unknown',
          'timestamp':
              (firstTransaction['timestamp'] as dynamic)?.toDate() ??
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
      // Load transactions for selected date range
      _loadFilteredData();
    }
  }

  String _getDateRangeText() {
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
      selectedColor: MallonColors.lightGreen,
      checkmarkColor: MallonColors.primaryGreen,
    );
  }
}

/// Activity item widget
class _ActivityItem extends StatefulWidget {
  final String action;
  final String toolName;
  final String staffName;
  final DateTime timestamp;
  final String? notes;
  final bool isBatch;
  final String? batchId;
  final String? toolBrand;
  final String? toolModel;

  const _ActivityItem({
    required this.action,
    required this.toolName,
    required this.staffName,
    required this.timestamp,
    this.notes,
    this.isBatch = false,
    this.batchId,
    this.toolBrand,
    this.toolModel,
  });

  @override
  State<_ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<_ActivityItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isCheckout = widget.action.toLowerCase() == 'checkout';
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
                    '${widget.action.toUpperCase()} - ${widget.toolName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.isBatch)
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('by ${widget.staffName}'),
                Text(
                  _formatTimestamp(widget.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: MallonColors.secondaryText,
                  ),
                ),
                if (widget.notes != null && !_isExpanded)
                  Text(
                    widget.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: MallonColors.secondaryText,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: actionColor,
              ),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded) ...[
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
                          value: widget.toolName,
                          color: actionColor,
                        ),
                        if (widget.toolBrand != null ||
                            widget.toolModel != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.label,
                            label: 'Brand & Model',
                            value:
                                '${widget.toolBrand ?? ''} ${widget.toolModel ?? ''}'
                                    .trim(),
                            color: actionColor,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: isCheckout ? 'Assigned To' : 'Returned By',
                          value: widget.staffName,
                          color: actionColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.swap_horiz,
                          label: 'Action',
                          value: widget.action.toUpperCase(),
                          color: actionColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Timestamp',
                          value:
                              '${widget.timestamp.day}/${widget.timestamp.month}/${widget.timestamp.year} at ${widget.timestamp.hour}:${widget.timestamp.minute.toString().padLeft(2, '0')}',
                          color: actionColor,
                        ),
                        if (widget.isBatch && widget.batchId != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.tag,
                            label: 'Batch ID',
                            value: widget.batchId!,
                            color: actionColor,
                          ),
                        ],
                        if (widget.notes != null &&
                            widget.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.notes,
                            label: 'Notes',
                            value: widget.notes!,
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

/// Batch group item widget - shows multiple tools processed in a batch
class _BatchGroupItem extends StatefulWidget {
  final String batchId;
  final List<Map<String, dynamic>> transactions;
  final String action;
  final String staffName;
  final DateTime timestamp;

  const _BatchGroupItem({
    required this.batchId,
    required this.transactions,
    required this.action,
    required this.staffName,
    required this.timestamp,
  });

  @override
  State<_BatchGroupItem> createState() => _BatchGroupItemState();
}

class _BatchGroupItemState extends State<_BatchGroupItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isCheckout = widget.action.toLowerCase() == 'checkout';
    final toolCount = widget.transactions.length;

    // Different colors for checkout vs checkin batches
    final batchColor = isCheckout
        ? MallonColors.checkedOut
        : MallonColors.available;
    final batchBgColor = isCheckout
        ? MallonColors.checkedOut.withOpacity(0.1)
        : MallonColors.available.withOpacity(0.1);

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
                    'BATCH ${widget.action.toUpperCase()} - $toolCount tools',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                    '$toolCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('by ${widget.staffName}'),
                Text(
                  _formatTimestamp(widget.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: MallonColors.secondaryText,
                  ),
                ),
                Text(
                  'Batch ID: ${widget.batchId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: MallonColors.secondaryText,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: batchColor,
              ),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded) ...[
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
                          value: widget.batchId,
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.layers,
                          label: 'Action',
                          value: widget.action.toUpperCase(),
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.build,
                          label: 'Tools Count',
                          value:
                              '${widget.transactions.length} tool${widget.transactions.length > 1 ? 's' : ''}',
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: isCheckout ? 'Assigned To' : 'Processed By',
                          value: widget.staffName,
                          color: batchColor,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Timestamp',
                          value:
                              '${widget.timestamp.day}/${widget.timestamp.month}/${widget.timestamp.year} at ${widget.timestamp.hour}:${widget.timestamp.minute.toString().padLeft(2, '0')}',
                          color: batchColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tools List Section
                  Row(
                    children: [
                      Icon(Icons.build, size: 18, color: batchColor),
                      const SizedBox(width: 8),
                      Text(
                        'Tools in This Batch (${widget.transactions.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.transactions.asMap().entries.map((entry) {
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

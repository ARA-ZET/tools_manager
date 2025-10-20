import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/tool.dart';
import '../services/secure_tool_transaction_service.dart';
import '../services/staff_service.dart';
import '../services/history_service.dart';
import '../services/tool_subcollection_history_service.dart';
import '../core/theme/mallon_theme.dart';
import 'add_tool_screen.dart';
import 'package:intl/intl.dart';

/// Tool detail screen showing tool information and history
class ToolDetailScreen extends StatefulWidget {
  final Tool tool;

  const ToolDetailScreen({super.key, required this.tool});

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SecureToolTransactionService _secureTransactionService =
      SecureToolTransactionService();
  final StaffService _staffService = StaffService();
  final HistoryService _historyService = HistoryService();
  final ToolSubcollectionHistoryService _subcollectionHistoryService =
      ToolSubcollectionHistoryService();
  Future<List<Map<String, dynamic>>>? _historyFuture;

  // Fallback status info for legacy tools (before instant fields were added)
  Map<String, String>? _legacyStatusInfo;
  bool _loadingLegacyStatus = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Refresh UI when tab changes
    });
    _refreshHistory();

    // Load legacy status info for tools checked out before instant fields were added
    if (widget.tool.status == 'checked_out' &&
        widget.tool.lastAssignedToName == null) {
      _loadLegacyStatusInfo();
    }
  }

  void _refreshHistory() {
    debugPrint('🔄 Refreshing history for tool: ${widget.tool.uniqueId}');
    setState(() {
      _historyFuture = _getToolHistoryFromProvider()
          .then((history) {
            debugPrint('📋 History loaded: ${history.length} entries');
            return history;
          })
          .catchError((error) {
            debugPrint('❌ Error loading history: $error');
            return <Map<String, dynamic>>[];
          });
    });
  }

  /// Load status info for legacy tools (checked out before instant fields were added)
  Future<void> _loadLegacyStatusInfo() async {
    if (_loadingLegacyStatus || widget.tool.status != 'checked_out') {
      return;
    }

    // Only load if the instant fields are missing
    if (widget.tool.lastAssignedToName != null) {
      return; // New fields exist, no need for legacy loading
    }

    setState(() {
      _loadingLegacyStatus = true;
    });

    try {
      // Get staff from currentHolder reference
      if (widget.tool.currentHolder != null) {
        final staffUid = widget.tool.currentHolder!.id;
        final staff = await _staffService.getStaffById(staffUid);

        if (mounted) {
          setState(() {
            _legacyStatusInfo = {
              'assignedTo': staff?.fullName ?? 'Unknown Staff',
              'assignedToJobCode': staff?.jobCode ?? 'Unknown',
            };
            _loadingLegacyStatus = false;
          });
          debugPrint(
            '✅ Loaded legacy status info for tool ${widget.tool.uniqueId}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading legacy status info: $e');
      if (mounted) {
        setState(() {
          _legacyStatusInfo = {
            'assignedTo': 'Error loading',
            'assignedToJobCode': 'Error',
          };
          _loadingLegacyStatus = false;
        });
      }
    }
  }

  /// Get tool history from tool subcollection (faster and tool-specific)
  Future<List<Map<String, dynamic>>> _getToolHistoryFromProvider() async {
    try {
      debugPrint(
        '📊 Loading history from tool subcollection for tool: ${widget.tool.id}',
      );

      // Use subcollection history service (reads from tools/{toolId}/history/{monthKey})
      final history = await _subcollectionHistoryService.getToolHistory(
        toolId: widget.tool.id,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        limit: 100,
      );

      if (history.isNotEmpty) {
        debugPrint(
          '✅ Loaded ${history.length} entries from tool subcollection',
        );
        return history;
      }

      // Fallback to legacy if subcollection is empty
      debugPrint('⚠️ No subcollection history, trying legacy...');
      return _getLegacyToolHistory();
    } catch (e) {
      debugPrint('❌ Error loading tool history from subcollection: $e');
      // Fall back to legacy system
      return _getLegacyToolHistory();
    }
  }

  /// Fallback method for legacy tool history
  Future<List<Map<String, dynamic>>> _getLegacyToolHistory() async {
    try {
      // First try to get readable history directly
      final readableHistory = await _secureTransactionService
          .getReadableToolHistory(widget.tool.uniqueId);

      if (readableHistory.isNotEmpty) {
        return readableHistory;
      }

      // No readable history found, try legacy history using tool ID
      final legacyHistory = await _historyService.getToolHistorySimple(
        widget.tool.id,
      );

      if (legacyHistory.isNotEmpty) {
        // Convert legacy history to readable format
        final convertedHistory = <Map<String, dynamic>>[];

        for (final entry in legacyHistory) {
          // Get staff name from UID
          String staffName = 'Unknown Staff';
          try {
            final staff = await _staffService.getStaffById(entry.byId);
            if (staff != null) {
              staffName = staff.fullName;
            }
          } catch (e) {
            // Keep default if staff lookup fails
          }

          convertedHistory.add({
            'id': entry.id,
            'action': entry.action.value,
            'timestamp': entry.timestamp,
            'notes': entry.notes ?? '',
            'staffId': entry.byId, // Keep UID as fallback
            'metadata': {
              'staffName': staffName,
              'toolName': widget.tool.displayName,
              'adminName': 'Legacy System',
            },
          });
        }

        return convertedHistory;
      }

      // No history found in either system
      return [];
    } catch (e) {
      debugPrint('Error loading legacy tool history: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.displayName),
        actions: [
          // Show refresh button only on history tab
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshHistory,
              tooltip: 'Refresh History',
            ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Tool'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code),
                  title: Text('Show QR Code'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'checkout',
                child: ListTile(
                  leading: Icon(Icons.assignment_return),
                  title: Text('Check Out/In'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Details'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDetailsTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: MallonColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.build,
                          color: MallonColors.mediumGrey,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.tool.displayName,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${widget.tool.uniqueId}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: MallonColors.secondaryText,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          ],
                        ),
                      ),
                      MallonWidgets.statusChip(status: widget.tool.status),
                    ],
                  ),
                  if (widget.tool.name.isNotEmpty &&
                      widget.tool.name != widget.tool.displayName) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.tool.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tool Information
          _buildInfoSection('Tool Information', [
            _InfoRow('Brand', widget.tool.brand),
            _InfoRow('Model', widget.tool.model),
            if (widget.tool.num.isNotEmpty)
              _InfoRow('Tool Number', widget.tool.num),
            _InfoRow(
              'Category',
              widget.tool.meta['category']
                      ?.toString()
                      .replaceAll('_', ' ')
                      .toUpperCase() ??
                  'Not specified',
            ),
            _InfoRow(
              'Condition',
              widget.tool.meta['condition']
                      ?.toString()
                      .replaceAll('_', ' ')
                      .toUpperCase() ??
                  'Not specified',
            ),
            _InfoRow(
              'Created',
              DateFormat(
                'MMM dd, yyyy \'at\' hh:mm a',
              ).format(widget.tool.createdAt),
            ),
            _InfoRow(
              'Last Updated',
              DateFormat(
                'MMM dd, yyyy \'at\' hh:mm a',
              ).format(widget.tool.updatedAt),
            ),
          ]),

          const SizedBox(height: 16),

          // Current Status - Using instant fields with legacy fallback
          if (widget.tool.status == 'checked_out') ...[
            _buildInfoSection('Current Status', [
              _InfoRow('Status', 'Checked Out', statusColor: Colors.orange),

              // Assigned To (with legacy fallback)
              if (widget.tool.lastAssignedToName != null)
                _InfoRow(
                  'Assigned To',
                  widget.tool.lastAssignedToName!,
                  trailingWidget: const Icon(Icons.person),
                )
              else if (_legacyStatusInfo != null &&
                  _legacyStatusInfo!['assignedTo'] != null)
                _InfoRow(
                  'Assigned To',
                  _legacyStatusInfo!['assignedTo']!,
                  trailingWidget: const Icon(Icons.person),
                )
              else if (_loadingLegacyStatus)
                _InfoRow(
                  'Assigned To',
                  'Loading...',
                  trailingWidget: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (widget.tool.currentHolder != null)
                _InfoRow(
                  'Assigned To',
                  'Staff Member (ID: ${widget.tool.currentHolder!.id.substring(0, 8)}...)',
                  trailingWidget: const Icon(Icons.person_outline),
                ),

              // Job Code (if available)
              if (widget.tool.lastAssignedToJobCode != null)
                _InfoRow(
                  'Job Code',
                  widget.tool.lastAssignedToJobCode!,
                  trailingWidget: const Icon(Icons.badge),
                )
              else if (_legacyStatusInfo != null &&
                  _legacyStatusInfo!['assignedToJobCode'] != null)
                _InfoRow(
                  'Job Code',
                  _legacyStatusInfo!['assignedToJobCode']!,
                  trailingWidget: const Icon(Icons.badge),
                ),

              // Assigned By
              if (widget.tool.lastAssignedByName != null)
                _InfoRow(
                  'Assigned By',
                  widget.tool.lastAssignedByName!,
                  trailingWidget: const Icon(Icons.admin_panel_settings),
                ),

              // Checkout timestamp
              if (widget.tool.lastAssignedAt != null)
                _InfoRow(
                  'Checked Out',
                  DateFormat(
                    'MMM dd, yyyy \'at\' hh:mm a',
                  ).format(widget.tool.lastAssignedAt!),
                  trailingWidget: const Icon(Icons.access_time),
                )
              else
                _InfoRow(
                  'Checked Out',
                  'Date not recorded',
                  trailingWidget: const Icon(Icons.access_time_outlined),
                ),
            ]),
            const SizedBox(height: 16),
          ],

          // Show status for available tools
          if (widget.tool.status == 'available') ...[
            _buildInfoSection('Current Status', [
              _InfoRow('Status', 'Available', statusColor: Colors.green),

              // Show last checkin info if available
              if (widget.tool.lastCheckinByName != null)
                _InfoRow(
                  'Last Returned By',
                  widget.tool.lastCheckinByName!,
                  trailingWidget: const Icon(Icons.assignment_return),
                ),

              if (widget.tool.lastCheckinAt != null)
                _InfoRow(
                  'Returned At',
                  DateFormat(
                    'MMM dd, yyyy \'at\' hh:mm a',
                  ).format(widget.tool.lastCheckinAt!),
                  trailingWidget: const Icon(Icons.access_time),
                )
              else
                _InfoRow(
                  'Ready For Use',
                  'Available for checkout',
                  trailingWidget: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),

              // Show last assignment info if available
              if (widget.tool.lastAssignedToName != null &&
                  widget.tool.lastAssignedAt != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  'Previously Assigned To',
                  widget.tool.lastAssignedToName!,
                  trailingWidget: const Icon(Icons.history, color: Colors.grey),
                ),
              ],
            ]),
            const SizedBox(height: 16),
          ],

          // Additional Information
          if (widget.tool.meta['notes']?.toString().isNotEmpty == true) ...[
            _buildInfoSection('Notes', [
              _InfoRow(
                'Additional Notes',
                widget.tool.meta['notes']?.toString() ?? '',
                isMultiline: true,
              ),
            ]),
            const SizedBox(height: 16),
          ],

          // QR Code Section
          _buildInfoSection('QR Code', [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MallonColors.lightGrey),
                    ),
                    child: QrImageView(
                      data: widget.tool.qrPayload,
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.tool.qrPayload,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: MallonColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    // Always use FutureBuilder since getToolTransactions is now async
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        return _buildHistoryContent(
          snapshot.data ?? [],
          snapshot.hasError,
          snapshot.connectionState == ConnectionState.waiting,
          snapshot.error?.toString(),
        );
      },
    );
  }

  Widget _buildHistoryContent(
    List<Map<String, dynamic>> historyEntries,
    bool hasError,
    bool isLoading,
    String? errorMessage,
  ) {
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load tool history at this time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MallonColors.secondaryText,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MallonColors.secondaryText,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading history...'),
          ],
        ),
      );
    }

    if (historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: MallonColors.mediumGrey),
            const SizedBox(height: 16),
            Text(
              'No History Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This tool hasn\'t been checked out or returned yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MallonColors.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyEntries.length,
      itemBuilder: (context, index) {
        final entry = historyEntries[index];
        return _ReadableHistoryCard(entry: entry);
      },
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: MallonColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _navigateToEditTool();
        break;
      case 'qr':
        _showQRCodeDialog();
        break;
      case 'checkout':
        // TODO: Navigate to checkout/checkin screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check out/in functionality coming soon!'),
          ),
        );
        break;
    }
  }

  /// Navigate to edit tool screen
  Future<void> _navigateToEditTool() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddToolScreen(tool: widget.tool)),
    );

    // If the tool was updated, refresh the current screen
    if (result == true) {
      // Refresh history (which will also reload status info)
      _refreshHistory();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tool updated successfully!'),
            backgroundColor: MallonColors.primaryGreen,
          ),
        );
      }
    }
  }

  void _showQRCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR Code - ${widget.tool.uniqueId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: widget.tool.qrPayload,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.tool.displayName,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.tool.qrPayload,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: MallonColors.secondaryText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement print functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print functionality coming soon!'),
                ),
              );
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }
}

/// Info row widget for displaying tool details
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? statusColor;
  final Widget? trailingWidget;
  final bool isMultiline;

  const _InfoRow(
    this.label,
    this.value, {
    this.statusColor,
    this.trailingWidget,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: MallonColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: statusColor),
            ),
          ),
          if (trailingWidget != null) trailingWidget!,
        ],
      ),
    );
  }
}

/// Readable history card widget for displaying tool history entries with names
class _ReadableHistoryCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _ReadableHistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final action = entry['action'] ?? 'unknown';

    // Support both formats:
    // 1. Tool subcollection format (flat): entry['staffName']
    // 2. Global history format (nested): entry['metadata']['staffName']
    final staffName =
        entry['staffName'] ??
        entry['metadata']?['staffName'] ??
        entry['staffId'] ??
        'Unknown Staff';

    final adminName =
        entry['assignedByName'] ??
        entry['metadata']?['adminName'] ??
        entry['metadata']?['admin'];

    final notes = entry['notes'];
    final timestamp = entry['timestamp'];

    // Format timestamp
    String formattedTime = 'Unknown time';
    if (timestamp != null) {
      try {
        final dateTime = timestamp.toDate();
        formattedTime = DateFormat(
          'MMM dd, yyyy \'at\' hh:mm a',
        ).format(dateTime);
      } catch (e) {
        formattedTime = 'Unknown time';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getActionIcon(action),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action == 'checkout' ? 'Check Out' : 'Check In',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MallonColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Staff information
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 16,
                  color: MallonColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Text(
                  action == 'checkout'
                      ? 'Assigned to: $staffName'
                      : 'Returned by: $staffName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MallonColors.secondaryText,
                  ),
                ),
              ],
            ),
            // Admin information
            // if (adminName != null && adminName.toString().isNotEmpty) ...[
            //   const SizedBox(height: 4),
            //   Row(
            //     children: [
            //       const Icon(
            //         Icons.admin_panel_settings,
            //         size: 16,
            //         color: MallonColors.secondaryText,
            //       ),
            //       const SizedBox(width: 4),
            //       Text(
            //         'Processed by: $adminName',
            //         style: Theme.of(context).textTheme.bodySmall?.copyWith(
            //           color: MallonColors.secondaryText,
            //         ),
            //       ),
            //     ],
            //   ),
            // ],
            // Notes
            if (notes != null && notes.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getActionIcon(String action) {
    if (action == 'checkout') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.assignment_return,
          color: Colors.orange,
          size: 20,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.assignment_turned_in,
          color: Colors.green,
          size: 20,
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tools_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/transactions_provider.dart';
import '../core/theme/mallon_theme.dart';

/// Dashboard screen showing overview of tool management system
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return IconButton(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: MallonColors.primaryGreen,
                  child: Text(
                    authProvider.user?.displayName
                            ?.substring(0, 1)
                            .toUpperCase() ??
                        authProvider.user?.email
                            ?.substring(0, 1)
                            .toUpperCase() ??
                        'U',
                    style: const TextStyle(
                      color: MallonColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onPressed: () {
                  // TODO: Show user menu
                },
              );
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats Section
            _QuickStatsSection(),

            SizedBox(height: 24),

            // Recent Activity Section
            _RecentActivitySection(),

            SizedBox(height: 24),

            // Quick Actions Section
            _QuickActionsSection(),
          ],
        ),
      ),
    );
  }
}

/// Quick stats cards showing tool availability
class _QuickStatsSection extends StatefulWidget {
  const _QuickStatsSection();

  @override
  State<_QuickStatsSection> createState() => _QuickStatsSectionState();
}

class _QuickStatsSectionState extends State<_QuickStatsSection> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ToolsProvider, StaffProvider>(
      builder: (context, toolsProvider, staffProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Stats',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // Refresh providers if there's an error
                    if (toolsProvider.hasError) toolsProvider.retry();
                    if (staffProvider.hasError) staffProvider.retry();
                  },
                  tooltip: 'Refresh Stats',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats Grid with Provider Data
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                // Available Tools
                _StatCard(
                  title: 'Available',
                  value: toolsProvider.isLoaded
                      ? '${toolsProvider.availableToolsCount}'
                      : '...',
                  icon: Icons.check_circle,
                  color: MallonColors.available,
                  isLoading: toolsProvider.isLoading,
                  hasError: toolsProvider.hasError,
                ),

                // Checked Out Tools
                _StatCard(
                  title: 'Checked Out',
                  value: toolsProvider.isLoaded
                      ? '${toolsProvider.checkedOutToolsCount}'
                      : '...',
                  icon: Icons.access_time,
                  color: MallonColors.checkedOut,
                  isLoading: toolsProvider.isLoading,
                  hasError: toolsProvider.hasError,
                ),

                // Total Tools
                _StatCard(
                  title: 'Total Tools',
                  value: toolsProvider.isLoaded
                      ? '${toolsProvider.totalToolsCount}'
                      : '...',
                  icon: Icons.build,
                  color: MallonColors.primaryGreen,
                  isLoading: toolsProvider.isLoading,
                  hasError: toolsProvider.hasError,
                ),

                // Active Staff (only show if authorized)
                _StatCard(
                  title: 'Active Staff',
                  value: staffProvider.isLoaded
                      ? '${staffProvider.activeStaffCount}'
                      : staffProvider.isUnauthorized
                      ? 'N/A'
                      : '...',
                  icon: Icons.people,
                  color: MallonColors.accentGreen,
                  isLoading: staffProvider.isLoading,
                  hasError: staffProvider.hasError,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Individual stat card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool hasError;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasError)
              Icon(Icons.error_outline, size: 32, color: MallonColors.error)
            else if (isLoading)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              hasError ? 'Error' : value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasError ? MallonColors.error : color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent activity section
class _RecentActivitySection extends StatefulWidget {
  const _RecentActivitySection();

  @override
  State<_RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<_RecentActivitySection> {
  bool _showAllActivities = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to audit/history screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Full audit screen coming soon'),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Activity List with Provider
        Consumer<TransactionsProvider>(
          builder: (context, transactionsProvider, child) {
            if (transactionsProvider.isLoading) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (transactionsProvider.hasError) {
              return Card(
                child: ListTile(
                  leading: Icon(Icons.error_outline, color: MallonColors.error),
                  title: const Text('Error loading activity'),
                  subtitle: Text(
                    transactionsProvider.errorMessage ?? 'Unknown error',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => transactionsProvider.retry(),
                  ),
                ),
              );
            }

            if (transactionsProvider.isUnauthorized) {
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.lock_outline,
                    color: MallonColors.mediumGrey,
                  ),
                  title: const Text('Activity not available'),
                  subtitle: const Text(
                    'Recent activity is only available to administrators',
                  ),
                ),
              );
            }

            final allHistory = transactionsProvider.getRecentTransactions(
              limit: _showAllActivities ? 100 : 20,
            );

            if (allHistory.isEmpty) {
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: MallonColors.mediumGrey,
                  ),
                  title: const Text('No recent activity'),
                  subtitle: const Text(
                    'Tool checkout/checkin activity will appear here',
                  ),
                ),
              );
            }

            // Show only first 5 activities if not showing all
            final displayHistory = _showAllActivities
                ? allHistory
                : allHistory.take(5).toList();
            final hasMoreActivities = allHistory.length > 5;

            return Card(
              child: Column(
                children: [
                  ...displayHistory.map((activity) {
                    return _ReadableActivityTile(activity: activity);
                  }),

                  // Show "Load More" button if there are more activities and not showing all
                  if (hasMoreActivities && !_showAllActivities)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAllActivities = true;
                          });
                        },
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          'Load More (${allHistory.length - 5} more)',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: MallonColors.primaryGreen,
                        ),
                      ),
                    ),

                  // Show "Show Less" button if showing all activities
                  if (_showAllActivities && hasMoreActivities)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAllActivities = false;
                          });
                        },
                        icon: const Icon(Icons.expand_less),
                        label: const Text('Show Less'),
                        style: TextButton.styleFrom(
                          foregroundColor: MallonColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Individual activity tile with readable names
class _ReadableActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ReadableActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final action = activity['action'] ?? 'unknown';
    final isCheckout = action == 'checkout';
    final icon = isCheckout ? Icons.output : Icons.input;
    final color = isCheckout ? MallonColors.checkedOut : MallonColors.available;

    // Extract readable information
    final toolName = activity['metadata']?['toolName'] ?? 'Unknown Tool';
    final staffName =
        activity['metadata']?['staffName'] ??
        activity['staffId'] ??
        'Unknown Staff';
    final notes = activity['notes'];
    final timestamp = activity['timestamp'];

    // Format timestamp
    String formattedTime = 'Unknown time';
    if (timestamp != null) {
      try {
        final dateTime = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inMinutes < 1) {
          formattedTime = 'Just now';
        } else if (difference.inHours < 1) {
          formattedTime = '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          formattedTime = '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          formattedTime = '${difference.inDays}d ago';
        } else {
          formattedTime = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        }
      } catch (e) {
        formattedTime = 'Unknown time';
      }
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        'Tool ${isCheckout ? 'checked out' : 'checked in'}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [Text('Tool: $toolName'), Text('Staff: $staffName')],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (notes != null && notes.toString().isNotEmpty) Text('$notes'),
              Text(
                formattedTime,
                style: TextStyle(color: MallonColors.mediumGrey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        isCheckout ? Icons.arrow_forward : Icons.arrow_back,
        color: color,
        size: 16,
      ),
    );
  }
}

/// Quick actions section
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Action Buttons
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _ActionButton(
              title: 'Scan Tool',
              icon: Icons.qr_code_scanner,
              onPressed: () {
                // TODO: Navigate to scan screen
              },
            ),
            _ActionButton(
              title: 'View Tools',
              icon: Icons.build,
              onPressed: () {
                // TODO: Navigate to tools screen
              },
            ),
            _ActionButton(
              title: 'Manage Staff',
              icon: Icons.people,
              onPressed: () {
                // TODO: Navigate to staff screen
              },
            ),
            _ActionButton(
              title: 'Settings',
              icon: Icons.settings,
              onPressed: () {
                // TODO: Navigate to settings screen
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: MallonColors.primaryGreen),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

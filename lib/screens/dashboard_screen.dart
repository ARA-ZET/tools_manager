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
      body: Consumer<ToolsProvider>(
        builder: (context, toolsProvider, child) {
          // Show loading indicator while providers are initializing
          if (toolsProvider.isLoading && !toolsProvider.isLoaded) {
            return Container(
              color: Colors.grey[50], // Light background
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        MallonColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading dashboard...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MallonColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MallonColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show content once loaded (or if there's an error, still show the UI)
          return const SingleChildScrollView(
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
          );
        },
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MallonColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.dashboard_outlined,
                        color: MallonColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Quick Stats',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MallonColors.primaryText,
                      ),
                    ),
                  ],
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

            // Stats Grid with Provider Data - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive columns based on screen width
                int crossAxisCount;
                double childAspectRatio;

                if (constraints.maxWidth < 600) {
                  // Mobile: 2 columns
                  crossAxisCount = 2;
                  childAspectRatio = 1.3;
                } else if (constraints.maxWidth < 900) {
                  // Tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 1.4;
                } else {
                  // Desktop: 4 columns
                  crossAxisCount = 4;
                  childAspectRatio = 1.5;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
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
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Individual stat card with enhanced visuals
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with circular background
              if (hasError)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MallonColors.error.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 32,
                    color: MallonColors.error,
                  ),
                )
              else if (isLoading)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
              const SizedBox(height: 12),
              // Value
              Text(
                hasError ? 'Error' : value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasError ? MallonColors.error : color,
                ),
              ),
              const SizedBox(height: 4),
              // Title
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MallonColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MallonColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history,
                    color: MallonColors.accentGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MallonColors.primaryText,
                  ),
                ),
              ],
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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

/// Individual activity tile with readable names and enhanced visuals
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

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          'Tool ${isCheckout ? 'checked out' : 'checked in'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.build_outlined,
                    size: 14,
                    color: MallonColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      toolName,
                      style: TextStyle(
                        color: MallonColors.primaryText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: MallonColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      staffName,
                      style: TextStyle(
                        color: MallonColors.secondaryText,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (notes != null && notes.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 14,
                      color: MallonColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        notes.toString(),
                        style: TextStyle(
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCheckout ? Icons.arrow_forward : Icons.arrow_back,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedTime,
              style: TextStyle(
                color: MallonColors.mediumGrey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MallonColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.touch_app,
                color: MallonColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: MallonColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Action Buttons - Responsive
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive columns based on screen width
            int crossAxisCount;
            double childAspectRatio;

            if (constraints.maxWidth < 600) {
              // Mobile: 2 columns
              crossAxisCount = 2;
              childAspectRatio = 2.0;
            } else if (constraints.maxWidth < 900) {
              // Tablet: 3 columns
              crossAxisCount = 3;
              childAspectRatio = 2.3;
            } else {
              // Desktop: 4 columns
              crossAxisCount = 4;
              childAspectRatio = 2.5;
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
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
            );
          },
        ),
      ],
    );
  }
}

/// Action button widget with enhanced visuals
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MallonColors.primaryGreen.withOpacity(0.05),
                MallonColors.accentGreen.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MallonColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: MallonColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MallonColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

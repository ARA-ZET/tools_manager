import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/tools_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/consumables_provider.dart';
import '../models/consumable.dart';
import '../models/measurement_unit.dart';
import '../core/theme/mallon_theme.dart';

/// Responsive utility for dashboard elements
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// Get responsive font size
  static double fontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive icon size
  static double iconSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive padding
  static double padding(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }
}

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
      backgroundColor: MallonColors.primaryGreen.withAlpha(30),
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
              spacing: 24,
              children: [
                // Quick Stats Section
                _QuickStatsSection(),

                // Recent Activity Section
                _RecentActivitySection(),

                // Quick Actions Section
                _QuickActionsSection(),

                // Consumables Insights Section
                _ConsumablesInsightsSection(),
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
                      padding: EdgeInsets.all(
                        ResponsiveHelper.padding(
                          context,
                          mobile: 6,
                          tablet: 7,
                          desktop: 8,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: MallonColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.dashboard_outlined,
                        color: MallonColors.primaryGreen,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 20,
                          tablet: 22,
                          desktop: 24,
                        ),
                      ),
                    ),

                    Text(
                      'Quick Stats',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MallonColors.primaryText,
                            fontSize: ResponsiveHelper.fontSize(
                              context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20,
                            ),
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: ResponsiveHelper.iconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
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
                  childAspectRatio = 1.2;
                } else if (constraints.maxWidth < 900) {
                  // Tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 1.3;
                } else {
                  // Desktop: 4 columns
                  crossAxisCount = 4;
                  childAspectRatio = 1.6;
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
                      imagePath: 'assets/images/available.jpg',
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
                      imagePath: 'assets/images/checkout.png',
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
                      imagePath: 'assets/images/staff.png',
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
                      imagePath: 'assets/images/active_staff.jpg',
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

/// Individual stat card with enhanced visuals and custom images
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? imagePath;
  final bool isLoading;
  final bool hasError;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.imagePath,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image (if provided)
            if (imagePath != null && !hasError && !isLoading)
              Image.asset(
                imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to gradient if image fails
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.1),
                          color.withOpacity(0.05),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
              // Gradient background fallback
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                  ),
                ),
              ),

            // Dark overlay for text readability
            if (imagePath != null && !hasError && !isLoading)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),

            // Content
            Padding(
              padding: EdgeInsets.all(
                ResponsiveHelper.padding(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with circular background
                  if (hasError)
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveHelper.padding(
                          context,
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: MallonColors.error.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                        color: Colors.white,
                      ),
                    )
                  else if (isLoading)
                    SizedBox(
                      width: ResponsiveHelper.iconSize(
                        context,
                        mobile: 40,
                        tablet: 48,
                        desktop: 56,
                      ),
                      height: ResponsiveHelper.iconSize(
                        context,
                        mobile: 40,
                        tablet: 48,
                        desktop: 56,
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: ResponsiveHelper.isMobile(context)
                            ? 2.5
                            : 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveHelper.padding(
                          context,
                          mobile: 4,
                          tablet: 6,
                          desktop: 8,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: imagePath != null
                            ? Colors.white.withOpacity(0.9)
                            : color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: imagePath != null
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icon,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                        color: imagePath != null ? color : color,
                      ),
                    ),

                  const Spacer(),

                  // Value
                  Text(
                    hasError ? 'Error' : value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.fontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                      color: imagePath != null && !hasError && !isLoading
                          ? Colors.white
                          : (hasError ? MallonColors.error : color),
                      shadows: imagePath != null && !hasError && !isLoading
                          ? [
                              Shadow(
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: imagePath != null && !hasError && !isLoading
                          ? Colors.white.withOpacity(0.9)
                          : MallonColors.secondaryText,
                      fontSize: ResponsiveHelper.fontSize(
                        context,
                        mobile: 11,
                        tablet: 12,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.w600,
                      shadows: imagePath != null && !hasError && !isLoading
                          ? [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
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
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.padding(
                      context,
                      mobile: 6,
                      tablet: 7,
                      desktop: 8,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: MallonColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history,
                    color: MallonColors.accentGreen,
                    size: ResponsiveHelper.iconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
                ),
                SizedBox(
                  width: ResponsiveHelper.padding(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  ),
                ),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MallonColors.primaryText,
                    fontSize: ResponsiveHelper.fontSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.goNamed('audit'),
              child: const Text('Load more...'),
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
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.padding(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
          vertical: ResponsiveHelper.padding(
            context,
            mobile: 6,
            tablet: 7,
            desktop: 8,
          ),
        ),
        leading: Container(
          padding: EdgeInsets.all(
            ResponsiveHelper.padding(
              context,
              mobile: 8,
              tablet: 9,
              desktop: 10,
            ),
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: ResponsiveHelper.iconSize(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
          ),
        ),
        title: Text(
          'Tool ${isCheckout ? 'checked out' : 'checked in'}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveHelper.fontSize(
              context,
              mobile: 10,
              tablet: 12,
              desktop: 14,
            ),
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveHelper.padding(
              context,
              mobile: 6,
              tablet: 7,
              desktop: 8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tool name section
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.build_outlined,
                      size: ResponsiveHelper.iconSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      color: MallonColors.secondaryText,
                    ),
                    SizedBox(
                      width: ResponsiveHelper.padding(
                        context,
                        mobile: 3,
                        tablet: 3.5,
                        desktop: 4,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        toolName,
                        style: TextStyle(
                          color: MallonColors.primaryText,
                          fontSize: ResponsiveHelper.fontSize(
                            context,
                            mobile: 12,
                            tablet: 12.5,
                            desktop: 13,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: ResponsiveHelper.padding(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                ),
              ),
              // Staff name and notes section in Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Staff name section
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: ResponsiveHelper.iconSize(
                            context,
                            mobile: 12,
                            tablet: 13,
                            desktop: 14,
                          ),
                          color: MallonColors.secondaryText,
                        ),
                        SizedBox(
                          width: ResponsiveHelper.padding(
                            context,
                            mobile: 3,
                            tablet: 3.5,
                            desktop: 4,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            !isCheckout
                                ? "Assigned to: $staffName"
                                : "Checked out by: $staffName",
                            style: TextStyle(
                              color: MallonColors.secondaryText,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: 12,
                                tablet: 12.5,
                                desktop: 13,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Notes section (conditional)
                    if (notes != null && notes.toString().isNotEmpty) ...[
                      SizedBox(
                        height: ResponsiveHelper.padding(
                          context,
                          mobile: 3,
                          tablet: 3.5,
                          desktop: 4,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: ResponsiveHelper.iconSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            ),
                            color: MallonColors.secondaryText,
                          ),
                          SizedBox(
                            width: ResponsiveHelper.padding(
                              context,
                              mobile: 3,
                              tablet: 3.5,
                              desktop: 4,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              notes.toString(),
                              style: TextStyle(
                                color: MallonColors.secondaryText,
                                fontSize: ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 11,
                                  tablet: 11.5,
                                  desktop: 12,
                                ),
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
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.padding(
                  context,
                  mobile: 6,
                  tablet: 7,
                  desktop: 8,
                ),
                vertical: ResponsiveHelper.padding(
                  context,
                  mobile: 3,
                  tablet: 3.5,
                  desktop: 4,
                ),
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCheckout ? Icons.arrow_forward : Icons.arrow_back,
                color: color,
                size: ResponsiveHelper.iconSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
            SizedBox(
              height: ResponsiveHelper.padding(
                context,
                mobile: 3,
                tablet: 3.5,
                desktop: 4,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                color: MallonColors.mediumGrey,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: 10,
                  tablet: 10.5,
                  desktop: 11,
                ),
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
              padding: EdgeInsets.all(
                ResponsiveHelper.padding(
                  context,
                  mobile: 4,
                  tablet: 5,
                  desktop: 6,
                ),
              ),
              decoration: BoxDecoration(
                color: MallonColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.touch_app,
                color: MallonColors.primaryGreen,
                size: ResponsiveHelper.iconSize(
                  context,
                  mobile: 20,
                  tablet: 24,
                  desktop: 28,
                ),
              ),
            ),
            SizedBox(
              width: ResponsiveHelper.padding(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              ),
            ),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: MallonColors.primaryText,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
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
              childAspectRatio = 1.2;
            } else if (constraints.maxWidth < 900) {
              // Tablet: 3 columns
              crossAxisCount = 3;
              childAspectRatio = 2.3;
            } else if (constraints.maxWidth < 1200) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            padding: EdgeInsets.all(
              ResponsiveHelper.padding(
                context,
                mobile: 12,
                tablet: 14,
                desktop: 16,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.padding(
                      context,
                      mobile: 10,
                      tablet: 11,
                      desktop: 12,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: MallonColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: ResponsiveHelper.iconSize(
                      context,
                      mobile: 24,
                      tablet: 26,
                      desktop: 28,
                    ),
                    color: MallonColors.primaryGreen,
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.padding(
                    context,
                    mobile: 10,
                    tablet: 11,
                    desktop: 12,
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MallonColors.primaryText,
                    fontSize: ResponsiveHelper.fontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
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

/// Consumables Insights Section
class _ConsumablesInsightsSection extends StatelessWidget {
  const _ConsumablesInsightsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConsumablesProvider>(
      builder: (context, consumablesProvider, child) {
        final bool isLoaded =
            !consumablesProvider.isLoading && !consumablesProvider.hasError;
        final int totalCount = consumablesProvider.activeConsumables.length;
        final int inStockCount = consumablesProvider.activeConsumables
            .where((c) => !c.isOutOfStock && c.stockLevel != StockLevel.low)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.padding(
                      context,
                      mobile: 4,
                      tablet: 5,
                      desktop: 6,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: MallonColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: MallonColors.accentGreen,
                    size: ResponsiveHelper.iconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
                ),
                SizedBox(
                  width: ResponsiveHelper.padding(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  ),
                ),
                Text(
                  'Consumables Insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MallonColors.primaryText,
                    fontSize: ResponsiveHelper.fontSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats Grid - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                double childAspectRatio;

                if (constraints.maxWidth < 600) {
                  // Mobile: 2 columns
                  crossAxisCount = 2;
                  childAspectRatio = 1.2;
                } else if (constraints.maxWidth < 900) {
                  // Tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 2.5;
                } else if (constraints.maxWidth < 1200) {
                  // Tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 2;
                } else {
                  // Desktop: 4 columns
                  crossAxisCount = 4;
                  childAspectRatio = 2;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    // Total Consumables
                    _ConsumableStatCard(
                      title: 'Total Items',
                      value: isLoaded ? '$totalCount' : '...',
                      icon: Icons.inventory_2,
                      color: MallonColors.primaryGreen,
                      isLoading: consumablesProvider.isLoading,
                    ),

                    // Low Stock
                    _ConsumableStatCard(
                      title: 'Low Stock',
                      value: isLoaded
                          ? '${consumablesProvider.lowStockCount}'
                          : '...',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      isLoading: consumablesProvider.isLoading,
                    ),

                    // Out of Stock
                    _ConsumableStatCard(
                      title: 'Out of Stock',
                      value: isLoaded
                          ? '${consumablesProvider.outOfStockCount}'
                          : '...',
                      icon: Icons.remove_circle_outline,
                      color: Colors.red,
                      isLoading: consumablesProvider.isLoading,
                    ),

                    // In Stock
                    _ConsumableStatCard(
                      title: 'In Stock',
                      value: isLoaded ? '$inStockCount' : '...',
                      icon: Icons.check_circle_outline,
                      color: MallonColors.available,
                      isLoading: consumablesProvider.isLoading,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Low Stock Items List
            if (isLoaded && consumablesProvider.lowStockCount > 0)
              _LowStockAlert(
                lowStockItems: consumablesProvider.lowStockConsumables,
              ),
          ],
        );
      },
    );
  }
}

/// Consumable stat card
class _ConsumableStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _ConsumableStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(
          ResponsiveHelper.padding(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: ResponsiveHelper.iconSize(
                  context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
                height: ResponsiveHelper.iconSize(
                  context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
                child: CircularProgressIndicator(
                  strokeWidth: ResponsiveHelper.isMobile(context) ? 2.5 : 3,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(
                  ResponsiveHelper.padding(
                    context,
                    mobile: 4,
                    tablet: 5,
                    desktop: 5,
                  ),
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: ResponsiveHelper.iconSize(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                  color: color,
                ),
              ),
            SizedBox(
              height: ResponsiveHelper.padding(
                context,
                mobile: 10,
                tablet: 11,
                desktop: 12,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                color: color,
              ),
            ),
            SizedBox(
              height: ResponsiveHelper.padding(
                context,
                mobile: 3,
                tablet: 3.5,
                desktop: 4,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MallonColors.secondaryText,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: 11,
                  tablet: 12,
                  desktop: 14,
                ),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Low stock alert widget
class _LowStockAlert extends StatelessWidget {
  final List<Consumable> lowStockItems;

  const _LowStockAlert({required this.lowStockItems});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orange.shade50,
      child: Padding(
        padding: EdgeInsets.all(
          ResponsiveHelper.padding(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: ResponsiveHelper.iconSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
                SizedBox(
                  width: ResponsiveHelper.padding(
                    context,
                    mobile: 6,
                    tablet: 7,
                    desktop: 8,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Items Need Restocking',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.fontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to consumables screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Navigate to Consumables screen'),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: ResponsiveHelper.padding(
                context,
                mobile: 10,
                tablet: 11,
                desktop: 12,
              ),
            ),
            ...lowStockItems.take(3).map((item) {
              final name = item.name;
              final currentQty = item.currentQuantity.toStringAsFixed(0);
              final minQty = item.minQuantity.toStringAsFixed(0);
              final unitLabel = item.unit.abbreviation;

              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveHelper.padding(
                    context,
                    mobile: 3,
                    tablet: 3.5,
                    desktop: 4,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: ResponsiveHelper.iconSize(
                        context,
                        mobile: 6,
                        tablet: 7,
                        desktop: 8,
                      ),
                      height: ResponsiveHelper.iconSize(
                        context,
                        mobile: 6,
                        tablet: 7,
                        desktop: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveHelper.padding(
                        context,
                        mobile: 10,
                        tablet: 11,
                        desktop: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: MallonColors.primaryText,
                          fontSize: ResponsiveHelper.fontSize(
                            context,
                            mobile: 13,
                            tablet: 14,
                            desktop: 15,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$currentQty / $minQty $unitLabel',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.fontSize(
                          context,
                          mobile: 12,
                          tablet: 12.5,
                          desktop: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (lowStockItems.length > 3) ...[
              SizedBox(
                height: ResponsiveHelper.padding(
                  context,
                  mobile: 6,
                  tablet: 7,
                  desktop: 8,
                ),
              ),
              Text(
                '+${lowStockItems.length - 3} more items need attention',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: ResponsiveHelper.fontSize(
                    context,
                    mobile: 11,
                    tablet: 11.5,
                    desktop: 12,
                  ),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

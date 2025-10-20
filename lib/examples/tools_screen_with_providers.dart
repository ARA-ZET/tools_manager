// Example: Updated Tools Screen with Provider-Based Filtering
// This shows how the tools screen would be transformed to use ToolsProvider

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tools_provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/mallon_theme.dart';

class ToolsScreenExample extends StatefulWidget {
  const ToolsScreenExample({super.key});

  @override
  State<ToolsScreenExample> createState() => _ToolsScreenExampleState();
}

class _ToolsScreenExampleState extends State<ToolsScreenExample> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        actions: [
          Consumer<ToolsProvider>(
            builder: (context, toolsProvider, child) {
              if (toolsProvider.hasError) {
                return IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  onPressed: () => toolsProvider.retry(),
                  tooltip: 'Retry loading tools',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<ToolsProvider>(
        builder: (context, toolsProvider, child) {
          // Handle loading state
          if (toolsProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tools...'),
                ],
              ),
            );
          }

          // Handle error state
          if (toolsProvider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading tools',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    toolsProvider.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MallonColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => toolsProvider.retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Get filtered tools from provider (memory-based, instant)
          final filteredTools = toolsProvider.getFilteredTools(
            status: _selectedFilter == 'all' ? null : _selectedFilter,
            searchQuery: _searchController.text.trim(),
          );

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search tools...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild for instant search
                  },
                ),
              ),

              // Filter Chips with Real-time Counts
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${toolsProvider.totalToolsCount})',
                      isSelected: _selectedFilter == 'all',
                      onTap: () => _updateFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Available (${toolsProvider.availableToolsCount})',
                      isSelected: _selectedFilter == 'available',
                      onTap: () => _updateFilter('available'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label:
                          'Checked Out (${toolsProvider.checkedOutToolsCount})',
                      isSelected: _selectedFilter == 'checked_out',
                      onTap: () => _updateFilter('checked_out'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tools List - No StreamBuilder needed, data is always current
              Expanded(
                child: filteredTools.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredTools.length,
                        itemBuilder: (context, index) {
                          final tool = filteredTools[index];
                          return _ToolCard(tool: tool);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // Admin actions based on provider data
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (!authProvider.canManageTools) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: () {
              // Navigate to add tool screen
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: MallonColors.mediumGrey),
          const SizedBox(height: 16),
          Text('No tools found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search or filter'
                : _selectedFilter == 'all'
                ? 'Add your first tool using the + button'
                : 'No tools match the current filter',
            textAlign: TextAlign.center,
            style: TextStyle(color: MallonColors.secondaryText),
          ),
        ],
      ),
    );
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }
}

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

class _ToolCard extends StatelessWidget {
  final dynamic tool; // Would be Tool model

  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MallonColors.lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build, color: MallonColors.mediumGrey),
            ),
            title: Text(tool.displayName),
            subtitle: Text('ID: ${tool.uniqueId}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status chip with real-time data
                MallonWidgets.statusChip(status: tool.status, isSmall: true),

                // Admin buttons (only visible to admins, no database calls needed)
                if (authProvider.isAdmin) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          // Edit functionality using provider
                          context.read<ToolsProvider>().updateTool(tool);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                      ),
                      IconButton(
                        onPressed: () {
                          // Delete functionality using provider
                          context.read<ToolsProvider>().deleteTool(tool.id);
                        },
                        icon: const Icon(Icons.delete, size: 16),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            onTap: () {
              // Navigate to tool details
            },
          ),
        );
      },
    );
  }
}

/* 
Key Improvements with Provider System:

1. PERFORMANCE:
   - No more StreamBuilder for every filter change
   - Instant search results (memory-based filtering)  
   - Real-time counts in filter chips
   - Single data load with automatic updates

2. REAL-TIME UPDATES:
   - Changes from other users appear instantly
   - No manual refresh needed
   - Consistent state across all screens

3. ROLE-BASED UI:
   - Admin buttons show/hide based on cached role data
   - No database calls to check permissions
   - Instant UI updates when role changes

4. ERROR HANDLING:
   - Built-in loading and error states
   - Retry functionality
   - Graceful fallbacks

5. DEVELOPER EXPERIENCE:
   - Simpler code structure
   - No complex stream management
   - Type-safe provider methods
   - Automatic cleanup

This pattern can be applied to all screens for consistent,
performant, and maintainable data management.
*/

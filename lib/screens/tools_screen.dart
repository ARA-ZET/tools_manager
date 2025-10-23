import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../models/tool.dart';
import '../providers/tools_provider.dart';
import '../providers/auth_provider.dart';
import '../services/staff_service.dart';
import '../services/tool_service.dart';
import 'add_tool_screen.dart';
import 'tool_detail_screen.dart';

/// Tools management screen
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
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
                setState(() {}); // Trigger rebuild to apply search filter
              },
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
                  label: 'Available',
                  isSelected: _selectedFilter == 'available',
                  onTap: () => _updateFilter('available'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Checked Out',
                  isSelected: _selectedFilter == 'checked_out',
                  onTap: () => _updateFilter('checked_out'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tools List
          Expanded(child: _buildToolsList()),
        ],
      ),

      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Only show the FAB to admin users
          if (!authProvider.isAdmin) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddToolScreen()),
              );
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _buildToolsList() {
    return Consumer<ToolsProvider>(
      builder: (context, toolsProvider, child) {
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

        if (toolsProvider.isLoading && !toolsProvider.isLoaded) {
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

        // Get filtered tools from provider (memory-based filtering)
        final tools = _getFilteredTools(toolsProvider);

        if (tools.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.build_outlined,
                  size: 64,
                  color: MallonColors.mediumGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tools found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFilter == 'all'
                      ? 'Add your first tool using the + button'
                      : 'No tools match the current filter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MallonColors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _ToolCard(
              tool: tool,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ToolDetailScreen(tool: tool),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  List<Tool> _getFilteredTools(ToolsProvider toolsProvider) {
    var filteredList = toolsProvider.allTools;

    // Apply status filter in memory
    if (_selectedFilter != 'all') {
      filteredList = filteredList
          .where((tool) => tool.status == _selectedFilter)
          .toList();
    }

    // Apply search filter in memory
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filteredList = filteredList.where((tool) {
        return tool.name.toLowerCase().contains(query) ||
            tool.brand.toLowerCase().contains(query) ||
            tool.model.toLowerCase().contains(query) ||
            tool.uniqueId.toLowerCase().contains(query) ||
            tool.num.toLowerCase().contains(query);
      }).toList();
    }

    // Tools are already sorted by the provider
    return filteredList;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tools'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Tools'),
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
              title: const Text('Available'),
              leading: Radio<String>(
                value: 'available',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  _updateFilter(value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Checked Out'),
              leading: Radio<String>(
                value: 'checked_out',
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

/// Tool card widget with worker name display
class _ToolCard extends StatefulWidget {
  final Tool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  final StaffService _staffService = StaffService();
  final ToolService _toolService = ToolService();
  String? _workerName;
  bool _isAdmin = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkerName();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staff = await _staffService.getStaffByAuthUid(user.uid);
        if (mounted) {
          setState(() {
            _isAdmin = staff?.role.isSupervisor ?? false;
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _handleEditTool(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddToolScreen(tool: widget.tool)),
    );

    // If the tool was updated, show success message
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tool updated successfully!'),
          backgroundColor: MallonColors.primaryGreen,
        ),
      );
    }
  }

  void _handleDeleteTool(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tool'),
        content: Text(
          'Are you sure you want to delete "${widget.tool.displayName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeleteTool(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTool(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _toolService.deleteTool(widget.tool.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted "${widget.tool.displayName}"'),
            backgroundColor: MallonColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tool: ${e.toString()}'),
            backgroundColor: MallonColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWorkerName() async {
    if (widget.tool.currentHolder != null &&
        widget.tool.status == 'checked_out') {
      try {
        // Get staff information from the current holder reference
        final staffUid = widget.tool.currentHolder!.id;
        final staff = await _staffService.getStaffById(staffUid);
        if (staff != null) {
          if (mounted) {
            setState(() {
              _workerName = staff.fullName;
            });
          }
        }
      } catch (e) {
        // Silently handle error - will show generic "Checked out" message
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Main tool info row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: MallonColors.lightGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.build,
                      color: MallonColors.mediumGrey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tool.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (widget.tool.name.isNotEmpty &&
                            widget.tool.name != widget.tool.displayName)
                          Text(widget.tool.name),
                        Text(
                          'ID: ${widget.tool.uniqueId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MallonColors.secondaryText,
                          ),
                        ),
                        if (widget.tool.num.isNotEmpty)
                          Text(
                            'Tool #: ${widget.tool.num}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MallonColors.secondaryText,
                            ),
                          ),
                        if (widget.tool.currentHolder != null &&
                            widget.tool.status == 'checked_out')
                          Text(
                            _workerName != null
                                ? 'Assigned to: $_workerName'
                                : 'Checked out',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MallonColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      MallonWidgets.statusChip(
                        status: widget.tool.status,
                        isSmall: true,
                      ),
                      // Admin buttons (only visible to admins)
                      if (_isAdmin) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleEditTool(context),
                              icon: const Icon(Icons.edit, size: 24),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            IconButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleDeleteTool(context),
                              icon: const Icon(Icons.delete, size: 24),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              iconSize: 16,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

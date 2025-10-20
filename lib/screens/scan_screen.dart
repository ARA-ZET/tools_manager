import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../models/staff.dart';
import '../models/tool.dart';
import '../providers/tools_provider.dart';
import '../providers/scan_provider.dart';
import '../services/staff_service.dart';
import '../widgets/scan/single_tool_scan_widget.dart';
import '../widgets/scan/batch_tool_scan_widget.dart';
import 'auth_debug_screen.dart';

/// Scanner screen for QR code scanning - Refactored for better maintainability
/// Separated single scan and batch scan logic into dedicated widgets
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final StaffService _staffService = StaffService();

  // State variables
  String _searchQuery = '';
  String _selectedFilter = 'all';
  Staff? _currentStaff;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add tab controller listener to handle camera lifecycle
    _tabController.addListener(_handleTabChange);

    // Initialize scan provider and load staff
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanProvider>().initialize();
    });
    _loadCurrentStaff();
  }

  void _handleTabChange() {
    // When switching tabs, just log for debugging
    if (_tabController.index == 0) {
      debugPrint('📷 Switched to Scan tab');
    } else {
      debugPrint('📋 Switched to Browse tab');
    }
  }

  /// Load current staff member from Firebase Auth
  Future<void> _loadCurrentStaff() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staff = await _staffService.getStaffByAuthUid(user.uid);
        if (mounted) {
          setState(() {
            _currentStaff = staff;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current staff: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Tools'),
        actions: [
          // User status indicator
          _buildUserStatusIndicator(),
          IconButton(
            onPressed: () {
              context.read<ScanProvider>().refreshStaff();
              _loadCurrentStaff();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh login status',
          ),
          _buildMenuButton(),
          // Batch mode toggle
          Consumer<ScanProvider>(
            builder: (context, scanProvider, child) {
              return Switch(
                value: scanProvider.isBatchMode,
                onChanged: (value) {
                  scanProvider.setScanMode(
                    value ? ScanMode.batch : ScanMode.single,
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
          Text('Batch', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
            Tab(icon: Icon(Icons.list), text: 'Browse'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildScannerTab(), _buildToolsListTab()],
      ),
    );
  }

  Widget _buildUserStatusIndicator() {
    if (_currentStaff != null) {
      return Tooltip(
        message: '${_currentStaff!.fullName} (${_currentStaff!.role.name})',
        child: CircleAvatar(
          radius: 16,
          backgroundColor: MallonColors.primaryGreen,
          child: Text(
            _currentStaff!.fullName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      return Tooltip(
        message: 'Not logged in',
        child: CircleAvatar(
          radius: 16,
          backgroundColor: MallonColors.error,
          child: const Icon(Icons.person_off, color: Colors.white, size: 16),
        ),
      );
    }
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'debug') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthDebugScreen()),
          );
        } else if (value == 'reset_scan') {
          context.read<ScanProvider>().resetDebounce();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scanner reset - ready for new scans'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'debug',
          child: Row(
            children: [
              Icon(Icons.bug_report),
              SizedBox(width: 8),
              Text('Debug Auth'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'reset_scan',
          child: Row(
            children: [
              Icon(Icons.refresh),
              SizedBox(width: 8),
              Text('Reset Scanner'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerTab() {
    return Consumer<ScanProvider>(
      builder: (context, scanProvider, child) {
        // Use dedicated widgets based on scan mode
        if (scanProvider.isBatchMode) {
          return BatchToolScanWidget(currentStaff: _currentStaff);
        } else {
          return SingleToolScanWidget(currentStaff: _currentStaff);
        }
      },
    );
  }

  Widget _buildToolsListTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tools by name, brand, model...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter Chips and Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Available', 'available'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Checked Out', 'checked_out'),
                    ],
                  ),
                ),
              ),
              Consumer<ScanProvider>(
                builder: (context, scanProvider, child) {
                  if (!scanProvider.isBatchMode) return const SizedBox.shrink();

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scanProvider.batchCount > 0
                          ? MallonColors.primaryGreen.withOpacity(0.2)
                          : MallonColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MallonColors.primaryGreen,
                        width: scanProvider.batchCount > 0 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: MallonColors.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scanProvider.batchCount}',
                          style: TextStyle(
                            color: MallonColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Tools List
        Expanded(
          child: Consumer<ToolsProvider>(
            builder: (context, toolsProvider, child) {
              if (toolsProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (toolsProvider.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: MallonColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading tools',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('${toolsProvider.errorMessage}'),
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
              final tools = toolsProvider.getFilteredTools(
                status: _selectedFilter == 'all' ? null : _selectedFilter,
                searchQuery: _searchQuery.trim(),
              );

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
                        _searchQuery.isNotEmpty
                            ? 'Try adjusting your search'
                            : 'Add some tools to get started',
                        style: TextStyle(color: MallonColors.secondaryText),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];
                  return _buildToolTile(tool);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = value == _selectedFilter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: MallonColors.lightGreen,
      checkmarkColor: MallonColors.primaryGreen,
    );
  }

  Widget _buildToolTile(Tool tool) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tool.isAvailable
              ? MallonColors.available
              : MallonColors.checkedOut,
          child: const Icon(Icons.build, color: Colors.white, size: 20),
        ),
        title: Text(
          tool.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${tool.uniqueId}'),
            if (tool.num.isNotEmpty) Text('Tool #: ${tool.num}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tool.isAvailable
                ? MallonColors.available.withOpacity(0.1)
                : MallonColors.checkedOut.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tool.isAvailable
                  ? MallonColors.available
                  : MallonColors.checkedOut,
            ),
          ),
          child: Text(
            tool.isAvailable ? 'AVAILABLE' : 'CHECKED OUT',
            style: TextStyle(
              color: tool.isAvailable
                  ? MallonColors.available
                  : MallonColors.checkedOut,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          // Tool selection is handled by scan widgets in scan tab
          // In browse tab, we can show a simple info snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switch to Scan tab to interact with ${tool.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';
import '../providers/auth_provider.dart';
import '../core/theme/mallon_theme.dart';

/// Add/Edit Tool Screen with QR Code Generation
class AddToolScreen extends StatefulWidget {
  final Tool? tool; // For editing existing tool

  const AddToolScreen({super.key, this.tool});

  @override
  State<AddToolScreen> createState() => _AddToolScreenState();
}

class _AddToolScreenState extends State<AddToolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toolService = ToolService();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _numController;
  late TextEditingController _notesController;
  late TextEditingController _categoryController;
  late TextEditingController _conditionController;

  bool _isLoading = false;
  bool _showQRCode = false;
  String? _generatedUniqueId;
  String? _generatedQrPayload;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final tool = widget.tool;
    _nameController = TextEditingController(text: tool?.name ?? '');
    _brandController = TextEditingController(text: tool?.brand ?? '');
    _modelController = TextEditingController(text: tool?.model ?? '');
    _numController = TextEditingController(text: tool?.num ?? '');
    _notesController = TextEditingController(
      text: tool?.meta['notes']?.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: tool?.meta['category']?.toString() ?? 'hand_tool',
    );
    _conditionController = TextEditingController(
      text: tool?.meta['condition']?.toString() ?? 'excellent',
    );

    if (tool != null) {
      _generatedUniqueId = tool.uniqueId;
      _generatedQrPayload = tool.qrPayload;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _numController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showQRCode || widget.tool == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showQRCode && widget.tool != null) {
          // If we're showing QR code after editing, return with success indicator
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tool != null ? 'Edit Tool' : 'Add New Tool'),
          actions: [
            if (_generatedUniqueId != null)
              IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () => setState(() => _showQRCode = !_showQRCode),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _showQRCode
            ? _buildQRCodeView()
            : _buildForm(),
        floatingActionButton: _showQRCode
            ? null
            : FloatingActionButton.extended(
                onPressed: _saveTool,
                icon: const Icon(Icons.save),
                label: Text(widget.tool != null ? 'Update Tool' : 'Save Tool'),
              ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _nameController,
              label: 'Tool Name',
              hint: 'e.g., Power Drill, Hammer, etc.',
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Tool name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _brandController,
                    label: 'Brand',
                    hint: 'e.g., DeWalt, Milwaukee',
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Brand is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _modelController,
                    label: 'Model',
                    hint: 'e.g., DCD771C2',
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Model is required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _numController,
              label: 'Tool Number',
              hint: 'Internal tool number/code',
            ),
            const SizedBox(height: 24),

            // Category and Condition Section
            _buildSectionHeader('Category & Condition'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildCategoryDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildConditionDropdown()),
              ],
            ),
            const SizedBox(height: 24),

            // Notes Section
            _buildSectionHeader('Additional Information'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Any additional information about this tool',
              maxLines: 3,
            ),

            // QR Code Preview
            if (_generatedUniqueId != null) ...[
              const SizedBox(height: 24),
              _buildSectionHeader('QR Code Preview'),
              const SizedBox(height: 16),
              _buildQRCodePreview(),
            ],

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _generatedUniqueId!,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tool ID: $_generatedUniqueId',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_brandController.text} ${_modelController.text}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MallonColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _nameController.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showQRCode = false),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Tool'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: widget.tool != null
                    ? ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MallonColors.primaryGreen,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement print QR code functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Print functionality coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print QR Code'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: MallonColors.primaryGreen,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _categoryController.text.isNotEmpty
          ? _categoryController.text
          : 'hand_tool',
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'hand_tool', child: Text('Hand Tool')),
        DropdownMenuItem(value: 'power_tool', child: Text('Power Tool')),
        DropdownMenuItem(value: 'measurement', child: Text('Measurement')),
        DropdownMenuItem(value: 'safety', child: Text('Safety Equipment')),
        DropdownMenuItem(value: 'cutting', child: Text('Cutting Tool')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
      ],
      onChanged: (value) => setState(() => _categoryController.text = value!),
    );
  }

  Widget _buildConditionDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _conditionController.text.isNotEmpty
          ? _conditionController.text
          : 'excellent',
      decoration: const InputDecoration(
        labelText: 'Condition',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'excellent', child: Text('Excellent')),
        DropdownMenuItem(value: 'good', child: Text('Good')),
        DropdownMenuItem(value: 'fair', child: Text('Fair')),
        DropdownMenuItem(value: 'needs_repair', child: Text('Needs Repair')),
        DropdownMenuItem(
          value: 'out_of_service',
          child: Text('Out of Service'),
        ),
      ],
      onChanged: (value) => setState(() => _conditionController.text = value!),
    );
  }

  Widget _buildQRCodePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: MallonColors.lightGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          QrImageView(
            data: _generatedUniqueId!,
            version: QrVersions.auto,
            size: 120.0,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            'ID: $_generatedUniqueId',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _saveTool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique ID if not editing
      if (widget.tool == null && _generatedUniqueId == null) {
        _generatedUniqueId = _toolService.generateUniqueId();
        _generatedQrPayload = Tool.generateQrPayload(_generatedUniqueId!);
      }

      // Prepare metadata
      final meta = <String, dynamic>{
        'notes': _notesController.text.trim(),
        'category': _categoryController.text,
        'condition': _conditionController.text,
        'createdBy': currentUser.uid,
        'lastModifiedBy': currentUser.uid,
      };

      final tool = Tool(
        id: widget.tool?.id ?? '',
        uniqueId: _generatedUniqueId ?? widget.tool!.uniqueId,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        num: _numController.text.trim(),
        images: widget.tool?.images ?? [],
        qrPayload:
            _generatedQrPayload ??
            widget.tool?.qrPayload ??
            Tool.generateQrPayload(_generatedUniqueId!),
        status: widget.tool?.status ?? 'available',
        currentHolder: widget.tool?.currentHolder,
        meta: meta,
        createdAt: widget.tool?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.tool != null) {
        // Update existing tool
        await _toolService.updateTool(widget.tool!.id, tool.toFirestore());
      } else {
        // Create new tool
        await _toolService.createTool(tool);
      }

      setState(() => _showQRCode = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.tool != null
                ? 'Tool updated successfully!'
                : 'Tool created successfully!',
          ),
          backgroundColor: MallonColors.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving tool: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

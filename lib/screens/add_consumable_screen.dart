import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/measurement_unit.dart';
import '../providers/consumables_provider.dart';
import '../core/theme/mallon_theme.dart';

/// Screen for adding a new consumable
class AddConsumableScreen extends StatefulWidget {
  const AddConsumableScreen({super.key});

  @override
  State<AddConsumableScreen> createState() => _AddConsumableScreenState();
}

class _AddConsumableScreenState extends State<AddConsumableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialQuantityController = TextEditingController(text: '0');
  final _minQuantityController = TextEditingController(text: '10');
  final _maxQuantityController = TextEditingController(text: '100');
  final _notesController = TextEditingController();

  String _selectedCategory = 'Wood Glue';
  MeasurementUnit _selectedUnit = MeasurementUnit.liters;
  bool _isSubmitting = false;

  // Workshop consumable categories
  final List<String> _categories = [
    'Wood Glue',
    'Contact Cement',
    'Adhesives',
    'Sandpaper',
    'Abrasives',
    'Tape',
    'Stains & Finishes',
    'Oils & Spirits',
    'Hardware',
    'Fasteners',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Set default unit based on category
    _updateUnitForCategory();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialQuantityController.dispose();
    _minQuantityController.dispose();
    _maxQuantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateUnitForCategory() {
    setState(() {
      _selectedUnit = MeasurementUnitHelper.getDefaultUnitForCategory(
        _selectedCategory,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Consumable')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildQuantitySection(),
              const SizedBox(height: 24),
              _buildAdditionalInfoSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g., Titebond II Wood Glue',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                    _updateUnitForCategory();
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantity & Measurement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MeasurementUnit>(
              initialValue: _selectedUnit,
              decoration: const InputDecoration(
                labelText: 'Measurement Unit *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
              items: MeasurementUnit.values.map((unit) {
                return DropdownMenuItem(
                  value: unit,
                  child: Row(
                    children: [
                      Icon(unit.icon, size: 20),
                      const SizedBox(width: 8),
                      Text('${unit.displayName} (${unit.abbreviation})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedUnit = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _initialQuantityController,
              decoration: InputDecoration(
                labelText: 'Initial Quantity *',
                hintText: '0',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory),
                suffixText: _selectedUnit.abbreviation,
              ),
              keyboardType: _selectedUnit.allowsDecimals
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Initial quantity is required';
                }
                final quantity = double.tryParse(value);
                if (quantity == null || quantity < 0) {
                  return 'Enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minQuantityController,
                    decoration: InputDecoration(
                      labelText: 'Min Quantity *',
                      hintText: '10',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.warning_amber),
                      suffixText: _selectedUnit.abbreviation,
                    ),
                    keyboardType: _selectedUnit.allowsDecimals
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final quantity = double.tryParse(value);
                      if (quantity == null || quantity < 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxQuantityController,
                    decoration: InputDecoration(
                      labelText: 'Max Quantity *',
                      hintText: '100',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.check_circle),
                      suffixText: _selectedUnit.abbreviation,
                    ),
                    keyboardType: _selectedUnit.allowsDecimals
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final quantity = double.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Invalid';
                      }
                      final minQty = double.tryParse(
                        _minQuantityController.text,
                      );
                      if (minQty != null && quantity <= minQty) {
                        return 'Must be > min';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'ll be alerted when stock falls below minimum quantity',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes or description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitForm,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_circle),
        label: Text(_isSubmitting ? 'Creating...' : 'Create Consumable'),
        style: ElevatedButton.styleFrom(
          backgroundColor: MallonColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final consumablesProvider = context.read<ConsumablesProvider>();

    final id = await consumablesProvider.addConsumable(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit.name,
      initialQuantity: double.parse(_initialQuantityController.text),
      minQuantity: double.parse(_minQuantityController.text),
      maxQuantity: double.parse(_maxQuantityController.text),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (id != null && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameController.text} created successfully'),
          backgroundColor: MallonColors.primaryGreen,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(consumablesProvider.errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

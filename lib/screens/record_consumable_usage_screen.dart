import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/theme/mallon_theme.dart';
import '../models/consumable.dart';
import '../models/staff.dart';
import '../models/measurement_unit.dart';
import '../providers/consumables_provider.dart';
import '../services/staff_service.dart';
import '../services/consumable_transaction_service.dart';

/// Minimal screen to record consumable usage
/// Similar to tool checkout but simplified for consumables
class RecordConsumableUsageScreen extends StatefulWidget {
  final Consumable consumable;

  const RecordConsumableUsageScreen({super.key, required this.consumable});

  @override
  State<RecordConsumableUsageScreen> createState() =>
      _RecordConsumableUsageScreenState();
}

class _RecordConsumableUsageScreenState
    extends State<RecordConsumableUsageScreen> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final StaffService _staffService = StaffService();
  final ConsumableTransactionService _transactionService =
      ConsumableTransactionService();

  Staff? _currentStaff;
  Staff? _selectedRecipient;
  List<Staff> _allStaff = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentStaff();
    _loadAllStaff();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staff = await _staffService.getStaffByAuthUid(user.uid);
        if (mounted) {
          setState(() {
            _currentStaff = staff;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllStaff() async {
    try {
      // Get first event from the stream
      final staff = await _staffService.getActiveStaffStream().first;
      if (mounted) {
        setState(() {
          _allStaff = staff;
        });
      }
    } catch (e) {
      debugPrint('Failed to load staff: $e');
    }
  }

  Future<void> _submitUsage() async {
    if (_quantityController.text.trim().isEmpty) {
      _showError('Please enter quantity used');
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showError('Please enter a valid quantity');
      return;
    }

    if (quantity > widget.consumable.currentQuantity) {
      _showError(
        'Quantity used (${quantity}) cannot exceed available stock (${widget.consumable.currentQuantity})',
      );
      return;
    }

    if (_currentStaff == null) {
      _showError('User information not available');
      return;
    }

    if (_selectedRecipient == null) {
      _showError('Please select who received the consumable');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final consumablesProvider = context.read<ConsumablesProvider>();

      // Record transaction - usedBy is who gave it, assignedTo in notes
      await _transactionService.recordUsage(
        consumableId: widget.consumable.id,
        quantity: quantity,
        usedBy: _currentStaff!.uid,
        assignedTo: _selectedRecipient!.uid,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Update quantity using service directly
      final newQuantity = widget.consumable.currentQuantity - quantity;
      await consumablesProvider.updateConsumable(widget.consumable.id, {
        'currentQuantity': newQuantity,
      });

      if (mounted) {
        // Show success and return
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded ${quantity} ${widget.consumable.unit.abbreviation} usage',
            ),
            backgroundColor: MallonColors.successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to record usage: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: MallonColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Usage'),
        backgroundColor: MallonColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: MallonColors.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCurrentStaff,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MallonColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Consumable info card
          _buildConsumableCard(),
          const SizedBox(height: 24),

          // User info
          _buildUserInfo(),
          const SizedBox(height: 24),

          // Recipient selector
          _buildRecipientSelector(),
          const SizedBox(height: 24),

          // Quantity input
          _buildQuantityInput(),
          const SizedBox(height: 24),

          // Notes input
          _buildNotesInput(),
          const SizedBox(height: 32),

          // Submit button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildConsumableCard() {
    final stockLevel = widget.consumable.stockLevel;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: MallonColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.consumable.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.consumable.category,
              style: TextStyle(color: MallonColors.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Stock level indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(stockLevel.colorValue).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stockLevel.displayName,
                    style: TextStyle(
                      color: Color(stockLevel.colorValue),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${widget.consumable.currentQuantity} ${widget.consumable.unit.abbreviation}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    if (_currentStaff == null) return const SizedBox.shrink();

    return Card(
      color: MallonColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.person, color: MallonColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Used by',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentStaff!.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentStaff!.jobCode,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Given To *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: DropdownButtonFormField<Staff>(
              value: _selectedRecipient,
              decoration: const InputDecoration(
                labelText: 'Select recipient',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add),
              ),
              items: _allStaff.map((staff) {
                return DropdownMenuItem<Staff>(
                  value: staff,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: MallonColors.primaryGreen.withOpacity(
                          0.2,
                        ),
                        child: Text(
                          staff.fullName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: MallonColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              staff.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              staff.jobCode,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Staff? newValue) {
                setState(() {
                  _selectedRecipient = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity Used *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            labelText: 'Enter quantity',
            hintText: '0.0',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.remove_circle_outline),
            suffixText: widget.consumable.unit.abbreviation,
          ),
          keyboardType: widget.consumable.unit.allowsDecimals
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Available: ${widget.consumable.currentQuantity} ${widget.consumable.unit.abbreviation}',
          style: TextStyle(fontSize: 12, color: MallonColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Add notes',
            hintText: 'e.g., Project name, task description',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitUsage,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(_isSubmitting ? 'Recording...' : 'Record Usage'),
        style: ElevatedButton.styleFrom(
          backgroundColor: MallonColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

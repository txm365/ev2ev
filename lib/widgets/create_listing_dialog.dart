// lib/widgets/create_listing_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateListingDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const CreateListingDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends State<CreateListingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _availableEnergyController = TextEditingController();
  final _minEnergyController = TextEditingController();
  final _maxEnergyController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedVehicleType = 'Electric Car';
  String _selectedConnectorType = 'Type 2';
  DateTime? _availabilityEnd;
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = [
    'Electric Car',
    'Electric Van',
    'Electric Truck',
    'Electric Bus',
    'Electric Motorcycle',
    'Hybrid Vehicle',
  ];

  final List<String> _connectorTypes = [
    'Type 2',
    'CCS',
    'CHAdeMO',
    'Tesla Supercharger',
    'Type 1',
    'CEE',
  ];

  @override
  void dispose() {
    _priceController.dispose();
    _availableEnergyController.dispose();
    _minEnergyController.dispose();
    _maxEnergyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Availability picker — guarded against use-after-dispose ──────────────
  Future<void> _selectAvailabilityEnd() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _availabilityEnd ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    // Guard: widget may have been disposed while the date picker was open
    if (!mounted) return;

    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _availabilityEnd ?? now.add(const Duration(hours: 1))),
      );

      // Guard: widget may have been disposed while the time picker was open
      if (!mounted) return;

      if (selectedTime != null) {
        setState(() {
          _availabilityEnd = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'pricePerKwh': double.parse(_priceController.text),
        'availableEnergy': double.parse(_availableEnergyController.text),
        'minEnergySale': double.parse(_minEnergyController.text),
        'maxEnergySale': double.parse(_maxEnergyController.text),
        'vehicleType': _selectedVehicleType,
        'connectorType': _selectedConnectorType,
        'availabilityEnd': _availabilityEnd,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      };

      widget.onSubmit(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create Energy Listing',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Form ────────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price
                      _buildSectionHeader('Pricing'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _priceController,
                        label: 'Price per kWh',
                        prefix: 'R',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(v) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Energy amounts
                      _buildSectionHeader('Energy Amounts'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _availableEnergyController,
                        label: 'Available Energy',
                        suffix: 'kWh',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter available energy';
                          }
                          if (double.tryParse(v) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _minEnergyController,
                              label: 'Min Sale',
                              suffix: 'kWh',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _maxEnergyController,
                              label: 'Max Sale',
                              suffix: 'kWh',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Vehicle & connector
                      _buildSectionHeader('Vehicle Details'),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Vehicle Type',
                        value: _selectedVehicleType,
                        items: _vehicleTypes,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedVehicleType = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Connector Type',
                        value: _selectedConnectorType,
                        items: _connectorTypes,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedConnectorType = v);
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Availability
                      _buildSectionHeader('Availability'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Available until:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _availabilityEnd != null
                                        ? '${_availabilityEnd!.day}/${_availabilityEnd!.month}/${_availabilityEnd!.year}'
                                          ' at ${_availabilityEnd!.hour.toString().padLeft(2, '0')}:${_availabilityEnd!.minute.toString().padLeft(2, '0')}'
                                        : 'No end time set (available indefinitely)',
                                    style: TextStyle(
                                      color: _availabilityEnd != null
                                          ? Colors.black87
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _selectAvailabilityEnd,
                                  child: Text(_availabilityEnd != null
                                      ? 'Change'
                                      : 'Set End Time'),
                                ),
                                if (_availabilityEnd != null)
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _availabilityEnd = null);
                                    },
                                    icon: const Icon(Icons.clear, size: 20),
                                    tooltip: 'Remove end time',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description
                      _buildSectionHeader('Description (Optional)'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText:
                              'Add details about your energy offering, location specifics, or any special requirements...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Action buttons ───────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Text('Create Listing'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: keyboardType ==
              const TextInputType.numberWithOptions(decimal: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
}
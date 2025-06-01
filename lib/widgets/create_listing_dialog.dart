// lib/widgets/create_listing_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateListingDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const CreateListingDialog({super.key, required this.onSubmit});

  @override
  CreateListingDialogState createState() => CreateListingDialogState();
}

class CreateListingDialogState extends State<CreateListingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _availableEnergyController = TextEditingController();
  final _minEnergyController = TextEditingController();
  final _maxEnergyController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedVehicleType = 'car';
  String _selectedConnectorType = 'CCS';
  DateTime? _availabilityEnd;
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = ['car', 'bike', 'scooter'];
  final List<String> _connectorTypes = ['CCS', 'CHAdeMO', 'Type2'];

  @override
  void dispose() {
    _priceController.dispose();
    _availableEnergyController.dispose();
    _minEnergyController.dispose();
    _maxEnergyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.sell, size: 32, color: Colors.green),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create Energy Listing',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Price per kWh
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price per kWh (R)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    helperText: 'Set your price per kilowatt-hour',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    if (price > 10) {
                      return 'Price seems too high (max R10/kWh)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Available Energy
                TextFormField(
                  controller: _availableEnergyController,
                  decoration: const InputDecoration(
                    labelText: 'Available Energy (kWh)',
                    prefixIcon: Icon(Icons.battery_full),
                    border: OutlineInputBorder(),
                    helperText: 'How much energy you can share',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter available energy';
                    }
                    final energy = double.tryParse(value);
                    if (energy == null || energy <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (energy > 100) {
                      return 'Amount seems too high (max 100 kWh)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Min/Max Energy Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minEnergyController,
                        decoration: const InputDecoration(
                          labelText: 'Min Sale (kWh)',
                          prefixIcon: Icon(Icons.minimize),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final min = double.tryParse(value);
                          if (min == null || min <= 0) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxEnergyController,
                        decoration: const InputDecoration(
                          labelText: 'Max Sale (kWh)',
                          prefixIcon: Icon(Icons.add),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final max = double.tryParse(value);
                          final min = double.tryParse(_minEnergyController.text);
                          if (max == null || max <= 0) {
                            return 'Invalid amount';
                          }
                          if (min != null && max < min) {
                            return 'Must be >= min';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle Type
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  items: _vehicleTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicleType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Connector Type
                DropdownButtonFormField<String>(
                  value: _selectedConnectorType,
                  decoration: const InputDecoration(
                    labelText: 'Connector Type',
                    prefixIcon: Icon(Icons.electrical_services),
                    border: OutlineInputBorder(),
                  ),
                  items: _connectorTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedConnectorType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Availability End (Optional)
                InkWell(
                  onTap: _selectAvailabilityEnd,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Available Until (Optional)',
                      prefixIcon: Icon(Icons.schedule),
                      border: OutlineInputBorder(),
                      helperText: 'Leave empty for no time limit',
                    ),
                    child: Text(
                      _availabilityEnd != null
                          ? '${_availabilityEnd!.day}/${_availabilityEnd!.month}/${_availabilityEnd!.year} '
                            '${_availabilityEnd!.hour.toString().padLeft(2, '0')}:'
                            '${_availabilityEnd!.minute.toString().padLeft(2, '0')}'
                          : 'Tap to select date and time',
                      style: TextStyle(
                        color: _availabilityEnd != null ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    helperText: 'Additional details for buyers',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitListing,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create Listing'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectAvailabilityEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _availabilityEnd = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'pricePerKwh': double.parse(_priceController.text),
        'availableEnergy': double.parse(_availableEnergyController.text),
        'minEnergySale': double.parse(_minEnergyController.text),
        'maxEnergySale': double.parse(_maxEnergyController.text),
        'vehicleType': _selectedVehicleType,
        'connectorType': _selectedConnectorType,
        'availabilityEnd': _availabilityEnd,
        'description': _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
      };

      widget.onSubmit(data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
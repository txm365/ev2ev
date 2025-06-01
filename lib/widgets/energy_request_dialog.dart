// lib/widgets/energy_request_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/energy_listing.dart';

class EnergyRequestDialog extends StatefulWidget {
  final EnergyListing listing;
  final Function(Map<String, dynamic>) onSubmit;

  const EnergyRequestDialog({
    super.key,
    required this.listing,
    required this.onSubmit,
  });

  @override
  EnergyRequestDialogState createState() => EnergyRequestDialogState();
}

class EnergyRequestDialogState extends State<EnergyRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _requestedEnergyController = TextEditingController();
  final _offeredPriceController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _useListingPrice = true;
  double get _estimatedCost {
    final energy = double.tryParse(_requestedEnergyController.text) ?? 0;
    final price = _useListingPrice 
        ? widget.listing.pricePerKwh 
        : (double.tryParse(_offeredPriceController.text) ?? widget.listing.pricePerKwh);
    return energy * price;
  }

  @override
  void initState() {
    super.initState();
    _offeredPriceController.text = widget.listing.pricePerKwh.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _requestedEnergyController.dispose();
    _offeredPriceController.dispose();
    _messageController.dispose();
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
                    const Icon(Icons.shopping_cart, size: 32, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Request Energy',
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
                const SizedBox(height: 16),

                // Seller Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              widget.listing.sellerName?.substring(0, 1).toUpperCase() ?? 'S',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.listing.sellerName ?? 'Seller',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${widget.listing.vehicleType.toUpperCase()} • ${widget.listing.connectorType}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          if (widget.listing.distance != null)
                            Text(
                              '${widget.listing.distance!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip('R${widget.listing.pricePerKwh.toStringAsFixed(2)}/kWh'),
                          const SizedBox(width: 8),
                          _buildInfoChip('${widget.listing.availableEnergy.toStringAsFixed(1)} kWh available'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Requested Energy
                TextFormField(
                  controller: _requestedEnergyController,
                  decoration: InputDecoration(
                    labelText: 'Energy Needed (kWh)',
                    prefixIcon: const Icon(Icons.battery_charging_full),
                    border: const OutlineInputBorder(),
                    helperText: 'Min: ${widget.listing.minEnergySale} kWh, '
                               'Max: ${widget.listing.maxEnergySale} kWh',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  onChanged: (value) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter energy amount';
                    }
                    final energy = double.tryParse(value);
                    if (energy == null || energy <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (energy < widget.listing.minEnergySale) {
                      return 'Minimum ${widget.listing.minEnergySale} kWh';
                    }
                    if (energy > widget.listing.maxEnergySale) {
                      return 'Maximum ${widget.listing.maxEnergySale} kWh';
                    }
                    if (energy > widget.listing.availableEnergy) {
                      return 'Only ${widget.listing.availableEnergy} kWh available';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Price Options
                Text(
                  'Price per kWh',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                
                RadioListTile<bool>(
                  title: Text('Accept seller\'s price (R${widget.listing.pricePerKwh.toStringAsFixed(2)}/kWh)'),
                  value: true,
                  groupValue: _useListingPrice,
                  onChanged: (value) {
                    setState(() {
                      _useListingPrice = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                
                RadioListTile<bool>(
                  title: const Text('Make a counter offer'),
                  value: false,
                  groupValue: _useListingPrice,
                  onChanged: (value) {
                    setState(() {
                      _useListingPrice = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                if (!_useListingPrice) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _offeredPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Your Offered Price (R/kWh)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (value) => setState(() {}),
                    validator: (value) {
                      if (!_useListingPrice) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your offer';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Estimated Cost
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Total Cost:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R${_estimatedCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Message
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message (Optional)',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                    helperText: 'Add a message to the seller',
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
                        onPressed: _isSubmitting ? null : _submitRequest,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send Request'),
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

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'requestedEnergy': double.parse(_requestedEnergyController.text),
        'offeredPricePerKwh': _useListingPrice 
            ? null 
            : double.parse(_offeredPriceController.text),
        'message': _messageController.text.isNotEmpty 
            ? _messageController.text 
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
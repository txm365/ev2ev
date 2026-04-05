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

  static const _vehicleTypes = [
    'Electric Car', 'Electric Van', 'Electric Truck',
    'Electric Bus', 'Electric Motorcycle', 'Hybrid Vehicle',
  ];

  static const _connectorTypes = [
    'Type 2', 'CCS', 'CHAdeMO',
    'Tesla Supercharger', 'Type 1', 'CEE',
  ];

  static const _green = Color(0xFF2E7D32);

  @override
  void dispose() {
    _priceController.dispose();
    _availableEnergyController.dispose();
    _minEnergyController.dispose();
    _maxEnergyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Availability picker ───────────────────────────────────────────────────
  Future<void> _selectAvailabilityEnd() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _availabilityEnd ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _availabilityEnd ?? now.add(const Duration(hours: 1))),
      );
      if (!mounted) return;
      if (selectedTime != null) {
        setState(() {
          _availabilityEnd = DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day,
            selectedTime.hour, selectedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      widget.onSubmit({
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Green gradient header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_green, Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Energy Listing',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('Set your price and availability',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xCCFFFFFF))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // ── Scrollable form ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Pricing ─────────────────────────────────────────
                    _sectionLabel(cs, Icons.bolt, Colors.amber[700]!, 'Pricing'),
                    const SizedBox(height: 10),
                    _field(
                      controller: _priceController,
                      label: 'Price per kWh',
                      prefix: 'R',
                      suffix: '/kWh',
                      cs: cs,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a price';
                        if (double.tryParse(v) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Energy amounts ──────────────────────────────────
                    _sectionLabel(cs, Icons.battery_charging_full, Colors.green, 'Energy Amounts'),
                    const SizedBox(height: 10),
                    _field(
                      controller: _availableEnergyController,
                      label: 'Total Available Energy',
                      suffix: 'kWh',
                      cs: cs,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter available energy';
                        if (double.tryParse(v) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _minEnergyController,
                            label: 'Min Sale',
                            suffix: 'kWh',
                            cs: cs,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            controller: _maxEnergyController,
                            label: 'Max Sale',
                            suffix: 'kWh',
                            cs: cs,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Vehicle ─────────────────────────────────────────
                    _sectionLabel(cs, Icons.electric_car, cs.primary, 'Vehicle Details'),
                    const SizedBox(height: 10),
                    _dropdown(
                      cs: cs,
                      label: 'Vehicle Type',
                      value: _selectedVehicleType,
                      items: _vehicleTypes,
                      onChanged: (v) =>
                          setState(() => _selectedVehicleType = v!),
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      cs: cs,
                      label: 'Connector Type',
                      value: _selectedConnectorType,
                      items: _connectorTypes,
                      onChanged: (v) =>
                          setState(() => _selectedConnectorType = v!),
                    ),

                    const SizedBox(height: 20),

                    // ── Availability ────────────────────────────────────
                    _sectionLabel(cs, Icons.schedule, Colors.teal, 'Availability'),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectAvailabilityEnd,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 18,
                                color: _availabilityEnd != null
                                    ? _green
                                    : cs.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _availabilityEnd != null
                                    ? '${_availabilityEnd!.day}/${_availabilityEnd!.month}/${_availabilityEnd!.year}  '
                                      '${_availabilityEnd!.hour.toString().padLeft(2, '0')}:${_availabilityEnd!.minute.toString().padLeft(2, '0')}'
                                    : 'No end time — always available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _availabilityEnd != null
                                      ? cs.onSurface
                                      : cs.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            if (_availabilityEnd != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _availabilityEnd = null),
                                child: Icon(Icons.close,
                                    size: 18,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4)),
                              )
                            else
                              const Text('Set',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _green,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Description ─────────────────────────────────────
                    _sectionLabel(
                        cs, Icons.chat_bubble_outline,
                        cs.onSurface.withValues(alpha: 0.5),
                        'Description (Optional)'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText:
                            'Tell buyers about your setup, location, or any special info…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: cs.outline.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _green, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Action buttons ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Create Listing',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(
      ColorScheme cs, IconData icon, Color iconColor, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required ColorScheme cs,
    String? prefix,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 2),
        ),
      ),
    );
  }

  Widget _dropdown({
    required ColorScheme cs,
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 2),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      items: items
          .map((item) =>
              DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
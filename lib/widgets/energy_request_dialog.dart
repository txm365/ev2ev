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
        : (double.tryParse(_offeredPriceController.text) ??
            widget.listing.pricePerKwh);
    return energy * price;
  }

  // ── Vehicle colour helpers (mirrors listing_card) ─────────────────────────
  Color _vehicleColor() {
    final v = widget.listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return const Color(0xFF7B1FA2);
    if (v.contains('truck')) return const Color(0xFFE65100);
    if (v.contains('van')) return const Color(0xFF0277BD);
    if (v.contains('motorcycle') || v.contains('scooter')) return const Color(0xFF00897B);
    if (v.contains('station') || v.contains('charging')) return const Color(0xFFAD1457);
    return const Color(0xFF2E7D32);
  }

  IconData _vehicleIcon() {
    final v = widget.listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return Icons.directions_bus;
    if (v.contains('truck')) return Icons.local_shipping;
    if (v.contains('van')) return Icons.airport_shuttle;
    if (v.contains('motorcycle') || v.contains('scooter')) return Icons.electric_moped;
    if (v.contains('station') || v.contains('charging')) return Icons.ev_station;
    return Icons.electric_car;
  }

  @override
  void initState() {
    super.initState();
    _offeredPriceController.text =
        widget.listing.pricePerKwh.toStringAsFixed(2);
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
    final color = _vehicleColor();
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coloured header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Icon(_vehicleIcon(), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Request Energy',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        widget.listing.sellerName ?? 'Energy Provider',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
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

          // ── Scrollable body ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Listing summary strip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _summaryTile(context, Icons.bolt,
                                Colors.amber[700]!,
                                'R${widget.listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                                'Price'),
                            Container(
                              width: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: color.withValues(alpha: 0.2),
                            ),
                            _summaryTile(context, Icons.battery_charging_full,
                                Colors.green,
                                '${widget.listing.availableEnergy.toStringAsFixed(1)} kWh',
                                'Available'),
                            if (widget.listing.distance != null) ...[
                              Container(
                                width: 1,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4),
                                color: color.withValues(alpha: 0.2),
                              ),
                              _summaryTile(context, Icons.near_me, cs.primary,
                                  '${widget.listing.distance!.toStringAsFixed(1)} km',
                                  'Distance'),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Energy amount field
                    Text('How much energy do you need?',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _requestedEnergyController,
                      decoration: InputDecoration(
                        labelText: 'Energy Amount (kWh)',
                        prefixIcon: const Icon(Icons.battery_charging_full),
                        helperText:
                            'Min ${widget.listing.minEnergySale.toStringAsFixed(1)} kWh  •  Max ${widget.listing.maxEnergySale.toStringAsFixed(1)} kWh',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: cs.outline.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter an amount';
                        final e = double.tryParse(v);
                        if (e == null) return 'Enter a valid number';
                        if (e < widget.listing.minEnergySale) {
                          return 'Minimum is ${widget.listing.minEnergySale} kWh';
                        }
                        if (e > widget.listing.maxEnergySale) {
                          return 'Maximum is ${widget.listing.maxEnergySale} kWh';
                        }
                        if (e > widget.listing.availableEnergy) {
                          return 'Only ${widget.listing.availableEnergy} kWh available';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 16),

                    // Price toggle
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Use seller\'s listed price',
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                            'R${widget.listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                        value: _useListingPrice,
                        activeColor: color,
                        onChanged: (v) => setState(() => _useListingPrice = v),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    if (!_useListingPrice) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _offeredPriceController,
                        decoration: InputDecoration(
                          labelText: 'Your Offered Price (R/kWh)',
                          prefixIcon: const Icon(Icons.attach_money),
                          helperText: 'Negotiate a different price',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: color, width: 2),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        validator: (v) {
                          if (!_useListingPrice) {
                            if (v == null || v.isEmpty) return 'Enter a price';
                            final p = double.tryParse(v);
                            if (p == null || p <= 0) return 'Enter a valid price';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Estimated cost banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estimated Total',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.8))),
                          Text(
                            'R${_estimatedCost.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Message field
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Message to Seller (optional)',
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                        helperText: 'Introduce yourself or ask a question',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
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
                                _isSubmitting ? null : _submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
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
                                : const Text('Send Request',
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

  Widget _summaryTile(BuildContext context, IconData icon, Color iconColor,
      String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 3),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      widget.onSubmit({
        'listingId': widget.listing.id,
        'requestedEnergy': double.parse(_requestedEnergyController.text),
        'offeredPricePerKwh': _useListingPrice
            ? widget.listing.pricePerKwh
            : double.parse(_offeredPriceController.text),
        'message': _messageController.text.isNotEmpty
            ? _messageController.text
            : null,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
      setState(() => _isSubmitting = false);
    }
  }
}
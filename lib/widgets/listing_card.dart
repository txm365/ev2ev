// lib/widgets/listing_card.dart
import 'package:flutter/material.dart';
import '../models/energy_listing.dart';

class ListingCard extends StatelessWidget {
  final EnergyListing listing;
  final VoidCallback onTap;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  Color _vehicleColor() {
    final v = listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return const Color(0xFF7B1FA2);
    if (v.contains('truck')) return const Color(0xFFE65100);
    if (v.contains('van')) return const Color(0xFF0277BD);
    if (v.contains('motorcycle') || v.contains('scooter') || v.contains('moto')) {
      return const Color(0xFF00897B);
    }
    if (v.contains('station') || v.contains('charging')) return const Color(0xFFAD1457);
    return const Color(0xFF2E7D32);
  }

  IconData _vehicleIcon() {
    final v = listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return Icons.directions_bus;
    if (v.contains('truck')) return Icons.local_shipping;
    if (v.contains('van')) return Icons.airport_shuttle;
    if (v.contains('motorcycle') || v.contains('scooter') || v.contains('moto')) {
      return Icons.electric_moped;
    }
    if (v.contains('station') || v.contains('charging')) return Icons.ev_station;
    return Icons.electric_car;
  }

  String _availabilityText() {
    if (listing.availabilityEnd == null) return 'Now';
    final diff = listing.availabilityEnd!.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  int _estimatedMinutes() =>
      listing.distance == null ? 0 : (listing.distance! / 30 * 60).round();

  @override
  Widget build(BuildContext context) {
    final color = _vehicleColor();
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.4)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(_vehicleIcon(), color: color, size: 22),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.surface, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.sellerName ?? 'Energy Provider',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${listing.vehicleType}  •  ${listing.connectorType}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (listing.distance != null) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${listing.distance!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '~${_estimatedMinutes()} min',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Stats row
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          _statTile(context,
                              icon: Icons.bolt,
                              iconColor: Colors.amber[700]!,
                              value: 'R${listing.pricePerKwh.toStringAsFixed(2)}',
                              label: 'per kWh'),
                          _vDivider(cs),
                          _statTile(context,
                              icon: Icons.battery_charging_full,
                              iconColor: Colors.green,
                              value:
                                  '${listing.availableEnergy.toStringAsFixed(1)} kWh',
                              label: 'Available'),
                          _vDivider(cs),
                          _statTile(context,
                              icon: Icons.schedule,
                              iconColor: cs.primary,
                              value: _availabilityText(),
                              label: 'Until',
                              compact: true),
                        ],
                      ),
                    ),
                  ),

                  // Description
                  if (listing.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      listing.description!,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Full-width Request Energy button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('Request Energy',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
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

  Widget _statTile(BuildContext context,
      {required IconData icon,
      required Color iconColor,
      required String value,
      required String label,
      bool compact = false}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider(ColorScheme cs) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: cs.onSurface.withValues(alpha: 0.08),
      );
}
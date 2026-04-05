// lib/widgets/listing_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/energy_listing.dart';
import '../providers/blockchain_provider.dart';

class ListingCard extends StatefulWidget {
  final EnergyListing listing;
  final VoidCallback onRequestTap; // only fires the Request Energy dialog

  const ListingCard({
    super.key,
    required this.listing,
    required this.onRequestTap,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  // ── Vehicle helpers ────────────────────────────────────────────────────────

  Color _vehicleColor() {
    final v = widget.listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return const Color(0xFF7B1FA2);
    if (v.contains('truck')) return const Color(0xFFE65100);
    if (v.contains('van')) return const Color(0xFF0277BD);
    if (v.contains('motorcycle') ||
        v.contains('scooter') ||
        v.contains('moto')) { return const Color(0xFF00897B); }
    if (v.contains('station') || v.contains('charging')) {
      return const Color(0xFFAD1457);
    }
    return const Color(0xFF2E7D32);
  }

  IconData _vehicleIcon() {
    final v = widget.listing.vehicleType.toLowerCase();
    if (v.contains('bus')) return Icons.directions_bus;
    if (v.contains('truck')) return Icons.local_shipping;
    if (v.contains('van')) return Icons.airport_shuttle;
    if (v.contains('motorcycle') ||
        v.contains('scooter') ||
        v.contains('moto')) { return Icons.electric_moped; }
    if (v.contains('station') || v.contains('charging')) {
      return Icons.ev_station;
    }
    return Icons.electric_car;
  }

  String _availabilityText() {
    if (widget.listing.availabilityEnd == null) return 'Now';
    final diff =
        widget.listing.availabilityEnd!.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  int _estimatedMinutes() => widget.listing.distance == null
      ? 0
      : (widget.listing.distance! / 30 * 60).round();

  @override
  Widget build(BuildContext context) {
    final color = _vehicleColor();
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.15),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle, // body tap = expand/collapse only
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.4)]),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Collapsed header (always visible) ─────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar + online dot
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                color.withValues(alpha: 0.12),
                            child: Icon(_vehicleIcon(),
                                color: color, size: 20),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: cs.surface, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      // Name + type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.listing.sellerName ??
                                  'Energy Provider',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.listing.vehicleType}  •  '
                              '${widget.listing.connectorType}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.5)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Price + distance + chevron
                      Builder(builder: (bCtx) {
                        final rate = bCtx
                            .watch<BlockchainProvider>()
                            .polToZarRate;
                        final polStr = rate != null && rate > 0
                            ? '≈ ${(widget.listing.pricePerKwh / rate).toStringAsFixed(4)} POL'
                            : '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R${widget.listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color),
                            ),
                            if (polStr.isNotEmpty)
                              Text(polStr,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurface.withValues(alpha: 0.4))),
                              if (widget.listing.distance != null)
                              Text(
                                '${widget.listing.distance!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.45)),
                              ),
                          ],
                        );
                      }),

                      const SizedBox(width: 6),

                      // Chevron indicator
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 20,
                            color:
                                cs.onSurface.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),

                  // ── Expanded content (animated) ────────────────────────
                  SizeTransition(
                    sizeFactor: _expandAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Stats row
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Builder(builder: (bCtx) {
                                  final rate = bCtx
                                      .watch<BlockchainProvider>()
                                      .polToZarRate;
                                  final pol = rate != null && rate > 0
                                      ? '≈ ${(widget.listing.pricePerKwh / rate).toStringAsFixed(4)} POL'
                                      : null;
                                  return _statTile(bCtx,
                                      icon: Icons.bolt,
                                      iconColor: Colors.amber[700]!,
                                      value: 'R${widget.listing.pricePerKwh.toStringAsFixed(2)}',
                                      sublabel: pol,
                                      label: 'per kWh');
                                }),
                                _vDivider(cs),
                                _statTile(context,
                                    icon: Icons.battery_charging_full,
                                    iconColor: Colors.green,
                                    value:
                                        '${widget.listing.availableEnergy.toStringAsFixed(1)} kWh',
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

                        // Drive time
                        if (widget.listing.distance != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '~${_estimatedMinutes()} min drive',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface
                                    .withValues(alpha: 0.45)),
                          ),
                        ],

                        // Description
                        if (widget.listing.description?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.listing.description!,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface
                                    .withValues(alpha: 0.6)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Request Energy button — separate tap, does NOT toggle card
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onRequestTap,
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('Request Energy',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
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
      String? sublabel,
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
            Text(value,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            if (sublabel != null)
              Text(sublabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.45))),
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
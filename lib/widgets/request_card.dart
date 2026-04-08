// lib/widgets/request_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/energy_request.dart';
import '../providers/blockchain_provider.dart';

class RequestCard extends StatefulWidget {
  final EnergyRequest request;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onNavigate;
  final VoidCallback? onPayWithMatic;

  const RequestCard({
    super.key,
    required this.request,
    required this.isReceived,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onShowOnMap,
    this.onNavigate,
    this.onPayWithMatic,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
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
    _expandAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor() {
    switch (widget.request.status) {
      case 'accepted': return const Color(0xFF2E7D32);
      case 'rejected': return const Color(0xFFC62828);
      case 'cancelled': return Colors.grey;
      default: return const Color(0xFFE65100);
    }
  }

  IconData _statusIcon() {
    switch (widget.request.status) {
      case 'accepted': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      case 'cancelled': return Icons.block_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  String _statusLabel() => widget.request.status[0].toUpperCase() +
      widget.request.status.substring(1);

  String _formatTimestamp(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(t);
  }

  bool _hasLocation() =>
      widget.request.sellerLocationLat != null &&
      widget.request.sellerLocationLng != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = _statusColor();
    final total = widget.request.offeredPricePerKwh != null
        ? widget.request.offeredPricePerKwh! * widget.request.requestedEnergy
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      elevation: 2,
      shadowColor: sc.withValues(alpha: 0.15),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [sc, sc.withValues(alpha: 0.4)]),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Collapsed header (always visible) ──────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: sc.withValues(alpha: 0.12),
                        child: Icon(_statusIcon(), color: sc, size: 20),
                      ),

                      const SizedBox(width: 12),

                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isReceived
                                  ? (widget.request.buyerName ?? 'Buyer')
                                  : (widget.request.sellerName ?? 'Seller'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.isReceived
                                  ? 'Wants to buy energy from you'
                                  : 'Your energy request',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),

                      // kWh + status chip + chevron
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.request.requestedEnergy.toStringAsFixed(1)} kWh',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sc.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              _statusLabel(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: sc),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 6),

                      // Chevron
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

                  // ── Expanded content ───────────────────────────────────
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
                                _statTile(context,
                                    icon: Icons.battery_charging_full,
                                    iconColor: Colors.green,
                                    value:
                                        '${widget.request.requestedEnergy.toStringAsFixed(1)} kWh',
                                    label: 'Requested'),
                                _vDivider(cs),
                                Builder(builder: (bCtx) {
                                  final bp = bCtx.watch<BlockchainProvider>();
                                  final rate = bp.polToZarRate;
                                  final priceZar =
                                      widget.request.offeredPricePerKwh;
                                  final polPerKwh = priceZar != null &&
                                          rate != null && rate > 0
                                      ? '≈ ${(priceZar / rate).toStringAsFixed(4)} ${bp.network.tokenSymbol}'
                                      : null;
                                  return _statTile(bCtx,
                                      icon: Icons.bolt,
                                      iconColor: Colors.amber[700]!,
                                      value: priceZar != null
                                          ? 'R${priceZar.toStringAsFixed(2)}'
                                          : 'Listed',
                                      sublabel: polPerKwh,
                                      label: 'per kWh');
                                }),
                                _vDivider(cs),
                                Builder(builder: (bCtx) {
                                  final bp = bCtx.watch<BlockchainProvider>();
                                  final rate = bp.polToZarRate;
                                  final polTotal = total != null &&
                                          rate != null && rate > 0
                                      ? '≈ ${(total / rate).toStringAsFixed(4)} ${bp.network.tokenSymbol}'
                                      : null;
                                  return _statTile(bCtx,
                                      icon: Icons.receipt_long,
                                      iconColor: cs.primary,
                                      value: total != null
                                          ? 'R${total.toStringAsFixed(2)}'
                                          : '—',
                                      sublabel: polTotal,
                                      label: 'Total');
                                }),
                              ],
                            ),
                          ),
                        ),

                        // Message
                        if (widget.request.message?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 14, color: cs.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.request.message!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.7)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Timestamp
                        const SizedBox(height: 8),
                        Text(
                          'Requested ${_formatTimestamp(widget.request.createdAt)}',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  cs.onSurface.withValues(alpha: 0.4)),
                        ),

                        // ── Accept / Reject ────────────────────────────
                        if (widget.isReceived &&
                            widget.request.status == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (widget.onReject != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: widget.onReject,
                                    icon: const Icon(Icons.close,
                                        size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                          color: Colors.red),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              if (widget.onReject != null &&
                                  widget.onAccept != null)
                                const SizedBox(width: 10),
                              if (widget.onAccept != null)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: widget.onAccept,
                                    icon: const Icon(Icons.check,
                                        size: 16),
                                    label: const Text('Accept'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],

                        // ── Cancel ─────────────────────────────────────
                        if (!widget.isReceived &&
                            widget.request.status == 'pending' &&
                            widget.onCancel != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: widget.onCancel,
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Cancel Request'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side:
                                    const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],

                        // ── Accepted actions ───────────────────────────
                        if (widget.request.status == 'accepted') ...[
                          if (_hasLocation() &&
                              widget.onShowOnMap != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: widget.onShowOnMap,
                                    icon: const Icon(
                                        Icons.map_outlined,
                                        size: 16),
                                    label: const Text('View on Map'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.primary,
                                      side: BorderSide(
                                          color: cs.primary
                                              .withValues(alpha: 0.6)),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: widget.onNavigate,
                                    icon: const Icon(
                                        Icons.navigation_rounded,
                                        size: 16),
                                    label: const Text('Navigate'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (!widget.isReceived &&
                              widget.onPayWithMatic != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.onPayWithMatic,
                                icon: const Icon(Icons.bolt_rounded,
                                    size: 18),
                                label: const Text('Pay with POL',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
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
      String? sublabel}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 1,
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
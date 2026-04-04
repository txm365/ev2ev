// lib/widgets/request_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/energy_request.dart';

class RequestCard extends StatelessWidget {
  final EnergyRequest request;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onNavigate;

  const RequestCard({
    super.key,
    required this.request,
    required this.isReceived,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onShowOnMap,
    this.onNavigate,
  });

  Color _statusColor() {
    switch (request.status) {
      case 'accepted': return const Color(0xFF2E7D32);
      case 'rejected': return const Color(0xFFC62828);
      case 'cancelled': return Colors.grey;
      default: return const Color(0xFFE65100); // pending
    }
  }

  IconData _statusIcon() {
    switch (request.status) {
      case 'accepted': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      case 'cancelled': return Icons.block_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  String _statusLabel() => request.status[0].toUpperCase() + request.status.substring(1);

  String _formatTimestamp(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(t);
  }

  bool _hasLocation() =>
      request.sellerLocationLat != null && request.sellerLocationLng != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = _statusColor();
    final total = request.offeredPricePerKwh != null
        ? request.offeredPricePerKwh! * request.requestedEnergy
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 2,
      shadowColor: sc.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status accent bar ──────────────────────────────────────────────
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [sc, sc.withValues(alpha: 0.4)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: sc.withValues(alpha: 0.12),
                      child: Icon(_statusIcon(), color: sc, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReceived
                                ? (request.buyerName ?? 'Buyer')
                                : (request.sellerName ?? 'Seller'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isReceived
                                ? 'Wants to buy energy from you'
                                : 'Your energy request',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sc,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Stats row ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _statTile(context,
                            icon: Icons.battery_charging_full,
                            iconColor: Colors.green,
                            value:
                                '${request.requestedEnergy.toStringAsFixed(1)} kWh',
                            label: 'Requested'),
                        _vDivider(cs),
                        _statTile(context,
                            icon: Icons.bolt,
                            iconColor: Colors.amber[700]!,
                            value: request.offeredPricePerKwh != null
                                ? 'R${request.offeredPricePerKwh!.toStringAsFixed(2)}'
                                : 'Listed',
                            label: 'per kWh'),
                        _vDivider(cs),
                        _statTile(context,
                            icon: Icons.receipt_long,
                            iconColor: cs.primary,
                            value: total != null
                                ? 'R${total.toStringAsFixed(2)}'
                                : '—',
                            label: 'Total'),
                      ],
                    ),
                  ),
                ),

                // ── Message ───────────────────────────────────────────────
                if (request.message?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 14,
                            color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.message!,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Timestamp ─────────────────────────────────────────────
                const SizedBox(height: 8),
                Text(
                  'Requested ${_formatTimestamp(request.createdAt)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.4)),
                ),

                // ── Accept / Reject (received pending) ────────────────────
                if (isReceived && request.status == 'pending') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (onReject != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      if (onReject != null && onAccept != null)
                        const SizedBox(width: 10),
                      if (onAccept != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onAccept,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                // ── Cancel (sent pending) ─────────────────────────────────
                if (!isReceived &&
                    request.status == 'pending' &&
                    onCancel != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel Request'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],

                // ── View on Map + Navigate (accepted with location) ───────
                if (request.status == 'accepted' &&
                    _hasLocation() &&
                    onShowOnMap != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onShowOnMap,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('View on Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.6)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onNavigate,
                          icon: const Icon(Icons.navigation_rounded,
                              size: 16),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context,
      {required IconData icon,
      required Color iconColor,
      required String value,
      required String label}) {
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
              maxLines: 1,
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
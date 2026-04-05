// lib/widgets/payment_bottom_sheet.dart
//
// Shows when buyer taps "Pay with POL" on an accepted request card.
// Guides through: balance check → amount preview → confirm → sign & broadcast
// All signing happens locally on the device via WalletService.
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import '../models/energy_request.dart';

class PaymentBottomSheet extends StatefulWidget {
  final EnergyRequest request;
  final String sellerWalletAddress;

  const PaymentBottomSheet({
    super.key,
    required this.request,
    required this.sellerWalletAddress,
  });

  /// Convenience launcher
  static Future<bool?> show(
    BuildContext context, {
    required EnergyRequest request,
    required String sellerWalletAddress,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PaymentBottomSheet(
        request: request,
        sellerWalletAddress: sellerWalletAddress,
      ),
    );
  }

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  // Simplified POL/ZAR conversion for demo — in production use a live price feed
  static const double _polToZar = 12.50; // 1 POL ≈ R12.50 (update regularly)
  static const _green = Color(0xFF2E7D32);

  _PayStep _step = _PayStep.preview;
  String? _txHash;

  double get _totalZar =>
      (widget.request.offeredPricePerKwh ?? 0) *
      widget.request.requestedEnergy;

  double get _totalPol => _totalZar / _polToZar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: Consumer<BlockchainProvider>(
        builder: (context, bp, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Content switches based on step
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStep(context, bp, cs),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    switch (_step) {
      case _PayStep.preview:
        return _buildPreview(context, bp, cs);
      case _PayStep.processing:
        return _buildProcessing(cs);
      case _PayStep.success:
        return _buildSuccess(context, cs);
      case _PayStep.failed:
        return _buildFailed(context, bp, cs);
    }
  }

  // ── Preview step ───────────────────────────────────────────────────────────
  Widget _buildPreview(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    final hasEnoughPol = bp.polBalance >= _totalPol;

    return Column(
      key: const ValueKey('preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: _green, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pay with POL',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Polygon blockchain payment',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Order summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _summaryRow('Energy', '${widget.request.requestedEnergy.toStringAsFixed(1)} kWh'),
              const SizedBox(height: 8),
              _summaryRow('Price', 'R${(widget.request.offeredPricePerKwh ?? 0).toStringAsFixed(2)}/kWh'),
              const Divider(height: 20),
              _summaryRow(
                'Total (ZAR)',
                'R${_totalZar.toStringAsFixed(2)}',
                bold: true,
              ),
              const SizedBox(height: 4),
              _summaryRow(
                'Total (POL)',
                '${_totalPol.toStringAsFixed(4)} POL',
                bold: true,
                valueColor: _green,
              ),
              const SizedBox(height: 4),
              Text(
                '≈ at R${_polToZar.toStringAsFixed(2)}/POL',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Wallet balance
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasEnoughPol
                ? _green.withValues(alpha: 0.06)
                : Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasEnoughPol
                  ? _green.withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasEnoughPol ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 18,
                color: hasEnoughPol ? _green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasEnoughPol
                      ? 'Balance: ${bp.polBalance.toStringAsFixed(4)} POL ✓'
                      : 'Insufficient balance (${bp.polBalance.toStringAsFixed(4)} POL). '
                        'Top up from the Wallet screen.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasEnoughPol ? _green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Escrow notice
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '🔒  Funds are locked in a smart contract escrow until you '
            'confirm receipt of energy. You can dispute or claim a refund '
            'if the energy is not delivered.',
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
                height: 1.5),
          ),
        ),

        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: hasEnoughPol ? () => _submit(context, bp) : null,
                icon: const Icon(Icons.lock_outlined, size: 18),
                label: const Text('Confirm & Pay',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Processing step ────────────────────────────────────────────────────────
  Widget _buildProcessing(ColorScheme cs) {
    return Padding(
      key: const ValueKey('processing'),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Signing transaction on device…',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            'Broadcasting to Polygon network.\nThis usually takes 2–5 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  // ── Success step ───────────────────────────────────────────────────────────
  Widget _buildSuccess(BuildContext context, ColorScheme cs) {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(Icons.check_circle_rounded,
              color: _green, size: 64),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text('Payment Escrowed!',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${_totalPol.toStringAsFixed(4)} POL locked in smart contract',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Next steps:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _nextStep('1', 'Seller transfers energy to your EV'),
              const SizedBox(height: 6),
              _nextStep('2', 'Seller taps "Confirm Delivery" in the app'),
              const SizedBox(height: 6),
              _nextStep('3', 'You confirm receipt — funds released to seller'),
            ],
          ),
        ),
        if (_txHash != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Tx: ${_txHash!.substring(0, 10)}…',
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Failed step ────────────────────────────────────────────────────────────
  Widget _buildFailed(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    return Column(
      key: const ValueKey('failed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
            child: Icon(Icons.error_outline, color: Colors.red, size: 56)),
        const SizedBox(height: 12),
        const Center(
          child: Text('Payment Failed',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        if (bp.errorMessage != null)
          Center(
            child: Text(
              bp.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  bp.clearError();
                  setState(() => _step = _PayStep.preview);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit(BuildContext context, BlockchainProvider bp) async {
    setState(() => _step = _PayStep.processing);

    final tradeId = await bp.depositToEscrow(
      supabaseRequestId: widget.request.id,
      sellerWalletAddress: widget.sellerWalletAddress,
      energyKwh: widget.request.requestedEnergy,
      totalPol: _totalPol,
    );

    if (!mounted) return;

    if (tradeId != null) {
      setState(() {
          _txHash = bp.trades.isNotEmpty ? null : null; // updated via provider
        _step = _PayStep.success;
      });
    } else {
      setState(() => _step = _PayStep.failed);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight:
                    bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            )),
      ],
    );
  }

  Widget _nextStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: _green,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

enum _PayStep { preview, processing, success, failed }
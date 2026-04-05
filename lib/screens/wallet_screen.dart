// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/blockchain_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _showMnemonic = false;
  String? _mnemonic;
  bool _loadingMnemonic = false;

  // Send POL form
  final _sendAddressController = TextEditingController();
  final _sendAmountController = TextEditingController();
  final _sendFormKey = GlobalKey<FormState>();
  bool _isSending = false;
  String? _lastTxHash;

  static const _green = Color(0xFF2E7D32);

  @override
  void dispose() {
    _sendAddressController.dispose();
    _sendAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
      ),
      body: Consumer<BlockchainProvider>(
        builder: (context, bp, _) {
          if (bp.isInitializing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up your wallet…'),
                ],
              ),
            );
          }

          if (!bp.walletReady) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    const Text('Wallet not ready',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('Please log in to initialise your wallet',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: bp.initialize,
                      child: const Text('Initialise Wallet'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── QR + address (hero, top of screen) ────────────────────
                _buildReceiveCard(bp, cs),

                const SizedBox(height: 14),

                // ── Balance ────────────────────────────────────────────────
                _buildBalanceCard(bp, cs),

                const SizedBox(height: 14),

                // ── Send POL ───────────────────────────────────────────────
                _buildSendCard(context, bp, cs),

                const SizedBox(height: 14),

                // ── Backup mnemonic ────────────────────────────────────────
                _buildMnemonicCard(context, bp, cs),

                const SizedBox(height: 14),

                // ── Testnet info ───────────────────────────────────────────
                _buildTestnetInfoCard(cs),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Balance card ────────────────────────────────────────────────────────────
  Widget _buildBalanceCard(BlockchainProvider bp, ColorScheme cs) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Wallet icon — small, on the side
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: _green, size: 20),
            ),
            const SizedBox(width: 14),

            // Balance + network label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bp.polBalance.toStringAsFixed(4)} POL',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Polygon Amoy Testnet',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Refresh button
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4)),
              onPressed: bp.isProcessing ? null : bp.refreshBalance,
              tooltip: 'Refresh balance',
            ),
          ],
        ),
      ),
    );
  }

  // ── Send POL card ───────────────────────────────────────────────────────────
  Widget _buildSendCard(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: _green, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Send POL',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text('Transfer to any wallet address',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Form(
              key: _sendFormKey,
              child: Column(
                children: [
                  // Recipient address
                  TextFormField(
                    controller: _sendAddressController,
                    decoration: InputDecoration(
                      labelText: 'Recipient address',
                      hintText: '0x...',
                      prefixIcon: const Icon(Icons.account_circle_outlined),
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
                      // Paste button suffix
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded,
                            size: 18),
                        tooltip: 'Paste',
                        onPressed: () async {
                          final data =
                              await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _sendAddressController.text =
                                data!.text!.trim();
                          }
                        },
                      ),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter a recipient address';
                      }
                      if (!v.trim().startsWith('0x') ||
                          v.trim().length != 42) {
                        return 'Enter a valid 0x address (42 characters)';
                      }
                      if (v.trim().toLowerCase() ==
                          bp.walletAddress?.toLowerCase()) {
                        return 'Cannot send to your own address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Amount
                  TextFormField(
                    controller: _sendAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'))
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'POL  ',
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
                      // Max button
                      suffixIcon: TextButton(
                        onPressed: () {
                          // Leave small amount for gas
                          final max = (bp.polBalance - 0.001)
                              .clamp(0.0, double.infinity);
                          _sendAmountController.text =
                              max.toStringAsFixed(4);
                        },
                        child: const Text('MAX',
                            style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      helperText:
                          'Available: ${bp.polBalance.toStringAsFixed(4)} POL',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter an amount';
                      final amount = double.tryParse(v);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      if (amount >= bp.polBalance) {
                        return 'Insufficient balance (keep some for gas)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Success tx hash
                  if (_lastTxHash != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sent! Tx: ${_lastTxHash!.substring(0, 18)}…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontFamily: 'monospace'),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _lastTxHash!));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Tx hash copied'),
                                duration: Duration(seconds: 2),
                              ));
                            },
                            child: const Icon(Icons.copy_outlined,
                                size: 14, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Error message
                  if (bp.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(bp.errorMessage!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (bp.isProcessing || _isSending)
                          ? null
                          : () => _handleSend(context, bp),
                      icon: (bp.isProcessing || _isSending)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        (bp.isProcessing || _isSending)
                            ? 'Sending…'
                            : 'Send POL',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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

  // ── Receive / QR card ───────────────────────────────────────────────────────
  Widget _buildReceiveCard(BlockchainProvider bp, ColorScheme cs) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            // QR code — centred, compact but scannable
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: QrImageView(
                data: bp.walletAddress ?? '',
                version: QrVersions.auto,
                size: 140,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Full address with copy button
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bp.walletAddress ?? '',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: bp.walletAddress!));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text('Address copied'),
                        duration: Duration(seconds: 2),
                      ));
                    },
                    child: Icon(Icons.copy_outlined,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Scan to receive POL · tap address to copy',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Backup mnemonic card ────────────────────────────────────────────────────
  Widget _buildMnemonicCard(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Backup Recovery Phrase',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your 12-word recovery phrase is the only way to restore '
              'your wallet. Store it somewhere safe and never share it.',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.5),
            ),
            const SizedBox(height: 14),
            if (!_showMnemonic)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _loadingMnemonic ? null : () => _revealMnemonic(bp),
                  icon: _loadingMnemonic
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Reveal Recovery Phrase'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (_mnemonic != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _mnemonic!
                          .split(' ')
                          .asMap()
                          .entries
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${e.key + 1}. ${e.value}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace'),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _mnemonic!));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('Recovery phrase copied'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ));
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showMnemonic = false),
                          icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 16),
                          label: const Text('Hide'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Testnet info card ───────────────────────────────────────────────────────
  Widget _buildTestnetInfoCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.info_outline, color: cs.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Get Test POL',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'This wallet uses Polygon Amoy testnet. Get free test '
                    'POL from faucet.polygon.technology or '
                    'faucets.alchemy.com — select Amoy and paste your '
                    'address above.',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _handleSend(
      BuildContext context, BlockchainProvider bp) async {
    if (!_sendFormKey.currentState!.validate()) return;

    // Confirm dialog
    final address = _sendAddressController.text.trim();
    final amount = double.parse(_sendAmountController.text);
    final confirmed = await _showSendConfirmDialog(address, amount);
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
      _lastTxHash = null;
    });

    bp.clearError();

    final txHash = await bp.sendMatic(
      toAddress: address,
      amount: amount,
    );

    if (!mounted) return;

    if (txHash != null) {
      setState(() {
        _lastTxHash = txHash;
        _isSending = false;
      });
      _sendAddressController.clear();
      _sendAmountController.clear();
    } else {
      setState(() => _isSending = false);
    }
  }

  Future<bool?> _showSendConfirmDialog(
      String address, double amount) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.send_rounded,
                color: _green, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Confirm Send',
              style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _confirmRow('Amount',
                      '${amount.toStringAsFixed(4)} POL'),
                  const Divider(height: 16),
                  _confirmRow('To', '${address.substring(0, 8)}…${address.substring(address.length - 6)}'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This transaction is irreversible. Make sure the address is correct.',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Send'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _revealMnemonic(BlockchainProvider bp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Show Recovery Phrase?',
              style: TextStyle(fontSize: 16)),
        ]),
        content: const Text(
          'Make sure nobody can see your screen. Never share this '
          'phrase with anyone. Anyone with these words can access '
          'your funds.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Show'),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loadingMnemonic = true);
    final phrase = await bp.walletServiceRef.getMnemonic();
    if (!mounted) return;
    setState(() {
      _mnemonic = phrase;
      _showMnemonic = true;
      _loadingMnemonic = false;
    });
  }
}
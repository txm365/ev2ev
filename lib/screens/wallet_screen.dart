// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/blockchain_provider.dart';
import '../services/auth_service.dart';
import '../models/app_network.dart';

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

  // ZAR exchange rate
  double? _polToZar;
  bool _loadingRate = false;

  // Send card expansion
  bool _sendExpanded = false;

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _fetchPolZarRate();
  }

  @override
  void dispose() {
    _sendAddressController.dispose();
    _sendAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchPolZarRate() async {
    if (_loadingRate) return;
    setState(() => _loadingRate = true);
    try {
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=polygon-ecosystem-token&vs_currencies=zar',
      );
      final response = await http.get(uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = (data['polygon-ecosystem-token']?['zar'] as num?)?.toDouble();
        if (rate != null && mounted) {
          setState(() => _polToZar = rate);
        }
      }
    } catch (_) {
      // Silently fail — ZAR label just won't show if network unavailable
    } finally {
      if (mounted) setState(() => _loadingRate = false);
    }
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

          // ── First launch: no wallet exists yet ────────────────────────
          if (bp.isFirstLaunch || !bp.walletReady) {
            return _WalletSetupScreen(bp: bp);
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
    final zarValue = _polToZar != null
        ? bp.polBalance * _polToZar!
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Heading row ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: cs.onSurface.withValues(alpha: 0.45))),
                TextButton.icon(
                  onPressed: () => _showSwitchAccountSheet(context, bp, cs),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: const Text('Switch account',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Balance row ──────────────────────────────────────────────
            Row(
              children: [
            // Wallet icon
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

            // Balance + ZAR approximation + network label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // POL amount
                  Text(
                    '${bp.polBalance.toStringAsFixed(4)} ${bp.network.tokenSymbol}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // ZAR value row
                  Row(
                    children: [
                      if (zarValue != null)
                        Text(
                          '≈ R${zarValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        )
                      else if (_loadingRate)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      if (zarValue != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${bp.network.displayName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ] else if (!_loadingRate)
                        Text(
                          bp.network.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  // Rate source note
                  if (zarValue != null)
                    Text(
                      'Rate via CoinGecko · tap ↻ to refresh',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),

            // Refresh button — also re-fetches ZAR rate
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4)),
              onPressed: bp.isProcessing
                  ? null
                  : () {
                      bp.refreshBalance();
                      _fetchPolZarRate();
                    },
              tooltip: 'Refresh balance',
            ),
          ],
        ),   // end balance Row
          ],
        ),   // end Column
      ),
    );
  }

  // ── Switch account bottom sheet ──────────────────────────────────────────────
  void _showSwitchAccountSheet(
      BuildContext context, BlockchainProvider bp, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SwitchAccountSheet(
        bp: bp,
        onImport: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => _ImportAccountSheet(bp: bp),
          );
        },
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
            // ── Collapsible header ──────────────────────────────────
            InkWell(
              onTap: () => setState(() => _sendExpanded = !_sendExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
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
                    const Expanded(
                      child: Column(
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
                    ),
                    AnimatedRotation(
                      turns: _sendExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 20,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expandable form ──────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _sendExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
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
                      // Paste + QR scan buttons
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded,
                                size: 18),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data =
                                  await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                _sendAddressController.text =
                                    data!.text!.trim();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded,
                                size: 18),
                            tooltip: 'Scan QR code',
                            onPressed: () => _scanQrCode(),
                          ),
                        ],
                      ),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                    onChanged: (_) {
                      // Clear provider error as user edits the address
                      final bp = context.read<BlockchainProvider>();
                      if (bp.errorMessage != null) bp.clearError();
                    },
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
                            : 'Send ${context.read<BlockchainProvider>().network.tokenSymbol}',
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
                          ClipboardData(text: bp.walletAddress ?? ''));
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
            // ── RED WARNING ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade400, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_rounded,
                      color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Back up your phrase now!',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade400),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If you uninstall the app, reinstall, or change '
                          'your phone without backing up this phrase, your '
                          'wallet and all funds will be permanently lost. '
                          'There is no way to recover them without this phrase.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade300,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Store it somewhere safe — never share it with anyone.',
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


  // ── Switch account bottom sheet ──────────────────────────────────────────────
  Widget _buildTestnetInfoCard(ColorScheme cs) {
    // Get network from provider — use listen:false since this is called in build

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

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QrScannerPage(),
        fullscreenDialog: true,
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      final cleaned = result.trim();
      _sendAddressController.text = cleaned;
      // Trigger validation immediately so the user sees feedback
      _sendFormKey.currentState?.validate();
    }
  }

  Future<void> _handleSend(
      BuildContext context, BlockchainProvider bp) async {
    if (!_sendFormKey.currentState!.validate()) return;

    // Confirm dialog
    final address = _sendAddressController.text.trim();
    final amount = double.parse(_sendAmountController.text);
    final confirmed = await _showSendConfirmDialog(address, amount);
    if (confirmed != true || !mounted) return;

    // ── Biometric / PIN gate ───────────────────────────────────────────
    final symbol = bp.network.tokenSymbol;
    final authed = await AuthService.instance.authenticate(
      'Confirm sending $amount $symbol to ${address.substring(0, 6)}…${address.substring(address.length - 4)}',
    );
    if (!authed || !mounted) return;

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
    // Require auth before showing recovery phrase
    final authed = await AuthService.instance.authenticate(
      'Authenticate to reveal your recovery phrase',
    );
    if (!authed || !mounted) return;

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

// ── QR Scanner full-screen page ───────────────────────────────────────────────
// Opened as a fullscreenDialog. Scans once, returns the decoded string,
// and closes. The camera is stopped as soon as a valid result is found.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    _hasScanned = true;
    _controller.stop();
    // Some wallet QRs encode "ethereum:0x..." — strip the scheme prefix
    final address = value.startsWith('ethereum:')
        ? value.replaceFirst('ethereum:', '')
        : value;
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Wallet QR Code'),
        actions: [
          // Torch toggle
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
          // Flip camera
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            tooltip: 'Flip camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed fills screen
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with cut-out guide box
          CustomPaint(
            painter: _ScannerOverlayPainter(cs),
            child: const SizedBox.expand(),
          ),

          // Bottom hint
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Point the camera at a wallet QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanner overlay painter ────────────────────────────────────────────────────
// Draws a semi-transparent dark overlay with a clear square cut-out in the
// centre to guide the user where to aim the camera.
class _ScannerOverlayPainter extends CustomPainter {
  final ColorScheme cs;
  const _ScannerOverlayPainter(this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    const cutoutSize = 240.0;
    const cornerRadius = 12.0;
    const cornerLength = 24.0;
    const strokeWidth = 3.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - cutoutSize / 2;
    final top = cy - cutoutSize / 2;
    final right = cx + cutoutSize / 2;
    final bottom = cy + cutoutSize / 2;

    // Dark overlay with hole
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final cutout = RRect.fromLTRBR(
        left, top, right, bottom, const Radius.circular(cornerRadius));

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Green corner brackets
    final cornerPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(left + cornerRadius, top),
        Offset(left + cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left, top + cornerRadius),
        Offset(left, top + cornerLength), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(right - cornerLength, top),
        Offset(right - cornerRadius, top), cornerPaint);
    canvas.drawLine(Offset(right, top + cornerRadius),
        Offset(right, top + cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(left + cornerRadius, bottom),
        Offset(left + cornerLength, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom - cornerLength),
        Offset(left, bottom - cornerRadius), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(right - cornerLength, bottom),
        Offset(right - cornerRadius, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom - cornerLength),
        Offset(right, bottom - cornerRadius), cornerPaint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) => false;
}

// ── Switch Account bottom sheet ────────────────────────────────────────────────

class _SwitchAccountSheet extends StatefulWidget {
  final BlockchainProvider bp;
  final VoidCallback? onImport;
  const _SwitchAccountSheet({required this.bp, this.onImport});

  @override
  State<_SwitchAccountSheet> createState() => _SwitchAccountSheetState();
}

class _SwitchAccountSheetState extends State<_SwitchAccountSheet> {
  List<Map<String, String>> _accounts = [];
  int _activeIndex = 0;
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await widget.bp.getSavedAccounts();
    final active = await widget.bp.walletServiceRef.getActiveIndex();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _activeIndex = active;
        _loading = false;
      });
    }
  }

  Future<void> _switch(int index) async {
    if (index == _activeIndex) {
      Navigator.pop(context);
      return;
    }
    setState(() => _switching = true);
    final success = await widget.bp.switchAccount(index);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Switched to ${_accounts[index]['label'] ?? 'Account ${index + 1}'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to switch account'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _truncate(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text('Switch account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Tap an account to switch to it',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5))),

          const SizedBox(height: 14),

          // ── Compact network selector ───────────────────────────────────
          Consumer<BlockchainProvider>(
            builder: (ctx, bp, _) => Row(
              children: [
                Text('Network',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.45))),
                const SizedBox(width: 12),
                ...AppNetwork.values.map((network) {
                  final isActive = bp.network == network;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => bp.switchNetwork(network),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                              : cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF2E7D32)
                                : cs.onSurface.withValues(alpha: 0.15),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 8,
                              color: isActive
                                  ? const Color(0xFF2E7D32)
                                  : cs.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              network.tokenSymbol,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? const Color(0xFF2E7D32)
                                      : cs.onSurface.withValues(alpha: 0.55)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              network.displayName,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isActive
                                      ? const Color(0xFF2E7D32).withValues(alpha: 0.7)
                                      : cs.onSurface.withValues(alpha: 0.35)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_accounts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No saved accounts yet.\n'
                  'Accounts are saved automatically when\n'
                  'you create or import a wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      height: 1.6),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final account = _accounts[i];
                final isActive = i == _activeIndex;
                return ListTile(
                  onTap: _switching ? null : () => _switch(i),
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? const Color(0xFF2E7D32)
                        : cs.onSurface.withValues(alpha: 0.08),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: isActive
                          ? Colors.white
                          : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  title: Text(
                    account['label'] ?? 'Account ${i + 1}',
                    style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.normal),
                  ),
                  subtitle: Text(
                    _truncate(account['address'] ?? ''),
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  ),
                  trailing: isActive
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF2E7D32))
                      : (_switching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.chevron_right_rounded,
                              color: Colors.grey)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                );
              },
            ),

          const SizedBox(height: 16),

          // Add new account hint
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onImport?.call();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Import another account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Text(
            'Use the "Import existing wallet" card to add another account',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ── First-launch wallet setup screen ──────────────────────────────────────────

class _WalletSetupScreen extends StatefulWidget {
  final BlockchainProvider bp;
  const _WalletSetupScreen({required this.bp});

  @override
  State<_WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<_WalletSetupScreen> {
  static const _green = Color(0xFF2E7D32);
  bool _showImport = false;
  bool _isCreating = false;
  bool _isImporting = false;
  final _importController = TextEditingController();
  String? _importError;

  @override
  void dispose() {
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _createWallet() async {
    _safeSetState(() => _isCreating = true);
    try {
      await widget.bp.createAndInitialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create wallet: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      _safeSetState(() => _isCreating = false);
    }
  }

  Future<void> _importWallet() async {
    final phrase = _importController.text.trim().toLowerCase();
    final words = phrase.split(' ');
    if (words.length != 12) {
      _safeSetState(() => _importError =
          'Please enter exactly 12 words separated by spaces.');
      return;
    }
    _safeSetState(() {
      _isImporting = true;
      _importError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success =
          await widget.bp.walletServiceRef.restoreFromMnemonic(phrase);
      if (!mounted) return;
      if (success) {
        await widget.bp.initialize();
        messenger.showSnackBar(const SnackBar(
          content: Text('Wallet imported successfully!'),
          backgroundColor: Colors.green,
        ));
      } else {
        _safeSetState(() {
          _isImporting = false;
          _importError =
              'Invalid recovery phrase. Please check each word and try again.';
        });
      }
    } catch (e) {
      _safeSetState(() {
        _isImporting = false;
        _importError = 'Import failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Icon
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _green,
                      size: 44),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Set up your wallet',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your wallet lets you pay for energy and receive payments on the Polygon blockchain.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    height: 1.6),
              ),

              const SizedBox(height: 40),

              if (!_showImport) ...[
                // ── Create new wallet button ───────────────────────────────
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createWallet,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                      _isCreating ? 'Creating wallet…' : 'Create new wallet',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Import existing wallet button ──────────────────────────
                OutlinedButton.icon(
                  onPressed: () =>
                      _safeSetState(() => _showImport = true),
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: const Text('Import existing wallet',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Warning note ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'A new wallet generates a 12-word recovery phrase. '
                          'Write it down and store it safely — it is the only '
                          'way to recover your funds if you reinstall the app.',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  cs.onSurface.withValues(alpha: 0.65),
                              height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ── Import form ────────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          _safeSetState(() => _showImport = false),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Text('Import existing wallet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Enter your 12-word recovery phrase exactly as it was given to you.',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.55),
                      height: 1.5),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _importController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'word1 word2 word3 … word12',
                    hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                    errorText: _importError,
                    errorMaxLines: 3,
                  ),
                  style: const TextStyle(
                      fontSize: 14, fontFamily: 'monospace'),
                  onChanged: (_) {
                    if (_importError != null) {
                      _safeSetState(() => _importError = null);
                    }
                  },
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importWallet,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.restore_rounded, size: 18),
                  label: Text(_isImporting ? 'Importing…' : 'Import wallet',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Import account bottom sheet (self-contained, always shows form) ────────────

class _ImportAccountSheet extends StatefulWidget {
  final BlockchainProvider bp;
  const _ImportAccountSheet({required this.bp});

  @override
  State<_ImportAccountSheet> createState() => _ImportAccountSheetState();
}

class _ImportAccountSheetState extends State<_ImportAccountSheet> {
  static const _green = Color(0xFF2E7D32);
  final _controller = TextEditingController();
  String? _error;
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final phrase = _controller.text.trim().toLowerCase();
    final words = phrase.split(' ');
    if (words.length != 12) {
      setState(() => _error = 'Please enter exactly 12 words separated by spaces.');
      return;
    }
    setState(() {
      _importing = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final success = await widget.bp.walletServiceRef.restoreFromMnemonic(phrase);
      if (!mounted) return;
      if (success) {
        await widget.bp.refreshBalance();
        navigator.pop();
        messenger.showSnackBar(const SnackBar(
          content: Text('Wallet imported and switched successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
      } else {
        setState(() {
          _importing = false;
          _error = 'Invalid recovery phrase. Check each word and try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = 'Import failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restore_rounded,
                    color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import existing wallet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Enter your 12-word recovery phrase',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Warning banner
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This adds the imported wallet to your saved accounts. '
                    'Make sure you have backed up any existing wallet first.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Phrase input
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'word1 word2 word3 … word12',
              hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35), fontSize: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(14),
              errorText: _error,
              errorMaxLines: 2,
            ),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),

          const SizedBox(height: 14),

          // Import button
          ElevatedButton.icon(
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.restore_rounded, size: 18),
            label: Text(_importing ? 'Importing…' : 'Import wallet',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
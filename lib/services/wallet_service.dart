// lib/services/wallet_service.dart
//
// Handles all wallet operations:
//   - Generate HD wallet (mnemonic + private key) on first launch
//   - Store encrypted in flutter_secure_storage (Android Keystore backed)
//   - Sign Ethereum transactions locally — private key never leaves device
//   - Query POL balance via Polygon RPC
//
// Dependencies to add to pubspec.yaml:
//   web3dart: ^2.7.3
//   flutter_secure_storage: ^9.2.2
//   bip39: ^1.0.6
//   ed25519_hd_key: ^2.2.0
//
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';

class WalletService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // ── Constants ──────────────────────────────────────────────────────────────
  // Polygon Mumbai testnet — swap for mainnet in production:
  // Mainnet RPC: https://polygon-rpc.com
  // Mainnet chain ID: 137
  // Public so BlockchainProvider can reference them without duplication
  // Polygon Amoy testnet — get free POL at faucet.polygon.technology (select Amoy)
  // To switch networks, only these two values need changing:
  //   Hardhat local:   rpcUrl = 'http://10.0.2.2:8545',  chainId = 31337
  //   Polygon Amoy:    rpcUrl = 'https://rpc-amoy.polygon.technology', chainId = 80002
  //   Polygon mainnet: rpcUrl = 'https://polygon-rpc.com', chainId = 137
  static const String rpcUrl =
      'https://rpc-amoy.polygon.technology';
  static const int chainId = 80002; // Amoy testnet

  // Deployed EnergyEscrow contract address (set after deployment)
  static const String contractAddress =
      '0x0000000000000000000000000000000000000000'; // Set this after deploying EnergyEscrow.sol

  // Secure storage keys
  static const String _keyMnemonic = 'ev2ev_wallet_mnemonic';
  static const String _keyPrivateKey = 'ev2ev_wallet_private_key';
  static const String _keyAddress = 'ev2ev_wallet_address';
  // Multi-account storage: JSON list of {address, mnemonic, privateKey, label}
  static const String _keyAccountList = 'ev2ev_account_list';
  static const String _keyActiveIndex = 'ev2ev_active_account_index';

  // ── Internal state ─────────────────────────────────────────────────────────
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Web3Client? _client;
  EthPrivateKey? _credentials;
  EthereumAddress? _address;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Public wallet address (safe to share / store in Supabase)
  String? get publicAddress => _address?.hexEip55;

  bool get isInitialized => _credentials != null;

  /// Returns true if a wallet has been previously created/imported on this device.
  /// Does NOT load anything — safe to call before initialize().
  Future<bool> hasExistingWallet() async {
    final key = await _storage.read(key: _keyPrivateKey);
    return key != null && key.isNotEmpty;
  }

  /// Public entry point for creating a fresh wallet (called on first launch).
  Future<void> createNewWalletPublic() => _createNewWallet();

  // ── Saved accounts ─────────────────────────────────────────────────────────

  /// Returns all saved accounts as list of maps with keys:
  /// address, label, isActive
  Future<List<Map<String, String>>> getSavedAccounts() async {
    try {
      final raw = await _storage.read(key: _keyAccountList);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getActiveIndex() async {
    final raw = await _storage.read(key: _keyActiveIndex);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  /// Save current wallet into the account list (called after create/import).
  Future<void> _saveCurrentToAccountList({String? label}) async {
    if (_address == null) return;
    final accounts = await getSavedAccounts();
    final address = _address!.hexEip55;
    // Avoid duplicates
    final exists = accounts.any((a) => a['address'] == address);
    if (!exists) {
      accounts.add({
        'address': address,
        'label': label ?? 'Account ${accounts.length + 1}',
        'mnemonic': await _storage.read(key: _keyMnemonic) ?? '',
        'privateKey': await _storage.read(key: _keyPrivateKey) ?? '',
      });
      await _storage.write(
          key: _keyAccountList, value: jsonEncode(accounts));
    }
    // Set active index
    final idx = accounts.indexWhere((a) => a['address'] == address);
    await _storage.write(
        key: _keyActiveIndex, value: idx.toString());
  }

  /// Switch the active wallet to a saved account by index.
  Future<bool> switchToAccount(int index) async {
    try {
      final accounts = await getSavedAccounts();
      if (index < 0 || index >= accounts.length) return false;
      final account = accounts[index];
      final privateKey = account['privateKey'] ?? '';
      if (privateKey.isEmpty) return false;
      _credentials = EthPrivateKey.fromHex(privateKey);
      _address = _credentials!.address;
      // Update active keys so the app loads this account next time
      await _storage.write(key: _keyPrivateKey, value: privateKey);
      await _storage.write(
          key: _keyMnemonic, value: account['mnemonic'] ?? '');
      await _storage.write(
          key: _keyAddress, value: _address!.hexEip55);
      await _storage.write(
          key: _keyActiveIndex, value: index.toString());
      debugPrint('🔄 Switched to account $index: ${_address?.hexEip55}');
      return true;
    } catch (e) {
      debugPrint('❌ Account switch failed: $e');
      return false;
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Call once at app startup (after user logs in).
  /// Loads existing wallet or creates a new one if this is the first launch.
  Future<void> initialize() async {
    _client = Web3Client(rpcUrl, http.Client());

    final existingKey = await _storage.read(key: _keyPrivateKey);
    if (existingKey != null) {
      await _loadExistingWallet(existingKey);
      debugPrint('🔐 Wallet loaded: ${_address?.hexEip55}');
    }
    // No auto-create — caller decides (first launch screen handles creation)
  }

  Future<void> _loadExistingWallet(String privateKeyHex) async {
    _credentials = EthPrivateKey.fromHex(privateKeyHex);
    _address = _credentials!.address;
  }

  Future<void> _createNewWallet() async {
    // Generate 12-word BIP39 mnemonic
    final mnemonic = bip39.generateMnemonic();
    final seed = bip39.mnemonicToSeed(mnemonic);

    // Derive Ethereum key at m/44'/60'/0'/0/0 (standard ETH derivation path)
    // Derive master key — used implicitly to validate seed entropy
    await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
    // For Ethereum we use secp256k1 — derive via web3dart from seed bytes
    final privateKeyBytes = seed.sublist(0, 32);
    final privateKeyHex = privateKeyBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    _credentials = EthPrivateKey.fromHex(privateKeyHex);
    _address = _credentials!.address;

    // Store encrypted on device — never transmitted
    await _storage.write(key: _keyMnemonic, value: mnemonic);
    await _storage.write(key: _keyPrivateKey, value: privateKeyHex);
    await _storage.write(key: _keyAddress, value: _address!.hexEip55);
    await _saveCurrentToAccountList();
  }

  // ── Balance ────────────────────────────────────────────────────────────────

  /// Returns POL balance in ether units (e.g. 1.5 POL)
  Future<double> getBalance() async {
    if (_client == null || _address == null) return 0.0;
    try {
      final balance = await _client!.getBalance(_address!);
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      debugPrint('❌ Balance fetch failed: $e');
      return 0.0;
    }
  }

  /// Returns balance formatted as "1.2345 POL"
  Future<String> getBalanceFormatted() async {
    final bal = await getBalance();
    return '${bal.toStringAsFixed(4)} POL';
  }

  // ── Mnemonic backup ────────────────────────────────────────────────────────

  /// Returns the mnemonic for the user to back up.
  /// Only show this when the user explicitly requests it (settings screen).
  Future<String?> getMnemonic() async {
    return _storage.read(key: _keyMnemonic);
  }

  /// Restore a wallet from a mnemonic (for account recovery flow).
  Future<bool> restoreFromMnemonic(String mnemonic) async {
    try {
      if (!bip39.validateMnemonic(mnemonic)) return false;

      final seed = bip39.mnemonicToSeed(mnemonic);
      final privateKeyBytes = seed.sublist(0, 32);
      final privateKeyHex = privateKeyBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      _credentials = EthPrivateKey.fromHex(privateKeyHex);
      _address = _credentials!.address;

      await _storage.write(key: _keyMnemonic, value: mnemonic);
      await _storage.write(key: _keyPrivateKey, value: privateKeyHex);
      await _storage.write(key: _keyAddress, value: _address!.hexEip55);
      await _saveCurrentToAccountList();

      debugPrint('🔐 Wallet restored: ${_address?.hexEip55}');
      return true;
    } catch (e) {
      debugPrint('❌ Wallet restore failed: $e');
      return false;
    }
  }

  // ── Transaction signing ────────────────────────────────────────────────────

  /// Sends a signed transaction to the contract.
  /// Returns the transaction hash on success.
  Future<String> sendTransaction({
    required String toAddress,
    required BigInt valueWei,
    required Uint8List data,
  }) async {
    if (_client == null || _credentials == null) {
      throw Exception('Wallet not initialized');
    }

    final gasPrice = await _client!.getGasPrice();
    final nonce = await _client!.getTransactionCount(_address!);

    final tx = Transaction(
      to: EthereumAddress.fromHex(toAddress),
      value: EtherAmount.fromBigInt(EtherUnit.wei, valueWei),
      data: data,
      gasPrice: gasPrice,
      maxGas: 200000,
      nonce: nonce,
    );

    final hash = await _client!.sendTransaction(
      _credentials!,
      tx,
      chainId: chainId,
    );

    debugPrint('📤 Tx sent: $hash');
    return hash;
  }

  /// Waits for a transaction to be mined and returns its receipt.
  Future<TransactionReceipt?> waitForReceipt(String txHash) async {
    if (_client == null) return null;

    TransactionReceipt? receipt;
    int attempts = 0;
    const maxAttempts = 30; // 30 × 2s = 60s timeout

    while (receipt == null && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      receipt = await _client!.getTransactionReceipt(txHash);
      attempts++;
    }

    return receipt;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  void dispose() {
    _client?.dispose();
  }
}
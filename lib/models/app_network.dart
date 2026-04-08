// lib/models/app_network.dart
//
// Defines the supported blockchain networks.
// Adding a new network only requires adding an entry here — all UI adapts automatically.

enum AppNetwork {
  polygon(
    displayName: 'Polygon Amoy',
    tokenSymbol: 'POL',
    rpcUrl: 'https://rpc-amoy.polygon.technology',
    chainId: 80002,
    coingeckoId: 'polygon-ecosystem-token',
    faucetUrl: 'https://faucet.polygon.technology',
    explorerUrl: 'https://www.oklink.com/amoy',
    isTestnet: true,
  ),
  ethereum(
    displayName: 'Ethereum Sepolia',
    tokenSymbol: 'ETH',
    rpcUrl: 'https://rpc.sepolia.org',
    chainId: 11155111,
    coingeckoId: 'ethereum',
    faucetUrl: 'https://sepoliafaucet.com',
    explorerUrl: 'https://sepolia.etherscan.io',
    isTestnet: true,
  );

  const AppNetwork({
    required this.displayName,
    required this.tokenSymbol,
    required this.rpcUrl,
    required this.chainId,
    required this.coingeckoId,
    required this.faucetUrl,
    required this.explorerUrl,
    required this.isTestnet,
  });

  final String displayName;
  final String tokenSymbol;
  final String rpcUrl;
  final int chainId;
  final String coingeckoId;
  final String faucetUrl;
  final String explorerUrl;
  final bool isTestnet;

  /// Friendly label shown in the network selector chip
  String get label => '$displayName${isTestnet ? ' (testnet)' : ''}';

  /// Returns the AppNetwork from its stored string key
  static AppNetwork fromKey(String key) =>
      AppNetwork.values.firstWhere((n) => n.name == key,
          orElse: () => AppNetwork.polygon);
}
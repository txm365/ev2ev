// lib/models/app_network.dart
//
// Defines the supported blockchain networks.
// Adding a new network only requires adding an entry here — all UI adapts automatically.

enum AppNetwork {
  // Local Hardhat node — for development and testing.
  // Run: npx hardhat node   in your hardhat project folder.
  // RPC is on your PC. Phone must be on same WiFi.
  // Replace 192.168.10.x with your PC's actual local IP (ip addr / ifconfig).
  hardhat(
    displayName: 'Hardhat Local',
    tokenSymbol: 'ETH',
    rpcUrl: 'http://localhost:8545',  // overridden at runtime via settings
    chainId: 31337,
    coingeckoId: 'ethereum',
    faucetUrl: 'http://localhost:8545',
    explorerUrl: 'http://localhost:8545',
    isTestnet: true,
  ),
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
    rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
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
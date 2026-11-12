import 'package:flutter/foundation.dart';

/// One supported EVM chain and the facts the wallet is allowed to assume.
///
/// Network keys are stable storage keys. Do not rename them: vaults, node
/// lists and receipts already persist these strings.
enum ChainFamily { bnb, ethereum }

@immutable
class ChainSpec {
  const ChainSpec({
    required this.key,
    required this.chainId,
    required this.name,
    required this.shortName,
    required this.nativeSymbol,
    required this.nativeName,
    required this.family,
    required this.isTestnet,
    required this.explorerBase,
    required this.apiBase,
    required this.apiKeyUrl,
    required this.priceSymbol,
    required this.defaultRpcs,
    required this.fallbacks,
  });

  final String key;
  final int chainId;
  final String name;
  final String shortName;
  final String nativeSymbol;
  final String nativeName;
  final ChainFamily family;
  final bool isTestnet;
  final String explorerBase;
  final String apiBase;
  final String apiKeyUrl;
  final String priceSymbol;
  final List<String> defaultRpcs;
  final List<String> fallbacks;

  String get explorerTxBase => '$explorerBase/tx/';
  String get explorerAddressBase => '$explorerBase/address/';
  String get apiKeyHost =>
      Uri.tryParse(apiBase)?.host.replaceFirst('api.', '') ?? apiBase;

  String explorerTx(String hash) => '$explorerTxBase$hash';
  String explorerAddress(String address) => '$explorerAddressBase$address';

  bool get isBnb => family == ChainFamily.bnb;
  bool get isEthereum => family == ChainFamily.ethereum;
}

class Chains {
  Chains._();

  static const bnbMainnet = ChainSpec(
    key: 'mainnet',
    chainId: 56,
    name: 'BNB Smart Chain',
    shortName: 'BSC',
    nativeSymbol: 'BNB',
    nativeName: 'BNB',
    family: ChainFamily.bnb,
    isTestnet: false,
    explorerBase: 'https://bscscan.com',
    apiBase: 'https://api.bscscan.com/v2/api',
    apiKeyUrl: 'https://bscscan.com/myapikey',
    priceSymbol: 'BNB',
    defaultRpcs: ['https://bsc-dataseed.bnbchain.org'],
    fallbacks: [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-dataseed-public.bnbchain.org',
      'https://bsc-dataseed.nariox.org',
      'https://bsc-rpc.publicnode.com',
      'https://1rpc.io/bnb',
      'https://bsc-mainnet.public.blastapi.io',
      'https://rpc.48.club',
    ],
  );

  static const bnbTestnet = ChainSpec(
    key: 'testnet',
    chainId: 97,
    name: 'BNB Smart Chain Testnet',
    shortName: 'BSC Testnet',
    nativeSymbol: 'tBNB',
    nativeName: 'Test BNB',
    family: ChainFamily.bnb,
    isTestnet: true,
    explorerBase: 'https://testnet.bscscan.com',
    apiBase: 'https://api.bscscan.com/v2/api',
    apiKeyUrl: 'https://bscscan.com/myapikey',
    priceSymbol: 'BNB',
    defaultRpcs: ['https://data-seed-prebsc-1-s1.bnbchain.org:8545'],
    fallbacks: [
      'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
      'https://bsc-testnet-rpc.publicnode.com',
    ],
  );

  static const ethereumMainnet = ChainSpec(
    key: 'ethereum',
    chainId: 1,
    name: 'Ethereum',
    shortName: 'Ethereum',
    nativeSymbol: 'ETH',
    nativeName: 'Ether',
    family: ChainFamily.ethereum,
    isTestnet: false,
    explorerBase: 'https://etherscan.io',
    apiBase: 'https://api.etherscan.io/v2/api',
    apiKeyUrl: 'https://etherscan.io/myapikey',
    priceSymbol: 'ETH',
    defaultRpcs: ['https://ethereum-rpc.publicnode.com'],
    fallbacks: [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
      'https://cloudflare-eth.com',
      'https://1rpc.io/eth',
    ],
  );

  static const sepolia = ChainSpec(
    key: 'sepolia',
    chainId: 11155111,
    name: 'Ethereum Sepolia',
    shortName: 'Sepolia',
    nativeSymbol: 'ETH',
    nativeName: 'Sepolia Ether',
    family: ChainFamily.ethereum,
    isTestnet: true,
    explorerBase: 'https://sepolia.etherscan.io',
    apiBase: 'https://api.etherscan.io/v2/api',
    apiKeyUrl: 'https://etherscan.io/myapikey',
    priceSymbol: 'ETH',
    defaultRpcs: ['https://ethereum-sepolia-rpc.publicnode.com'],
    fallbacks: [
      'https://ethereum-sepolia-rpc.publicnode.com',
      'https://rpc.sepolia.org',
      'https://sepolia.drpc.org',
    ],
  );

  static const List<ChainSpec> all = [
    bnbMainnet,
    bnbTestnet,
    ethereumMainnet,
    sepolia,
  ];

  static ChainSpec byKey(String key) {
    for (final chain in all) {
      if (chain.key == key) return chain;
    }
    return bnbMainnet;
  }

  static ChainSpec? byChainId(int chainId) {
    for (final chain in all) {
      if (chain.chainId == chainId) return chain;
    }
    return null;
  }

  static String nativeSymbolFor(String network) => byKey(network).nativeSymbol;

  static String nameFor(String network) => byKey(network).name;

  static String shortNameFor(String network) => byKey(network).shortName;

  static bool isTestnet(String network) => byKey(network).isTestnet;

  static bool isEthereum(String network) =>
      byKey(network).family == ChainFamily.ethereum;

  /// Human label used in menus and review sheets.
  static String label(String network) {
    final chain = byKey(network);
    return '${chain.name} (${chain.chainId})';
  }
}

import 'package:bitcoin_base/bitcoin_base.dart';

/// UTXO blockchains supported by the wallet. EVM chains stay in [Chains].
enum UtxoChain { bitcoin, litecoin, dogecoin }

enum UtxoAddressKind { p2pkh, p2shP2wpkh, p2wpkh, p2tr }

enum UtxoIndexerKind { esplora, blockCypher }

class UtxoNetworkSpec {
  const UtxoNetworkSpec({
    required this.key,
    required this.chain,
    required this.network,
    required this.coinType,
    required this.name,
    required this.shortName,
    required this.nativeSymbol,
    required this.isTestnet,
    required this.explorerBase,
    required this.indexerBase,
    required this.indexerKind,
    required this.addressKinds,
    required this.dustSatoshi,
    required this.supportsRbf,
  });

  final String key;
  final UtxoChain chain;
  final BasedUtxoNetwork network;
  final int coinType;
  final String name;
  final String shortName;
  final String nativeSymbol;
  final bool isTestnet;
  final String explorerBase;
  final String indexerBase;
  final UtxoIndexerKind indexerKind;
  final List<UtxoAddressKind> addressKinds;
  final int dustSatoshi;
  final bool supportsRbf;

  String get explorerTxBase => '$explorerBase/tx/';
  String get explorerAddressBase => '$explorerBase/address/';
  String explorerTx(String hash) => '$explorerTxBase$hash';
  String explorerAddress(String address) => '$explorerAddressBase$address';

  bool get isBitcoin => chain == UtxoChain.bitcoin;
  bool get isLitecoin => chain == UtxoChain.litecoin;
  bool get isDogecoin => chain == UtxoChain.dogecoin;

  int purposeFor(UtxoAddressKind kind) {
    return switch (kind) {
      UtxoAddressKind.p2pkh => 44,
      UtxoAddressKind.p2shP2wpkh => 49,
      UtxoAddressKind.p2wpkh => 84,
      UtxoAddressKind.p2tr => 86,
    };
  }

  String pathFor(
    UtxoAddressKind kind, {
    int account = 0,
    bool change = false,
    int index = 0,
  }) {
    final purpose = purposeFor(kind);
    final changeIndex = change ? 1 : 0;
    return "m/$purpose'/$coinType'/$account'/$changeIndex/$index";
  }
}

class UtxoNetworks {
  UtxoNetworks._();

  static const btcMainnet = UtxoNetworkSpec(
    key: 'btc-mainnet',
    chain: UtxoChain.bitcoin,
    network: BitcoinNetwork.mainnet,
    coinType: 0,
    name: 'Bitcoin',
    shortName: 'BTC',
    nativeSymbol: 'BTC',
    isTestnet: false,
    explorerBase: 'https://mempool.space',
    indexerBase: 'https://mempool.space/api',
    indexerKind: UtxoIndexerKind.esplora,
    addressKinds: [
      UtxoAddressKind.p2pkh,
      UtxoAddressKind.p2shP2wpkh,
      UtxoAddressKind.p2wpkh,
      UtxoAddressKind.p2tr,
    ],
    dustSatoshi: 546,
    supportsRbf: true,
  );

  static const btcTestnet = UtxoNetworkSpec(
    key: 'btc-testnet',
    chain: UtxoChain.bitcoin,
    network: BitcoinNetwork.testnet,
    coinType: 1,
    name: 'Bitcoin Testnet',
    shortName: 'BTC Testnet',
    nativeSymbol: 'tBTC',
    isTestnet: true,
    explorerBase: 'https://mempool.space/testnet',
    indexerBase: 'https://mempool.space/testnet/api',
    indexerKind: UtxoIndexerKind.esplora,
    addressKinds: [
      UtxoAddressKind.p2pkh,
      UtxoAddressKind.p2shP2wpkh,
      UtxoAddressKind.p2wpkh,
      UtxoAddressKind.p2tr,
    ],
    dustSatoshi: 546,
    supportsRbf: true,
  );

  static const ltcMainnet = UtxoNetworkSpec(
    key: 'ltc-mainnet',
    chain: UtxoChain.litecoin,
    network: LitecoinNetwork.mainnet,
    coinType: 2,
    name: 'Litecoin',
    shortName: 'LTC',
    nativeSymbol: 'LTC',
    isTestnet: false,
    explorerBase: 'https://litecoinspace.org',
    indexerBase: 'https://litecoinspace.org/api',
    indexerKind: UtxoIndexerKind.esplora,
    addressKinds: [
      UtxoAddressKind.p2pkh,
      UtxoAddressKind.p2shP2wpkh,
      UtxoAddressKind.p2wpkh,
    ],
    dustSatoshi: 1000,
    supportsRbf: true,
  );

  static const ltcTestnet = UtxoNetworkSpec(
    key: 'ltc-testnet',
    chain: UtxoChain.litecoin,
    network: LitecoinNetwork.testnet,
    coinType: 1,
    name: 'Litecoin Testnet',
    shortName: 'LTC Testnet',
    nativeSymbol: 'tLTC',
    isTestnet: true,
    explorerBase: 'https://litecoinspace.org/testnet',
    indexerBase: 'https://litecoinspace.org/testnet/api',
    indexerKind: UtxoIndexerKind.esplora,
    addressKinds: [
      UtxoAddressKind.p2pkh,
      UtxoAddressKind.p2shP2wpkh,
      UtxoAddressKind.p2wpkh,
    ],
    dustSatoshi: 1000,
    supportsRbf: true,
  );

  static const dogeMainnet = UtxoNetworkSpec(
    key: 'doge-mainnet',
    chain: UtxoChain.dogecoin,
    network: DogecoinNetwork.mainnet,
    coinType: 3,
    name: 'Dogecoin',
    shortName: 'DOGE',
    nativeSymbol: 'DOGE',
    isTestnet: false,
    explorerBase: 'https://dogechain.info',
    indexerBase: 'https://api.blockcypher.com/v1/doge/main',
    indexerKind: UtxoIndexerKind.blockCypher,
    addressKinds: [UtxoAddressKind.p2pkh],
    dustSatoshi: 1000000,
    supportsRbf: false,
  );

  static const dogeTestnet = UtxoNetworkSpec(
    key: 'doge-testnet',
    chain: UtxoChain.dogecoin,
    network: DogecoinNetwork.testnet,
    coinType: 1,
    name: 'Dogecoin Testnet',
    shortName: 'DOGE Testnet',
    nativeSymbol: 'tDOGE',
    isTestnet: true,
    explorerBase: 'https://blockexplorer.one/dogecoin/testnet',
    indexerBase: 'https://api.blockcypher.com/v1/doge/test',
    indexerKind: UtxoIndexerKind.blockCypher,
    addressKinds: [UtxoAddressKind.p2pkh],
    dustSatoshi: 1000000,
    supportsRbf: false,
  );

  static const List<UtxoNetworkSpec> all = [
    btcMainnet,
    btcTestnet,
    ltcMainnet,
    ltcTestnet,
    dogeMainnet,
    dogeTestnet,
  ];

  static UtxoNetworkSpec byKey(String key) {
    for (final network in all) {
      if (network.key == key) return network;
    }
    return btcMainnet;
  }

  static List<UtxoNetworkSpec> forChain(UtxoChain chain) => [
    for (final network in all)
      if (network.chain == chain) network,
  ];

  static String label(String key) {
    final network = byKey(key);
    return '${network.name}${network.isTestnet ? ' · TESTNET' : ' · MAINNET'}';
  }
}

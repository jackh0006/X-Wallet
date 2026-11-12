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
    required this.genesisHash,
    required this.magicHex,
    required this.defaultPort,
    required this.powAlgorithm,
    required this.difficultyRule,
    required this.consensusNotes,
    this.supportsMweb = false,
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
  final String genesisHash;
  final String magicHex;
  final int defaultPort;
  final String powAlgorithm;
  final String difficultyRule;
  final String consensusNotes;
  final bool supportsMweb;

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
    genesisHash:
        '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
    magicHex: 'f9beb4d9',
    defaultPort: 8333,
    powAlgorithm: 'SHA-256d',
    difficultyRule: '2016-block retarget; 10-minute target',
    consensusNotes: 'Bitcoin Core consensus; no MWEB',
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
    genesisHash:
        '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
    magicHex: '0b110907',
    defaultPort: 18333,
    powAlgorithm: 'SHA-256d',
    difficultyRule: '2016-block retarget; testnet rules',
    consensusNotes: 'Bitcoin testnet; no MWEB',
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
    genesisHash:
        '12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2',
    magicHex: 'fbc0b6db',
    defaultPort: 9333,
    powAlgorithm: 'Scrypt',
    difficultyRule: '2016-block retarget; 2.5-minute target',
    consensusNotes: 'Litecoin Core consensus; MWEB not implemented',
    supportsMweb: false,
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
    genesisHash:
        '4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0',
    magicHex: 'fdd2c8f1',
    defaultPort: 19335,
    powAlgorithm: 'Scrypt',
    difficultyRule: '2016-block retarget; testnet rules',
    consensusNotes: 'Litecoin testnet; MWEB not implemented',
    supportsMweb: false,
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
    genesisHash:
        '1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691',
    magicHex: 'c0c0c0c0',
    defaultPort: 22556,
    powAlgorithm: 'Scrypt',
    difficultyRule: 'DigiShield per-block retarget',
    consensusNotes:
        'Dogecoin Core consensus; AuxPoW merged mining; no SegWit/Taproot',
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
    genesisHash:
        'bb0a78264637406b6360aad926284d544d7049f45189db5664f3c4d07350559e',
    magicHex: 'fcc1b7dc',
    defaultPort: 44556,
    powAlgorithm: 'Scrypt',
    difficultyRule: 'DigiShield per-block retarget',
    consensusNotes: 'Dogecoin testnet; AuxPoW merged mining; no SegWit/Taproot',
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

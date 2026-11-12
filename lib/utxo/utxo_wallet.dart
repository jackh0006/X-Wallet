import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

import 'utxo_network.dart';

class UtxoWalletException implements Exception {
  const UtxoWalletException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One derived UTXO account. Secret material stays in this object and is never
/// written to logs or exported implicitly.
class UtxoAccount {
  const UtxoAccount({
    required this.network,
    required this.kind,
    required this.account,
    required this.index,
    required this.change,
    required this.path,
    required this.address,
    required this.publicKeyHex,
    required this.privateKey,
    required this.compressed,
  });

  final UtxoNetworkSpec network;
  final UtxoAddressKind kind;
  final int account;
  final int index;
  final bool change;
  final String path;
  final String address;
  final String publicKeyHex;
  final ECPrivate privateKey;
  final bool compressed;

  String get wif =>
      UtxoWallet.exportWif(privateKey, network, compressed: compressed);

  String get addressType => switch (kind) {
    UtxoAddressKind.p2pkh => 'P2PKH (legacy)',
    UtxoAddressKind.p2shP2wpkh => 'P2SH-P2WPKH (nested SegWit)',
    UtxoAddressKind.p2wpkh => 'P2WPKH (native SegWit)',
    UtxoAddressKind.p2tr => 'P2TR (Taproot)',
  };
}

class UtxoWallet {
  UtxoWallet._();

  static List<int> seedFromMnemonic(String phrase, {String passphrase = ''}) {
    try {
      final mnemonic = Mnemonic.fromString(phrase.trim());
      return Bip39SeedGenerator(mnemonic).generate(passphrase);
    } catch (error) {
      throw UtxoWalletException('Invalid BIP39 recovery phrase: $error');
    }
  }

  static UtxoAccount derive({
    required String phrase,
    required UtxoNetworkSpec network,
    required UtxoAddressKind kind,
    String passphrase = '',
    int account = 0,
    bool change = false,
    int index = 0,
  }) {
    if (!network.addressKinds.contains(kind)) {
      throw UtxoWalletException(
        '${network.name} does not support ${kind.name} addresses.',
      );
    }
    final seed = seedFromMnemonic(phrase, passphrase: passphrase);
    return deriveFromSeed(
      seed: seed,
      network: network,
      kind: kind,
      account: account,
      change: change,
      index: index,
    );
  }

  static UtxoAccount deriveFromSeed({
    required List<int> seed,
    required UtxoNetworkSpec network,
    required UtxoAddressKind kind,
    int account = 0,
    bool change = false,
    int index = 0,
  }) {
    final purpose = network.purposeFor(kind);
    final Bip44Base root = switch (purpose) {
      44 => Bip44.fromSeed(seed, _bip44Coin(network)),
      49 => Bip49.fromSeed(seed, _bip49Coin(network)),
      84 => Bip84.fromSeed(seed, _bip84Coin(network)),
      86 => Bip86.fromSeed(seed, Bip86Coins.bitcoin),
      _ => throw UtxoWalletException('Unsupported purpose $purpose'),
    };
    final path = network.pathFor(
      kind,
      account: account,
      change: change,
      index: index,
    );
    final derived = root.purpose.coin
        .account(account)
        .change(change ? Bip44Changes.chainInt : Bip44Changes.chainExt)
        .addressIndex(index);
    final privateKey = ECPrivate.fromBytes(derived.privateKey.raw);
    final publicKey = privateKey.getPublic();
    final address = _addressFor(publicKey, network, kind);
    return UtxoAccount(
      network: network,
      kind: kind,
      account: account,
      index: index,
      change: change,
      path: path,
      address: address,
      publicKeyHex: publicKey.toHex(),
      privateKey: privateKey,
      compressed: true,
    );
  }

  static UtxoAccount fromWif({
    required String wif,
    required UtxoNetworkSpec network,
    UtxoAddressKind kind = UtxoAddressKind.p2pkh,
  }) {
    final version = network.network.wifNetVer;
    if (version == null) {
      throw UtxoWalletException('${network.name} has no WIF prefix.');
    }
    try {
      final decoded = WifDecoder.decode(wif.trim(), netVer: version);
      final privateKey = ECPrivate.fromBytes(decoded.$1);
      final publicKey = privateKey.getPublic();
      final address = _addressFor(publicKey, network, kind);
      return UtxoAccount(
        network: network,
        kind: kind,
        account: 0,
        index: 0,
        change: false,
        path: 'imported-wif',
        address: address,
        publicKeyHex: publicKey.toHex(),
        privateKey: privateKey,
        compressed: decoded.$2 == PubKeyModes.compressed,
      );
    } on UtxoWalletException {
      rethrow;
    } catch (error) {
      throw UtxoWalletException('Invalid WIF for ${network.name}: $error');
    }
  }

  static UtxoAccount fromHex({
    required String privateKeyHex,
    required UtxoNetworkSpec network,
    UtxoAddressKind kind = UtxoAddressKind.p2pkh,
    bool compressed = true,
  }) {
    try {
      final normalized = privateKeyHex.startsWith('0x')
          ? privateKeyHex.substring(2)
          : privateKeyHex;
      final privateKey = ECPrivate.fromHex(normalized);
      final publicKey = privateKey.getPublic();
      final address = _addressFor(publicKey, network, kind);
      return UtxoAccount(
        network: network,
        kind: kind,
        account: 0,
        index: 0,
        change: false,
        path: 'imported-hex',
        address: address,
        publicKeyHex: publicKey.toHex(),
        privateKey: privateKey,
        compressed: compressed,
      );
    } catch (error) {
      throw UtxoWalletException('Invalid private key hex: $error');
    }
  }

  static String exportWif(
    ECPrivate privateKey,
    UtxoNetworkSpec network, {
    bool compressed = true,
  }) {
    final version = network.network.wifNetVer;
    if (version == null) {
      throw UtxoWalletException('${network.name} has no WIF prefix.');
    }
    return WifEncoder.encode(
      privateKey.toBytes(),
      netVer: version,
      pubKeyMode: compressed
          ? PubKeyModes.compressed
          : PubKeyModes.uncompressed,
    );
  }

  static bool validateAddress(String address, UtxoNetworkSpec network) {
    try {
      BitcoinAddressUtils.decodeAddress(address.trim(), network.network);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _addressFor(
    ECPublic publicKey,
    UtxoNetworkSpec network,
    UtxoAddressKind kind,
  ) {
    return switch (kind) {
      UtxoAddressKind.p2pkh => publicKey.toAddress().toAddress(network.network),
      UtxoAddressKind.p2shP2wpkh => publicKey.toP2wpkhInP2sh().toAddress(
        network.network,
      ),
      UtxoAddressKind.p2wpkh => publicKey.toSegwitAddress().toAddress(
        network.network,
      ),
      UtxoAddressKind.p2tr => publicKey.toTaprootAddress().toAddress(
        network.network,
      ),
    };
  }

  static Bip44Coins _bip44Coin(UtxoNetworkSpec network) {
    return switch ((network.chain, network.isTestnet)) {
      (UtxoChain.bitcoin, false) => Bip44Coins.bitcoin,
      (UtxoChain.bitcoin, true) => Bip44Coins.bitcoinTestnet,
      (UtxoChain.litecoin, false) => Bip44Coins.litecoin,
      (UtxoChain.litecoin, true) => Bip44Coins.litecoinTestnet,
      (UtxoChain.dogecoin, false) => Bip44Coins.dogecoin,
      (UtxoChain.dogecoin, true) => Bip44Coins.dogecoinTestnet,
    };
  }

  static Bip49Coins _bip49Coin(UtxoNetworkSpec network) {
    return switch ((network.chain, network.isTestnet)) {
      (UtxoChain.bitcoin, false) => Bip49Coins.bitcoin,
      (UtxoChain.bitcoin, true) => Bip49Coins.bitcoinTestnet,
      (UtxoChain.litecoin, false) => Bip49Coins.litecoin,
      (UtxoChain.litecoin, true) => Bip49Coins.litecoinTestnet,
      _ => throw UtxoWalletException('${network.name} does not support BIP49.'),
    };
  }

  static Bip84Coins _bip84Coin(UtxoNetworkSpec network) {
    return switch ((network.chain, network.isTestnet)) {
      (UtxoChain.bitcoin, false) => Bip84Coins.bitcoin,
      (UtxoChain.bitcoin, true) => Bip84Coins.bitcoinTestnet,
      (UtxoChain.litecoin, false) => Bip84Coins.litecoin,
      (UtxoChain.litecoin, true) => Bip84Coins.litecoinTestnet,
      _ => throw UtxoWalletException('${network.name} does not support BIP84.'),
    };
  }
}

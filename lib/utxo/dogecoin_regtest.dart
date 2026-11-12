import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

/// Dogecoin regtest uses the testnet BIP32 coin but a different P2PKH prefix
/// (0x6f) from public Dogecoin testnet (0x71). This class exists so the same
/// address/transaction code can be exercised against a local Dogecoin Core
/// regtest node without pretending the public testnet parameters are correct.
class DogecoinRegtestNetwork implements BasedUtxoNetwork {
  const DogecoinRegtestNetwork();

  @override
  List<int>? get wifNetVer => const [0xef];

  @override
  List<int>? get p2pkhNetVer => const [0x6f];

  @override
  List<int>? get p2shNetVer => const [0xc4];

  @override
  String? get p2wpkhHrp => null;

  @override
  CoinConf get conf => CoinsConf.dogecoinTestNet;

  @override
  List<BitcoinAddressType> get supportedAddress => [P2pkhAddressType.p2pkh];

  @override
  String get identifier => 'dogecoin:regtest';

  @override
  String get name => 'DogecoinRegtest';

  @override
  int get tag => 999;

  @override
  List<BipCoins> get coins => const [Bip44Coins.dogecoinTestnet];

  @override
  bool get isMainnet => false;
}

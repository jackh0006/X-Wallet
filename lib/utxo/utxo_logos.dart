import 'utxo_network.dart';

/// Official chain marks are shipped locally; the wallet never fetches a logo.
class UtxoLogos {
  UtxoLogos._();

  static String assetFor(UtxoChain chain) => switch (chain) {
    UtxoChain.bitcoin => 'assets/tokens/btc.png',
    UtxoChain.litecoin => 'assets/tokens/ltc.png',
    UtxoChain.dogecoin => 'assets/tokens/doge.png',
  };
}

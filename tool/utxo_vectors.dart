// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  final out = <Map<String, String>>[];
  for (final network in UtxoNetworks.all) {
    for (final kind in network.addressKinds) {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: network,
        kind: kind,
      );
      out.add({
        'network': network.key,
        'kind': kind.name,
        'path': account.path,
        'address': account.address,
        'pubkey': account.publicKeyHex,
      });
    }
  }
  print(jsonEncode(out));
}

// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main(List<String> args) {
  final kind = UtxoAddressKind.values.firstWhere(
    (k) => k.name == (args.isEmpty ? 'p2pkh' : args.first),
  );
  final index = args.length > 1 ? int.parse(args[1]) : 0;
  final change = args.length > 2 && args[2] == 'change';
  final account = UtxoWallet.derive(
    phrase: _phrase,
    network: UtxoNetworks.byKey(args.length > 3 ? args[3] : 'btc-testnet'),
    kind: kind,
    index: index,
    change: change,
  );
  print(
    jsonEncode({
      'address': account.address,
      'path': account.path,
      'wif': account.wif,
      'pubkey': account.publicKeyHex,
    }),
  );
}

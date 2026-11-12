// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_transaction.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main(List<String> args) {
  if (args.length < 6) {
    throw StateError('usage: txid vout valueSats amountSats feeRate toAddress');
  }
  final network = UtxoNetworks.byKey(args.length > 6 ? args[6] : 'btc-testnet');
  final account = UtxoWallet.derive(
    phrase: _phrase,
    network: network,
    kind: UtxoAddressKind.p2pkh,
  );
  final change = UtxoWallet.derive(
    phrase: _phrase,
    network: network,
    kind: UtxoAddressKind.p2pkh,
    change: true,
  );
  final plan = UtxoTransactionEngine.planAndSign(
    account: account,
    changeAccount: change,
    recipient: args[5],
    amountSatoshi: int.parse(args[3]),
    feeRateSatPerVbyte: int.parse(args[4]),
    available: [
      Utxo(
        txid: args[0],
        vout: int.parse(args[1]),
        valueSatoshi: int.parse(args[2]),
        confirmed: true,
      ),
    ],
  );
  print(
    jsonEncode({
      'raw': plan.rawHex,
      'txid': plan.txId,
      'fee': plan.feeSatoshi,
      'change': plan.changeSatoshi,
      'changeAddress': change.address,
      'owner': account.address,
    }),
  );
}

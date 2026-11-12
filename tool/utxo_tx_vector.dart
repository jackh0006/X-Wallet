// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_transaction.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';
import 'package:bitcoin_base/bitcoin_base.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _txid =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  final out = <Map<String, Object>>[];
  for (final spec in [
    (UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh, 100000, 50000, 2),
    (UtxoNetworks.btcMainnet, UtxoAddressKind.p2tr, 100000, 50000, 2),
    (UtxoNetworks.ltcMainnet, UtxoAddressKind.p2wpkh, 100000, 50000, 2),
    (UtxoNetworks.dogeMainnet, UtxoAddressKind.p2pkh, 10000000, 2000000, 100),
  ]) {
    final network = spec.$1;
    final kind = spec.$2;
    final account = UtxoWallet.derive(
      phrase: _phrase,
      network: network,
      kind: kind,
    );
    final change = UtxoWallet.derive(
      phrase: _phrase,
      network: network,
      kind: kind,
      change: true,
    );
    final recipient = UtxoWallet.derive(
      phrase: _phrase,
      network: network,
      kind: kind,
      index: 1,
    ).address;
    final plan = UtxoTransactionEngine.planAndSign(
      account: account,
      changeAccount: change,
      recipient: recipient,
      amountSatoshi: spec.$4,
      feeRateSatPerVbyte: spec.$5,
      available: [
        Utxo(txid: _txid, vout: 0, valueSatoshi: spec.$3, confirmed: true),
      ],
    );
    final ownerAddress = BitcoinAddressUtils.decodeAddress(
      account.address,
      network.network,
    );
    out.add({
      'network': network.key,
      'kind': kind.name,
      'ownerAddress': account.address,
      'prevoutScript': ownerAddress.toScriptPubKey().toHex(),
      'prevoutValue': spec.$3,
      'raw': plan.rawHex,
      'txid': plan.txId,
      'fee': plan.feeSatoshi,
      'change': plan.changeSatoshi,
      'recipient': recipient,
      'changeAddress': change.address,
      'amount': plan.amountSatoshi,
    });
  }
  print(jsonEncode(out));
}

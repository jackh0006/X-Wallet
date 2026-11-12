import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_transaction.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _txid =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  UtxoAccount accountFor(UtxoNetworkSpec network, UtxoAddressKind kind) =>
      UtxoWallet.derive(
        phrase: _phrase,
        network: network,
        kind: kind,
        index: 0,
      );

  UtxoAccount changeFor(UtxoNetworkSpec network, UtxoAddressKind kind) =>
      UtxoWallet.derive(
        phrase: _phrase,
        network: network,
        kind: kind,
        change: true,
        index: 0,
      );

  UtxoTransactionPlan plan(
    UtxoNetworkSpec network,
    UtxoAddressKind kind, {
    int amount = 50000,
  }) {
    final account = accountFor(network, kind);
    final change = changeFor(network, kind);
    final recipient = UtxoWallet.derive(
      phrase: _phrase,
      network: network,
      kind: kind,
      index: 1,
    ).address;
    return UtxoTransactionEngine.planAndSign(
      account: account,
      changeAccount: change,
      recipient: recipient,
      amountSatoshi: amount,
      feeRateSatPerVbyte: 2,
      available: const [
        Utxo(
          txid: _txid,
          vout: 0,
          valueSatoshi: 100000,
          confirmed: true,
          blockHeight: 800000,
        ),
      ],
    );
  }

  test('Bitcoin native SegWit transaction builds and balances', () {
    final p = plan(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    expect(p.rawHex, isNotEmpty);
    expect(p.txId, hasLength(64));
    expect(p.feeSatoshi, greaterThan(0));
    expect(p.changeSatoshi, greaterThan(0));
    expect(p.feeSatoshi + p.changeSatoshi + p.amountSatoshi, 100000);
    expect(p.vsize, greaterThan(0));
    expect(p.totalDebitSatoshi, p.amountSatoshi + p.feeSatoshi);
  });

  test('Bitcoin Taproot transaction builds', () {
    final p = plan(UtxoNetworks.btcMainnet, UtxoAddressKind.p2tr);
    expect(p.rawHex, startsWith('02'));
    expect(p.txId, hasLength(64));
  });

  test('Bitcoin legacy and nested SegWit build', () {
    for (final kind in [UtxoAddressKind.p2pkh, UtxoAddressKind.p2shP2wpkh]) {
      final p = plan(UtxoNetworks.btcMainnet, kind);
      expect(p.rawHex, isNotEmpty, reason: kind.name);
    }
  });

  test('Litecoin SegWit and legacy build', () {
    for (final kind in [UtxoAddressKind.p2pkh, UtxoAddressKind.p2wpkh]) {
      final p = plan(UtxoNetworks.ltcMainnet, kind);
      expect(p.rawHex, isNotEmpty, reason: kind.name);
    }
  });

  test('Dogecoin legacy builds', () {
    final account = accountFor(UtxoNetworks.dogeMainnet, UtxoAddressKind.p2pkh);
    final change = changeFor(UtxoNetworks.dogeMainnet, UtxoAddressKind.p2pkh);
    final p = UtxoTransactionEngine.planAndSign(
      account: account,
      changeAccount: change,
      recipient: change.address,
      amountSatoshi: 2000000,
      feeRateSatPerVbyte: 100,
      available: const [
        Utxo(txid: _txid, vout: 0, valueSatoshi: 10000000, confirmed: true),
      ],
    );
    expect(p.rawHex, isNotEmpty);
  });

  test('same inputs produce the same raw transaction', () {
    final a = plan(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    final b = plan(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    expect(a.rawHex, b.rawHex);
    expect(a.txId, b.txId);
  });

  test('insufficient funds is refused', () {
    final account = accountFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    final change = changeFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    expect(
      () => UtxoTransactionEngine.planAndSign(
        account: account,
        changeAccount: change,
        recipient: change.address,
        amountSatoshi: 200000,
        feeRateSatPerVbyte: 2,
        available: const [
          Utxo(txid: _txid, vout: 0, valueSatoshi: 100000, confirmed: true),
        ],
      ),
      throwsA(isA<UtxoTransactionException>()),
    );
  });

  test('wrong-network recipient is refused', () {
    final account = accountFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    final change = changeFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    final ltc = UtxoWallet.derive(
      phrase: _phrase,
      network: UtxoNetworks.ltcMainnet,
      kind: UtxoAddressKind.p2wpkh,
      index: 1,
    ).address;
    expect(
      () => UtxoTransactionEngine.planAndSign(
        account: account,
        changeAccount: change,
        recipient: ltc,
        amountSatoshi: 50000,
        feeRateSatPerVbyte: 2,
        available: const [
          Utxo(txid: _txid, vout: 0, valueSatoshi: 100000, confirmed: true),
        ],
      ),
      throwsA(isA<UtxoTransactionException>()),
    );
  });

  test('zero amount and unconfirmed-only sets are refused', () {
    final account = accountFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    final change = changeFor(UtxoNetworks.btcMainnet, UtxoAddressKind.p2wpkh);
    expect(
      () => UtxoTransactionEngine.planAndSign(
        account: account,
        changeAccount: change,
        recipient: change.address,
        amountSatoshi: 0,
        feeRateSatPerVbyte: 2,
        available: const [],
      ),
      throwsA(isA<UtxoTransactionException>()),
    );
    expect(
      () => UtxoTransactionEngine.planAndSign(
        account: account,
        changeAccount: change,
        recipient: change.address,
        amountSatoshi: 1000,
        feeRateSatPerVbyte: 2,
        available: const [
          Utxo(txid: _txid, vout: 0, valueSatoshi: 100000, confirmed: false),
        ],
      ),
      throwsA(isA<UtxoTransactionException>()),
    );
  });
}

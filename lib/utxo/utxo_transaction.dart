import 'package:bitcoin_base/bitcoin_base.dart';

import 'utxo_network.dart';
import 'utxo_wallet.dart';

class UtxoTransactionException implements Exception {
  const UtxoTransactionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Utxo {
  const Utxo({
    required this.txid,
    required this.vout,
    required this.valueSatoshi,
    required this.confirmed,
    this.blockHeight = 0,
  });

  final String txid;
  final int vout;
  final int valueSatoshi;
  final bool confirmed;
  final int blockHeight;
}

class UtxoTransactionPlan {
  const UtxoTransactionPlan({
    required this.rawHex,
    required this.txId,
    required this.feeSatoshi,
    required this.changeSatoshi,
    required this.vsize,
    required this.inputs,
    required this.recipient,
    required this.amountSatoshi,
    required this.network,
  });

  final String rawHex;
  final String txId;
  final int feeSatoshi;
  final int changeSatoshi;
  final int vsize;
  final List<Utxo> inputs;
  final String recipient;
  final int amountSatoshi;
  final UtxoNetworkSpec network;

  int get totalDebitSatoshi => amountSatoshi + feeSatoshi;
}

class UtxoTransactionEngine {
  UtxoTransactionEngine._();

  /// Greedy largest-first selection with fee estimation at each step.
  static UtxoTransactionPlan planAndSign({
    required UtxoAccount account,
    required UtxoAccount changeAccount,
    required String recipient,
    required int amountSatoshi,
    required int feeRateSatPerVbyte,
    required List<Utxo> available,
    bool replaceable = true,
  }) {
    if (amountSatoshi <= 0) {
      throw const UtxoTransactionException('Amount must be greater than zero.');
    }
    if (feeRateSatPerVbyte <= 0 || feeRateSatPerVbyte > 100000) {
      throw const UtxoTransactionException('Invalid fee rate.');
    }
    if (!UtxoWallet.validateAddress(recipient, account.network)) {
      throw UtxoTransactionException(
        'Recipient is not a valid ${account.network.name} address.',
      );
    }
    if (!UtxoWallet.validateAddress(changeAccount.address, account.network)) {
      throw const UtxoTransactionException('Change address is invalid.');
    }
    final spendable = [
      for (final utxo in available)
        if (utxo.confirmed && utxo.valueSatoshi > 0) utxo,
    ]..sort((a, b) => b.valueSatoshi.compareTo(a.valueSatoshi));
    if (spendable.isEmpty) {
      throw const UtxoTransactionException('No confirmed spendable outputs.');
    }

    final ownerAddress = BitcoinAddressUtils.decodeAddress(
      account.address,
      account.network.network,
    );
    final recipientAddress = BitcoinAddressUtils.decodeAddress(
      recipient,
      account.network.network,
    );
    final changeAddress = BitcoinAddressUtils.decodeAddress(
      changeAccount.address,
      account.network.network,
    );

    UtxoWithAddress wrap(Utxo utxo) => UtxoWithAddress(
      utxo: BitcoinUtxo(
        txHash: utxo.txid,
        value: BigInt.from(utxo.valueSatoshi),
        vout: utxo.vout,
        scriptType: ownerAddress.type,
        blockHeight: utxo.blockHeight,
      ),
      ownerDetails: UtxoAddressDetails(
        publicKey: account.publicKeyHex,
        address: ownerAddress,
      ),
    );

    final selected = <Utxo>[];
    var total = 0;
    var change = 0;
    var fee = 0;
    var outputs = <BitcoinBaseOutput>[];
    var vsize = 0;
    final useChange = account.network.dustSatoshi >= 0;

    for (final utxo in spendable) {
      selected.add(utxo);
      total += utxo.valueSatoshi;
      final baseOutputs = <BitcoinBaseOutput>[
        BitcoinOutput(
          address: recipientAddress,
          value: BigInt.from(amountSatoshi),
        ),
        if (useChange)
          BitcoinOutput(address: changeAddress, value: BigInt.zero),
      ];
      vsize = BitcoinTransactionBuilder.estimateTransactionSize(
        utxos: selected.map(wrap).toList(growable: false),
        outputs: baseOutputs,
        network: account.network.network,
        enableRBF: replaceable && account.network.supportsRbf,
      );
      fee = vsize * feeRateSatPerVbyte;
      if (total >= amountSatoshi + fee) break;
    }
    if (total < amountSatoshi + fee) {
      throw const UtxoTransactionException(
        'Not enough confirmed funds for the amount and fee.',
      );
    }

    change = total - amountSatoshi - fee;
    if (change < account.network.dustSatoshi) {
      // Dust change is uneconomical; add it to the fee instead of creating an
      // unspendable output.
      fee = total - amountSatoshi;
      change = 0;
      outputs = [
        BitcoinOutput(
          address: recipientAddress,
          value: BigInt.from(amountSatoshi),
        ),
      ];
    } else {
      outputs = [
        BitcoinOutput(
          address: recipientAddress,
          value: BigInt.from(amountSatoshi),
        ),
        BitcoinOutput(address: changeAddress, value: BigInt.from(change)),
      ];
    }

    final wrapped = selected.map(wrap).toList(growable: false);
    final builder = BitcoinTransactionBuilder(
      outPuts: outputs,
      fee: BigInt.from(fee),
      network: account.network.network,
      utxos: wrapped,
      enableRBF: replaceable && account.network.supportsRbf,
    );
    final tx = builder.buildTransaction((digest, utxo, publicKey, sighash) {
      if (publicKey != account.publicKeyHex) {
        throw const UtxoTransactionException(
          'A selected output belongs to a different key.',
        );
      }
      if (utxo.utxo.isP2tr) {
        return account.privateKey.signBip340(digest, sighash: sighash);
      }
      return account.privateKey.signECDSA(digest, sighash: sighash);
    });
    final raw = tx.serialize();
    final txId = tx.txId();
    final finalVsize = tx.hasWitness ? tx.getVSize() : tx.getSize();
    return UtxoTransactionPlan(
      rawHex: raw,
      txId: txId,
      feeSatoshi: fee,
      changeSatoshi: change,
      vsize: finalVsize,
      inputs: List.unmodifiable(selected),
      recipient: recipient,
      amountSatoshi: amountSatoshi,
      network: account.network,
    );
  }
}

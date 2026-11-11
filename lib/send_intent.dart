import 'dart:typed_data';

/// Round-6 terminal parity: pre-signature intent verification.
///
/// The terminal wallet (v1, `src/index.js` → `verifyTransactionIntent`) re-checks
/// every field of the transaction object against the values the user reviewed,
/// right before signing, and refuses to sign on any mismatch. This is the GUI
/// equivalent, kept as pure functions so it can be unit-tested byte-for-byte.
///
/// The point is defense in depth: even if a future change (or a bug) altered
/// the recipient, amount, contract or fee between the review screen and the
/// signature, the signature is refused instead of silently sending the wrong
/// transaction.
class SendIntent {
  SendIntent._();

  static const String _transferSelector = 'a9059cbb';
  static const String _zeros24 = '000000000000000000000000';

  /// Gas limit for the reviewed transfer: estimate + 20% headroom, rounded UP
  /// so the limit can never close below the simulation. Exact terminal v1
  /// formula: `(gasEstimate * 120n + 99n) / 100n`.
  static BigInt gasLimitWithBuffer(BigInt gasEstimate) =>
      (gasEstimate * BigInt.from(120) + BigInt.from(99)) ~/ BigInt.from(100);

  /// Decodes (recipient, amount) from ERC-20 `transfer` calldata.
  /// Throws [StateError] when the bytes are not exactly that call: the
  /// selector, one address word and one amount word, and nothing else.
  /// Trailing bytes are rejected because a non-standard token could act on
  /// them while the review screen still showed a plain transfer.
  static (String, BigInt) decodeErc20Transfer(Uint8List data) {
    final hex = _hex(data);
    if (!hex.startsWith(_transferSelector) || hex.length != 8 + 64 + 64) {
      throw StateError('Calldata is not an exact ERC-20 transfer.');
    }
    final recipientWord = hex.substring(8, 8 + 64);
    final amountWord = hex.substring(8 + 64, 8 + 128);
    if (!recipientWord.startsWith(_zeros24)) {
      throw StateError('Transfer recipient is not a plain address.');
    }
    return (
      '0x${recipientWord.substring(24)}',
      BigInt.parse(amountWord, radix: 16),
    );
  }

  /// Refuses (throws [StateError]) when the transaction that is about to be
  /// SIGNED no longer matches what the user reviewed.
  ///
  /// Mirrors the terminal checks one-to-one:
  ///  · chain id did not change between review and signing
  ///  · the gas limit is present and positive
  ///  · native: exact recipient, exact value, no calldata
  ///  · token: exact contract as `to`, zero value, calldata decodes to the
  ///    exact recipient and amount
  ///  · fees equal the chosen preset (EIP-1559 pair, or legacy gas price)
  static void verify({
    required int chainId,
    required int intendedChainId,
    required bool native,
    required String intendedRecipient, // checksummed
    required BigInt intendedAmount,
    required String tokenAddress, // contract the token transfer targets
    required String txTo, // what the signed transaction actually targets
    required BigInt? txValue, // wei for native; null/zero for token
    required Uint8List txData,
    required BigInt? txGasLimit,
    required BigInt? txGasPrice,
    required BigInt? txMaxFeePerGas,
    required BigInt? txMaxPriorityFeePerGas,
    required String feeMode,
    required BigInt expectedGasPrice, // legacy preset
    required BigInt expectedMaxFee, // eip1559 preset
    required BigInt expectedPriority, // eip1559 preset
    int? nonce, // reviewed nonce
    String? from, // reviewed sender
    int? txNonce, // nonce in the exact signed object
    String? txFrom, // sender in the exact signed object
  }) {
    if (nonce != null && txNonce != nonce) {
      throw StateError(
        'Transaction nonce changed after review. Refusing to sign.',
      );
    }
    if (from != null && txFrom != null && !_sameAddress(from, txFrom)) {
      throw StateError(
        'Transaction sender changed after review. Refusing to sign.',
      );
    }
    if (chainId != intendedChainId) {
      throw StateError(
        'Transaction chain id changed after review. Refusing to sign.',
      );
    }
    if (txGasLimit == null || txGasLimit <= BigInt.zero) {
      throw StateError('Transaction has no safe gas limit. Refusing to sign.');
    }
    if (!_sameAddress(txTo, native ? intendedRecipient : tokenAddress)) {
      throw StateError(
        native
            ? 'Native-transfer details changed after review. Refusing to sign.'
            : 'Token contract changed after review. Refusing to sign.',
      );
    }
    if (native) {
      if (txValue != intendedAmount || txData.isNotEmpty) {
        throw StateError(
          'Native-transfer details changed after review. Refusing to sign.',
        );
      }
    } else {
      if (txValue != null && txValue != BigInt.zero) {
        throw StateError(
          'Token transfer value changed after review. Refusing to sign.',
        );
      }
      final (recipient, amount) = decodeErc20Transfer(txData);
      if (!_sameAddress(recipient, intendedRecipient) ||
          amount != intendedAmount) {
        throw StateError(
          'Token recipient or amount changed after review. Refusing to sign.',
        );
      }
    }
    if (feeMode == 'eip1559') {
      if (txMaxFeePerGas != expectedMaxFee ||
          txMaxPriorityFeePerGas != expectedPriority) {
        throw StateError(
          'EIP-1559 fee changed after review. Refusing to sign.',
        );
      }
    } else if (txGasPrice != expectedGasPrice) {
      throw StateError('Gas price changed after review. Refusing to sign.');
    }
  }

  static bool _sameAddress(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  static String _hex(Uint8List data) {
    final sb = StringBuffer();
    for (final b in data) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

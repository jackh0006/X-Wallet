import 'wallet_core.dart';

/// Local, user-controlled safety limits for signing.
///
/// This is not a substitute for a hardware wallet or an independent audit. It
/// prevents accidental large transfers and can lock signing entirely.
class SpendingPolicy {
  const SpendingPolicy({
    required this.frozen,
    required this.maxPerTxWei,
    required this.allowlist,
  });

  final bool frozen;
  final BigInt maxPerTxWei;
  final Set<String> allowlist;

  bool get hasMaxPerTx => maxPerTxWei > BigInt.zero;
  bool get hasAllowlist => allowlist.isNotEmpty;

  /// Returns a human-readable refusal, or null when the transfer is allowed.
  String? rejection({
    required BigInt nativeAmountWei,
    required String recipient,
  }) {
    if (frozen) {
      return 'Signing is frozen in Settings → Spending safety. Unfreeze it '
          'deliberately before sending.';
    }
    final normalized = recipient.trim().toLowerCase();
    if (hasAllowlist &&
        !allowlist.contains(normalized) &&
        !allowlist.contains(
          WalletCore.checksumAddress(recipient).toLowerCase(),
        )) {
      return 'This recipient is not in your allowlist. Add it in Settings → '
          'Spending safety, or clear the allowlist deliberately.';
    }
    if (hasMaxPerTx && nativeAmountWei > maxPerTxWei) {
      return 'This native transfer is above your per-transaction safety limit '
          '${WalletCore.formatEther(maxPerTxWei)} BNB. Raise the limit in '
          'Settings → Spending safety if this is intentional.';
    }
    return null;
  }
}

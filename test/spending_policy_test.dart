import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/spending_policy.dart';

void main() {
  const recipient = '0x1111111111111111111111111111111111111111';

  test('frozen policy rejects every transfer', () {
    final policy = SpendingPolicy(
      frozen: true,
      maxPerTxWei: BigInt.zero,
      allowlist: {},
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.one, recipient: recipient),
      isNotNull,
    );
  });

  test('allowlist rejects an unknown recipient', () {
    final policy = SpendingPolicy(
      frozen: false,
      maxPerTxWei: BigInt.zero,
      allowlist: {'0x2222222222222222222222222222222222222222'},
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.one, recipient: recipient),
      isNotNull,
    );
  });

  test('allowlist accepts a listed recipient case-insensitively', () {
    final policy = SpendingPolicy(
      frozen: false,
      maxPerTxWei: BigInt.zero,
      allowlist: {'0x1111111111111111111111111111111111111111'},
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.one, recipient: recipient),
      isNull,
    );
  });

  test('per-transaction native limit rejects above the cap', () {
    final policy = SpendingPolicy(
      frozen: false,
      maxPerTxWei: BigInt.from(100),
      allowlist: {},
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.from(101), recipient: recipient),
      isNotNull,
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.from(100), recipient: recipient),
      isNull,
    );
  });

  test('token transfers do not hit the native max', () {
    final policy = SpendingPolicy(
      frozen: false,
      maxPerTxWei: BigInt.from(100),
      allowlist: {},
    );
    expect(
      policy.rejection(nativeAmountWei: BigInt.zero, recipient: recipient),
      isNull,
    );
  });
}

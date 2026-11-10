import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/security.dart';

void main() {
  test('weak PINs are rejected', () {
    for (final pin in [
      '12345',
      '123456',
      '654321',
      '000000',
      '111111',
      '121212',
      '112233',
      '123123',
      'abcdef',
      '',
    ]) {
      expect(
        AppSecurity.isWeakPin(pin),
        isTrue,
        reason: '$pin must be rejected as a new PIN',
      );
    }
  });

  test('non-trivial six-digit PINs are accepted', () {
    for (final pin in ['482915', '907314', '604827']) {
      expect(
        AppSecurity.isWeakPin(pin),
        isFalse,
        reason: '$pin should be accepted',
      );
    }
  });
}

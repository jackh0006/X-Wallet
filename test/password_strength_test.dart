import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/password_strength.dart';

void main() {
  test('empty password is very weak', () {
    final result = evaluatePassword('');
    expect(result.level, PasswordStrength.veryWeak);
    expect(result.label, 'Very weak');
  });

  test('short password is weak even with mixed characters', () {
    final result = evaluatePassword('aB3!');
    expect(result.isWeak, isTrue);
  });

  test('common password is rejected by the score', () {
    final result = evaluatePassword('password123');
    expect(result.isWeak, isTrue);
    expect(result.score, lessThanOrEqualTo(2));
  });

  test('long mixed passphrase is very strong', () {
    final result = evaluatePassword('Correct-Horse-Battery-Staple-2026!');
    expect(result.level, PasswordStrength.veryStrong);
    expect(result.score, greaterThanOrEqualTo(6));
  });

  test('a short password is allowed by the scorer, only scored low', () {
    final result = evaluatePassword('abc');
    expect(result.label, 'Very weak');
    expect(result.advice, isNotEmpty);
  });
}

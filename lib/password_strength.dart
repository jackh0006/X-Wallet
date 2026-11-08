/// Password-strength scoring for the local vault.
///
/// This is guidance for the person choosing a password. It is not a policy
/// gate: the vault accepts any non-empty password, because the owner may use a
/// password manager, a long passphrase, or a legacy password. The score is
/// shown so a weak choice is visible before the vault is created.
enum PasswordStrength { veryWeak, weak, fair, strong, veryStrong }

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.level,
    required this.score,
    required this.label,
    required this.advice,
  });

  final PasswordStrength level;
  final int score;
  final String label;
  final String advice;

  bool get isWeak =>
      level == PasswordStrength.veryWeak || level == PasswordStrength.weak;
}

const _commonPasswords = <String>{
  'password',
  'password1',
  'password123',
  '123456',
  '12345678',
  '123456789',
  'qwerty',
  'qwerty123',
  'abc123',
  'letmein',
  'welcome',
  'admin',
  'iloveyou',
  'monkey',
  'dragon',
  'football',
  'baseball',
  'sunshine',
  'princess',
  'trustno1',
  'master',
  'shadow',
  'superman',
  'michael',
  'ninja',
  'mustang',
  'access',
  'flower',
  'hello',
  'freedom',
  'whatever',
  'wallet',
  'bitcoin',
  'crypto',
  'ethereum',
  'binance',
};

bool _isSequential(String value) {
  if (value.length < 4) return false;
  var ascending = true;
  var descending = true;
  for (var i = 1; i < value.length; i++) {
    final delta = value.codeUnitAt(i) - value.codeUnitAt(i - 1);
    if (delta != 1) ascending = false;
    if (delta != -1) descending = false;
  }
  return ascending || descending;
}

bool _isRepeated(String value) {
  if (value.length < 4) return false;
  return value.split('').toSet().length == 1;
}

/// Scores [password] from 0 (very weak) to 7 (very strong).
PasswordStrengthResult evaluatePassword(String password) {
  if (password.isEmpty) {
    return const PasswordStrengthResult(
      level: PasswordStrength.veryWeak,
      score: 0,
      label: 'Very weak',
      advice: 'Enter a password or passphrase.',
    );
  }

  final normalized = password.toLowerCase();
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  final common = _commonPasswords.contains(normalized);
  final repeated = _isRepeated(password);
  final sequential = _isSequential(normalized);

  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (password.length >= 20) score++;
  if (hasLower && hasUpper) score++;
  if (hasDigit) score++;
  if (hasSymbol) score++;

  if (password.length < 8) score = score.clamp(0, 1);
  if (common || repeated || sequential) score = score.clamp(0, 2);
  if (common || repeated) score = score.clamp(0, 1);

  final level = switch (score) {
    <= 1 => PasswordStrength.veryWeak,
    2 => PasswordStrength.weak,
    3 => PasswordStrength.fair,
    <= 5 => PasswordStrength.strong,
    _ => PasswordStrength.veryStrong,
  };

  final advice = switch (level) {
    PasswordStrength.veryWeak =>
      'Add length and mix letters, numbers, and symbols. Avoid common words.',
    PasswordStrength.weak =>
      'Use at least 12 characters with several character types.',
    PasswordStrength.fair =>
      'Add length or another character type for a stronger vault password.',
    PasswordStrength.strong =>
      'Good password. A longer passphrase is even stronger.',
    PasswordStrength.veryStrong =>
      'Very strong. Keep it offline and never reuse it.',
  };

  return PasswordStrengthResult(
    level: level,
    score: score,
    label: switch (level) {
      PasswordStrength.veryWeak => 'Very weak',
      PasswordStrength.weak => 'Weak',
      PasswordStrength.fair => 'Fair',
      PasswordStrength.strong => 'Strong',
      PasswordStrength.veryStrong => 'Very strong',
    },
    advice: advice,
  );
}

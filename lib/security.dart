import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:local_auth/local_auth.dart';

import 'storage.dart';
import 'workers.dart';

/// Biometric/PIN unlock helpers.
///
/// The optional app-lock PIN is verified with Argon2id (64 MiB, t=3, p=4 —
/// the same envelope as the vault): a leaked `salt:hash` string is no longer
/// cheap to brute-force. Only the salted hash lives in secure storage, never
/// the PIN. Failed attempts trigger exponential backoff in seconds,
/// `min(2^(n-1), 900)`, persisted with the flag so restarts cannot cheat it.
class AppSecurity {
  AppSecurity._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> deviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// A new app PIN must be 6+ digits and must not be trivial.
  ///
  /// Existing vaults keep their old PIN working; this rule applies when a PIN
  /// is created or replaced.
  static bool isWeakPin(String pin) {
    if (!RegExp(r'^[0-9]{6,12}$').hasMatch(pin)) return true;
    if (pin.split('').toSet().length == 1) return true;
    var ascending = true;
    var descending = true;
    for (var i = 1; i < pin.length; i++) {
      final previous = pin.codeUnitAt(i - 1);
      final current = pin.codeUnitAt(i);
      if (current != previous + 1) ascending = false;
      if (current != previous - 1) descending = false;
    }
    if (ascending || descending) return true;
    const common = {
      '121212',
      '112233',
      '123123',
      '159753',
      '147258',
      '258369',
      '123456',
      '654321',
      '111111',
      '000000',
      '666666',
      '999999',
    };
    return common.contains(pin);
  }

  /// Number of PIN failures recorded in the persisted backoff state.
  static Future<int> failedAttempts() async =>
      (await AppStorage.getBackoffState())?.$1 ?? 0;

  static String _salt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static Future<void> setPin(String pin) async {
    final salt = _salt();
    final hash = await _hash(pin, salt);
    // Prefix selects parameters on read; entries written by v1.0.2 had none
    // and are treated as obsolete SHA-256 records (see [pinIsLegacy]).
    await AppStorage.setPinHash('a2:$salt:$hash');
    await AppStorage.clearBackoffState();
  }

  /// True when secure storage holds a pre-1.0.3 (SHA-256, obsolete) record.
  static Future<bool> pinIsLegacy() async {
    final stored = await AppStorage.getPinHash();
    return stored != null && !stored.startsWith('a2:');
  }

  /// Remaining wait time before a PIN entry attempt is allowed, if any.
  static Future<Duration> backoffRemaining() async {
    final state = await AppStorage.getBackoffState();
    if (state == null) return Duration.zero;
    final (count, untilMs) = state;
    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    if (count > 0) {
      // Refresh the stored window so calendar skips do not help.
      final scaled = remaining;
      await AppStorage.setBackoffState(
        count,
        DateTime.now().millisecondsSinceEpoch + scaled.inMilliseconds,
      );
    }
    return remaining;
  }

  static Future<void> registerFailedAttempt() async {
    final state = await AppStorage.getBackoffState();
    final count = (state?.$1 ?? 0) + 1;
    final seconds = min(1 << (count - 1), 900);
    final until = DateTime.now().millisecondsSinceEpoch + seconds * 1000;
    await AppStorage.setBackoffState(count, until);
  }

  static Future<void> clearBackoff() => AppStorage.clearBackoffState();

  static Future<bool> verifyPin(String pin) async {
    final stored = await AppStorage.getPinHash();
    if (stored == null) return true;
    if (!stored.startsWith('a2:')) {
      // Legacy SHA-256 record → obsolete by policy, never accepted.
      await registerFailedAttempt();
      return false;
    }
    final parts = stored.split(':');
    if (parts.length != 3) {
      await registerFailedAttempt();
      return false;
    }
    final computed = await _hash(pin, parts[1]);
    final ok = _constantEquals(utf8.encode(computed), utf8.encode(parts[2]));
    if (!ok) {
      await registerFailedAttempt();
    } else {
      await clearBackoff();
    }
    return ok;
  }

  static Future<bool> hasPin() async => (await AppStorage.getPinHash()) != null;

  static Future<void> clearPin() async {
    await AppStorage.clearPinHash();
    await AppStorage.clearBackoffState();
  }

  static Future<String> _hash(String pin, String salt) async {
    // Argon2 v = 0x13 accepts ≥8-byte salts; the base64 salt string (22 bytes)
    // is passed raw, so the same salt always yields the same record. The work
    // runs on a worker isolate so the UI keeps answering the desktop.
    return compute(pinHashJob, <String>[pin, salt]);
  }

  static bool _constantEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

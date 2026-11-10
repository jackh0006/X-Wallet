import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'kdf.dart';

/// Portable encrypted backup envelope (BNBBKP01).
///
/// The vault envelope (BNBVL004) is deliberately bound to a device secret, so
/// it cannot be restored on a new machine. A disaster-recovery backup must
/// therefore be a separate format that depends only on something the user can
/// carry: the password (plus the recovery phrase for HD accounts).
///
/// Format (all integers little-endian):
///
/// ```
/// header  = magic8 "BNBBKP01" | version(1)=1 | m,t,p (uint32 x3) | salt(16)
/// body    = nonce(24) | ciphertext | mac(16)
/// AAD     = header
/// KDF     = Argon2id v1.3 (64 MiB, t=3, p=4), 32-byte key
/// cipher  = XChaCha20-Poly1305
/// plain   = {"v":1,"kind":"x-wallet-portable-backup","label":...,
///            "createdAt":...,"accounts":[...]}
/// ```
///
/// The payload is the same account list the vault stores, so restore can
/// re-encrypt it under the new device's secret. A backup is offline-guessable
/// with the password alone: use a strong, unique password and store the file
/// offline.
class PortableBackup {
  PortableBackup._();

  static const List<int> magic = [
    0x42, 0x4e, 0x42, 0x42, 0x4b, 0x50, 0x30, 0x31, // "BNBBKP01"
  ];
  static const int version = 1;
  static const int saltLength = 16;
  static const int nonceLength = 24;
  static const int keyLength = 32;
  static const int macLength = 16;
  // Fixed production profile. Tests may lower these ONLY through
  // useFastProfileForTest(), which refuses to run outside flutter test.
  static int memoryKiB = 65536;
  static int iterations = 3;
  static int parallelism = 4;
  static const int headerLength = 8 + 1 + 12 + saltLength; // 37

  @visibleForTesting
  static void useFastProfileForTest() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('The fast backup profile is test-only.');
    }
    memoryKiB = 1024;
    iterations = 1;
    parallelism = 1;
  }

  @visibleForTesting
  static void resetProfileForTest() {
    memoryKiB = 65536;
    iterations = 3;
    parallelism = 4;
  }

  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();

  static String get magicText => utf8.decode(magic);

  static bool isPortableBackup(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length < magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> encrypt({
    required String password,
    required String accountsJson,
    String label = 'Backup',
  }) async {
    if (password.isEmpty) throw ArgumentError('Backup password is required.');
    final accounts = jsonDecode(accountsJson);
    if (accounts is! List) {
      throw const FormatException('Vault payload is not a JSON list.');
    }
    final salt = _random(saltLength);
    final nonce = _random(nonceLength);
    final header = _header(salt);
    final key = await Argon2Kdf.derive(
      password: utf8.encode(password),
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    );
    final plaintext = jsonEncode({
      'v': 1,
      'kind': 'x-wallet-portable-backup',
      'label': label.trim().isEmpty ? 'Backup' : label.trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': accounts,
    });
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: header,
    );
    final out = BytesBuilder();
    out.add(header);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  static Future<PortableBackupData> decrypt({
    required String encoded,
    required String password,
  }) async {
    final bytes = base64Decode(encoded);
    if (bytes.length < headerLength + nonceLength + macLength + 1) {
      throw const FormatException('Backup data is truncated.');
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) {
        throw const FormatException('Not an X Wallet portable backup.');
      }
    }
    final view = ByteData.sublistView(bytes);
    final gotVersion = bytes[magic.length];
    if (gotVersion != version) {
      throw const FormatException('Unsupported backup version.');
    }
    final memory = view.getUint32(magic.length + 1, Endian.little);
    final iters = view.getUint32(magic.length + 5, Endian.little);
    final parallel = view.getUint32(magic.length + 9, Endian.little);
    if (memory != memoryKiB || iters != iterations || parallel != parallelism) {
      throw const FormatException('Unsafe backup parameters.');
    }
    final header = Uint8List.sublistView(bytes, 0, headerLength);
    final salt = Uint8List.sublistView(
      bytes,
      headerLength - saltLength,
      headerLength,
    );
    final nonce = Uint8List.sublistView(
      bytes,
      headerLength,
      headerLength + nonceLength,
    );
    final cipherText = Uint8List.sublistView(
      bytes,
      headerLength + nonceLength,
      bytes.length - macLength,
    );
    final mac = Uint8List.sublistView(bytes, bytes.length - macLength);
    final key = await Argon2Kdf.derive(
      password: utf8.encode(password),
      salt: salt,
      memoryKiB: memory,
      iterations: iters,
      parallelism: parallel,
    );
    final List<int> clear;
    try {
      clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: header,
      );
    } catch (_) {
      throw const FormatException('Wrong password or corrupted backup.');
    }
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map || decoded['kind'] != 'x-wallet-portable-backup') {
      throw const FormatException('Backup payload is not recognised.');
    }
    final accounts = decoded['accounts'];
    if (accounts is! List) {
      throw const FormatException('Backup does not contain an account list.');
    }
    return PortableBackupData(
      label: '${decoded['label'] ?? 'Backup'}',
      createdAt: '${decoded['createdAt'] ?? ''}',
      accountsJson: jsonEncode(accounts),
    );
  }

  static Uint8List _header(Uint8List salt) {
    final out = BytesBuilder()
      ..add(magic)
      ..addByte(version);
    final params = ByteData(12)
      ..setUint32(0, memoryKiB, Endian.little)
      ..setUint32(4, iterations, Endian.little)
      ..setUint32(8, parallelism, Endian.little);
    out
      ..add(params.buffer.asUint8List())
      ..add(salt);
    return out.toBytes();
  }

  static Uint8List _random(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }
}

class PortableBackupData {
  const PortableBackupData({
    required this.label,
    required this.createdAt,
    required this.accountsJson,
  });

  final String label;
  final String createdAt;
  final String accountsJson;
}

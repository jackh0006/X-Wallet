import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/portable_backup.dart';
import 'package:bnb_wallet_gui/vault.dart';

Future<List<int>> fastTestKdf(
  String password,
  List<int> salt, {
  required int memoryKiB,
  required int iterations,
  required int parallelism,
}) async {
  final data = Uint8List.fromList([...utf8.encode(password), ...salt]);
  final out = Uint8List(32);
  for (var i = 0; i < data.length; i++) {
    out[i % 32] ^= data[i] + i;
  }
  return out;
}

void main() {
  const accounts =
      '[{"label":"Main","address":"0x1111111111111111111111111111111111111111",'
      '"privateKeyHex":"0x2222222222222222222222222222222222222222222222222222222222222222"}]';

  setUp(() => PortableBackup.useFastProfileForTest());
  tearDown(() => PortableBackup.resetProfileForTest());

  test('round-trips with the password only', () async {
    final encoded = await PortableBackup.encrypt(
      password: 'correct horse battery staple',
      accountsJson: accounts,
      label: 'Main',
    );
    expect(PortableBackup.isPortableBackup(encoded), isTrue);
    expect(encoded.contains('privateKeyHex'), isFalse);
    final data = await PortableBackup.decrypt(
      encoded: encoded,
      password: 'correct horse battery staple',
    );
    expect(data.label, 'Main');
    expect(jsonDecode(data.accountsJson), jsonDecode(accounts));
  });

  test('a wrong password fails closed', () async {
    final encoded = await PortableBackup.encrypt(
      password: 'right',
      accountsJson: accounts,
    );
    await expectLater(
      PortableBackup.decrypt(encoded: encoded, password: 'wrong'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a single flipped ciphertext byte is rejected', () async {
    final encoded = await PortableBackup.encrypt(
      password: 'right',
      accountsJson: accounts,
    );
    final bytes = base64Decode(encoded);
    bytes[PortableBackup.headerLength + 30] ^= 0x01;
    await expectLater(
      PortableBackup.decrypt(encoded: base64Encode(bytes), password: 'right'),
      throwsA(isA<FormatException>()),
    );
  });

  test('truncated data is rejected before any KDF work', () async {
    final encoded = await PortableBackup.encrypt(
      password: 'right',
      accountsJson: accounts,
    );
    final bytes = base64Decode(encoded).sublist(0, 20);
    await expectLater(
      PortableBackup.decrypt(encoded: base64Encode(bytes), password: 'right'),
      throwsA(isA<FormatException>()),
    );
  });

  test('restores on a fresh device without the old device secret', () async {
    VaultCipher.debugKdfOverride =
        (
          String password,
          List<int> salt,
          int memoryKiB,
          int iterations,
          int parallelism,
        ) => fastTestKdf(
          password,
          salt,
          memoryKiB: memoryKiB,
          iterations: iterations,
          parallelism: parallelism,
        );
    addTearDown(() => VaultCipher.debugKdfOverride = null);

    final backup = await PortableBackup.encrypt(
      password: 'backup-password',
      accountsJson: accounts,
    );
    final data = await PortableBackup.decrypt(
      encoded: backup,
      password: 'backup-password',
    );
    // Model a brand-new install: new device secret, new vault password.
    final newVault = await VaultCipher.encrypt(
      'new-device-password',
      data.accountsJson,
      'new-device-secret',
    );
    final clear = await VaultCipher.decrypt(
      'new-device-password',
      newVault,
      'new-device-secret',
    );
    expect(clear, data.accountsJson);
    await expectLater(
      VaultCipher.decrypt('new-device-password', newVault, 'old-device-secret'),
      throwsA(isA<VaultException>()),
    );
  });
}

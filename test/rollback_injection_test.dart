// Real Argon2id is intentional: these tests prove the full import/commit/
// verification/rollback path, not a mocked approximation.
@Tags(['kdf'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/posix_fs.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/vault.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/temp_dir.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

const _password = 'test-password-123456';
const _deviceSecret = 'kyPz0/cp8BD5wc0dSlsfIjeptDwKRUKe5RGrW6d20ss=';
const _keyHex =
    '0x115b527ce6cb943286dee1503e7645b0d021cc0cd43b9cbf7cb80eeba9db6b49';

Future<String> _vaultBlob(String label) async {
  final key = WalletCore.privateKeyFromHex(_keyHex);
  return VaultCipher.encrypt(
    _password,
    jsonEncode([
      {
        'label': label,
        'address': key.address.eip55With0x,
        'privateKeyHex': WalletCore.privateKeyHex(key),
        'mnemonic':
            'test test test test test test test test test test test junk',
        'savedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      },
    ]),
    _deviceSecret,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late AppState state;
  late int previousUmask;

  setUp(() async {
    PosixFs.selfCheck();
    previousUmask = PosixFs.setUmask(
      63,
    ); // 0077: production-safe directory mode.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    AppStorage.resetPreferencesForTest();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-rollback-injection-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    final vault = await AppStorage.vaultFile();
    await File('${vault.parent.path}/device_secret_v2.drawer')
        .writeAsString(_deviceSecret, flush: true);
    state = AppState();
    state.lock();
  });

  tearDown(() async {
    // `lock()` emits an asynchronous encrypted audit entry.  Calling it here
    // races the immediate removal of this fixture's application-data
    // directory, leaving a newly-created log file behind.  Each setUp creates
    // a fresh state and locks it before use, so no teardown lock is needed.
    StorageDebugHooks.reset();
    AppStorage.resetDeviceSecretMemo();
    await deleteTestDirectory(tmp);
    PosixFs.restoreUmask(previousUmask);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  Future<(String original, String replacement, File vault)> prepare() async {
    final original = await _vaultBlob('Original');
    final replacement = await _vaultBlob('Replacement');
    expect(
      replacement,
      isNot(original),
      reason: 'Each encryption must use fresh random salt/nonces.',
    );
    final vault = await AppStorage.vaultFile();
    await AppStorage.writeVaultAtomic(original);
    await state.init();
    expect(
      state.hasVault,
      true,
      reason: 'Rollback only applies to a prior vault.',
    );
    await File('${tmp.path}/valid-backup.bnb').writeAsString(replacement);
    return (original, replacement, vault);
  }

  Future<void> importValidBackup() => state.importVault(
    '${tmp.path}/valid-backup.bnb',
    password: _password,
    confirmReplace: true,
  );

  test(
    'post-commit verification failure rolls back exact original bytes',
    () async {
      final (original, replacement, vault) = await prepare();
      var commitReached = false;
      AtomicWriteResult? rollback;
      StorageDebugHooks.afterRenameCommit = (_) {
        if (commitReached) return;
        commitReached = true;
        StorageDebugHooks.injectReadbackVerificationFailure = true;
      };
      StorageDebugHooks.afterRollbackWrite = (_, result) => rollback = result;

      await expectLater(importValidBackup(), throwsA(isA<StateError>()));

      expect(commitReached, true, reason: 'The replacement commit must occur.');
      expect(rollback, isNotNull, reason: 'Rollback must be attempted.');
      expect(rollback!.committed, true);
      expect(rollback!.error, isNull);
      expect(await vault.readAsString(), original);
      expect(
        (await state.loadVaultAccounts(_password)).single.label,
        'Original',
      );
      expect(
        await File('${tmp.path}/valid-backup.bnb').readAsString(),
        replacement,
        reason: 'The source backup must never be modified.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'rollback write failure is observable and leaves committed replacement',
    () async {
      final (original, replacement, vault) = await prepare();
      var commitReached = false;
      AtomicWriteResult? rollback;
      final unrelated = File('${tmp.path}/unrelated.txt');
      await unrelated.writeAsString('must survive');
      StorageDebugHooks.afterRenameCommit = (_) {
        if (commitReached) return;
        commitReached = true;
        StorageDebugHooks.injectReadbackVerificationFailure = true;
      };
      StorageDebugHooks.injectRollbackWriteFailure = true;
      StorageDebugHooks.afterRollbackWrite = (_, result) => rollback = result;

      await expectLater(importValidBackup(), throwsA(isA<StateError>()));

      expect(commitReached, true, reason: 'The replacement commit must occur.');
      expect(rollback, isNotNull, reason: 'Rollback must be attempted.');
      expect(
        rollback!.committed,
        false,
        reason: 'Failure injection must reach the rollback write itself.',
      );
      expect(rollback!.error, contains('Injected pre-commit write failure'));
      expect(
        await vault.readAsString(),
        replacement,
        reason: 'Failed rollback must not falsely report restored bytes.',
      );
      expect(await vault.readAsString(), isNot(original));
      expect(await unrelated.readAsString(), 'must survive');
      expect(
        (await state.loadVaultAccounts(_password)).single.label,
        'Replacement',
        reason: 'The committed replacement remains valid for manual recovery.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

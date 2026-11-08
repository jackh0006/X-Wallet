// The vault envelope is overridden with a fast reversible encoder in this
// test; production Argon2id is covered by vault_test.dart and the KDF tests.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/vault.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

const _keyA =
    '0x115b527ce6cb943286dee1503e7645b0d021cc0cd43b9cbf7cb80eeba9db6b49';
const _keyB =
    '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('x-wallet-multi-test-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    appState.lockForTest();
    AppState.vaultEncryptOverride = (password, plaintext, device) async {
      return base64Encode(
        utf8.encode(jsonEncode({'p': password, 'd': device, 'x': plaintext})),
      );
    };
    AppState.vaultDecryptOverride = (password, blob, device) async {
      final data = jsonDecode(utf8.decode(base64Decode(blob)));
      if (data['p'] != password || data['d'] != device) {
        throw const VaultException('Vault authentication failed.');
      }
      return data['x'] as String;
    };
  });

  tearDown(() async {
    AppState.vaultEncryptOverride = null;
    AppState.vaultDecryptOverride = null;
    appState.lockForTest();
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('one vault password holds multiple wallets', () async {
    await appState.saveVaultAccount(
      'x',
      label: 'Spending',
      key: WalletCore.privateKeyFromHex(_keyA),
    );
    await appState.saveVaultAccount(
      'x',
      label: 'Savings',
      key: WalletCore.privateKeyFromHex(_keyB),
    );

    final accounts = await appState.loadVaultAccounts('x');
    expect(accounts.map((a) => a.label), ['Spending', 'Savings']);
    expect(accounts, hasLength(2));
  });

  test('a second password cannot silently create a second vault', () async {
    await appState.saveVaultAccount(
      'first-password',
      label: 'First',
      key: WalletCore.privateKeyFromHex(_keyA),
    );

    await expectLater(
      appState.saveVaultAccount(
        'second-password',
        label: 'Second',
        key: WalletCore.privateKeyFromHex(_keyB),
      ),
      throwsA(isA<VaultException>()),
    );
  });

  test('session unlock lists, switches, renames, and removes', () async {
    await appState.saveVaultAccount(
      'x',
      label: 'Spending',
      key: WalletCore.privateKeyFromHex(_keyA),
    );
    await appState.saveVaultAccount(
      'x',
      label: 'Savings',
      key: WalletCore.privateKeyFromHex(_keyB),
    );

    final accounts = await appState.unlockVaultAccounts('x');
    expect(appState.vaultUnlocked, isTrue);
    expect(appState.vaultAccountAt(0).label, 'Spending');
    expect(
      accounts[0].address,
      WalletCore.privateKeyFromHex(_keyA).address.eip55With0x,
    );

    await appState.renameVaultAccount('x', 0, 'Daily spending');
    expect(appState.vaultAccountAt(0).label, 'Daily spending');

    await appState.deleteVaultAccount('x', accounts[1].address);
    expect(appState.vaultAccountsCache, hasLength(1));
    expect(appState.vaultAccountAt(0).label, 'Daily spending');

    appState.lockForTest();
    expect(appState.vaultUnlocked, isFalse);
  });

  test('wrong password is rejected', () async {
    await appState.saveVaultAccount(
      'x',
      label: 'Spending',
      key: WalletCore.privateKeyFromHex(_keyA),
    );
    await expectLater(
      appState.unlockVaultAccounts('not-x'),
      throwsA(isA<VaultException>()),
    );
  });
}

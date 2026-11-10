import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/models.dart';
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
    AppStorage.resetPreferencesForTest();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    tmp = await Directory.systemTemp.createTemp('x-wallet-vaults-test-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    await AppStorage.ensureVaultRegistry();
    await appState.refreshVaults();
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

  Future<void> addVault(String label, String password, String key) async {
    await appState.createVault(label, password);
    await appState.saveVaultAccount(
      password,
      label: 'Wallet in $label',
      key: WalletCore.privateKeyFromHex(key),
    );
  }

  test('creates three independent vaults and refuses a fourth', () async {
    await addVault('Main', 'a', _keyA);
    await addVault('Trading', 'b', _keyB);
    await addVault('Savings', 'c', _keyA);

    expect(appState.vaults, hasLength(3));
    expect(appState.vaults.map((v) => v.label), ['Main', 'Trading', 'Savings']);
    await expectLater(
      appState.createVault('Fourth', 'd'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'switching verifies the target password and isolates accounts',
    () async {
      await addVault('Main', 'a', _keyA);
      final main = appState.vaults.single;
      await addVault('Trading', 'b', _keyB);
      final trading = appState.vaults.last;

      await appState.switchVault(main.id, 'a');
      final mainAccounts = await appState.loadVaultAccounts('a');
      expect(mainAccounts, hasLength(1));
      expect(mainAccounts.single.label, 'Wallet in Main');

      await expectLater(
        appState.switchVault(trading.id, 'wrong'),
        throwsA(isA<VaultException>()),
      );
      expect(appState.activeVaultId, main.id);

      await appState.switchVault(trading.id, 'b');
      final tradingAccounts = await appState.loadVaultAccounts('b');
      expect(tradingAccounts, hasLength(1));
      expect(tradingAccounts.single.label, 'Wallet in Trading');
    },
  );

  test('a rename persists without touching the file', () async {
    await addVault('Main', 'a', _keyA);
    final entry = appState.vaults.single;
    await appState.renameVault(entry.id, 'Household');
    expect(appState.vaults.single.label, 'Household');
    expect(File(entry.file).existsSync(), isTrue);
  });

  test(
    'deleting needs the password, shreds the file and switches active',
    () async {
      await addVault('Main', 'a', _keyA);
      final main = appState.vaults.single;
      await addVault('Trading', 'b', _keyB);
      final trading = appState.vaults.last;

      await expectLater(
        appState.deleteVault(main.id, 'wrong'),
        throwsA(isA<VaultException>()),
      );
      expect(File(main.file).existsSync(), isTrue);

      await appState.deleteVault(main.id, 'a');
      expect(File(main.file).existsSync(), isFalse);
      expect(appState.vaults, hasLength(1));
      expect(appState.activeVaultId, trading.id);

      await appState.deleteVault(trading.id, 'b');
      expect(appState.vaults, isEmpty);
      expect(appState.activeVaultId, isNull);
      expect(await AppStorage.vaultExists(), isFalse);
    },
  );

  test('changing the password re-encrypts and rejects the old one', () async {
    await addVault('Main', 'old-password', _keyA);
    await appState.changeVaultPassword('old-password', 'new-password');
    final accounts = await appState.loadVaultAccounts('new-password');
    expect(accounts, hasLength(1));
    await expectLater(
      appState.loadVaultAccounts('old-password'),
      throwsA(isA<VaultException>()),
    );
  });

  test('pending transactions are scoped to the active vault', () async {
    await addVault('Main', 'a', _keyA);
    final main = appState.vaults.single;
    final address = WalletCore.privateKeyFromHex(_keyA).address.eip55With0x;
    await appState.addPendingTx(
      PendingTx(
        hash: '0x${'a' * 64}',
        network: 'mainnet',
        from: address,
        to: address,
        native: true,
        assetSymbol: 'BNB',
        assetAddress: '',
        amountRaw: '1',
        amountHuman: '0.000000000000000001',
        decimals: 18,
        gasLimit: '21000',
        nonce: 0,
        mode: 'eip1559',
        priorityFeePerGas: '1',
        maxFeePerGas: '2',
        gasPrice: '0',
        sentAt: '2026-01-01T00:00:00.000Z',
        tierLabel: 'Market',
        status: 'broadcast',
      ),
    );
    expect(appState.pendingTxs, hasLength(1));
    await addVault('Trading', 'b', _keyB);
    final trading = appState.vaults.last;
    await appState.switchVault(trading.id, 'b');
    expect(appState.pendingTxs, isEmpty);
    await appState.selectVault(main.id);
    expect(appState.pendingTxs, hasLength(1));
    await appState.switchVault(main.id, 'a');
    expect(appState.pendingTxs, hasLength(1));
  });
}

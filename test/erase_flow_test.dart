import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round-7: "Erase everything" must actually remove every stored artifact —
/// vault, temp vault, device-key drawer, the preferences file — and it must
/// report honestly (empty list) only when nothing survived on disk.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'network': 'testnet',
      'rpc': 'https://example.invalid',
      'nodes': '[]',
      'tokens': '[]',
      'profiles': '[]',
      'auto_lock_seconds': 300,
      'tor_enabled': true,
    });
    tmp = await Directory.systemTemp.createTemp('bnb-erase-test');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
  });
  tearDown(() async {
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('eraseAllData removes vault, tmp, drawer and the prefs file — and reports clean', () async {
    final vault = File('${tmp.path}/bnb-wallet-vault.bnb')
      ..writeAsStringSync('BNBVL004fake-blob');
    final tmpVault = File('${vault.path}.tmp')..writeAsStringSync('partial');
    final drawer = File('${tmp.path}/device_secret_v2.drawer')
      ..writeAsStringSync('AAAA');
    final prefsFile = File('${tmp.path}/shared_preferences.json')
      ..writeAsStringSync('{}');
    final logFile = File('${tmp.path}/bnb-wallet-log.bin')
      ..writeAsStringSync('BNBLOG01fake');
    final orphanVaultTemp = File('${tmp.path}/.bnb-wallet-vault.bnb-deadbeef')
      ..writeAsStringSync('orphan');
    final orphanLogTemp = File('${tmp.path}/.bnb-wallet-log.bin-deadbeef')
      ..writeAsStringSync('orphan');
    expect(await AppStorage.vaultExists(), isTrue);

    final leftovers = await AppStorage.eraseAllData();

    expect(
      leftovers,
      isEmpty,
      reason: 'a clean wipe must report nothing left behind',
    );
    expect(await vault.exists(), isFalse);
    expect(await tmpVault.exists(), isFalse);
    expect(await drawer.exists(), isFalse);
    expect(await prefsFile.exists(), isFalse);
    expect(await logFile.exists(), isFalse);
    expect(await orphanVaultTemp.exists(), isFalse);
    expect(await orphanLogTemp.exists(), isFalse);
    expect(await AppStorage.vaultExists(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'network',
      'rpc',
      'nodes',
      'tokens',
      'profiles',
      'auto_lock_seconds',
      'tor_enabled',
      'tor_host',
      'tor_port',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: '"$key" must be gone');
    }
  });
}

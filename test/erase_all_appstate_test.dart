import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/storage.dart';

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
    AppStorage.resetPreferencesForTest();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('x-wallet-erase-all-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await AppStorage.init();
    appState.lockForTest();
  });

  tearDown(() async {
    AppStorage.resetDeviceSecretMemo();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'AppState.eraseAll completes and removes vault, log and prefs',
    () async {
      final vault = File('${tmp.path}/bnb-wallet-vault.bnb')
        ..writeAsStringSync('BNBVL004fake');
      final log = File('${tmp.path}/bnb-wallet-log.bin')
        ..writeAsStringSync('BNBLOG01fake');
      final drawer = File('${tmp.path}/device_secret_v2.drawer')
        ..writeAsStringSync('AAAA');

      final leftovers = await appState.eraseAll().timeout(
        const Duration(seconds: 20),
      );

      expect(
        leftovers,
        isEmpty,
        reason: 'a clean erase must report no leftovers',
      );
      expect(await vault.exists(), isFalse);
      expect(await log.exists(), isFalse);
      expect(await drawer.exists(), isFalse);
      expect(appState.hasVault, isFalse);
      expect(appState.unlocked, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

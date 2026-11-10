import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

/// Regression: the global RpcService is constructed before preferences exist,
/// so its first transport was built as DIRECT. It must be rebuilt after storage
/// init, otherwise enabling Tor/proxy silently sends the first request direct.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    AppStorage.resetPreferencesForTest();
    SharedPreferences.setMockInitialValues({
      'tor_enabled': true,
      'tor_host': '127.0.0.1',
      'tor_port': 1, // deliberately closed
    });
    tmp = await Directory.systemTemp.createTemp('x-wallet-startup-test-');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'a transport built before init is rebuilt through the dead proxy',
    () async {
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        HttpOverrides.global = savedOverrides;
      });

      // Constructed while preferences are still unavailable → direct fallback.
      final rpc = RpcService();

      await AppStorage.init();
      // The fix under test:
      rpc.rebuildTransport();

      try {
        await rpc.transportForTest
            .get(Uri.parse('http://127.0.0.1:${server.port}/'))
            .timeout(const Duration(seconds: 5));
        fail(
          'The request reached the loopback server directly. A configured Tor '
          'route must fail closed, never fall back to direct.',
        );
      } catch (error) {
        // A dead SOCKS port is the expected failure. It proves the route was
        // applied; a direct client would have succeeded instead.
        expect(error, isNot(isA<TestFailure>()));
      }
    },
  );

  test('USD prices default to off', () async {
    AppStorage.resetPreferencesForTest();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    expect(AppStorage.showUsd, isFalse);
  });
}

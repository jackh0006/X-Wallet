import 'package:bnb_wallet_gui/price_service.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kill switch blocks RPC before any request', () async {
    var calls = 0;
    final rpc = RpcService(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    rpc.setKillSwitch(true);

    await expectLater(
      rpc.getNativeBalance('0x1111111111111111111111111111111111111111'),
      throwsStateError,
    );
    expect(calls, 0);
  });

  test('kill switch blocks explorer history before any request', () async {
    var calls = 0;
    final rpc = RpcService(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    rpc.setNetwork('ethereum');
    rpc.setExplorerKey('ethereum', 'eth-key');
    rpc.setKillSwitch(true);

    await expectLater(
      rpc.history('0x1111111111111111111111111111111111111111'),
      throwsStateError,
    );
    expect(calls, 0);
  });

  test('kill switch clears prices and blocks price requests', () async {
    SharedPreferences.setMockInitialValues({
      'show_usd': true,
      'price_provider': 'coingecko',
      'network_kill_switch': true,
    });
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();
    PriceService.instance.resetForTest();
    var calls = 0;
    PriceService.instance.debugClient = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });

    await PriceService.instance.refresh(force: true);

    expect(calls, 0);
    expect(PriceService.instance.price('ETH'), isNull);
  });

  test('kill switch preference survives a storage round trip', () async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();
    expect(AppStorage.networkKillSwitch, isFalse);

    await AppStorage.setNetworkKillSwitch(true);
    expect(AppStorage.networkKillSwitch, isTrue);
    await AppStorage.setNetworkKillSwitch(false);
    expect(AppStorage.networkKillSwitch, isFalse);
  });
}

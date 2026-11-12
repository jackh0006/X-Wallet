import 'dart:convert';

import 'package:bnb_wallet_gui/price_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PriceService.instance.resetForTest();
    SharedPreferences.setMockInitialValues({
      'show_usd': true,
      'price_provider': 'coingecko',
    });
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();
  });

  tearDown(() => PriceService.instance.resetForTest());

  test('a pinned provider is the only one contacted', () async {
    final calls = <Uri>[];
    PriceService.instance.debugClient = MockClient((request) async {
      calls.add(request.url);
      if (request.url.host == 'api.coingecko.com') {
        return http.Response(
          jsonEncode({
            'ethereum': {'usd': 2000.0},
            'tether': {'usd': 1.0},
          }),
          200,
        );
      }
      return http.Response('{}', 500);
    });

    await PriceService.instance.refresh(force: true);

    expect(calls, hasLength(1));
    expect(calls.single.host, 'api.coingecko.com');
    expect(PriceService.instance.sourceLabel, 'CoinGecko');
    expect(PriceService.instance.price('ETH'), closeTo(2000, 0.001));
    expect(PriceService.instance.lastError, isNull);
  });

  test('a pinned provider never silently falls back', () async {
    SharedPreferences.setMockInitialValues({
      'show_usd': true,
      'price_provider': 'coinmarketcap',
    });
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();

    final calls = <Uri>[];
    PriceService.instance.debugClient = MockClient((request) async {
      calls.add(request.url);
      return http.Response('{}', 503);
    });

    await PriceService.instance.refresh(force: true);

    expect(calls, hasLength(1));
    expect(calls.single.host, 'api.coinmarketcap.com');
    expect(PriceService.instance.lastError, isNotNull);
    expect(PriceService.instance.price('ETH'), isNull);
  });

  test('automatic mode keeps the documented fallback order', () async {
    SharedPreferences.setMockInitialValues({
      'show_usd': true,
      'price_provider': 'auto',
    });
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();

    final calls = <Uri>[];
    PriceService.instance.debugClient = MockClient((request) async {
      calls.add(request.url);
      if (request.url.host == 'api.coinmarketcap.com') {
        return http.Response(
          jsonEncode({
            'data': {
              'cryptoCurrencyList': [
                {
                  'symbol': 'ETH',
                  'quotes': [
                    {'price': 2100.0},
                  ],
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('{}', 500);
    });

    await PriceService.instance.refresh(force: true);

    expect(calls, hasLength(1));
    expect(calls.single.host, 'api.coinmarketcap.com');
    expect(PriceService.instance.sourceLabel, 'CoinMarketCap');
    expect(PriceService.instance.price('ETH'), closeTo(2100, 0.001));
  });

  test('provider labels are stable and explicit', () {
    expect(PriceService.providerLabel('auto'), contains('Automatic'));
    expect(PriceService.providerLabel('coinmarketcap'), 'CoinMarketCap');
    expect(PriceService.providerLabel('coingecko'), 'CoinGecko');
    expect(PriceService.providerLabel('binance'), 'Binance');
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/price_service.dart';

void main() {
  test('usdValue converts raw units with token decimals', () {
    final service = PriceService.instance;
    final oneAndHalf = BigInt.parse('1500000000000000000');
    expect(service.usdValue(oneAndHalf, 18, 600), closeTo(900, 0.0001));
    final twentyFive = BigInt.from(25000000);
    expect(service.usdValue(twentyFive, 6, 1), closeTo(25, 0.0001));
  });

  test('usdValue returns null when no price is known', () {
    expect(PriceService.instance.usdValue(BigInt.one, 18, null), isNull);
  });

  test('usdLabel uses short, readable dollar amounts', () {
    expect(usdLabel(null), '—');
    expect(usdLabel(0), r'$0.00');
    expect(usdLabel(1234.56), r'$1235');
    expect(usdLabel(12.345), r'$12.35');
    expect(usdLabel(0.123456), r'$0.1235');
  });

  test('CoinMarketCap listing parsing keeps wanted symbols only', () {
    final out = <String, double>{};
    final found = PriceService.applyCoinMarketCap(
      {
        'data': {
          'cryptoCurrencyList': [
            {
              'symbol': 'BNB',
              'quotes': [
                {'price': 680.25},
              ],
            },
            {
              'symbol': 'USDT',
              'quotes': [
                {'price': 0.999},
              ],
            },
            {
              'symbol': 'NOTWANTED',
              'quotes': [
                {'price': 12},
              ],
            },
          ],
        },
      },
      out,
      {'BNB', 'USDT', 'USDC'},
    );
    expect(found, 2);
    expect(out['BNB'], closeTo(680.25, 0.0001));
    expect(out['USDT'], closeTo(0.999, 0.0001));
    expect(out.containsKey('NOTWANTED'), isFalse);
  });

  test('CoinGecko simple/price parsing maps ids to symbols', () {
    final out = <String, double>{};
    final found = PriceService.applyCoinGecko(
      {
        'binancecoin': {'usd': 681.5},
        'tether': {'usd': 1.0},
      },
      out,
      {'BNB': 'binancecoin', 'USDT': 'tether', 'USDC': 'usd-coin'},
    );
    expect(found, 2);
    expect(out['BNB'], closeTo(681.5, 0.0001));
    expect(out['USDT'], closeTo(1.0, 0.0001));
  });
}

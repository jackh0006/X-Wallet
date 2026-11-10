import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/price_service.dart';

void main() {
  test('usdValue converts raw units with token decimals', () {
    final service = PriceService.instance;
    // 1.5 BNB at $600 = $900.
    final oneAndHalf = BigInt.parse('1500000000000000000');
    expect(service.usdValue(oneAndHalf, 18, 600), closeTo(900, 0.0001));

    // 25 USDT (6 decimals) at $1 = $25.
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
}

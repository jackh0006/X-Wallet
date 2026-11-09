import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/token_registry.dart';

void main() {
  const usdt = TokenInfo(
    symbol: 'USDT',
    name: 'Tether USD (BSC)',
    address: '0x55d398326f99059fF775485246999027B3197955',
    decimals: 18,
  );
  const lookalike = TokenInfo(
    symbol: 'USDT-2878723',
    name: 'Tether USD',
    address: '0x1111111111111111111111111111111111111111',
    decimals: 18,
  );
  const native = TokenInfo(
    symbol: 'BNB',
    name: 'BNB Smart Chain',
    address: '',
    decimals: 18,
    native: true,
  );

  test('canonical BSC token uses its standard name and network', () {
    final p = TokenRegistry.of(usdt);
    expect(p.symbol, 'USDT');
    expect(p.name, 'Tether USD');
    expect(p.network, 'BSC');
    expect(p.canonical, isTrue);
    expect(p.warning, isNull);
    expect(TokenRegistry.label(usdt), 'USDT · BSC');
  });

  test('a lookalike contract is marked unverified', () {
    final p = TokenRegistry.of(lookalike);
    expect(p.symbol, 'USDT-2878723 (unverified)');
    expect(p.canonical, isFalse);
    expect(p.warning, isNotNull);
  });

  test('native BNB is labelled with BSC', () {
    final p = TokenRegistry.of(native);
    expect(p.symbol, 'BNB');
    expect(p.network, 'BSC');
    expect(TokenRegistry.label(native), 'BNB · BSC');
  });
}

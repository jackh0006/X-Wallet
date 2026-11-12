import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/default_tokens.dart';
import 'package:bnb_wallet_gui/models.dart';

void main() {
  test('USDT and USDC have the canonical BSC contracts', () {
    expect(
      DefaultTokens.usdt.address.toLowerCase(),
      '0x55d398326f99059ff775485246999027b3197955',
    );
    expect(
      DefaultTokens.usdc.address.toLowerCase(),
      '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
    );
    expect(DefaultTokens.usdt.decimals, 18);
    expect(DefaultTokens.usdc.decimals, 18);
    expect(DefaultTokens.usdt.native, isFalse);
    expect(DefaultTokens.usdc.native, isFalse);
  });

  test('missing defaults are merged exactly once', () {
    final state = AppState();
    final merged = state.withDefaultTokens([
      const TokenInfo(
        symbol: 'CAKE',
        name: 'PancakeSwap',
        address: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
        decimals: 18,
      ),
    ]);

    expect(
      merged.map((t) => t.symbol),
      containsAll(['CAKE', 'USDT', 'USDC', 'XAUT']),
    );
    expect(
      merged.where((t) => t.symbol == 'USDT' && t.network == 'mainnet'),
      hasLength(1),
    );
    expect(
      merged.where((t) => t.symbol == 'USDT' && t.network == 'ethereum'),
      hasLength(1),
    );
    expect(
      merged.where((t) => t.symbol == 'USDC' && t.network == 'mainnet'),
      hasLength(1),
    );

    final again = state.withDefaultTokens(merged);
    expect(again.where((t) => t.symbol == 'USDT'), hasLength(2));
    expect(again.where((t) => t.symbol == 'USDC'), hasLength(2));
    expect(again, hasLength(merged.length));
  });

  test('an existing USDT contract is not duplicated by a case variant', () {
    final state = AppState();
    final merged = state.withDefaultTokens([
      const TokenInfo(
        symbol: 'USDT',
        name: 'Custom Tether label',
        address: '0x55D398326F99059fF775485246999027B3197955',
        decimals: 18,
      ),
    ]);
    expect(
      merged.where((t) => t.symbol == 'USDT' && t.network == 'mainnet'),
      hasLength(1),
    );
    expect(
      merged.where((t) => t.symbol == 'USDC' && t.network == 'mainnet'),
      hasLength(1),
    );
  });
}

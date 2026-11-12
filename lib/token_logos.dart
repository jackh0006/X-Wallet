import 'package:flutter/material.dart';

import 'models.dart';

/// Local token marks. The app never fetches logos from the network.
class TokenLogos {
  TokenLogos._();

  static const Map<String, String> _byAddress = {
    '0x55d398326f99059ff775485246999027b3197955': 'assets/tokens/usdt.png',
    '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d': 'assets/tokens/usdc.png',
    '0xe9e7cea3dedca5984780bafc599bd69add087d56': 'assets/tokens/busd.png',
    '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82': 'assets/tokens/cake.png',
    '0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c': 'assets/tokens/btcb.png',
    '0x2170ed0880ac9a755fd29b2688956bd959f933f8': 'assets/tokens/eth.png',
    '0x1d2f0da169ceb9fc7b3144628db156f3f6c60dbe': 'assets/tokens/xrp.png',
    '0x3ee2200efb3400fabb9aacf31297cbdd1d435d47': 'assets/tokens/ada.png',
    '0xba2ae424d960c26247dd6c32edc70b295c744c43': 'assets/tokens/doge.png',
    '0xdac17f958d2ee523a2206206994597c13d831ec7': 'assets/tokens/usdt.png',
    '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': 'assets/tokens/usdc.png',
  };

  static const Map<String, String> _bySymbol = {
    'BNB': 'assets/tokens/bnb.png',
    'BTC': 'assets/tokens/btc.png',
    'LTC': 'assets/tokens/ltc.png',
    'USDT': 'assets/tokens/usdt.png',
    'USDC': 'assets/tokens/usdc.png',
    'BUSD': 'assets/tokens/busd.png',
    'CAKE': 'assets/tokens/cake.png',
    'BTCB': 'assets/tokens/btcb.png',
    'ETH': 'assets/tokens/eth.png',
    'XRP': 'assets/tokens/xrp.png',
    'ADA': 'assets/tokens/ada.png',
    'DOGE': 'assets/tokens/doge.png',
  };

  static String? assetFor(TokenInfo token) {
    final byAddress = _byAddress[token.address.toLowerCase()];
    if (byAddress != null) return byAddress;
    return _bySymbol[token.symbol.toUpperCase()];
  }
}

class TokenLogo extends StatelessWidget {
  const TokenLogo({super.key, required this.token, this.size = 28});

  final TokenInfo token;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = TokenLogos.assetFor(token);
    if (asset == null) {
      return Icon(Icons.account_balance_wallet, size: size);
    }
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            Icon(Icons.account_balance_wallet, size: size),
      ),
    );
  }
}

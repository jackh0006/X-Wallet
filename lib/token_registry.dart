import 'models.dart';

/// Canonical names for well-known BNB Smart Chain tokens.
///
/// Some contracts return symbols like `USDT-2878723`. A wallet must not
/// silently present an unknown contract as the real USDT. Known addresses are
/// shown with their standard name; unknown lookalikes are marked unverified.
class TokenRegistry {
  TokenRegistry._();

  static const Map<String, ({String symbol, String name})> _bsc = {
    '0x55d398326f99059ff775485246999027b3197955': (
      symbol: 'USDT',
      name: 'Tether USD',
    ),
    '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d': (
      symbol: 'USDC',
      name: 'USD Coin',
    ),
    '0xe9e7cea3dedca5984780bafc599bd69add087d56': (
      symbol: 'BUSD',
      name: 'Binance USD',
    ),
    '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82': (
      symbol: 'CAKE',
      name: 'PancakeSwap',
    ),
    '0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c': (
      symbol: 'BTCB',
      name: 'Bitcoin BEP20',
    ),
    '0x2170ed0880ac9a755fd29b2688956bd959f933f8': (
      symbol: 'ETH',
      name: 'Ethereum Token',
    ),
    '0x1d2f0da169ceb9fc7b3144628db156f3f6c60dbe': (
      symbol: 'XRP',
      name: 'XRP Token',
    ),
    '0x3ee2200efb3400fabb9aacf31297cbdd1d435d47': (
      symbol: 'ADA',
      name: 'Cardano Token',
    ),
    '0xba2ae424d960c26247dd6c32edc70b295c744c43': (
      symbol: 'DOGE',
      name: 'Dogecoin Token',
    ),
  };

  static const Set<String> _knownSymbols = {
    'BNB',
    'USDT',
    'USDC',
    'BUSD',
    'CAKE',
    'BTCB',
    'ETH',
    'XRP',
    'ADA',
    'DOGE',
  };

  static String networkLabel(String network) {
    if (network == 'mainnet') return 'BSC';
    if (network == 'testnet') return 'BSC Testnet';
    return network;
  }

  static TokenPresentation of(TokenInfo token) {
    if (token.native) {
      return TokenPresentation(
        symbol: 'BNB',
        name: 'BNB',
        network: networkLabel(token.network),
        canonical: true,
        warning: null,
      );
    }
    final canonical = _bsc[token.address.toLowerCase()];
    if (canonical != null) {
      return TokenPresentation(
        symbol: canonical.symbol,
        name: canonical.name,
        network: networkLabel(token.network),
        canonical: true,
        warning: null,
      );
    }
    final upper = token.symbol.toUpperCase();
    final lookalike = _knownSymbols.any(
      (known) => upper != known && upper.startsWith(known),
    );
    return TokenPresentation(
      symbol: lookalike ? '${token.symbol} (unverified)' : token.symbol,
      name: token.name.trim().isEmpty ? 'Unverified token' : token.name,
      network: networkLabel(token.network),
      canonical: false,
      warning: lookalike
          ? 'This contract imitates a well-known token name. Verify the '
                'contract address before using it.'
          : null,
    );
  }

  /// Short label for compact rows: `USDT · BSC`.
  static String label(TokenInfo token) {
    final p = of(token);
    return '${p.symbol} · ${p.network}';
  }
}

class TokenPresentation {
  const TokenPresentation({
    required this.symbol,
    required this.name,
    required this.network,
    required this.canonical,
    required this.warning,
  });

  final String symbol;
  final String name;
  final String network;
  final bool canonical;
  final String? warning;
}

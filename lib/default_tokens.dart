import 'models.dart';

/// Tokens every supported mainnet wallet shows by default.
///
/// These contracts are the canonical BSC deployments. They are ordinary
/// BEP-20 tokens: the wallet reads symbol, decimals, and balance from the
/// contract and never trusts a hardcoded balance. Users can hide or remove
/// them; the defaults are merged back on the next start if missing.
class DefaultTokens {
  DefaultTokens._();

  static const TokenInfo usdt = TokenInfo(
    symbol: 'USDT',
    name: 'Tether USD (BSC)',
    address: '0x55d398326f99059fF775485246999027B3197955',
    decimals: 18,
    network: 'mainnet',
  );

  static const TokenInfo usdc = TokenInfo(
    symbol: 'USDC',
    name: 'USD Coin (BSC)',
    address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    decimals: 18,
    network: 'mainnet',
  );

  static const TokenInfo ethUsdt = TokenInfo(
    symbol: 'USDT',
    name: 'Tether USD (Ethereum)',
    address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    decimals: 6,
    network: 'ethereum',
  );

  static const TokenInfo ethUsdc = TokenInfo(
    symbol: 'USDC',
    name: 'USD Coin (Ethereum)',
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    decimals: 6,
    network: 'ethereum',
  );

  /// Canonical Tether Gold ERC-20 on Ethereum. "XAUTUSDT" is a market pair,
  /// not an ERC-20 contract, so the wallet ships the token itself as XAUT.
  static const TokenInfo ethXaut = TokenInfo(
    symbol: 'XAUT',
    name: 'Tether Gold (Ethereum)',
    address: '0x68749665FF8D2d112Fa859AA293F07A622782F38',
    decimals: 6,
    network: 'ethereum',
  );

  static const List<TokenInfo> bsc = [usdt, usdc];
  static const List<TokenInfo> ethereum = [ethUsdt, ethUsdc, ethXaut];
  static const List<TokenInfo> all = [...bsc, ...ethereum];

  /// True when [token] is one of the built-in defaults on any chain.
  static bool isDefault(TokenInfo token) => all.any(
    (item) =>
        item.address.toLowerCase() == token.address.toLowerCase() &&
        item.network == token.network,
  );
}

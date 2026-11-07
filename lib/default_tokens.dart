import 'models.dart';

/// Tokens every BNB Smart Chain wallet shows by default.
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

  static const List<TokenInfo> bsc = [usdt, usdc];

  /// True when [token] is one of the built-in BSC defaults.
  static bool isDefault(TokenInfo token) => bsc.any(
    (item) =>
        item.address.toLowerCase() == token.address.toLowerCase() &&
        item.network == token.network,
  );
}

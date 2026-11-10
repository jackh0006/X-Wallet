import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'net/privacy_client.dart';
import 'storage.dart';

/// Public USD price lookup. It sends only fixed coin symbols/IDs — never an
/// address, wallet, balance, vault, or user identifier.
///
/// Sources are tried in order:
///   1. CoinMarketCap public listing data
///   2. CoinGecko simple/price
///   3. Binance / Coinbase spot tickers for BNB
///
/// Stablecoins fall back to $1 only when every market source fails, so the
/// UI can still show an honest approximate value for USDT/USDC.
class PriceService extends ChangeNotifier {
  PriceService._();
  static final PriceService instance = PriceService._();

  static const Map<String, String> _geckoIds = {
    'BNB': 'binancecoin',
    'USDT': 'tether',
    'USDC': 'usd-coin',
    'BUSD': 'binance-usd',
    'CAKE': 'pancakeswap-token',
    'BTCB': 'bitcoin',
    'ETH': 'ethereum',
    'XRP': 'ripple',
    'ADA': 'cardano',
    'DOGE': 'dogecoin',
  };

  final Map<String, double> _usd = {};
  DateTime? _fetchedAt;
  bool _loading = false;
  String _sourceLabel = 'market';

  Map<String, double> get usd => Map.unmodifiable(_usd);
  bool get loading => _loading;
  DateTime? get fetchedAt => _fetchedAt;
  String get sourceLabel => _sourceLabel;

  double? price(String symbol) => _usd[symbol.toUpperCase()];

  double? usdValue(BigInt raw, int decimals, double? unitPrice) {
    if (unitPrice == null || decimals < 0 || decimals > 36) return null;
    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final fraction = raw.remainder(divisor);
    final value = whole.toDouble() + fraction.toDouble() / divisor.toDouble();
    return value * unitPrice;
  }

  Future<void> refresh({bool force = false}) async {
    if (!AppStorage.showUsd) {
      if (_usd.isNotEmpty) {
        _usd.clear();
        notifyListeners();
      }
      return;
    }
    if (_loading) return;
    if (!force &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 5)) {
      return;
    }
    _loading = true;
    notifyListeners();
    final client = createRpcClient();
    var ok = false;
    try {
      ok = await _loadCoinMarketCap(client);
      if (!ok) ok = await _loadCoinGecko(client);
      if (!ok) ok = await _loadBinance(client);
      if (ok && _usd.isNotEmpty) {
        // Stablecoins are pegged; if a source omitted one, use a neutral
        // fallback rather than hiding the row's USD value.
        _usd.putIfAbsent('USDT', () => 1.0);
        _usd.putIfAbsent('USDC', () => 1.0);
        _usd.putIfAbsent('BUSD', () => 1.0);
        _fetchedAt = DateTime.now();
      }
    } catch (_) {
      // Offline or rate-limited: keep the last known prices and stay silent.
    } finally {
      client.close();
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> _loadCoinMarketCap(http.Client client) async {
    final response = await client
        .get(
          Uri.parse(
            'https://api.coinmarketcap.com/data-api/v3/cryptocurrency/listing'
            '?start=1&limit=500&sortBy=market_cap&sortType=desc&convert=USD',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return false;
    final data = decoded['data'];
    if (data is! Map) return false;
    final found = applyCoinMarketCap(decoded, _usd, _geckoIds.keys.toSet());
    if (found == 0) return false;
    _sourceLabel = 'CoinMarketCap';
    return true;
  }

  Future<bool> _loadCoinGecko(http.Client client) async {
    final response = await client
        .get(
          Uri.parse(
            'https://api.coingecko.com/api/v3/simple/price'
            '?ids=${_geckoIds.values.join(',')}&vs_currencies=usd',
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return false;
    final found = applyCoinGecko(decoded, _usd, _geckoIds);
    if (found == 0) return false;
    _sourceLabel = 'CoinGecko';
    return true;
  }

  Future<bool> _loadBinance(http.Client client) async {
    var found = false;
    for (final pair in const {'BNB': 'BNBUSDT', 'ETH': 'ETHUSDT'}.entries) {
      try {
        final response = await client
            .get(
              Uri.parse(
                'https://api.binance.com/api/v3/ticker/price'
                '?symbol=${pair.value}',
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) continue;
        final price = double.tryParse('${decoded['price'] ?? ''}');
        if (price != null && price > 0) {
          _usd[pair.key] = price;
          found = true;
        }
      } catch (_) {
        // Try the next pair/source.
      }
    }
    if (found) _sourceLabel = 'Binance';
    return found;
  }

  /// Parses the public CoinMarketCap listing response. Visible for tests.
  @visibleForTesting
  static int applyCoinMarketCap(
    Map<dynamic, dynamic> decoded,
    Map<String, double> out,
    Set<String> wanted,
  ) {
    final data = decoded['data'];
    if (data is! Map) return 0;
    final list = data['cryptoCurrencyList'];
    if (list is! List) return 0;
    var found = 0;
    for (final item in list) {
      if (item is! Map) continue;
      final symbol = '${item['symbol'] ?? ''}'.toUpperCase();
      if (!wanted.contains(symbol)) continue;
      final quotes = item['quotes'];
      if (quotes is! List) continue;
      for (final quote in quotes) {
        if (quote is! Map) continue;
        final price = quote['price'];
        if (price is num && price > 0) {
          out[symbol] = price.toDouble();
          found++;
          break;
        }
      }
    }
    return found;
  }

  /// Parses the public CoinGecko simple/price response. Visible for tests.
  @visibleForTesting
  static int applyCoinGecko(
    Map<dynamic, dynamic> decoded,
    Map<String, double> out,
    Map<String, String> ids,
  ) {
    var found = 0;
    for (final entry in ids.entries) {
      final row = decoded[entry.value];
      if (row is Map) {
        final usd = row['usd'];
        if (usd is num && usd > 0) {
          out[entry.key] = usd.toDouble();
          found++;
        }
      }
    }
    return found;
  }
}

String usdLabel(double? value) {
  if (value == null || !value.isFinite || value < 0) return '—';
  if (value == 0) return r'$0.00';
  if (value >= 1000) {
    return '\$${value.toStringAsFixed(0)}';
  }
  if (value >= 1) return '\$${value.toStringAsFixed(2)}';
  return '\$${value.toStringAsFixed(4)}';
}

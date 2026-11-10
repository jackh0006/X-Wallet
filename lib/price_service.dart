import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'net/privacy_client.dart';
import 'storage.dart';

/// Public USD price lookup. It sends only a fixed list of coin IDs — never an
/// address, wallet, balance, vault, or user identifier.
class PriceService extends ChangeNotifier {
  PriceService._();
  static final PriceService instance = PriceService._();

  static const Map<String, String> _ids = {
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

  Map<String, double> get usd => Map.unmodifiable(_usd);
  bool get loading => _loading;
  DateTime? get fetchedAt => _fetchedAt;

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
    try {
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=${_ids.values.join(',')}&vs_currencies=usd',
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          for (final entry in _ids.entries) {
            final row = decoded[entry.value];
            if (row is Map) {
              final usd = row['usd'];
              if (usd is num) _usd[entry.key] = usd.toDouble();
            }
          }
          _fetchedAt = DateTime.now();
        }
      }
    } catch (_) {
      // Offline or rate-limited: keep the last known prices and stay silent.
    } finally {
      client.close();
      _loading = false;
      notifyListeners();
    }
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

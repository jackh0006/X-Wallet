import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/rpc_service.dart';

void main() {
  test('default public RPC doors are HTTPS and unique', () {
    final urls = [
      ...BnbNetworks.mainnetFallbacks,
      ...BnbNetworks.testnetFallbacks,
    ];
    expect(urls.toSet(), hasLength(urls.length));
    for (final url in urls) {
      expect(url.startsWith('https://'), isTrue, reason: url);
      expect(url.contains('localhost'), isFalse, reason: url);
      expect(url.contains('127.0.0.1'), isFalse, reason: url);
    }
  });

  test('every network default is present in its fallback list', () {
    for (final entry in BnbNetworks.defaultRpcs.entries) {
      final fallbacks = entry.key == 'testnet'
          ? BnbNetworks.testnetFallbacks
          : BnbNetworks.mainnetFallbacks;
      expect(fallbacks, contains(entry.value));
    }
  });

  test('the public mainnet set includes independent operators', () {
    final joined = BnbNetworks.mainnetFallbacks.join(' ');
    expect(joined, contains('bnbchain.org'));
    expect(joined, contains('publicnode.com'));
    expect(joined, contains('1rpc.io'));
    expect(joined, contains('blastapi.io'));
  });
}

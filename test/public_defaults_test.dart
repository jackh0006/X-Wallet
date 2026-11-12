import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/chains.dart';
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
      expect(
        Chains.byKey(entry.key).fallbacks,
        contains(entry.value),
        reason: entry.key,
      );
    }
  });

  test('all supported chains have HTTPS, unique defaults', () {
    for (final chain in Chains.all) {
      expect(chain.defaultRpcs, isNotEmpty, reason: chain.key);
      expect(chain.fallbacks.toSet(), hasLength(chain.fallbacks.length));
      for (final url in chain.fallbacks) {
        expect(url.startsWith('https://'), isTrue, reason: url);
      }
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

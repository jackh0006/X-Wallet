import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static, repository-level proof for the data-boundary claims in
/// `docs/DATA_CONTROL.md`.
///
/// This test does not prove that a compromised operating system cannot read an
/// unlocked wallet. It proves that the shipped source does not contain a
/// telemetry SDK, an AI/remote-control client, or a network path inside the
/// key-handling and signing modules.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('locked dependencies contain no telemetry, ads, or AI SDK', () {
    final pubspec = read('pubspec.yaml').toLowerCase();
    const forbidden = <String>[
      'firebase',
      'google_analytics',
      'analytics',
      'sentry',
      'amplitude',
      'mixpanel',
      'segment',
      'crashlytics',
      'appsflyer',
      'adjust_sdk',
      'openai',
      'anthropic',
      'chatgpt',
    ];
    for (final needle in forbidden) {
      expect(
        pubspec,
        isNot(contains(needle)),
        reason: 'pubspec.yaml must not depend on $needle',
      );
    }
  });

  test('key and signing modules contain no network code', () {
    const keyModules = <String>[
      'lib/vault.dart',
      'lib/kdf.dart',
      'lib/wallet_core.dart',
      'lib/cold_tx_codec.dart',
      'lib/send_intent.dart',
      'lib/spending_policy.dart',
    ];
    final networkPattern = RegExp(
      r'(HttpClient|IOClient|WebSocket|RawSocket|Socket\.connect|https?://)',
    );
    for (final module in keyModules) {
      final source = read(module);
      expect(
        networkPattern.hasMatch(source),
        isFalse,
        reason: '$module must not contain a network path',
      );
    }
  });

  test('signing modules do not import the RPC or UI layers', () {
    const signingModules = <String>[
      'lib/vault.dart',
      'lib/kdf.dart',
      'lib/wallet_core.dart',
      'lib/cold_tx_codec.dart',
      'lib/send_intent.dart',
    ];
    for (final module in signingModules) {
      final source = read(module);
      for (final forbiddenImport in <String>[
        "rpc_service.dart",
        "net/privacy_client.dart",
        "screens/",
      ]) {
        expect(
          source,
          isNot(contains(forbiddenImport)),
          reason: '$module must not import $forbiddenImport',
        );
      }
    }
  });

  test('the sole outbound HTTP choke point is the privacy client', () {
    final privacy = read('lib/net/privacy_client.dart');
    expect(privacy, contains('HttpClient'));
    expect(privacy, contains('createRpcClient'));

    // Any other direct HttpClient construction outside tests would bypass the
    // privacy manager and the documented routing guarantees.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('lib/net/privacy_client.dart')) continue;
      if (entity.readAsStringSync().contains('HttpClient(')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'unexpected HttpClient sites: $offenders',
    );
  });
}

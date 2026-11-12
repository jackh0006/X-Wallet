import 'package:bnb_wallet_gui/widgets/network_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('badge names mainnet, testnet and custom networks in text', (
    tester,
  ) async {
    Future<void> pump(String network) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NetworkBadge(network: network)),
      ),
    );

    await pump('mainnet');
    expect(find.text('BSC · MAINNET'), findsOneWidget);

    await pump('sepolia');
    expect(find.text('SEPOLIA · TESTNET'), findsOneWidget);

    await pump('my-custom-chain');
    expect(find.text('CUSTOM NETWORK'), findsOneWidget);
  });
}

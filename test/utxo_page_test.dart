import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/screens/utxo_page.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetPreferencesForTest();
    await AppStorage.init();
    appState.lockForTest();
  });

  testWidgets('UTXO page explains the missing recovery phrase', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UtxoPage()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unlock a wallet with a recovery phrase first'),
      findsOneWidget,
    );
    expect(find.text('Bitcoin, Litecoin & Dogecoin'), findsOneWidget);
  });

  testWidgets('selecting Litecoin states that MWEB is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UtxoPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Litecoin · MAINNET').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('MWEB is NOT supported'), findsOneWidget);
  });

  testWidgets('switching to a test network shows an unmistakable warning', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UtxoPage()));
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitcoin Testnet · TESTNET').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'TESTNET — these coins have no ordinary monetary value',
      ),
      findsOneWidget,
    );
  });
}

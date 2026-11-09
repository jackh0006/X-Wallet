import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/main.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> bootstrap(WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    appState.lock();
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const XWalletApp());
    await tester.pumpAndSettle();
    // The Shell may remember the Wallet tab from a previous test; tapping the
    // label works whether it is selected (filled icon) or not.
    await tester.tap(find.text('Wallet').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create wallet offers 12/24, one path per popular wallet, account index',
    (tester) async {
      await bootstrap(tester);

      await tester.tap(find.text('Create a new wallet'));
      await tester.pumpAndSettle();

      expect(find.text('12 words'), findsOneWidget);
      expect(find.text('24 words'), findsOneWidget);
      expect(find.text('MetaMask / Trust / BIP-44'), findsOneWidget);
      expect(
        find.textContaining('MetaMask, Trust Wallet, SafePal'),
        findsOneWidget,
      );
      expect(find.text("m/44'/60'/0'/0/0"), findsOneWidget);

      // Account indexes are generated instead of repeating six path rows.
      await tester.enterText(find.byType(TextField).first, '9');
      await tester.pumpAndSettle();
      expect(find.text("m/44'/60'/0'/0/9"), findsOneWidget);

      // 12-word creation shows a numbered 12-word grid, not three words.
      await tester.tap(find.text('12 words'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate 12 words'));
      await tester.pumpAndSettle();

      expect(find.text('Your 12-word recovery phrase'), findsOneWidget);
      final numbered = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => RegExp(r'^\d+\.$').hasMatch(text.data ?? ''))
          .length;
      expect(numbered, 12);
      expect(
        find.text("MetaMask / Trust / BIP-44 · m/44'/60'/0'/0/9"),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('new private key shows a one-time backup dialog', (tester) async {
    await bootstrap(tester);

    await tester.tap(find.text('Create a new wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recovery phrase (12 / 24 words)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New private key (generated)').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('brand-new random private key'), findsOneWidget);
    await tester.tap(find.text('Generate private key'));
    await tester.pumpAndSettle();

    expect(find.text('Back up your new private key'), findsOneWidget);
    expect(find.textContaining('0x'), findsWidgets);
    expect(find.text('I wrote down the whole private key.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('existing private key creates the wallet immediately', (
    tester,
  ) async {
    await bootstrap(tester);

    await tester.tap(find.text('Create a new wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recovery phrase (12 / 24 words)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing private key (paste)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create wallet').last);
    await tester.pumpAndSettle();

    expect(find.text('Wallet created'), findsOneWidget);
    expect(
      find.text('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'),
      findsOneWidget,
    );
  });
}

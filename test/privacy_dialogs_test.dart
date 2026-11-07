import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/screens/privacy_dialogs.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootstrap(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showProxySettingsDialog(context),
                  child: const Text('open proxy'),
                ),
                TextButton(
                  onPressed: () => showTorSettingsDialog(context),
                  child: const Text('open tor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('proxy dialog parses a pasted URL into host, port and auth', (
    tester,
  ) async {
    await bootstrap(tester);
    await tester.tap(find.text('open proxy'));
    await tester.pumpAndSettle();

    expect(find.text('Custom proxy'), findsOneWidget);
    expect(find.textContaining('no direct fallback'), findsOneWidget);

    // Options live in the dropdown menu, not in the closed field. Open it and
    // prove the remote-DNS option is actually offered before parsing a URL.
    await tester.tap(find.byType(DropdownButtonFormField<ProxyType>));
    await tester.pumpAndSettle();
    expect(find.text('SOCKS5h — remote DNS (Tor-style)'), findsOneWidget);
    await tester.tap(find.text('SOCKS5h — remote DNS (Tor-style)'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'socks5h://alice:secret@proxy.example:1081',
    );
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[1].controller?.text, 'proxy.example');
    expect(fields[2].controller?.text, '1081');
    expect(fields[3].controller?.text, 'alice');
    expect(fields[4].controller?.text, 'secret');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Tor dialog shows managed/external choices and bridge types', (
    tester,
  ) async {
    await bootstrap(tester);
    await tester.tap(find.text('open tor'));
    await tester.pumpAndSettle();

    expect(find.text('Tor and bridges'), findsOneWidget);
    expect(find.text('Managed Tor'), findsOneWidget);
    expect(find.text('Existing Tor or Orbot'), findsOneWidget);
    expect(find.text('Start managed Tor'), findsOneWidget);

    await tester.ensureVisible(find.text('No bridge (direct Tor)').last);
    await tester.tap(find.text('No bridge (direct Tor)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('obfs4').last);
    await tester.pumpAndSettle();
    expect(find.text('Bridge lines'), findsOneWidget);
    expect(find.textContaining('iat-mode=0'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}

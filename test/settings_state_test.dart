import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/screens/settings_page.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings rebuilds when network and toggles change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.light(), home: const SettingsPage()),
    );
    await tester.pumpAndSettle();

    SegmentedButton<String> network = tester.widget(
      find.byType(SegmentedButton<String>),
    );
    expect(network.selected, {'mainnet'});

    appState.rpc.setNetwork('testnet');
    await tester.pump();
    network = tester.widget(find.byType(SegmentedButton<String>));
    expect(network.selected, {'testnet'});

    expect(appState.liteMode, isFalse);
    await appState.setLiteMode(true);
    expect(appState.liteMode, isTrue);
  });
}

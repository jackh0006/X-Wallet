import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/l10n/ui_strings.dart';
import 'package:bnb_wallet_gui/localized_text.dart' as l10n;

void main() {
  testWidgets('English is the only supported language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: l10n.Text('Add node')),
      ),
    );
    await tester.pump();
    expect(find.text('Add node'), findsOneWidget);
    expect(translateUi('en', 'Add node'), 'Add node');
    expect(translateUi('fa', 'Add node'), 'Add node');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/l10n/ui_strings.dart';
import 'package:bnb_wallet_gui/localized_text.dart' as l10n;

void main() {
  testWidgets('Text follows the selected locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: l10n.Text('Add node')),
      ),
    );
    await tester.pump();
    expect(find.text('Add node'), findsNothing);
    expect(find.text(translateUi('fa', 'Add node')), findsOneWidget);
  });
}

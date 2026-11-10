import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/encrypted_log_store.dart';
import 'package:bnb_wallet_gui/screens/home_page.dart';
import 'package:bnb_wallet_gui/screens/send_page.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round-7: the parts must connect. Unlocking an existing vault must land the
/// user on the screen they came for — the send form from the Send gate, the
/// Wallet tab from Home — and must NOT replay the brand-new-wallet save
/// offers ("Save public profile?", "Save encrypted vault?") that belong to
/// the import flow.
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

const _testKeyHex =
    '0x115b527ce6cb943286dee1503e7645b0d021cc0cd43b9cbf7cb80eeba9db6b49';
const _testPassword = 'test-password-123456';

/// Cheap, deterministic stand-in for the vault KDF, injected through the
/// debug-only seam in AppState (release builds always run the real cipher).
/// A wrong password still fails, so the unlock error path stays honest.
Future<String> _testEncrypt(
  String password,
  String plaintext,
  String device,
) async => base64.encode(utf8.encode('vtest:$password:$plaintext'));

Future<String> _testDecrypt(String password, String blob, String device) async {
  final decoded = utf8.decode(base64.decode(blob));
  final prefix = 'vtest:$password:';
  if (!decoded.startsWith(prefix)) {
    throw const FormatException('Vault password does not match.');
  }
  return decoded.substring(prefix.length);
}

/// A tall surface so lazily-built ListView cards (actions, welcome) exist.
void _bigSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Poll through the widget binding only. The hardened Linux storage layer
/// uses real descriptor I/O, so each poll gives that I/O a bounded real-time
/// turn after the modal handler has returned to the frame.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  int tries = 40,
  Duration step = const Duration(milliseconds: 500),
}) async {
  for (var i = 0; i < tries; i++) {
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(step);
  }
  await tester.pump(step);
}

String _visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.isNotEmpty)
    .join(' | ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bnb-nav-test');
    PathProviderPlatform.instance = _MockPathProvider(tmp.path);
    await AppStorage.init();
    // These are navigation tests, not network tests.  HomePage starts a
    // refresh as soon as it is mounted; with a real RPC pool that would try
    // several 10-second timeouts and keep the test isolate alive after the
    // assertions.  Offline makes connect() fail immediately and keeps the
    // navigation fixture hermetic.
    appState.rpc.setOffline(true);
    AppState.vaultEncryptOverride = _testEncrypt;
    AppState.vaultDecryptOverride = _testDecrypt;
    // This fixture shares the global state across widget cases.  It needs the
    // key cleared, but must not start an unrelated asynchronous audit write
    // into a directory the fixture will replace or delete.
    appState.lockForTest();
    appState.tab = 0;
  });
  tearDown(() async {
    // Finish any unawaited audit append while its unlocked key and isolated
    // data directory still exist.  This is a lifecycle ownership barrier,
    // not a delay: the Linux storage path has no fake-clock I/O boundary.
    await EncryptedLogStore.flush();
    AppState.vaultEncryptOverride = null;
    AppState.vaultDecryptOverride = null;
    appState.rpc.setOffline(false);
    appState.lockForTest();
    AppStorage.resetDeviceSecretMemo();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets(
    'unlocking at the Send gate lands straight on the send form, no save offers',
    (tester) async {
      await tester.runAsync(
        () => appState.saveVaultAccount(
          _testPassword,
          label: 'Vault W',
          key: WalletCore.privateKeyFromHex(_testKeyHex),
        ),
      );
      expect(appState.hasVault, isTrue);
      appState.tab = 2;
      await tester.pumpWidget(const MaterialApp(home: SendPage()));
      await tester.pumpAndSettle();
      expect(find.text('Open my vault'), findsOneWidget);

      await tester.tap(find.text('Open my vault'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock encrypted vault'), findsOneWidget);
      final dialogField = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(dialogField, _testPassword);
      final field = tester.widget<TextField>(dialogField);
      expect(
        field.controller?.text,
        _testPassword,
        reason: 'enterText must land in the password field',
      );
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Unlock encrypted vault'),
        findsNothing,
        reason:
            'Unlock must close the password dialog. On screen: ${_visibleTexts(tester)}',
      );
      // The dialog handler has returned, but its filesystem-backed vault
      // operation needs a real-event-loop turn before widget frames resume.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find.text('Choose a wallet').evaluate().isNotEmpty,
      );
      if (find.text('Choose a wallet').evaluate().isEmpty) {
        fail(
          'Vault accounts dialog never appeared. On screen: ${_visibleTexts(tester)}',
        );
      }
      await tester.tap(find.text('Vault W'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpUntil(tester, () => appState.unlocked);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        appState.unlocked,
        isTrue,
        reason: 'unlock must complete. On screen: ${_visibleTexts(tester)}',
      );
      expect(find.text('Vault W is now active.'), findsOneWidget);
      expect(
        find.text('Save public profile?'),
        findsNothing,
        reason:
            'the account is already in the vault; no profile offer on unlock',
      );
      expect(
        find.text('Save encrypted vault?'),
        findsNothing,
        reason: 'the account is already in the vault; no vault offer on unlock',
      );
      expect(
        find.text('Send native coin or EVM tokens'),
        findsOneWidget,
        reason: 'the send form itself must be on screen, ready to send',
      );
      expect(find.text('Review transfer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('unlocking from Home lands on the Wallet tab, no save offers', (
    tester,
  ) async {
    _bigSurface(tester);
    await tester.runAsync(
      () => appState.saveVaultAccount(
        _testPassword,
        label: 'Vault W',
        key: WalletCore.privateKeyFromHex(_testKeyHex),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    final open = find.text('Open my saved wallet');
    expect(open, findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    final dialogField = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(dialogField, _testPassword);
    final field = tester.widget<TextField>(dialogField);
    expect(
      field.controller?.text,
      _testPassword,
      reason: 'enterText must land in the password field',
    );
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Unlock encrypted vault'),
      findsNothing,
      reason:
          'Unlock must close the password dialog. On screen: ${_visibleTexts(tester)}',
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('Choose a wallet').evaluate().isNotEmpty,
    );
    if (find.text('Choose a wallet').evaluate().isEmpty) {
      fail(
        'Vault accounts dialog never appeared. On screen: ${_visibleTexts(tester)}',
      );
    }
    await tester.tap(find.text('Vault W'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpUntil(tester, () => appState.unlocked);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      appState.unlocked,
      isTrue,
      reason: 'unlock must complete. On screen: ${_visibleTexts(tester)}',
    );
    expect(
      appState.tab,
      1,
      reason: 'unlocking from Home must show the wallet itself',
    );
    expect(find.text('Vault W is now active.'), findsOneWidget);
    expect(find.text('Save public profile?'), findsNothing);
    expect(find.text('Save encrypted vault?'), findsNothing);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Home quick action "Send" switches to the Send tab', (
    tester,
  ) async {
    _bigSurface(tester);
    // unlock() performs real descriptor-backed storage I/O.  Awaiting it in
    // the fake-async widget zone blocks the harness forever; give it a real
    // event-loop turn exactly as the vault-backed cases above do.
    await tester.runAsync(
      () => appState.unlock(WalletCore.privateKeyFromHex(_testKeyHex)),
    );
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 100));
    final button = find.widgetWithText(FilledButton, 'Send');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(appState.tab, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    appState.lockForTest();
  });
}

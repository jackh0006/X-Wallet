import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/security.dart';
import 'package:bnb_wallet_gui/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppStorage.resetPreferencesForTest();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  test('node credentials never reach the plain preferences', () async {
    const node = RpcNode(
      label: 'Private node',
      url: 'https://node.example',
      network: 'mainnet',
      transport: NodeTransport.customProxy,
      proxyHost: '127.0.0.1',
      proxyPort: 1080,
      proxyUser: 'alice',
      proxyPass: 'proxy-secret',
      authType: NodeAuthType.bearer,
      authToken: 'bearer-secret',
      customHeaders: {'x-api-key': 'header-secret'},
    );
    await AppStorage.setNodes([node]);

    final raw = SharedPreferences.getInstance().then(
      (prefs) => prefs.getString('nodes') ?? '',
    );
    final plain = await raw;
    expect(plain, isNot(contains('proxy-secret')));
    expect(plain, isNot(contains('bearer-secret')));
    expect(plain, isNot(contains('header-secret')));
    expect(plain, isNot(contains('alice')));

    final loaded = AppStorage.nodes.single;
    expect(loaded.proxyPass, 'proxy-secret');
    expect(loaded.authToken, 'bearer-secret');
    expect(loaded.customHeaders['x-api-key'], 'header-secret');
  });

  test('the export form strips every credential', () {
    const node = RpcNode(
      label: 'Private node',
      url: 'https://node.example',
      network: 'mainnet',
      proxyUser: 'alice',
      proxyPass: 'proxy-secret',
      authType: NodeAuthType.bearer,
      authToken: 'bearer-secret',
      customHeaders: {'x-api-key': 'header-secret'},
    );
    final exported = jsonEncode(node.toPublicJson());
    expect(exported, isNot(contains('secret')));
    expect(exported, isNot(contains('alice')));
    expect(exported, isNot(contains('x-api-key')));
  });

  test('a missing PIN record fails closed', () async {
    expect(await AppSecurity.verifyPin('123456'), isFalse);
  });
}

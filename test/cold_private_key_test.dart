import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/cold_wallet_protocol.dart';
import 'package:bnb_wallet_gui/cold_wallet_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const from = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  const keyHex =
      '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  const otherKeyHex =
      '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  setUp(() async {
    await ColdWalletService.resetForTests();
  });

  ColdTxRequest request() => ColdWalletService.instance.createRequest(
    chainId: 56,
    from: from,
    to: to,
    value: BigInt.from(10).pow(18),
    gasLimit: BigInt.from(21000),
    maxFeePerGas: BigInt.from(1000000000),
    maxPriorityFeePerGas: BigInt.from(1000000000),
    nonce: 0,
    data: '0x',
    assetInfo: const ColdTxAssetInfo(isNative: true, symbol: 'BNB'),
    lifetime: const Duration(minutes: 10),
  );

  test('a private-key-only wallet can sign a cold request', () async {
    final req = request();
    final signature = await ColdWalletService.instance.signRequestWithKey(
      request: req,
      key: WalletCore.privateKeyFromHex(keyHex),
    );

    final checked = WalletCore.verifyColdSignatureDetailed(
      request: req,
      signature: signature,
      expectedFrom: from,
    );
    expect(checked.ok, isTrue, reason: checked.reason);
    expect(signature.from, from);
  });

  test('a different private key is refused for the same request', () async {
    await expectLater(
      ColdWalletService.instance.signRequestWithKey(
        request: request(),
        key: WalletCore.privateKeyFromHex(otherKeyHex),
      ),
      throwsA(isA<ColdProtocolException>()),
    );
  });

  test('private-key signing is replay-safe', () async {
    final req = request();
    final first = await ColdWalletService.instance.signRequestWithKey(
      request: req,
      key: WalletCore.privateKeyFromHex(keyHex),
    );
    final second = await ColdWalletService.instance.signRequestWithKey(
      request: req,
      key: WalletCore.privateKeyFromHex(keyHex),
    );
    expect(second.requestId, first.requestId);
    expect(second.rawSignedTx, first.rawSignedTx);
  });
}

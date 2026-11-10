import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/price_service.dart';
import 'package:bnb_wallet_gui/send_intent.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/token_registry.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pending transaction recovery state', () {
    PendingTx row({String status = 'signed', String? rawHex}) => PendingTx(
      hash: '0x${'a' * 64}',
      network: 'mainnet',
      from: '0x1111111111111111111111111111111111111111',
      to: '0x2222222222222222222222222222222222222222',
      native: true,
      assetSymbol: 'BNB',
      assetAddress: '',
      amountRaw: '1000',
      amountHuman: '0.000001',
      decimals: 18,
      gasLimit: '21000',
      nonce: 7,
      mode: 'eip1559',
      priorityFeePerGas: '1',
      maxFeePerGas: '2',
      gasPrice: '0',
      sentAt: '2026-01-01T00:00:00.000Z',
      tierLabel: 'Market',
      rawHex: rawHex,
      status: status,
    );

    test('signed bytes, status and vault id survive a restart', () {
      final original = row(status: 'unknown', rawHex: '0xdeadbeef');
      final decoded = PendingTx.fromJson(original.toJson());
      expect(decoded.rawHex, '0xdeadbeef');
      expect(decoded.status, 'unknown');
      expect(decoded.nonce, 7);
      expect(decoded.copyWith(status: 'broadcast').status, 'broadcast');
    });

    test('older rows without the new fields still decode as broadcast', () {
      final legacy = row().toJson()
        ..remove('rawHex')
        ..remove('status')
        ..remove('vaultId');
      final decoded = PendingTx.fromJson(legacy);
      expect(decoded.status, 'broadcast');
      expect(decoded.rawHex, isNull);
    });
  });

  group('cancel and approval review', () {
    test('a cancel with an explicit zero value passes verification', () {
      final self = '0x1111111111111111111111111111111111111111';
      SendIntent.verify(
        chainId: 56,
        intendedChainId: 56,
        native: true,
        intendedRecipient: self,
        intendedAmount: BigInt.zero,
        tokenAddress: '',
        txTo: self,
        txValue: BigInt.zero,
        txData: Uint8List(0),
        txGasLimit: BigInt.from(21000),
        txGasPrice: BigInt.from(3),
        txMaxFeePerGas: null,
        txMaxPriorityFeePerGas: null,
        feeMode: 'legacy',
        expectedGasPrice: BigInt.from(3),
        expectedMaxFee: BigInt.zero,
        expectedPriority: BigInt.zero,
      );
    });

    test('approve decodes and displays the spender', () {
      const from = '0x1111111111111111111111111111111111111111';
      const spender = '0x3333333333333333333333333333333333333333';
      const token = '0x4444444444444444444444444444444444444444';
      final amount = BigInt.from(123456);
      final data =
          '0x095ea7b3'
          '${spender.substring(2).padLeft(64, '0')}'
          '${amount.toRadixString(16).padLeft(64, '0')}';
      final now = DateTime.now().toUtc();
      final result = WalletCore.decodeTxRequest(
        request: ColdTxRequest(
          version: 1,
          chainId: 56,
          from: from,
          to: token,
          value: '0x0',
          gasLimit: '0x5208',
          maxFeePerGas: '0x2',
          maxPriorityFeePerGas: '0x1',
          nonce: 1,
          data: data,
          assetInfo: const ColdTxAssetInfo(
            isNative: false,
            contractAddress: token,
            decimals: 18,
            symbol: 'TST',
          ),
          expiresAt: now.add(const Duration(hours: 1)).toIso8601String(),
          createdAt: now.toIso8601String(),
          id: 'approve-test',
        ),
        coldAddresses: const [from],
        knownTokens: const {},
      );
      expect(result.functionName, 'approve');
      expect(
        result.decodedTo?.toLowerCase(),
        WalletCore.checksumAddress(spender).toLowerCase(),
      );
      expect(result.decodedValue, amount);
      expect(result.warning, contains('spender'));
    });

    test('an unlimited approval is flagged at the 2^255 threshold', () {
      const from = '0x1111111111111111111111111111111111111111';
      const spender = '0x3333333333333333333333333333333333333333';
      const token = '0x4444444444444444444444444444444444444444';
      final amount = BigInt.from(2).pow(255);
      final data =
          '0x095ea7b3'
          '${spender.substring(2).padLeft(64, '0')}'
          '${amount.toRadixString(16).padLeft(64, '0')}';
      final now = DateTime.now().toUtc();
      final result = WalletCore.decodeTxRequest(
        request: ColdTxRequest(
          version: 1,
          chainId: 56,
          from: from,
          to: token,
          value: '0x0',
          gasLimit: '0x5208',
          maxFeePerGas: '0x2',
          maxPriorityFeePerGas: '0x1',
          nonce: 1,
          data: data,
          assetInfo: const ColdTxAssetInfo(
            isNative: false,
            contractAddress: token,
            decimals: 18,
            symbol: 'TST',
          ),
          expiresAt: now.add(const Duration(hours: 1)).toIso8601String(),
          createdAt: now.toIso8601String(),
          id: 'unlimited-test',
        ),
        coldAddresses: const [from],
        knownTokens: const {},
      );
      expect(result.warning, contains('UNLIMITED'));
    });
  });

  group('token identity', () {
    TokenInfo token(String symbol) => TokenInfo(
      symbol: symbol,
      name: symbol,
      address: '0x9999999999999999999999999999999999999999',
      decimals: 18,
      native: false,
    );

    test('an exact well-known symbol on an unknown contract is unverified', () {
      final p = TokenRegistry.of(token('USDT'));
      expect(p.canonical, isFalse);
      expect(p.symbol, contains('unverified'));
      expect(p.warning, isNotNull);
    });

    test('an ordinary unknown symbol still carries a verify warning', () {
      final p = TokenRegistry.of(token('ZZZ'));
      expect(p.canonical, isFalse);
      expect(p.warning, isNotNull);
    });
  });

  group('clipboard guard', () {
    test('WIF and keystore JSON are refused', () {
      expect(
        ClipboardGuard.secretFree(
          '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ',
        ),
        isFalse,
      );
      expect(
        ClipboardGuard.secretFree(
          '{"crypto":{"cipher":"aes-128-ctr","ciphertext":"00"}}',
        ),
        isFalse,
      );
    });

    test('a public transaction hash stays copyable', () {
      expect(ClipboardGuard.secretFree('0x${'a' * 64}'), isTrue);
    });
  });

  group('privacy defaults', () {
    test('USD price lookups are off by default', () async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.init();
      expect(AppStorage.showUsd, isFalse);
    });

    test('cold mode never refreshes prices', () async {
      SharedPreferences.setMockInitialValues({
        'wallet_mode': 1,
        'show_usd': true,
      });
      await AppStorage.init();
      await PriceService.instance.refresh(force: true);
      expect(PriceService.instance.fetchedAt, isNull);
      expect(PriceService.instance.usd, isEmpty);
    });
  });
}

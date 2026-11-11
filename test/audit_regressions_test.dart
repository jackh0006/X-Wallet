import 'package:flutter_test/flutter_test.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/security.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  group('official BIP-39 vector', () {
    test('Trezor vector 1 seed and passphrase handling', () {
      final mnemonic = Mnemonic.fromSentence(
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
        Language.english,
        passphrase: 'TREZOR',
      );
      final seedHex = mnemonic.seed
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        seedHex,
        'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531'
        'f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04',
      );
    });

    test('the standard path derives the known first address', () {
      final key = WalletCore.derivePrivateKey(
        phrase:
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about',
      );
      expect(
        key.address.eip55With0x.toLowerCase(),
        '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      );
    });
  });

  group('EIP-55 input validation', () {
    test('a correct mixed-case checksum is accepted', () {
      expect(
        WalletCore.isChecksumValid(
          '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
        ),
        isTrue,
      );
    });

    test('a changed mixed-case letter is rejected', () {
      expect(
        WalletCore.isChecksumValid(
          '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD',
        ),
        isFalse,
      );
    });

    test('all-lowercase and all-uppercase are accepted as unchecksummed', () {
      expect(
        WalletCore.isChecksumValid(
          '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
        ),
        isTrue,
      );
      expect(
        WalletCore.isChecksumValid(
          '0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED',
        ),
        isTrue,
      );
    });
  });

  group('PIN backoff schedule', () {
    test('never overflows to an expired cooldown', () {
      expect(AppSecurity.backoffSecondsForCount(1), 1);
      expect(AppSecurity.backoffSecondsForCount(2), 2);
      expect(AppSecurity.backoffSecondsForCount(10), 512);
      expect(AppSecurity.backoffSecondsForCount(11), 900);
      expect(AppSecurity.backoffSecondsForCount(64), 900);
      expect(AppSecurity.backoffSecondsForCount(100), 900);
    });
  });

  group('cold ERC-20 contract binding', () {
    ColdTxRequest requestWith({
      required String token,
      required String assetContract,
      required String data,
    }) {
      final now = DateTime.now().toUtc();
      return ColdTxRequest(
        version: 1,
        chainId: 56,
        from: '0x1111111111111111111111111111111111111111',
        to: token,
        value: '0x0',
        gasLimit: '0x5208',
        maxFeePerGas: '0x2',
        maxPriorityFeePerGas: '0x1',
        nonce: 1,
        data: data,
        assetInfo: ColdTxAssetInfo(
          isNative: false,
          contractAddress: assetContract,
          decimals: 18,
          symbol: 'TST',
        ),
        expiresAt: now.add(const Duration(hours: 1)).toIso8601String(),
        createdAt: now.toIso8601String(),
        id: 'contract-binding',
      );
    }

    final spender = '0x3333333333333333333333333333333333333333';
    final amountWord = '0' * 64;
    final data =
        '0x095ea7b3'
        '${spender.substring(2).padLeft(64, '0')}'
        '$amountWord';

    test('approve with a mismatched asset contract is refused', () {
      expect(
        () => WalletCore.decodeTxRequest(
          request: requestWith(
            token: '0x4444444444444444444444444444444444444444',
            assetContract: '0x5555555555555555555555555555555555555555',
            data: data,
          ),
          coldAddresses: const ['0x1111111111111111111111111111111111111111'],
          knownTokens: const {},
        ),
        throwsArgumentError,
      );
    });

    test('approve with the matching contract is accepted', () {
      final result = WalletCore.decodeTxRequest(
        request: requestWith(
          token: '0x4444444444444444444444444444444444444444',
          assetContract: '0x4444444444444444444444444444444444444444',
          data: data,
        ),
        coldAddresses: const ['0x1111111111111111111111111111111111111111'],
        knownTokens: const {},
      );
      expect(result.functionName, 'approve');
      expect(result.decodedTo, isNotNull);
    });
  });
}

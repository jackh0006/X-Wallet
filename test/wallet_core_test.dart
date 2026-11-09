import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/wallet.dart';

import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  group('BIP-39 / BIP-44 vectors', () {
    // Canonical test vector from the Ethereum toolchain (Foundry/Anvil and
    // every reference wallet): 12-word "junk" mnemonic at the default path.
    test('standard junk mnemonic -> first EVM account', () {
      final key = WalletCore.derivePrivateKey(
        phrase: 'test test test test test test test test test test test junk',
        passphrase: '',
        path: WalletCore.defaultPath,
      );
      expect(
        key.address.eip55With0x,
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      );
    });

    test('generates 12- and 24-word phrases and rejects other lengths', () {
      final twelve = WalletCore.generateMnemonic(wordCount: 12);
      final twentyFour = WalletCore.generateMnemonic(wordCount: 24);
      expect(twelve.trim().split(RegExp(r'\s+')), hasLength(12));
      expect(twentyFour.trim().split(RegExp(r'\s+')), hasLength(24));
      expect(WalletCore.validateMnemonic(twelve), isTrue);
      expect(WalletCore.validateMnemonic(twentyFour), isTrue);
      expect(
        () => WalletCore.generateMnemonic(wordCount: 15),
        throwsArgumentError,
      );
    });

    test('all standard EVM paths are listed and indexes are generated', () {
      expect(
        WalletCore.standardPaths['MetaMask / Trust / BIP-44'],
        "m/44'/60'/0'/0/{index}",
      );
      expect(
        WalletCore.standardPaths['Ledger Legacy / MEW'],
        "m/44'/60'/0'/{index}",
      );
      expect(
        WalletCore.standardPaths['Ledger Live (account index)'],
        "m/44'/60'/{index}'/0/0",
      );
      expect(WalletCore.standardPathForAccount(1), "m/44'/60'/0'/0/1");
      expect(WalletCore.standardPathForAccount(9), "m/44'/60'/0'/0/9");
      expect(
        WalletCore.pathForLabel('MetaMask / Trust / BIP-44', 3),
        "m/44'/60'/0'/0/3",
      );
      expect(
        WalletCore.pathForLabel('Ledger Live (account index)', 2),
        "m/44'/60'/2'/0/0",
      );
      expect(WalletCore.standardPaths, hasLength(7));
      for (final entry in WalletCore.standardPaths.entries) {
        if (entry.key == 'Custom') {
          expect(entry.value, isEmpty);
        } else {
          expect(entry.value, startsWith('m/'));
        }
      }
    });

    test('different account path derives a different address', () {
      const phrase =
          'test test test test test test test test test test test junk';
      final account0 = WalletCore.derivePrivateKey(
        phrase: phrase,
        path: "m/44'/60'/0'/0/0",
      );
      final account1 = WalletCore.derivePrivateKey(
        phrase: phrase,
        path: "m/44'/60'/0'/0/1",
      );
      expect(account1.address, isNot(account0.address));
    });

    test('private-key import uses the same known vector', () {
      final key = WalletCore.privateKeyFromHex(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
      );
      expect(
        key.address.eip55With0x,
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      );
    });

    test('derivation is deterministic and passphrase-sensitive', () {
      const phrase =
          'test test test test test test test test test test test junk';
      final a = WalletCore.derivePrivateKey(
        phrase: phrase,
        passphrase: '',
        path: WalletCore.defaultPath,
      );
      final b = WalletCore.derivePrivateKey(
        phrase: phrase,
        passphrase: '',
        path: WalletCore.defaultPath,
      );
      final alt = WalletCore.derivePrivateKey(
        phrase: phrase,
        passphrase: 'sh',
        path: WalletCore.defaultPath,
      );
      expect(a.privateKey, b.privateKey);
      expect(a.address, b.address);
      expect(alt.address, isNot(a.address));
    });

    test('validateMnemonic checks checksum and wordlist', () {
      const junk =
          'test test test test test test test test test test test junk';
      expect(WalletCore.validateMnemonic(junk), isTrue);
      expect(WalletCore.validateMnemonic('not real words at all'), isFalse);
      expect(
        WalletCore.validateMnemonic(
          'test test test test test test test test test test test',
        ),
        isFalse,
      );
    });
  });

  group('EIP-55 checksum vectors', () {
    // Mixed-case checksum addresses from the EIP-55 test cases.
    const vectors = <String, String>{
      '5aaeb6053f3e94c9b9a09f33669435e7ef1beaed':
          '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      'fb6916095ca1df60bb79ce92ce3ea74c37c5d359':
          '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
      '52908400098527886e0f7030069857d2e4169ee7':
          '0x52908400098527886E0F7030069857D2E4169EE7',
      'de709f2102306220921060314725629080e2fb77':
          '0xde709f2102306220921060314725629080E2Fb77',
      '0000000000000000000000000000000000000001':
          '0x0000000000000000000000000000000000000001',
    };
    for (final entry in vectors.entries) {
      test('checksums ${entry.key}', () {
        final address = EthereumAddress.fromHex(entry.key, enforceEip55: false);
        expect(address.eip55With0x, entry.value);
        expect(WalletCore.checksumAddress(entry.key), entry.value);
      });
    }

    test('checksum validation catches single flipped letters', () {
      const good = '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
      // Canonical form reproduces itself.
      expect(WalletCore.checksumAddress(good.toLowerCase()), good);
      // A single flipped letter no longer equals its own EIP-55 form —
      // exactly the visual near-miss the poisoning dialog must expose.
      const tampered = '0xfb6916095ca1df60bB79Ce92cE3Ea74c37c5d359';
      expect(WalletCore.checksumAddress(tampered), isNot(tampered));
      // Syntax check stays true for a tampered (but well-formed) address —
      // that is why the send dialog prints the FULL checksummed form.
      expect(WalletCore.isValidAddress(tampered), isTrue);
    });
  });

  group('address poisoning affix helper', () {
    // sharesAffixes flags "drip address" lookalikes with a shared prefix or
    // suffix of at least 4 characters (long enough to skip random matches,
    // short enough to catch the classic 6-char-suffix poisoning attack).
    test('detects matching suffix', () {
      final a = WalletCore.sharesAffixes(
        '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
        '0xaaaabbbbccdd1111bB79Ce92cE3Ea74c37c5d359',
      );
      expect(a, isTrue);
    });

    test('detects matching prefix', () {
      final a = WalletCore.sharesAffixes(
        '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
        '0xfB6916095ca1df60aaaaaaaaaaaaaaaaaaaaaaaa',
      );
      expect(a, isTrue);
    });

    test('unrelated addresses are not flagged', () {
      final a = WalletCore.sharesAffixes(
        '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
        '0x0000000000000000000000000000000000000001',
      );
      expect(a, isFalse);
    });
  });
}

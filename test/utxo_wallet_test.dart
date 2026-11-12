import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  group('Bitcoin official derivation vectors', () {
    test('BIP84 native SegWit first address', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2wpkh,
      );
      expect(account.address, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
      expect(account.path, "m/84'/0'/0'/0/0");
    });

    test('BIP86 Taproot first address', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2tr,
      );
      expect(
        account.address,
        'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr',
      );
      expect(account.path, "m/86'/0'/0'/0/0");
    });

    test('BIP49 nested SegWit first address', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2shP2wpkh,
      );
      expect(account.address, '37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf');
      expect(account.path, "m/49'/0'/0'/0/0");
    });

    test('BIP44 legacy first address', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2pkh,
      );
      expect(account.address, '1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA');
      expect(account.path, "m/44'/0'/0'/0/0");
    });
  });

  group('network-aware addresses', () {
    test('Bitcoin testnet SegWit uses tb1', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcTestnet,
        kind: UtxoAddressKind.p2wpkh,
      );
      expect(account.address.startsWith('tb1q'), isTrue);
      expect(account.path, "m/84'/1'/0'/0/0");
    });

    test('Litecoin mainnet SegWit uses ltc1', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.ltcMainnet,
        kind: UtxoAddressKind.p2wpkh,
      );
      expect(account.address.startsWith('ltc1q'), isTrue);
      expect(account.path, "m/84'/2'/0'/0/0");
    });

    test('Dogecoin mainnet legacy starts with D', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.dogeMainnet,
        kind: UtxoAddressKind.p2pkh,
      );
      expect(account.address.startsWith('D'), isTrue);
      expect(account.path, "m/44'/3'/0'/0/0");
    });

    test('each generated address validates on its own network only', () {
      for (final network in UtxoNetworks.all) {
        final kind = network.addressKinds.first;
        final account = UtxoWallet.derive(
          phrase: _phrase,
          network: network,
          kind: kind,
        );
        expect(UtxoWallet.validateAddress(account.address, network), isTrue);
        expect(
          UtxoWallet.validateAddress(account.address, UtxoNetworks.btcMainnet),
          network.key == 'btc-mainnet',
        );
      }
    });
  });

  group('key formats', () {
    test('WIF round-trips and keeps the same address', () {
      for (final network in UtxoNetworks.all) {
        final kind = network.addressKinds.first;
        final account = UtxoWallet.derive(
          phrase: _phrase,
          network: network,
          kind: kind,
        );
        final restored = UtxoWallet.fromWif(
          wif: account.wif,
          network: network,
          kind: kind,
        );
        expect(restored.address, account.address, reason: network.key);
        expect(restored.privateKey.toHex(), account.privateKey.toHex());
      }
    });

    test('raw hex import matches WIF import', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2wpkh,
      );
      final imported = UtxoWallet.fromHex(
        privateKeyHex: account.privateKey.toHex(),
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2wpkh,
      );
      expect(imported.address, account.address);
    });

    test('wrong-network WIF is rejected', () {
      final account = UtxoWallet.derive(
        phrase: _phrase,
        network: UtxoNetworks.btcMainnet,
        kind: UtxoAddressKind.p2pkh,
      );
      expect(
        () => UtxoWallet.fromWif(
          wif: account.wif,
          network: UtxoNetworks.ltcMainnet,
        ),
        throwsA(isA<UtxoWalletException>()),
      );
    });

    test('invalid mnemonic is rejected', () {
      expect(
        () => UtxoWallet.derive(
          phrase: 'not a real mnemonic phrase',
          network: UtxoNetworks.btcMainnet,
          kind: UtxoAddressKind.p2wpkh,
        ),
        throwsA(isA<UtxoWalletException>()),
      );
    });
  });
}

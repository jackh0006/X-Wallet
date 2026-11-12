import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chain identity matches official Core parameters', () {
    test('Bitcoin mainnet/testnet', () {
      final main = UtxoNetworks.btcMainnet;
      expect(
        main.genesisHash,
        '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
      );
      expect(main.magicHex, 'f9beb4d9');
      expect(main.defaultPort, 8333);
      expect(main.powAlgorithm, 'SHA-256d');

      final test = UtxoNetworks.btcTestnet;
      expect(
        test.genesisHash,
        '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
      );
      expect(test.magicHex, '0b110907');
      expect(test.defaultPort, 18333);
    });

    test('Litecoin mainnet/testnet', () {
      final main = UtxoNetworks.ltcMainnet;
      expect(
        main.genesisHash,
        '12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2',
      );
      expect(main.magicHex, 'fbc0b6db');
      expect(main.defaultPort, 9333);
      expect(main.powAlgorithm, 'Scrypt');
      expect(main.supportsMweb, isFalse);

      final test = UtxoNetworks.ltcTestnet;
      expect(
        test.genesisHash,
        '4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0',
      );
      expect(test.magicHex, 'fdd2c8f1');
      expect(test.defaultPort, 19335);
    });

    test('Dogecoin mainnet/testnet', () {
      final main = UtxoNetworks.dogeMainnet;
      expect(
        main.genesisHash,
        '1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691',
      );
      expect(main.magicHex, 'c0c0c0c0');
      expect(main.defaultPort, 22556);
      expect(main.powAlgorithm, 'Scrypt');
      expect(main.consensusNotes, contains('AuxPoW'));

      final test = UtxoNetworks.dogeTestnet;
      expect(
        test.genesisHash,
        'bb0a78264637406b6360aad926284d544d7049f45189db5664f3c4d07350559e',
      );
      expect(test.magicHex, 'fcc1b7dc');
      expect(test.defaultPort, 44556);
    });

    test('no two networks share identity parameters', () {
      final seen = <String>{};
      for (final network in UtxoNetworks.all) {
        expect(seen.add(network.genesisHash), isTrue, reason: network.key);
        expect(seen.add(network.magicHex), isTrue, reason: network.key);
        expect(seen.add('${network.defaultPort}'), isTrue, reason: network.key);
      }
    });

    test('network address prefixes never cross-validate', () {
      for (final a in UtxoNetworks.all) {
        for (final b in UtxoNetworks.all) {
          if (a.key == b.key) continue;
          final kind = a.addressKinds.first;
          final account = UtxoWallet.derive(
            phrase: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
            network: a,
            kind: kind,
          );
          // Testnet P2PKH version bytes are shared by BTC/LTC/DOGE. A base58
          // address alone cannot distinguish those test networks; mainnet
          // prefixes are distinct. The UI must always show the selected chain.
          final bothTestnets = a.isTestnet && b.isTestnet;
          expect(
            UtxoWallet.validateAddress(account.address, b),
            bothTestnets ? isA<bool>() : isFalse,
            reason: '${a.key} address validated on ${b.key}',
          );
        }
      }
    });
  });
}

import 'package:bnb_wallet_gui/chains.dart';
import 'package:bnb_wallet_gui/default_tokens.dart';
import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:bnb_wallet_gui/token_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('chain registry', () {
    test(
      'supports BNB and Ethereum mainnet/testnet with explicit chain IDs',
      () {
        expect(Chains.byKey('mainnet').chainId, 56);
        expect(Chains.byKey('testnet').chainId, 97);
        expect(Chains.byKey('ethereum').chainId, 1);
        expect(Chains.byKey('sepolia').chainId, 11155111);
        expect(Chains.byKey('ethereum').nativeSymbol, 'ETH');
        expect(Chains.byKey('mainnet').nativeSymbol, 'BNB');
        expect(Chains.byKey('ethereum').explorerBase, 'https://etherscan.io');
        expect(Chains.byKey('sepolia').isTestnet, isTrue);
      },
    );

    test('legacy network table exposes every chain', () {
      for (final chain in Chains.all) {
        expect(BnbNetworks.chainIds[chain.key], chain.chainId);
        expect(BnbNetworks.defaultRpcs[chain.key], chain.defaultRpcs.first);
        expect(BnbNetworks.explorers[chain.key], chain.explorerBase);
      }
    });

    test('a BNB node URL is not an Ethereum default', () {
      final eth = Chains.byKey('ethereum');
      expect(eth.defaultRpcs.any((url) => url.contains('bsc')), isFalse);
      expect(eth.fallbacks.any((url) => url.contains('bsc')), isFalse);
    });
  });

  group('default Ethereum tokens', () {
    test('USDT, USDC and XAUT use canonical Ethereum contracts', () {
      expect(
        DefaultTokens.ethUsdt.address,
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      );
      expect(DefaultTokens.ethUsdt.decimals, 6);
      expect(
        DefaultTokens.ethUsdc.address,
        '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      );
      expect(DefaultTokens.ethUsdc.decimals, 6);
      expect(
        DefaultTokens.ethXaut.address,
        '0x68749665FF8D2d112Fa859AA293F07A622782F38',
      );
      expect(DefaultTokens.ethXaut.decimals, 6);
      expect(DefaultTokens.ethXaut.symbol, 'XAUT');
      expect(DefaultTokens.ethereum, hasLength(3));
      expect(DefaultTokens.all, containsAll(DefaultTokens.bsc));
      expect(DefaultTokens.all, containsAll(DefaultTokens.ethereum));
    });

    test('Ethereum token presentation is chain-aware', () {
      final usdt = TokenRegistry.of(DefaultTokens.ethUsdt);
      expect(usdt.symbol, 'USDT');
      expect(usdt.network, 'Ethereum');
      expect(usdt.canonical, isTrue);

      final xaut = TokenRegistry.of(DefaultTokens.ethXaut);
      expect(xaut.symbol, 'XAUT');
      expect(xaut.network, 'Ethereum');

      final native = TokenInfo(
        symbol: 'ETH',
        name: 'Ether',
        address: '',
        decimals: 18,
        network: 'ethereum',
        native: true,
      );
      expect(TokenRegistry.label(native), 'ETH · Ethereum');
    });

    test('a BSC contract on the Ethereum network stays unverified', () {
      const fake = TokenInfo(
        symbol: 'USDT',
        name: 'Tether USD',
        address: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18,
        network: 'ethereum',
      );
      final shown = TokenRegistry.of(fake);
      expect(shown.canonical, isFalse);
      expect(shown.symbol, contains('unverified'));
    });
  });

  group('saved RPC nodes are isolated per chain', () {
    test('a BNB node never becomes the Ethereum node', () async {
      SharedPreferences.setMockInitialValues({});
      AppStorage.resetPreferencesForTest();
      await AppStorage.init();

      await AppStorage.setRpc('https://bnb.example', 'mainnet');
      await AppStorage.setRpc('https://eth.example', 'ethereum');

      expect(AppStorage.getRpcFor('mainnet'), 'https://bnb.example');
      expect(AppStorage.getRpcFor('ethereum'), 'https://eth.example');
      expect(AppStorage.getRpcFor('sepolia'), Chains.sepolia.defaultRpcs.first);
      // Switching the active network must not overwrite the other chain.
      await AppStorage.setNetwork('ethereum');
      expect(AppStorage.getRpcFor('mainnet'), 'https://bnb.example');
    });
  });

  group('explorer keys are isolated', () {
    test('BscScan and Etherscan keys never cross', () {
      final rpc = RpcService();
      rpc.setExplorerKey('mainnet', 'bsc-key');
      rpc.setExplorerKey('ethereum', 'eth-key');
      expect(rpc.explorerKeyFor('mainnet'), 'bsc-key');
      expect(rpc.explorerKeyFor('testnet'), 'bsc-key');
      expect(rpc.explorerKeyFor('ethereum'), 'eth-key');
      expect(rpc.explorerKeyFor('sepolia'), 'eth-key');
    });
  });
}

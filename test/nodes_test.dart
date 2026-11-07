import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/app_state.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:bnb_wallet_gui/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  final state = AppState();

  group('RPC node phone book (terminal-grade management)', () {
    test('adds, filters by network side, rejects duplicates', () async {
      await state.addNode(
        'My home node',
        'https://node.example/test',
        network: 'testnet',
      );
      await state.addNode(
        'Other node',
        'https://other.example',
        network: 'mainnet',
      );

      // currentNetworkNodes filters by the side the RPC is standing on.
      state.rpc.setNetwork('testnet');
      expect(state.currentNetworkNodes.map((n) => n.label), ['My home node']);
      state.rpc.setNetwork('mainnet');
      expect(state.currentNetworkNodes.map((n) => n.label), ['Other node']);

      // Duplicate URLs are refused (case-insensitive).
      await expectLater(
        state.addNode('Another label', 'HTTPS://OTHER.EXAMPLE'),
        throwsStateError,
      );
    });

    test('edits label + url and keeps the node on its side', () async {
      await state.addNode('First', 'https://first.example', network: 'mainnet');
      final index = state.nodes.indexWhere((n) => n.label == 'First');
      await state.editNode(index, 'Second', 'https://second.example');
      expect(state.nodes[index].label, 'Second');
      expect(state.nodes[index].url, 'https://second.example');
      expect(state.nodes[index].network, 'mainnet');
    });

    test('isNodeActive matches the currently configured RPC', () async {
      final node = state.nodes.first;
      expect(state.isNodeActive(node), node.url == state.rpc.configuredRpc);
    });

    test('delete of a non-active node keeps the active door intact', () async {
      await state.addNode(
        'Victim',
        'https://victim.example',
        network: 'mainnet',
      );
      final victimIndex = state.nodes.indexWhere((n) => n.label == 'Victim');
      final victim = state.nodes[victimIndex];
      final activeBefore = state.rpc.configuredRpc;
      await state.deleteNode(victimIndex);
      expect(state.nodes.contains(victim), isFalse);
      expect(state.rpc.configuredRpc, activeBefore);
    });

    test('reset brings back the official doors for both sides', () async {
      await state.resetNodesToDefaults();
      final mainnet = [
        for (final n in state.nodes)
          if (n.network == 'mainnet') n,
      ];
      final testnet = [
        for (final n in state.nodes)
          if (n.network == 'testnet') n,
      ];
      expect(mainnet.length, BnbNetworks.mainnetFallbacks.length);
      expect(testnet.length, BnbNetworks.testnetFallbacks.length);
      expect(mainnet.every((n) => n.url.startsWith('https://')), isTrue);
      expect(testnet.every((n) => n.url.startsWith('https')), isTrue);
    });

    test('every node mutation writes a story line', () async {
      state.rpc.clearStory();
      await state.addNode(
        'Storyful',
        'https://story.example',
        network: 'mainnet',
      );
      expect(
        state.rpc.story.where((l) => l.text.contains('Storyful')),
        isNotEmpty,
      );
      state.rpc.clearStory();
    });
  });
}

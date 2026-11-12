import 'dart:convert';

import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const wallet = '0x1111111111111111111111111111111111111111';

  http.Response historyResponse() => http.Response(
    jsonEncode({
      'status': '1',
      'message': 'OK',
      'result': [
        {
          'hash': '0xabc',
          'from': wallet,
          'to': '0x2222222222222222222222222222222222222222',
          'value': '1000',
          'timeStamp': '1700000000',
          'isError': '0',
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  test('Ethereum history goes to Etherscan v2 with chainid 1', () async {
    Uri? seen;
    final rpc = RpcService(
      httpClient: MockClient((request) async {
        seen = request.url;
        return historyResponse();
      }),
    );
    rpc.setNetwork('ethereum');
    rpc.setExplorerKey('ethereum', 'eth-key');

    final rows = await rpc.history(wallet);
    expect(rows, hasLength(1));
    expect(seen!.host, 'api.etherscan.io');
    expect(seen!.path, '/v2/api');
    expect(seen!.queryParameters['chainid'], '1');
    expect(seen!.queryParameters['apikey'], 'eth-key');
    expect(seen!.queryParameters['address'], wallet);
  });

  test('BSC history stays on BscScan with chainid 56', () async {
    Uri? seen;
    final rpc = RpcService(
      httpClient: MockClient((request) async {
        seen = request.url;
        return historyResponse();
      }),
    );
    rpc.setNetwork('mainnet');
    rpc.setExplorerKey('mainnet', 'bsc-key');

    await rpc.history(wallet);
    expect(seen!.host, 'api.bscscan.com');
    expect(seen!.queryParameters['chainid'], '56');
    expect(seen!.queryParameters['apikey'], 'bsc-key');
  });

  test('Sepolia history uses chainid 11155111', () async {
    Uri? seen;
    final rpc = RpcService(
      httpClient: MockClient((request) async {
        seen = request.url;
        return historyResponse();
      }),
    );
    rpc.setNetwork('sepolia');
    rpc.setExplorerKey('sepolia', 'eth-key');

    await rpc.history(wallet);
    expect(seen!.queryParameters['chainid'], '11155111');
    expect(seen!.host, 'api.etherscan.io');
  });

  test('a BSC key alone cannot unlock Ethereum history', () async {
    final rpc = RpcService(
      httpClient: MockClient((request) async => historyResponse()),
    );
    rpc.setExplorerKey('mainnet', 'bsc-key');
    rpc.setNetwork('ethereum');

    expect(() => rpc.history(wallet), throwsStateError);
  });
}

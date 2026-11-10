import 'dart:convert';

import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _rpcUrl = 'http://127.0.0.1:8545';

http.Response _rpc(Object? id, Object? result) => http.Response(
  jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
  200,
  headers: {'content-type': 'application/json'},
);

RpcService _service(Future<http.Response> Function(http.Request) handler) {
  final rpc = RpcService(httpClient: MockClient(handler));
  rpc.setStrictFlag(true);
  rpc.setConfiguredRpc(_rpcUrl);
  addTearDown(rpc.dispose);
  return rpc;
}

MockClient _chainClient(String chainHex, {String balance = '0x0'}) {
  return MockClient((request) async {
    final body = jsonDecode(request.body);
    if (body is! Map) return http.Response('not a request', 400);
    final method = body['method'];
    return switch (method) {
      'eth_chainId' => _rpc(body['id'], chainHex),
      'eth_getBalance' => _rpc(body['id'], balance),
      'eth_blockNumber' => _rpc(body['id'], '0x1'),
      'eth_getTransactionCount' => _rpc(body['id'], '0x0'),
      _ => http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'error': {'code': -32601, 'message': 'method not found'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    };
  });
}

void main() {
  test('a correct chain ID connects and a wrong one fails closed', () async {
    final good = RpcService(
      httpClient: _chainClient('0x38'), // 56
    );
    good.setStrictFlag(true);
    good.setConfiguredRpc(_rpcUrl);
    addTearDown(good.dispose);
    await good.connect(allowFallback: false);
    expect(good.isConnected, isTrue);
    expect(good.chainId, 56);

    final wrong = _service((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _rpc(body['id'], '0x1'); // Ethereum mainnet
    });
    await expectLater(
      wrong.connect(allowFallback: false),
      throwsA(isA<StateError>()),
    );
    expect(wrong.isConnected, isFalse);
  });

  test(
    'a non-JSON or HTML response is a connection failure, not a crash',
    () async {
      final rpc = _service(
        (_) async => http.Response('<html>captive portal</html>', 200),
      );
      await expectLater(
        rpc.connect(allowFallback: false),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('an oversized uint256 balance is preserved exactly', () async {
    const max =
        '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    final rpc = _service((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return switch (body['method']) {
        'eth_chainId' => _rpc(body['id'], '0x38'),
        'eth_getBalance' => _rpc(body['id'], max),
        _ => _rpc(body['id'], '0x0'),
      };
    });
    await rpc.connect(allowFallback: false);
    final balance = await rpc.getNativeBalance(
      '0x1111111111111111111111111111111111111111',
    );
    expect(balance, BigInt.parse(max.substring(2), radix: 16));
  });

  test('a malformed balance is refused instead of being guessed', () async {
    final rpc = _service((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return switch (body['method']) {
        'eth_chainId' => _rpc(body['id'], '0x38'),
        'eth_getBalance' => _rpc(body['id'], 'not-hex'),
        _ => _rpc(body['id'], '0x0'),
      };
    });
    await rpc.connect(allowFallback: false);
    await expectLater(
      rpc.getNativeBalance('0x1111111111111111111111111111111111111111'),
      throwsA(anything),
    );
  });

  test('switching to testnet rejects a node that answers mainnet', () async {
    final rpc = _service((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _rpc(body['id'], '0x38'); // 56, not 97
    });
    rpc.setNetwork('testnet');
    expect(rpc.chainId, 97);
    await expectLater(
      rpc.connect(allowFallback: false),
      throwsA(isA<StateError>()),
    );
  });

  test('the URL policy never allows plain HTTP to a public host', () {
    expect(nodeUrlAllowed('https://bsc-dataseed.example'), isTrue);
    expect(nodeUrlAllowed('http://127.0.0.1:8545'), isTrue);
    expect(nodeUrlAllowed('http://10.0.0.5:8545'), isTrue);
    expect(nodeUrlAllowed('http://192.168.1.5:8545'), isTrue);
    expect(nodeUrlAllowed('http://example.com'), isFalse);
    expect(nodeUrlAllowed('ws://example.com'), isFalse);
    expect(nodeUrlAllowed(''), isFalse);
    expect(nodeUrlAllowed('https://user:pass@node.example'), isFalse);
    expect(nodeUrlAllowed('https://169.254.169.254/latest/meta-data'), isFalse);
    expect(nodeUrlAllowed('https://metadata.google.internal'), isFalse);
  });
}

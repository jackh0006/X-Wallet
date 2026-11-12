import 'dart:convert';

import 'package:bnb_wallet_gui/utxo/utxo_network.dart';
import 'package:bnb_wallet_gui/utxo/utxo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
  const txid =
      '1111111111111111111111111111111111111111111111111111111111111111';

  test('kill switch blocks UTXO lookup before any request', () async {
    var calls = 0;
    final service = UtxoService(
      client: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
      killSwitch: () => true,
    );
    await expectLater(
      service.fetchUtxos(UtxoNetworks.btcMainnet, address),
      throwsA(isA<UtxoServiceException>()),
    );
    expect(calls, 0);
  });

  test('Esplora UTXOs are parsed with confirmation state', () async {
    final service = UtxoService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/address/$address/utxo');
        return http.Response(
          jsonEncode([
            {
              'txid': txid,
              'vout': 1,
              'value': 12345,
              'status': {'confirmed': true, 'block_height': 800000},
            },
            {
              'txid': txid,
              'vout': 2,
              'value': 500,
              'status': {'confirmed': false},
            },
          ]),
          200,
        );
      }),
    );
    final utxos = await service.fetchUtxos(UtxoNetworks.btcMainnet, address);
    expect(utxos, hasLength(2));
    expect(utxos.first.valueSatoshi, 12345);
    expect(utxos.first.confirmed, isTrue);
    expect(utxos.first.blockHeight, 800000);
    expect(utxos.last.confirmed, isFalse);
  });

  test('Esplora fee estimate chooses a usable bucket', () async {
    final service = UtxoService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/fee-estimates');
        return http.Response(jsonEncode({'2': 3.2, '6': 1.1}), 200);
      }),
    );
    final quote = await service.feeQuote(UtxoNetworks.btcMainnet);
    expect(quote.satPerVbyte, 4);
    expect(quote.confirmedOnly, isTrue);
  });

  test('Esplora broadcast returns the node txid', () async {
    final service = UtxoService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/tx');
        expect(request.body, '0200');
        return http.Response(txid, 200);
      }),
    );
    expect(await service.broadcast(UtxoNetworks.btcMainnet, '0200'), txid);
  });

  test('BlockCypher Dogecoin UTXOs are parsed', () async {
    final service = UtxoService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.blockcypher.com');
        return http.Response(
          jsonEncode({
            'txrefs': [
              {
                'tx_hash': txid,
                'tx_output_n': 0,
                'value': 100000000,
                'confirmations': 3,
                'block_height': 5000000,
              },
            ],
          }),
          200,
        );
      }),
    );
    final utxos = await service.fetchUtxos(
      UtxoNetworks.dogeMainnet,
      'DH5yaieqoZN36fDVciNyRueRGvGLR3mr7L',
    );
    expect(utxos, hasLength(1));
    expect(utxos.single.valueSatoshi, 100000000);
    expect(utxos.single.confirmed, isTrue);
  });

  test('Dogecoin broadcast parses tx.hash', () async {
    final service = UtxoService(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/doge/main/txs/push');
        return http.Response(
          jsonEncode({
            'tx': {'hash': txid},
          }),
          201,
        );
      }),
    );
    expect(await service.broadcast(UtxoNetworks.dogeMainnet, '0200'), txid);
  });

  test('invalid raw hex and malformed responses are refused', () async {
    final service = UtxoService(
      client: MockClient((_) async => http.Response('{"status":"bad"}', 200)),
    );
    expect(
      () => service.broadcast(UtxoNetworks.btcMainnet, 'xyz'),
      throwsA(isA<UtxoServiceException>()),
    );
    await expectLater(
      service.fetchUtxos(UtxoNetworks.btcMainnet, address),
      throwsA(isA<UtxoServiceException>()),
    );
  });
}

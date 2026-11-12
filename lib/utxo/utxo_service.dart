// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../net/privacy_client.dart';
import 'utxo_network.dart';
import 'utxo_transaction.dart';

class UtxoServiceException implements Exception {
  const UtxoServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UtxoTransactionStatus {
  const UtxoTransactionStatus({
    required this.confirmed,
    required this.blockHeight,
    required this.confirmations,
  });
  final bool confirmed;
  final int blockHeight;
  final int confirmations;
}

class UtxoFeeQuote {
  const UtxoFeeQuote({
    required this.satPerVbyte,
    required this.source,
    required this.confirmedOnly,
  });
  final int satPerVbyte;
  final String source;
  final bool confirmedOnly;
}

/// Network access for UTXO chains. It is deliberately separate from the EVM
/// RpcService so the kill switch can be applied to both without pretending the
/// protocols are the same.
class UtxoService {
  // The public name is `client`; the field is private by design.
  UtxoService({
    http.Client? client,
    bool Function()? killSwitch,
    http.Client Function()? clientFactory,
  }) : _client = client,
       _killSwitch = killSwitch ?? (() => false),
       _clientFactory = clientFactory ?? createRpcClient;

  http.Client? _client;
  final bool Function() _killSwitch;
  final http.Client Function() _clientFactory;

  http.Client get _transport => _client ??= _clientFactory();

  void _guard() {
    if (_killSwitch()) {
      throw const UtxoServiceException(
        'The network kill switch is on: no UTXO request is allowed.',
      );
    }
  }

  Future<List<Utxo>> fetchUtxos(UtxoNetworkSpec network, String address) async {
    _guard();
    if (!address.trim().isNotEmpty) {
      throw const UtxoServiceException('Address is empty.');
    }
    return switch (network.indexerKind) {
      UtxoIndexerKind.esplora => _fetchEsplora(network, address),
      UtxoIndexerKind.blockCypher => _fetchBlockCypher(network, address),
    };
  }

  Future<List<Utxo>> _fetchEsplora(
    UtxoNetworkSpec network,
    String address,
  ) async {
    final uri = Uri.parse('${network.indexerBase}/address/$address/utxo');
    final response = await _transport
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw UtxoServiceException(
        'UTXO lookup failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const UtxoServiceException('UTXO response is not a list.');
    }
    final out = <Utxo>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final txid = '${item['txid'] ?? ''}';
      final vout = (item['vout'] as num?)?.toInt();
      final value = (item['value'] as num?)?.toInt();
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid) ||
          vout == null ||
          vout < 0 ||
          value == null ||
          value <= 0) {
        throw const UtxoServiceException('Malformed UTXO entry.');
      }
      final status = item['status'];
      final confirmed = status is Map && status['confirmed'] == true;
      final blockHeight = status is Map
          ? (status['block_height'] as num?)?.toInt() ?? 0
          : 0;
      out.add(
        Utxo(
          txid: txid,
          vout: vout,
          valueSatoshi: value,
          confirmed: confirmed,
          blockHeight: blockHeight,
        ),
      );
    }
    return out;
  }

  Future<List<Utxo>> _fetchBlockCypher(
    UtxoNetworkSpec network,
    String address,
  ) async {
    final uri = Uri.parse(
      '${network.indexerBase}/addrs/$address'
      '?unspentOnly=true&includeScript=false',
    );
    final response = await _transport
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw UtxoServiceException(
        'UTXO lookup failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UtxoServiceException('UTXO response is not an object.');
    }
    final refs = decoded['txrefs'];
    if (refs == null) return const [];
    if (refs is! List) {
      throw const UtxoServiceException('UTXO txrefs is not a list.');
    }
    final out = <Utxo>[];
    for (final item in refs) {
      if (item is! Map) continue;
      final txid = '${item['tx_hash'] ?? ''}';
      final vout = (item['tx_output_n'] as num?)?.toInt();
      final value = (item['value'] as num?)?.toInt();
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid) ||
          vout == null ||
          vout < 0 ||
          value == null ||
          value <= 0) {
        throw const UtxoServiceException('Malformed UTXO entry.');
      }
      final confirmations = (item['confirmations'] as num?)?.toInt() ?? 0;
      out.add(
        Utxo(
          txid: txid,
          vout: vout,
          valueSatoshi: value,
          confirmed: confirmations > 0,
          blockHeight: (item['block_height'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return out;
  }

  Future<UtxoFeeQuote> feeQuote(UtxoNetworkSpec network) async {
    _guard();
    if (network.indexerKind == UtxoIndexerKind.blockCypher) {
      // Dogecoin relay policy is expressed per 1000 bytes. 0.001 DOGE/kB is
      // 100 sat/vB; use the relay floor rather than inventing a market rate.
      return const UtxoFeeQuote(
        satPerVbyte: 100,
        source: 'Dogecoin relay floor',
        confirmedOnly: true,
      );
    }
    final uri = Uri.parse('${network.indexerBase}/fee-estimates');
    final response = await _transport
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw UtxoServiceException(
        'Fee lookup failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UtxoServiceException('Fee response is not an object.');
    }
    for (final key in const ['2', '3', '1', '6']) {
      final value = decoded[key];
      if (value is num && value > 0) {
        return UtxoFeeQuote(
          satPerVbyte: value.ceil(),
          source: '${network.shortName} mempool.space $key-block estimate',
          confirmedOnly: true,
        );
      }
    }
    throw const UtxoServiceException('No usable fee estimate returned.');
  }

  Future<UtxoTransactionStatus> transactionStatus(
    UtxoNetworkSpec network,
    String txid,
  ) async {
    _guard();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw const UtxoServiceException('Invalid transaction ID.');
    }
    if (network.indexerKind == UtxoIndexerKind.esplora) {
      final response = await _transport
          .get(Uri.parse('${network.indexerBase}/tx/$txid/status'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        return const UtxoTransactionStatus(
          confirmed: false,
          blockHeight: 0,
          confirmations: 0,
        );
      }
      if (response.statusCode != 200) {
        throw UtxoServiceException(
          'Status lookup failed (HTTP ${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const UtxoServiceException('Status response is not an object.');
      }
      final confirmed = decoded['confirmed'] == true;
      return UtxoTransactionStatus(
        confirmed: confirmed,
        blockHeight: (decoded['block_height'] as num?)?.toInt() ?? 0,
        confirmations: confirmed ? 1 : 0,
      );
    }
    final response = await _transport
        .get(Uri.parse('${network.indexerBase}/txs/$txid'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw UtxoServiceException(
        'Status lookup failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UtxoServiceException('Status response is not an object.');
    }
    final confirmations = (decoded['confirmations'] as num?)?.toInt() ?? 0;
    return UtxoTransactionStatus(
      confirmed: confirmations > 0,
      blockHeight: (decoded['block_height'] as num?)?.toInt() ?? 0,
      confirmations: confirmations,
    );
  }

  Future<String> broadcast(UtxoNetworkSpec network, String rawHex) async {
    _guard();
    final raw = rawHex.startsWith('0x') ? rawHex.substring(2) : rawHex;
    if (raw.isEmpty ||
        raw.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(raw)) {
      throw const UtxoServiceException('Raw transaction is not valid hex.');
    }
    return switch (network.indexerKind) {
      UtxoIndexerKind.esplora => _broadcastEsplora(network, raw),
      UtxoIndexerKind.blockCypher => _broadcastBlockCypher(network, raw),
    };
  }

  Future<String> _broadcastEsplora(UtxoNetworkSpec network, String raw) async {
    final response = await _transport
        .post(
          Uri.parse('${network.indexerBase}/tx'),
          headers: const {'Content-Type': 'text/plain'},
          body: raw,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw UtxoServiceException(
        'Broadcast failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
    final txid = response.body.trim();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw const UtxoServiceException(
        'Node returned an invalid transaction ID.',
      );
    }
    return txid.toLowerCase();
  }

  Future<String> _broadcastBlockCypher(
    UtxoNetworkSpec network,
    String raw,
  ) async {
    final response = await _transport
        .post(
          Uri.parse('${network.indexerBase}/txs/push'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'tx': raw}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw UtxoServiceException(
        'Broadcast failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    final txid = decoded is Map ? '${decoded['tx']?['hash'] ?? ''}' : '';
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw const UtxoServiceException(
        'Node returned an invalid transaction ID.',
      );
    }
    return txid.toLowerCase();
  }
}

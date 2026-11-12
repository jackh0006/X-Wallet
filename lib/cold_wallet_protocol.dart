import 'chains.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import 'cold_tx_codec.dart';
import 'cold_wallet.dart';
import 'wallet_core.dart';

/// Versioned, canonical and strictly validated QR/file protocol used by the
/// cold-wallet flow.
///
/// The protocol is intentionally small and allow-listed.  Unknown fields are
/// rejected instead of being ignored, so a future/forged envelope cannot
/// smuggle a second interpretation of the same transaction past the signer.
class ColdWalletProtocol {
  ColdWalletProtocol._();

  static const String magic = 'BNBCOLD';
  static const int version = 1;
  static const int maxPairingBytes = 8 * 1024;
  static const int maxRequestBytes = 32 * 1024;
  static const int maxSignatureBytes = 16 * 1024;

  static const String kindPairing = 'pairing';
  static const String kindRequest = 'request';
  static const String kindSignature = 'signature';

  // ---------------------------------------------------------------------------
  // Envelope
  // ---------------------------------------------------------------------------

  static String encodeEnvelope({
    required String kind,
    required Map<String, dynamic> payload,
    required int maxBytes,
  }) {
    final canonicalPayload = _canonicalMap(payload);
    final envelope = <String, dynamic>{
      'magic': magic,
      'version': version,
      'kind': kind,
      'payload': canonicalPayload,
      'checksum': checksumOfPayload(canonicalPayload),
    };
    final text = jsonEncode(envelope);
    if (utf8.encode(text).length > maxBytes) {
      throw const ColdProtocolException(
        'Payload is too large for this channel',
      );
    }
    return text;
  }

  static Map<String, dynamic> decodeEnvelope({
    required String text,
    required String expectedKind,
    required int maxBytes,
  }) {
    if (utf8.encode(text).length > maxBytes) {
      throw const ColdProtocolException(
        'Payload is too large for this channel',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const ColdProtocolException('Payload is not valid JSON');
    }
    if (decoded is! Map) {
      throw const ColdProtocolException('Envelope must be a JSON object');
    }
    final envelope = _asMap(decoded);
    _requireExactKeys(envelope, const {
      'magic',
      'version',
      'kind',
      'payload',
      'checksum',
    }, 'envelope');
    if (envelope['magic'] != magic) {
      throw const ColdProtocolException('Unknown cold-wallet protocol');
    }
    if (_asInt(envelope['version'], 'version') != version) {
      throw const ColdProtocolException('Unsupported protocol version');
    }
    if (envelope['kind'] != expectedKind) {
      throw ColdProtocolException(
        'Expected a $expectedKind envelope, got ${envelope['kind']}',
      );
    }
    final payload = _asMap(envelope['payload']);
    final checksum = _asString(envelope['checksum'], 'checksum');
    final expected = checksumOfPayload(payload);
    if (!_constantTimeEquals(checksum.toLowerCase(), expected)) {
      throw const ColdProtocolException('Payload checksum mismatch');
    }
    return payload;
  }

  static String checksumOfPayload(Map<String, dynamic> payload) =>
      crypto.sha256.convert(utf8.encode(canonicalJson(payload))).toString();

  static String canonicalJson(Map<String, dynamic> payload) =>
      jsonEncode(_canonicalMap(payload));

  // ---------------------------------------------------------------------------
  // Pairing
  // ---------------------------------------------------------------------------

  static ColdPairingData exportPairing({
    required String walletName,
    required int chainId,
    required List<String> addresses,
    bool includeXpub = false,
    String? xpub,
  }) {
    if (walletName.trim().isEmpty || walletName.length > 64) {
      throw const ColdProtocolException('Wallet name must be 1–64 characters');
    }
    if (Chains.byChainId(chainId) == null) {
      throw const ColdProtocolException(
        'Only BSC mainnet/testnet pairing is supported',
      );
    }
    if (addresses.isEmpty || addresses.length > 50) {
      throw const ColdProtocolException('Pairing must contain 1–50 addresses');
    }
    final seen = <String>{};
    final normalized = <String>[];
    for (final address in addresses) {
      final checksummed = _validAddress(address);
      if (!seen.add(checksummed.toLowerCase())) {
        throw const ColdProtocolException(
          'Pairing contains duplicate addresses',
        );
      }
      normalized.add(checksummed);
    }
    if (includeXpub && (xpub == null || xpub.trim().isEmpty)) {
      throw const ColdProtocolException('xpub was requested but is empty');
    }
    final data = ColdPairingData(
      version: version,
      walletName: walletName.trim(),
      chainId: chainId,
      addresses: normalized,
      fingerprint: WalletCore.computeFingerprint(
        normalized.first,
        addresses: normalized,
        chainId: chainId,
      ),
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      xpub: includeXpub ? xpub : null,
      includeXpub: includeXpub,
    );
    // Round-trip through the decoder so export cannot produce data the
    // importer would reject.
    decodePairingEnvelope(encodePairing(data));
    return data;
  }

  static String encodePairing(ColdPairingData data) => encodeEnvelope(
    kind: kindPairing,
    payload: data.toJson(),
    maxBytes: maxPairingBytes,
  );

  static ColdPairingData decodePairingEnvelope(String text) => decodePairing(
    decodeEnvelope(
      text: text,
      expectedKind: kindPairing,
      maxBytes: maxPairingBytes,
    ),
  );

  static ColdPairingData decodePairing(Map<String, dynamic> payload) {
    _requireAllowedKeys(payload, const {
      'version',
      'walletName',
      'chainId',
      'addresses',
      'fingerprint',
      'exportedAt',
      'includeXpub',
      'xpub',
    }, 'pairing');
    _requireFields(payload, const {
      'version',
      'walletName',
      'chainId',
      'addresses',
      'fingerprint',
      'exportedAt',
      'includeXpub',
    }, 'pairing');
    if (_asInt(payload['version'], 'version') != version) {
      throw const ColdProtocolException('Unsupported pairing version');
    }
    final walletName = _asString(payload['walletName'], 'walletName').trim();
    if (walletName.isEmpty || walletName.length > 64) {
      throw const ColdProtocolException('Invalid wallet name');
    }
    final chainId = _asInt(payload['chainId'], 'chainId');
    if (Chains.byChainId(chainId) == null) {
      throw const ColdProtocolException('Unsupported pairing chain');
    }
    final rawAddresses = payload['addresses'];
    if (rawAddresses is! List ||
        rawAddresses.isEmpty ||
        rawAddresses.length > 50) {
      throw const ColdProtocolException('Invalid pairing address list');
    }
    final addresses = <String>[];
    final seen = <String>{};
    for (final raw in rawAddresses) {
      final address = _validAddress(_asString(raw, 'address'));
      if (!seen.add(address.toLowerCase())) {
        throw const ColdProtocolException('Duplicate pairing address');
      }
      addresses.add(address);
    }
    final fingerprint = _asString(payload['fingerprint'], 'fingerprint');
    final expectedFingerprint = WalletCore.computeFingerprint(
      addresses.first,
      addresses: addresses,
      chainId: chainId,
    );
    if (fingerprint != expectedFingerprint) {
      throw const ColdProtocolException('Pairing fingerprint mismatch');
    }
    final exportedAt = _validTimestamp(payload['exportedAt'], 'exportedAt');
    if (exportedAt.isAfter(
      DateTime.now().toUtc().add(const Duration(days: 1)),
    )) {
      throw const ColdProtocolException('Pairing export time is in the future');
    }
    final includeXpub = payload['includeXpub'] == true;
    final xpub = payload['xpub']?.toString();
    if (includeXpub &&
        (xpub == null || xpub.trim().isEmpty || xpub.length > 256)) {
      throw const ColdProtocolException('Invalid xpub');
    }
    if (!includeXpub && xpub != null && xpub.isNotEmpty) {
      throw const ColdProtocolException('xpub present without includeXpub');
    }
    return ColdPairingData(
      version: version,
      walletName: walletName,
      chainId: chainId,
      addresses: addresses,
      fingerprint: fingerprint,
      exportedAt: exportedAt.toIso8601String(),
      xpub: includeXpub ? xpub : null,
      includeXpub: includeXpub,
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction request
  // ---------------------------------------------------------------------------

  static String encodeRequest(ColdTxRequest request) {
    validateRequest(request);
    return encodeEnvelope(
      kind: kindRequest,
      payload: request.toJson(),
      maxBytes: maxRequestBytes,
    );
  }

  static ColdTxRequest decodeRequestEnvelope(String text) => decodeRequest(
    decodeEnvelope(
      text: text,
      expectedKind: kindRequest,
      maxBytes: maxRequestBytes,
    ),
  );

  static ColdTxRequest decodeRequest(Map<String, dynamic> payload) {
    _requireExactKeys(payload, const {
      'version',
      'chainId',
      'from',
      'to',
      'value',
      'gasLimit',
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'nonce',
      'data',
      'assetInfo',
      'expiresAt',
      'createdAt',
      'id',
    }, 'request');
    if (_asInt(payload['version'], 'version') != version) {
      throw const ColdProtocolException('Unsupported request version');
    }
    final request = ColdTxRequest(
      version: version,
      chainId: _asInt(payload['chainId'], 'chainId'),
      from: _validAddress(_asString(payload['from'], 'from')),
      to: _validAddress(_asString(payload['to'], 'to')),
      value: _hexQuantity(payload['value'], 'value'),
      gasLimit: _hexQuantity(payload['gasLimit'], 'gasLimit'),
      maxFeePerGas: _hexQuantity(payload['maxFeePerGas'], 'maxFeePerGas'),
      maxPriorityFeePerGas: _hexQuantity(
        payload['maxPriorityFeePerGas'],
        'maxPriorityFeePerGas',
      ),
      nonce: _asInt(payload['nonce'], 'nonce'),
      data: _hexData(payload['data'], 'data', allowEmpty: true),
      assetInfo: _decodeAssetInfo(payload['assetInfo']),
      expiresAt: _validTimestamp(
        payload['expiresAt'],
        'expiresAt',
      ).toIso8601String(),
      createdAt: _validTimestamp(
        payload['createdAt'],
        'createdAt',
      ).toIso8601String(),
      id: _asString(payload['id'], 'id'),
    );
    validateRequest(request);
    return request;
  }

  static void validateRequest(ColdTxRequest request) {
    if (request.version != version) {
      throw const ColdProtocolException('Unsupported request version');
    }
    if (Chains.byChainId(request.chainId) == null) {
      throw const ColdProtocolException('Unsupported request chain');
    }
    final id = request.id ?? '';
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id)) {
      throw const ColdProtocolException('Invalid request ID');
    }
    final fields = ColdTxFields(
      chainId: request.chainId,
      nonce: BigInt.from(request.nonce),
      maxPriorityFeePerGas: _parseHexBigInt(
        request.maxPriorityFeePerGas,
        'maxPriorityFeePerGas',
      ),
      maxFeePerGas: _parseHexBigInt(request.maxFeePerGas, 'maxFeePerGas'),
      gasLimit: _parseHexBigInt(request.gasLimit, 'gasLimit'),
      to: request.to,
      value: _parseHexBigInt(request.value, 'value'),
      data: _parseHexBytes(request.data, allowEmpty: true),
      accessList: const [],
    );
    ColdTxCodec.validateFields(
      chainId: fields.chainId,
      nonce: fields.nonce,
      maxPriorityFeePerGas: fields.maxPriorityFeePerGas,
      maxFeePerGas: fields.maxFeePerGas,
      gasLimit: fields.gasLimit,
      to: fields.to,
      value: fields.value,
      data: fields.data,
      accessList: fields.accessList,
    );
    if (request.nonce < 0) {
      throw const ColdProtocolException('Negative nonce');
    }
    final created = _validTimestamp(request.createdAt, 'createdAt');
    final expires = _validTimestamp(request.expiresAt, 'expiresAt');
    if (!expires.isAfter(created)) {
      throw const ColdProtocolException('Request expiry must follow creation');
    }
    if (expires.isAfter(created.add(const Duration(hours: 24)))) {
      throw const ColdProtocolException(
        'Request expiry is too far in the future',
      );
    }
    if (created.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      throw const ColdProtocolException(
        'Request creation time is in the future',
      );
    }
    if (DateTime.now().toUtc().isAfter(expires)) {
      throw const ColdProtocolException('Request has expired');
    }
    // Reject a display/asset mismatch that could trick the signer.
    if (request.assetInfo.isNative) {
      if (fields.data.isNotEmpty) {
        throw const ColdProtocolException(
          'Native asset request carries calldata',
        );
      }
    }
  }

  static String requestHash(ColdTxRequest request) {
    validateRequest(request);
    final fields = ColdTxFields(
      chainId: request.chainId,
      nonce: BigInt.from(request.nonce),
      maxPriorityFeePerGas: _parseHexBigInt(
        request.maxPriorityFeePerGas,
        'maxPriorityFeePerGas',
      ),
      maxFeePerGas: _parseHexBigInt(request.maxFeePerGas, 'maxFeePerGas'),
      gasLimit: _parseHexBigInt(request.gasLimit, 'gasLimit'),
      to: request.to,
      value: _parseHexBigInt(request.value, 'value'),
      data: _parseHexBytes(request.data, allowEmpty: true),
      accessList: const [],
    );
    return fields.signingDigestHex;
  }

  // ---------------------------------------------------------------------------
  // Signed response
  // ---------------------------------------------------------------------------

  static String encodeSignature(ColdTxSignature signature) {
    validateSignature(signature);
    return encodeEnvelope(
      kind: kindSignature,
      payload: signature.toJson(),
      maxBytes: maxSignatureBytes,
    );
  }

  static ColdTxSignature decodeSignatureEnvelope(String text) =>
      decodeSignature(
        decodeEnvelope(
          text: text,
          expectedKind: kindSignature,
          maxBytes: maxSignatureBytes,
        ),
      );

  static ColdTxSignature decodeSignature(Map<String, dynamic> payload) {
    _requireExactKeys(payload, const {
      'version',
      'requestId',
      'requestHash',
      'chainId',
      'from',
      'r',
      's',
      'v',
      'yParity',
      'signedTxHash',
      'signedAt',
      'rawSignedTx',
    }, 'signature');
    final signature = ColdTxSignature(
      version: _asInt(payload['version'], 'version'),
      requestId: _asString(payload['requestId'], 'requestId'),
      requestHash: _asString(payload['requestHash'], 'requestHash'),
      chainId: _asInt(payload['chainId'], 'chainId'),
      from: _validAddress(_asString(payload['from'], 'from')),
      r: _hexData(payload['r'], 'r'),
      s: _hexData(payload['s'], 's'),
      v: _hexQuantity(payload['v'], 'v'),
      yParity: _asInt(payload['yParity'], 'yParity'),
      signedTxHash: _hexData(payload['signedTxHash'], 'signedTxHash'),
      signedAt: _validTimestamp(
        payload['signedAt'],
        'signedAt',
      ).toIso8601String(),
      rawSignedTx: _hexData(payload['rawSignedTx'], 'rawSignedTx'),
    );
    validateSignature(signature);
    return signature;
  }

  static void validateSignature(ColdTxSignature signature) {
    if (signature.version != version) {
      throw const ColdProtocolException('Unsupported signature version');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(signature.requestId)) {
      throw const ColdProtocolException('Invalid request ID in signature');
    }
    if (Chains.byChainId(signature.chainId) == null) {
      throw const ColdProtocolException('Unsupported signature chain');
    }
    if (signature.r.length != 66 ||
        signature.s.length != 66 ||
        !_isHex(signature.r) ||
        !_isHex(signature.s)) {
      throw const ColdProtocolException('r/s must be 32-byte hex strings');
    }
    final v = _parseHexInt(signature.v, 'v');
    if (v < 0 || v > 3) {
      throw const ColdProtocolException('v must be the full recovery ID 0..3');
    }
    if (signature.yParity != (v & 1)) {
      throw const ColdProtocolException('yParity does not match v');
    }
    if (signature.signedTxHash.length != 66 ||
        !_isHex(signature.signedTxHash)) {
      throw const ColdProtocolException('Invalid signed transaction hash');
    }
    if (signature.requestHash == null ||
        signature.requestHash!.length != 66 ||
        !_isHex(signature.requestHash!)) {
      throw const ColdProtocolException('Invalid request hash');
    }
    if (signature.rawSignedTx == null ||
        !signature.rawSignedTx!.startsWith('0x02')) {
      throw const ColdProtocolException('Missing or invalid raw signed tx');
    }
    final raw = _parseHexBytes(signature.rawSignedTx!, allowEmpty: false);
    final parsed = ColdTxCodec.parseSigned(Uint8List.fromList(raw));
    if (parsed.fields.chainId != signature.chainId) {
      throw const ColdProtocolException('Raw transaction chain mismatch');
    }
    if (parsed.yParity != signature.yParity) {
      throw const ColdProtocolException('Raw transaction yParity mismatch');
    }
    if (parsed.hash.toLowerCase() != signature.signedTxHash.toLowerCase()) {
      throw const ColdProtocolException('Raw transaction hash mismatch');
    }
    final r = _parseHexBigInt(signature.r, 'r');
    final s = _parseHexBigInt(signature.s, 's');
    if (r != parsed.r || s != parsed.s) {
      throw const ColdProtocolException('Raw transaction r/s mismatch');
    }
    final requestHash = signature.requestHash;
    if (requestHash == null || !_isHex(requestHash)) {
      throw const ColdProtocolException('Missing request hash');
    }
    if (parsed.fields.signingDigestHex.toLowerCase() !=
        requestHash.toLowerCase()) {
      throw const ColdProtocolException('Request hash mismatch');
    }
  }

  // ---------------------------------------------------------------------------
  // Strict JSON helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const ColdProtocolException('Expected a JSON object');
    }
    final out = <String, dynamic>{};
    for (final entry in value.entries) {
      out['${entry.key}'] = entry.value;
    }
    return out;
  }

  static void _requireExactKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String where,
  ) {
    _requireAllowedKeys(map, allowed, where);
    _requireFields(map, allowed, where);
  }

  static void _requireAllowedKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String where,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw ColdProtocolException('Unknown field "$key" in $where');
      }
    }
  }

  static void _requireFields(
    Map<String, dynamic> map,
    Set<String> required,
    String where,
  ) {
    for (final key in required) {
      if (!map.containsKey(key)) {
        throw ColdProtocolException('Missing field "$key" in $where');
      }
    }
  }

  static String _asString(Object? value, String field) {
    if (value is! String) {
      throw ColdProtocolException('$field must be a string');
    }
    return value;
  }

  static int _asInt(Object? value, String field) {
    if (value is! int) {
      throw ColdProtocolException('$field must be an integer');
    }
    return value;
  }

  static DateTime _validTimestamp(Object? value, String field) {
    final text = _asString(value, field);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      throw ColdProtocolException('$field is not a valid timestamp');
    }
    return parsed.toUtc();
  }

  static String _validAddress(String value) {
    final clean = value.startsWith('0x') || value.startsWith('0X')
        ? value.substring(2)
        : value;
    if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(clean)) {
      throw ColdProtocolException('Invalid address: $value');
    }
    return EthereumAddress.fromHex('0x$clean').eip55With0x;
  }

  /// Parse a hex quantity (`0x1`, `0x01` and `0x00` are all accepted and
  /// normalised to lowercase). Quantities are not byte strings.
  static String _hexQuantity(Object? value, String field) {
    final text = _asString(value, field).trim();
    if (!text.startsWith('0x') && !text.startsWith('0X')) {
      throw ColdProtocolException('$field must be 0x-prefixed');
    }
    final body = text.substring(2);
    if (body.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(body)) {
      throw ColdProtocolException('$field is not a hex quantity');
    }
    return '0x${body.toLowerCase()}';
  }

  /// Parse a hex byte string. These must contain a whole number of bytes.
  static String _hexData(
    Object? value,
    String field, {
    bool allowEmpty = false,
  }) {
    final text = _asString(value, field).trim();
    if (!text.startsWith('0x') && !text.startsWith('0X')) {
      throw ColdProtocolException('$field must be 0x-prefixed');
    }
    final body = text.substring(2);
    if (body.isEmpty && !allowEmpty) {
      throw ColdProtocolException('$field must not be empty');
    }
    if (body.isNotEmpty && !RegExp(r'^[0-9a-fA-F]+$').hasMatch(body)) {
      throw ColdProtocolException('$field is not valid hex');
    }
    if (body.length.isOdd) {
      throw ColdProtocolException(
        '$field must have an even number of hex digits',
      );
    }
    return '0x${body.toLowerCase()}';
  }

  static Uint8List _parseHexBytes(String value, {required bool allowEmpty}) {
    if (!value.startsWith('0x') && !value.startsWith('0X')) {
      throw const ColdProtocolException('Hex bytes need a 0x prefix');
    }
    final body = value.substring(2);
    if (body.isEmpty) {
      if (allowEmpty) return Uint8List(0);
      throw const ColdProtocolException('Hex bytes must not be empty');
    }
    if (body.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(body)) {
      throw const ColdProtocolException('Invalid hex bytes');
    }
    return Uint8List.fromList(hexToBytes(body));
  }

  static BigInt _parseHexBigInt(String value, String field) {
    if (!value.startsWith('0x') && !value.startsWith('0X')) {
      throw ColdProtocolException('$field must be 0x-prefixed');
    }
    final body = value.substring(2);
    if (body.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(body)) {
      throw ColdProtocolException('$field is not valid hex');
    }
    return BigInt.parse(body, radix: 16);
  }

  static int _parseHexInt(String value, String field) {
    final parsed = _parseHexBigInt(value, field);
    if (parsed > BigInt.from(0x7fffffff)) {
      throw ColdProtocolException('$field is too large');
    }
    return parsed.toInt();
  }

  static bool _isHex(String value) =>
      value.startsWith('0x') &&
      RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value) &&
      (value.length - 2).isEven;

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static ColdTxAssetInfo _decodeAssetInfo(Object? value) {
    final map = _asMap(value);
    _requireAllowedKeys(map, const {
      'isNative',
      'symbol',
      'name',
      'contractAddress',
      'decimals',
      'isUnknown',
      'warning',
    }, 'assetInfo');
    _requireFields(map, const {'isNative', 'isUnknown'}, 'assetInfo');
    final contract = map['contractAddress']?.toString();
    if (contract != null && contract.isNotEmpty) {
      _validAddress(contract);
    }
    return ColdTxAssetInfo(
      isNative: map['isNative'] == true,
      symbol: map['symbol']?.toString(),
      name: map['name']?.toString(),
      contractAddress: contract,
      decimals: (map['decimals'] as num?)?.toInt(),
      isUnknown: map['isUnknown'] == true,
      warning: map['warning']?.toString(),
    );
  }

  static Map<String, dynamic> _canonicalMap(Map<String, dynamic> input) {
    final keys = input.keys.toList()..sort();
    final out = <String, dynamic>{};
    for (final key in keys) {
      out[key] = _canonicalValue(input[key]);
    }
    return out;
  }

  static Object? _canonicalValue(Object? value) {
    if (value is Map) {
      return _canonicalMap(_asMap(value));
    }
    if (value is List) {
      return [for (final item in value) _canonicalValue(item)];
    }
    return value;
  }
}

class ColdProtocolException implements Exception {
  const ColdProtocolException(this.message);
  final String message;
  @override
  String toString() => 'ColdProtocolException: $message';
}

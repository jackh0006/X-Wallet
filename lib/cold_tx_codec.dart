import 'dart:typed_data';

import 'chains.dart';

import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

/// Strict EIP-1559 transaction codec used by the cold-wallet flow.
///
/// The `rlp` package treats every `List<int>` as an RLP list, which is wrong
/// for byte strings such as a 20-byte address or calldata.  This codec encodes
/// byte strings explicitly and parses signed transactions with canonical-RLP
/// checks.  It is deliberately independent from the wallet's signing and
/// recovery code so a malformed transaction cannot be accepted just because
/// the same faulty encoder produced it.
class ColdTxCodec {
  ColdTxCodec._();

  static final BigInt _secp256k1N = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );
  static final BigInt _halfN = _secp256k1N >> 1;
  static final BigInt _maxUint256 = (BigInt.one << 256) - BigInt.one;

  static const int maxDataBytes = 128 * 1024;
  static const int maxGasLimit = 30000000;
  static final Set<int> supportedChainIds = Set.unmodifiable({
    for (final chain in Chains.all) chain.chainId,
  });

  /// Validate the common EIP-1559 field bounds.  Throws [ColdTxFormatException]
  /// with a stable reason instead of silently signing nonsense.
  static void validateFields({
    required int chainId,
    required BigInt nonce,
    required BigInt maxPriorityFeePerGas,
    required BigInt maxFeePerGas,
    required BigInt gasLimit,
    required String to,
    required BigInt value,
    required Uint8List data,
    required List<ColdAccessListItem> accessList,
    bool enforceChain = true,
  }) {
    if (enforceChain && !supportedChainIds.contains(chainId)) {
      throw ColdTxFormatException('Unsupported chain ID: $chainId');
    }
    if (nonce < BigInt.zero || nonce > _maxUint256) {
      throw const ColdTxFormatException('Invalid nonce');
    }
    if (maxPriorityFeePerGas < BigInt.zero ||
        maxFeePerGas < BigInt.zero ||
        maxPriorityFeePerGas > _maxUint256 ||
        maxFeePerGas > _maxUint256) {
      throw const ColdTxFormatException('Invalid fee');
    }
    if (maxFeePerGas < maxPriorityFeePerGas) {
      throw const ColdTxFormatException(
        'maxFeePerGas is lower than maxPriorityFeePerGas',
      );
    }
    if (gasLimit <= BigInt.zero || gasLimit > BigInt.from(maxGasLimit)) {
      throw ColdTxFormatException('Invalid gas limit: $gasLimit');
    }
    if (value < BigInt.zero || value > _maxUint256) {
      throw const ColdTxFormatException('Invalid value');
    }
    if (data.length > maxDataBytes) {
      throw const ColdTxFormatException('Calldata is too large');
    }
    final toBytes = _parseAddress(to);
    if (toBytes.every((b) => b == 0)) {
      throw const ColdTxFormatException('Refusing to send to the zero address');
    }
    if (accessList.isNotEmpty) {
      throw const ColdTxFormatException(
        'Access lists are not supported by this cold-wallet protocol',
      );
    }
  }

  /// Build the exact bytes that are hashed for EIP-1559 signing:
  /// `0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas,
  /// gasLimit, to, value, data, accessList])`.
  static Uint8List unsignedPayload(ColdTxFields fields) {
    final list = _list([
      encodeInt(BigInt.from(fields.chainId)),
      encodeInt(fields.nonce),
      encodeInt(fields.maxPriorityFeePerGas),
      encodeInt(fields.maxFeePerGas),
      encodeInt(fields.gasLimit),
      encodeBytes(_parseAddress(fields.to)),
      encodeInt(fields.value),
      encodeBytes(fields.data),
      encodeList(const []),
    ]);
    return Uint8List.fromList([0x02, ...list]);
  }

  static Uint8List signingDigest(ColdTxFields fields) =>
      _keccak(unsignedPayload(fields));

  static Uint8List digestOfPayload(Uint8List payload) => _keccak(payload);

  /// Build `0x02 || rlp([... unsigned fields ..., yParity, r, s])`.
  static Uint8List signedPayload(
    ColdTxFields fields, {
    required int yParity,
    required BigInt r,
    required BigInt s,
  }) {
    if (yParity != 0 && yParity != 1) {
      throw const ColdTxFormatException('Invalid yParity');
    }
    _validateSignatureScalars(r, s);
    final list = _list([
      encodeInt(BigInt.from(fields.chainId)),
      encodeInt(fields.nonce),
      encodeInt(fields.maxPriorityFeePerGas),
      encodeInt(fields.maxFeePerGas),
      encodeInt(fields.gasLimit),
      encodeBytes(_parseAddress(fields.to)),
      encodeInt(fields.value),
      encodeBytes(fields.data),
      encodeList(const []),
      encodeInt(BigInt.from(yParity)),
      encodeInt(r),
      encodeInt(s),
    ]);
    return Uint8List.fromList([0x02, ...list]);
  }

  /// Parse a signed EIP-1559 transaction and verify that its RLP is canonical.
  static ColdSignedTx parseSigned(Uint8List raw) {
    if (raw.isEmpty || raw.first != 0x02) {
      throw const ColdTxFormatException('Not an EIP-1559 transaction');
    }
    final reader = _RlpReader(raw.sublist(1));
    final items = reader.readTopLevelList();
    if (!reader.isDone) {
      throw const ColdTxFormatException('Trailing bytes after transaction');
    }
    if (items.length != 12) {
      throw ColdTxFormatException(
        'EIP-1559 transaction must have 12 fields, got ${items.length}',
      );
    }

    final chainId = _readInt(items[0], 'chainId');
    final nonce = _readInt(items[1], 'nonce');
    final maxPriorityFeePerGas = _readInt(items[2], 'maxPriorityFeePerGas');
    final maxFeePerGas = _readInt(items[3], 'maxFeePerGas');
    final gasLimit = _readInt(items[4], 'gasLimit');
    final to = _readAddress(items[5], 'to');
    final value = _readInt(items[6], 'value');
    final data = _readBytes(items[7], 'data');
    final accessList = _readList(items[8], 'accessList');
    if (accessList.isNotEmpty) {
      throw const ColdTxFormatException(
        'Non-empty access list is not supported',
      );
    }
    final yParity = _readInt(items[9], 'yParity');
    if (yParity != BigInt.zero && yParity != BigInt.one) {
      throw const ColdTxFormatException('yParity must be 0 or 1');
    }
    final r = _readInt(items[10], 'r');
    final s = _readInt(items[11], 's');
    _validateSignatureScalars(r, s);

    final fields = ColdTxFields(
      chainId: chainId.toInt(),
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: gasLimit,
      to: EthereumAddress.fromHex(
        bytesToHex(_parseAddress(to), include0x: true),
      ).eip55With0x,
      value: value,
      data: data,
      accessList: const [],
    );
    validateFields(
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

    // Re-encode and compare byte-for-byte: RLP integers must not have leading
    // zeroes and strings/lists must use the shortest possible length prefix.
    final canonical = signedPayload(
      fields,
      yParity: yParity.toInt(),
      r: r,
      s: s,
    );
    if (!_bytesEqual(canonical, raw)) {
      throw const ColdTxFormatException('Non-canonical signed transaction RLP');
    }

    return ColdSignedTx(
      fields: fields,
      yParity: yParity.toInt(),
      r: r,
      s: s,
      raw: Uint8List.fromList(raw),
      hash: bytesToHex(digestOfPayload(raw), include0x: true),
    );
  }

  static void _validateSignatureScalars(BigInt r, BigInt s) {
    if (r <= BigInt.zero || r >= _secp256k1N) {
      throw const ColdTxFormatException('r is outside the secp256k1 range');
    }
    if (s <= BigInt.zero || s > _halfN) {
      throw const ColdTxFormatException(
        's is outside the low-s secp256k1 range',
      );
    }
  }

  /// Encode a byte string.  This is the method that must be used for every
  /// address, calldata and access-list byte payload.
  static Uint8List encodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return Uint8List.fromList([0x80]);
    if (bytes.length == 1 && bytes[0] < 0x80) {
      return Uint8List.fromList([bytes[0]]);
    }
    return _concat(
      _lengthPrefix(bytes.length, 0x80),
      Uint8List.fromList(bytes),
    );
  }

  /// Encode a non-negative integer with the shortest RLP representation.
  static Uint8List encodeInt(BigInt value) {
    if (value < BigInt.zero) {
      throw const ColdTxFormatException('Negative integer in RLP');
    }
    if (value == BigInt.zero) return Uint8List.fromList([0x80]);
    final bytes = <int>[];
    var remaining = value;
    while (remaining > BigInt.zero) {
      bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
      remaining >>= 8;
    }
    return encodeBytes(bytes);
  }

  static Uint8List encodeList(List<Uint8List> items) {
    final body = _concatAll(items);
    return _concat(_lengthPrefix(body.length, 0xc0), body);
  }

  static Uint8List _list(List<Uint8List> items) => encodeList(items);

  static Uint8List _lengthPrefix(int length, int offset) {
    if (length <= 55) {
      return Uint8List.fromList([offset + length]);
    }
    final lengthBytes = <int>[];
    var remaining = length;
    while (remaining > 0) {
      lengthBytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }
    return Uint8List.fromList([
      offset + 55 + lengthBytes.length,
      ...lengthBytes,
    ]);
  }

  static Uint8List _concat(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length + b.length);
    out.setRange(0, a.length, a);
    out.setRange(a.length, out.length, b);
    return out;
  }

  static Uint8List _concatAll(List<Uint8List> parts) {
    var total = 0;
    for (final part in parts) {
      total += part.length;
    }
    final out = Uint8List(total);
    var offset = 0;
    for (final part in parts) {
      out.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return out;
  }

  static Uint8List _parseAddress(String address) {
    final clean = address.startsWith('0x') || address.startsWith('0X')
        ? address.substring(2)
        : address;
    if (clean.length != 40 || !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(clean)) {
      throw ColdTxFormatException('Invalid address: $address');
    }
    return Uint8List.fromList(hexToBytes(clean));
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Uint8List _keccak(Uint8List bytes) =>
      Uint8List.fromList(keccak256(bytes));

  static Uint8List _readBytes(_RlpItem item, String field) {
    if (item.isList) {
      throw ColdTxFormatException('$field must be an RLP byte string');
    }
    return item.bytes;
  }

  static List<_RlpItem> _readList(_RlpItem item, String field) {
    if (!item.isList) {
      throw ColdTxFormatException('$field must be an RLP list');
    }
    return item.children;
  }

  static String _readAddress(_RlpItem item, String field) {
    final bytes = _readBytes(item, field);
    if (bytes.length != 20) {
      throw ColdTxFormatException('$field must be exactly 20 bytes');
    }
    return bytesToHex(bytes, include0x: true);
  }

  static BigInt _readInt(_RlpItem item, String field) {
    final bytes = _readBytes(item, field);
    if (bytes.isEmpty) return BigInt.zero;
    if (bytes.first == 0) {
      throw ColdTxFormatException('$field has a leading zero');
    }
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }
}

class ColdTxFields {
  ColdTxFields({
    required this.chainId,
    required this.nonce,
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasLimit,
    required this.to,
    required this.value,
    required this.data,
    required this.accessList,
  });

  final int chainId;
  final BigInt nonce;
  final BigInt maxPriorityFeePerGas;
  final BigInt maxFeePerGas;
  final BigInt gasLimit;
  final String to;
  final BigInt value;
  final Uint8List data;
  final List<ColdAccessListItem> accessList;

  Uint8List unsignedPayload() => ColdTxCodec.unsignedPayload(this);
  Uint8List signingDigest() => ColdTxCodec.signingDigest(this);
  String get signingDigestHex => bytesToHex(signingDigest(), include0x: true);

  ColdTxFields copyWith({
    int? chainId,
    BigInt? nonce,
    BigInt? maxPriorityFeePerGas,
    BigInt? maxFeePerGas,
    BigInt? gasLimit,
    String? to,
    BigInt? value,
    Uint8List? data,
    List<ColdAccessListItem>? accessList,
  }) => ColdTxFields(
    chainId: chainId ?? this.chainId,
    nonce: nonce ?? this.nonce,
    maxPriorityFeePerGas: maxPriorityFeePerGas ?? this.maxPriorityFeePerGas,
    maxFeePerGas: maxFeePerGas ?? this.maxFeePerGas,
    gasLimit: gasLimit ?? this.gasLimit,
    to: to ?? this.to,
    value: value ?? this.value,
    data: data ?? this.data,
    accessList: accessList ?? this.accessList,
  );

  bool sameTransaction(ColdTxFields other) =>
      chainId == other.chainId &&
      nonce == other.nonce &&
      maxPriorityFeePerGas == other.maxPriorityFeePerGas &&
      maxFeePerGas == other.maxFeePerGas &&
      gasLimit == other.gasLimit &&
      to.toLowerCase() == other.to.toLowerCase() &&
      value == other.value &&
      _bytesEqual(data, other.data) &&
      accessList.length == other.accessList.length;

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ColdAccessListItem {
  const ColdAccessListItem({required this.address, required this.storageKeys});
  final String address;
  final List<String> storageKeys;
}

class ColdSignedTx {
  const ColdSignedTx({
    required this.fields,
    required this.yParity,
    required this.r,
    required this.s,
    required this.raw,
    required this.hash,
  });

  final ColdTxFields fields;
  final int yParity;
  final BigInt r;
  final BigInt s;
  final Uint8List raw;
  final String hash;

  String get rawHex => bytesToHex(raw, include0x: true, padToEvenLength: true);
}

class ColdTxFormatException implements Exception {
  const ColdTxFormatException(this.message);
  final String message;
  @override
  String toString() => 'ColdTxFormatException: $message';
}

/// Minimal canonical RLP reader.  It intentionally accepts only the subset
/// used by EIP-1559 transactions and rejects trailing or non-canonical data.
class _RlpReader {
  _RlpReader(this._data);
  final Uint8List _data;
  int _offset = 0;

  bool get isDone => _offset == _data.length;

  List<_RlpItem> readTopLevelList() {
    final item = _readItem();
    if (!item.isList) {
      throw const ColdTxFormatException('Transaction must be an RLP list');
    }
    return item.children;
  }

  _RlpItem _readItem() {
    if (_offset >= _data.length) {
      throw const ColdTxFormatException('Unexpected end of RLP data');
    }
    final first = _data[_offset++];
    if (first < 0x80) {
      return _RlpItem.bytes(Uint8List.fromList([first]));
    }
    if (first <= 0xb7) {
      final length = first - 0x80;
      return _RlpItem.bytes(_take(length));
    }
    if (first <= 0xbf) {
      final lengthOfLength = first - 0xb7;
      final length = _readLength(lengthOfLength);
      if (length < 56) {
        throw const ColdTxFormatException('Non-canonical RLP string length');
      }
      return _RlpItem.bytes(_take(length));
    }
    if (first <= 0xf7) {
      final length = first - 0xc0;
      return _RlpItem.list(_readChildren(length));
    }
    final lengthOfLength = first - 0xf7;
    final length = _readLength(lengthOfLength);
    if (length < 56) {
      throw const ColdTxFormatException('Non-canonical RLP list length');
    }
    return _RlpItem.list(_readChildren(length));
  }

  int _readLength(int lengthOfLength) {
    if (lengthOfLength <= 0 || lengthOfLength > 4) {
      throw const ColdTxFormatException('Invalid RLP length');
    }
    var length = 0;
    for (var i = 0; i < lengthOfLength; i++) {
      if (_offset >= _data.length) {
        throw const ColdTxFormatException('Unexpected end of RLP length');
      }
      length = (length << 8) | _data[_offset++];
    }
    return length;
  }

  List<_RlpItem> _readChildren(int length) {
    final end = _offset + length;
    if (end > _data.length) {
      throw const ColdTxFormatException('RLP list exceeds input');
    }
    final children = <_RlpItem>[];
    while (_offset < end) {
      children.add(_readItem());
    }
    if (_offset != end) {
      throw const ColdTxFormatException('RLP list length mismatch');
    }
    return children;
  }

  Uint8List _take(int length) {
    final end = _offset + length;
    if (end > _data.length) {
      throw const ColdTxFormatException('RLP string exceeds input');
    }
    final out = Uint8List.fromList(_data.sublist(_offset, end));
    _offset = end;
    return out;
  }
}

class _RlpItem {
  _RlpItem.bytes(this.bytes) : isList = false, children = const [];
  _RlpItem.list(this.children) : isList = true, bytes = Uint8List(0);

  final bool isList;
  final Uint8List bytes;
  final List<_RlpItem> children;
}

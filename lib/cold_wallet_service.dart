import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import 'cold_wallet.dart';
import 'cold_wallet_protocol.dart';
import 'rpc_service.dart';
import 'storage.dart';
import 'wallet_core.dart';

/// Stateful, persistent glue for the two halves of the cold-wallet workflow.
///
/// Everything stored here is public: pairing addresses, unsigned requests and
/// signed transactions. No seed, private key or passphrase ever enters this
/// service. The actual signing remains in [WalletCore] and the online half
/// only ever receives a raw transaction whose signature was verified against
/// the exact request it is about to broadcast.
class ColdWalletService {
  ColdWalletService._();
  static final ColdWalletService instance = ColdWalletService._();

  static const String _pairingKey = 'cold_pairing_v1';
  static const String _pendingRequestsKey = 'cold_pending_requests_v1';
  static const String _signaturesKey = 'cold_signed_responses_v1';
  static const String _signedRequestIdsKey = 'cold_signed_request_ids_v1';
  static const String _broadcastHashesKey = 'cold_broadcast_hashes_v1';
  static const int _maxStored = 20;

  // ---------------------------------------------------------------- pairing --

  Future<ColdPairingData?> loadPairing() async {
    final raw = AppStorage.prefs.getString(_pairingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ColdWalletProtocol.decodePairingEnvelope(raw);
    } catch (_) {
      // Corrupt or expired pairing data is not useful; fail closed by making
      // the online companion ask for a fresh pairing rather than guessing.
      return null;
    }
  }

  Future<void> savePairing(ColdPairingData pairing) async {
    final envelope = ColdWalletProtocol.encodePairing(pairing);
    // Decode once more before persisting so a malformed value can never be
    // written by a future caller.
    ColdWalletProtocol.decodePairingEnvelope(envelope);
    await AppStorage.prefs.setString(_pairingKey, envelope);
  }

  Future<void> clearPairing() async {
    await AppStorage.prefs.remove(_pairingKey);
  }

  // ------------------------------------------------------------- requests ----

  ColdTxRequest createRequest({
    required int chainId,
    required String from,
    required String to,
    required BigInt value,
    required BigInt gasLimit,
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
    required int nonce,
    required String data,
    required ColdTxAssetInfo assetInfo,
    Duration lifetime = const Duration(minutes: 30),
  }) {
    if (lifetime <= Duration.zero || lifetime > const Duration(hours: 24)) {
      throw const ColdProtocolException('Invalid request lifetime');
    }
    final now = DateTime.now().toUtc();
    final id = _newRequestId();
    final request = ColdTxRequest(
      version: ColdWalletProtocol.version,
      chainId: chainId,
      from: from,
      to: to,
      value: hexQuantity(value),
      gasLimit: hexQuantity(gasLimit),
      maxFeePerGas: hexQuantity(maxFeePerGas),
      maxPriorityFeePerGas: hexQuantity(maxPriorityFeePerGas),
      nonce: nonce,
      data: data,
      assetInfo: assetInfo,
      expiresAt: now.add(lifetime).toIso8601String(),
      createdAt: now.toIso8601String(),
      id: id,
    );
    ColdWalletProtocol.validateRequest(request);
    return request;
  }

  Future<void> storePendingRequest(ColdTxRequest request) async {
    final envelope = ColdWalletProtocol.encodeRequest(request);
    final existing = AppStorage.prefs.getStringList(_pendingRequestsKey) ?? [];
    final id = request.id!;
    for (final item in existing) {
      try {
        final old = ColdWalletProtocol.decodeRequestEnvelope(item);
        if (old.id == id) {
          throw const ColdProtocolException(
            'This request ID is already in the pending list',
          );
        }
      } catch (error) {
        if (error is ColdProtocolException &&
            error.message.contains('already')) {
          rethrow;
        }
        // Expired/invalid old entries are ignored and pruned below.
      }
    }
    final kept = <String>[];
    for (final item in existing) {
      try {
        ColdWalletProtocol.decodeRequestEnvelope(item);
        kept.add(item);
      } catch (_) {
        // Drop unreadable or expired entries instead of growing forever.
      }
    }
    kept.add(envelope);
    await AppStorage.prefs.setStringList(
      _pendingRequestsKey,
      _bounded(kept.reversed),
    );
  }

  Future<List<ColdTxRequest>> pendingRequests() async {
    final raw = AppStorage.prefs.getStringList(_pendingRequestsKey) ?? const [];
    final requests = <ColdTxRequest>[];
    for (final item in raw) {
      try {
        requests.add(ColdWalletProtocol.decodeRequestEnvelope(item));
      } catch (_) {
        // Ignore expired/corrupt entries; the UI treats that as no request.
      }
    }
    return requests;
  }

  Future<ColdTxRequest?> latestPendingRequest() async {
    final all = await pendingRequests();
    return all.isEmpty ? null : all.first;
  }

  Future<ColdTxRequest?> pendingRequestById(String requestId) async {
    for (final request in await pendingRequests()) {
      if (request.id == requestId) return request;
    }
    return null;
  }

  Future<void> clearPendingRequest(String requestId) async {
    final raw = AppStorage.prefs.getStringList(_pendingRequestsKey) ?? const [];
    final kept = <String>[];
    for (final item in raw) {
      try {
        final request = ColdWalletProtocol.decodeRequestEnvelope(item);
        if (request.id == requestId) continue;
        kept.add(item);
      } catch (_) {
        // Expired entries are dropped.
      }
    }
    await AppStorage.prefs.setStringList(_pendingRequestsKey, kept);
  }

  // ------------------------------------------------------------- signing ----

  /// Sign on the cold device. This method never uses the network.
  ///
  /// If the exact request was already signed, the stored response is returned
  /// without producing a second signature; a replay with a different request
  /// hash is refused outright.
  Future<ColdTxSignature> signRequest({
    required ColdTxRequest request,
    required String phrase,
    String passphrase = '',
    String path = WalletCore.defaultPath,
  }) async {
    final addresses = WalletCore.deriveAddressList(
      phrase: phrase,
      passphrase: passphrase,
      count: 20,
    );
    final index = addresses.indexWhere(
      (a) => a.toLowerCase() == request.from.toLowerCase(),
    );
    if (index < 0) {
      throw const ColdProtocolException(
        'The from address is not one of this cold wallet\'s first 20 '
        'default BIP-44 addresses',
      );
    }

    // Requests carry no derivation path. When the caller did not override the
    // path, bind the address to its default account index instead of always
    // signing with index 0 — which would otherwise produce a different signer
    // than the request named.
    final signingPath = path == WalletCore.defaultPath
        ? "m/44'/60'/0'/0/$index"
        : path;
    final key = WalletCore.derivePrivateKey(
      phrase: phrase,
      passphrase: passphrase,
      path: signingPath,
    );
    return _signWithKey(request: request, key: key);
  }

  /// Signs a cold request with a raw private key (no recovery phrase).
  ///
  /// The replay checks, request validation, address binding, immediate
  /// signature verification, and signature storage are identical to the
  /// phrase path.
  Future<ColdTxSignature> signRequestWithKey({
    required ColdTxRequest request,
    required EthPrivateKey key,
  }) => _signWithKey(request: request, key: key);

  Future<ColdTxSignature> _signWithKey({
    required ColdTxRequest request,
    required EthPrivateKey key,
  }) async {
    ColdWalletProtocol.validateRequest(request);
    final id = request.id;
    if (id == null || id.isEmpty) {
      throw const ColdProtocolException('Request has no unique ID');
    }
    final expectedHash = ColdWalletProtocol.requestHash(request);
    final existing = await signatureForRequest(id);
    if (existing != null) {
      if (existing.requestHash?.toLowerCase() == expectedHash.toLowerCase()) {
        return existing;
      }
      throw const ColdProtocolException(
        'This request ID was already signed with different bytes',
      );
    }
    if (key.address.eip55With0x.toLowerCase() != request.from.toLowerCase()) {
      throw const ColdProtocolException(
        'The unlocked private key does not match the request "from" address',
      );
    }

    final signature = WalletCore.signTransactionWithKey(
      privateKey: key,
      request: request,
    );
    final checked = WalletCore.verifyColdSignatureDetailed(
      request: request,
      signature: signature,
      expectedFrom: request.from,
    );
    if (!checked.ok) {
      throw StateError(
        'The just-produced signature failed verification: '
        '${checked.reason}',
      );
    }
    await _appendSignature(signature);
    await _appendUnique(_signedRequestIdsKey, id);
    return signature;
  }

  Future<ColdTxSignature?> signatureForRequest(String requestId) async {
    for (final signature in await storedSignatures()) {
      if (signature.requestId == requestId) return signature;
    }
    return null;
  }

  Future<List<ColdTxSignature>> storedSignatures() async {
    final raw = AppStorage.prefs.getStringList(_signaturesKey) ?? const [];
    final signatures = <ColdTxSignature>[];
    for (final item in raw) {
      try {
        signatures.add(ColdWalletProtocol.decodeSignatureEnvelope(item));
      } catch (_) {
        // A corrupt stored signature is ignored; it can never be broadcast.
      }
    }
    return signatures;
  }

  Future<ColdTxSignature?> latestSignature() async {
    final all = await storedSignatures();
    return all.isEmpty ? null : all.first;
  }

  Future<void> _appendSignature(ColdTxSignature signature) async {
    final envelope = ColdWalletProtocol.encodeSignature(signature);
    final existing = AppStorage.prefs.getStringList(_signaturesKey) ?? const [];
    await AppStorage.prefs.setStringList(
      _signaturesKey,
      _bounded([envelope, ...existing]),
    );
  }

  // ---------------------------------------------------- online verification --

  /// Verify a response against the exact pending request and the paired
  /// address, and refuse anything already broadcast.
  Future<ColdVerifyResult> verifyResponse({
    required ColdTxRequest request,
    required ColdTxSignature signature,
    required String expectedFrom,
  }) async {
    final id = request.id;
    if (id == null || id.isEmpty) {
      return const ColdVerifyResult.fail('Request has no unique ID');
    }
    final stored = await pendingRequestById(id);
    if (stored == null) {
      return const ColdVerifyResult.fail(
        'This request is not in the pending list (expired, unknown or already used)',
      );
    }
    final storedHash = ColdWalletProtocol.requestHash(stored);
    final incomingHash = ColdWalletProtocol.requestHash(request);
    if (storedHash.toLowerCase() != incomingHash.toLowerCase()) {
      return const ColdVerifyResult.fail(
        'The pending request has different bytes from the one being verified',
      );
    }
    if (signature.signedTxHash.trim().isEmpty ||
        await isBroadcast(signature.signedTxHash)) {
      return const ColdVerifyResult.fail(
        'This signed transaction has already been broadcast',
      );
    }
    final signedAt = DateTime.tryParse(signature.signedAt);
    if (signedAt == null) {
      return const ColdVerifyResult.fail('Signature timestamp is invalid');
    }
    if (signedAt.toUtc().isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      return const ColdVerifyResult.fail(
        'Signature timestamp is in the future',
      );
    }
    final expires = DateTime.tryParse(request.expiresAt);
    if (expires == null) {
      return const ColdVerifyResult.fail('Request expiry is invalid');
    }
    // The signer must have acted before the request expired. A small clock
    // skew is tolerated; a signature produced hours after expiry is not.
    if (signedAt.toUtc().isAfter(
      expires.toUtc().add(const Duration(minutes: 5)),
    )) {
      return const ColdVerifyResult.fail(
        'The signature was produced after the request expired',
      );
    }
    if (expectedFrom.trim().isEmpty) {
      return const ColdVerifyResult.fail('No paired signer address');
    }
    return WalletCore.verifyColdSignatureDetailed(
      request: request,
      signature: signature,
      expectedFrom: expectedFrom,
    );
  }

  /// Broadcast only after [verifyResponse] succeeds. The node's returned hash
  /// must equal the hash computed from the raw bytes; a mismatch is treated as
  /// an unknown outcome and the bytes are marked as used so they are never
  /// replayed by this device.
  Future<String> broadcastResponse({
    required RpcService rpc,
    required ColdTxRequest request,
    required ColdTxSignature signature,
    required String expectedFrom,
  }) async {
    final verified = await verifyResponse(
      request: request,
      signature: signature,
      expectedFrom: expectedFrom,
    );
    if (!verified.ok) {
      throw StateError(verified.reason);
    }
    final raw = verified.rawSignedTx!;
    final expectedHash = verified.txHash!;
    final returned = await rpc.sendRawHex(raw);
    final normalizedReturned = returned.toLowerCase();
    await _appendUnique(_broadcastHashesKey, expectedHash.toLowerCase());
    if (normalizedReturned != expectedHash.toLowerCase()) {
      throw StateError(
        'The node returned a different transaction hash. Do NOT resend: the '
        'transaction may already be accepted. Check the explorer for '
        '$expectedHash and the sender nonce.',
      );
    }
    await clearPendingRequest(request.id!);
    return expectedHash;
  }

  Future<bool> isBroadcast(String txHash) async {
    final used =
        AppStorage.prefs.getStringList(_broadcastHashesKey) ?? const [];
    return used.any((h) => h.toLowerCase() == txHash.toLowerCase());
  }

  Future<bool> isRequestSigned(String requestId) async {
    final ids =
        AppStorage.prefs.getStringList(_signedRequestIdsKey) ?? const [];
    return ids.contains(requestId);
  }

  Future<void> _appendUnique(String key, String value) async {
    final existing = AppStorage.prefs.getStringList(key) ?? const [];
    await AppStorage.prefs.setStringList(
      key,
      _bounded([value, ...existing.where((item) => item != value)]),
    );
  }

  // --------------------------------------------------------------- helpers --

  /// Even-length lowercase hex quantity. Protocol requests are JSON, so there
  /// is no RLP rule forcing the shortest integer representation here.
  static String hexQuantity(BigInt value) {
    if (value < BigInt.zero) {
      throw const ColdProtocolException('Negative quantity');
    }
    if (value == BigInt.zero) return '0x00';
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return '0x$hex';
  }

  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<String> _bounded(Iterable<String> values) =>
      values.take(_maxStored).toList(growable: false);

  @visibleForTesting
  static Future<void> resetForTests() async {
    for (final key in const [
      _pairingKey,
      _pendingRequestsKey,
      _signaturesKey,
      _signedRequestIdsKey,
      _broadcastHashesKey,
    ]) {
      await AppStorage.prefs.remove(key);
    }
  }
}

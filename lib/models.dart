import 'package:flutter/foundation.dart';

/// A token shown in the wallet. `native` marks BNB itself.
@immutable
class TokenInfo {
  const TokenInfo({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.network = 'mainnet',
    this.native = false,
  });

  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String network;
  final bool native;

  TokenInfo copyWith({
    String? symbol,
    String? name,
    String? address,
    int? decimals,
    String? network,
    bool? native,
  }) => TokenInfo(
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    address: address ?? this.address,
    decimals: decimals ?? this.decimals,
    network: network ?? this.network,
    native: native ?? this.native,
  );

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'address': address,
    'decimals': decimals,
    'network': network,
  };

  factory TokenInfo.fromJson(Map<String, dynamic> json) => TokenInfo(
    symbol: (json['symbol'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    address: (json['address'] ?? '').toString(),
    decimals: (json['decimals'] as num?)?.toInt() ?? 18,
    network: (json['network'] ?? 'mainnet').toString(),
  );
}

/// A public-only watch profile: label + address, never a secret.
@immutable
class WalletProfile {
  const WalletProfile({
    required this.label,
    required this.address,
    this.source = 'watch',
    this.createdAt,
  });

  final String label;
  final String address;
  final String source;
  final String? createdAt;

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    'source': source,
    if (createdAt != null) 'createdAt': createdAt,
  };

  factory WalletProfile.fromJson(Map<String, dynamic> json) => WalletProfile(
    label: (json['label'] ?? '').toString(),
    address: (json['address'] ?? '').toString(),
    source: (json['source'] ?? 'watch').toString(),
    createdAt: json['createdAt']?.toString(),
  );
}

/// A user-saved RPC node.
@immutable
class RpcNode {
  const RpcNode({
    required this.label,
    required this.url,
    this.network = 'mainnet',
    this.enabled = true,
    this.transport = NodeTransport.inherit,
    this.proxyHost,
    this.proxyPort,
    this.proxyUser,
    this.proxyPass,
    // R4 networking hardening fields
    this.authType = NodeAuthType.none,
    this.authToken,
    this.authUsername,
    this.authPassword,
    this.customHeaders = const {},
    this.pinnedSpkiHashes = const [],
    this.useForReads = true,
    this.useForBroadcast = true,
    this.selectionMode = NodeSelectionMode.manual,
    this.latencyMs,
  });

  final String label;
  final String url;
  final String network;

  /// A switched-off node stays in the book but the wallet never asks it
  /// anything (§10d enable/disable). Defaults to true for old saved books.
  final bool enabled;

  /// Per-node transport override (§10d, R2). Default: inherit global setting.
  final NodeTransport transport;

  /// Custom SOCKS5 proxy for this node (when transport = NodeTransport.customProxy).
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPass;

  // R4: HTTP authentication (Bearer/Basic)
  final NodeAuthType authType;
  final String? authToken; // for Bearer
  final String? authUsername; // for Basic
  final String? authPassword; // for Basic

  // R4: Custom headers (with validation to prevent identifying headers)
  final Map<String, String> customHeaders;

  // R4: Certificate pinning — list of SPKI SHA-256 hashes (base64)
  final List<String> pinnedSpkiHashes;

  // R4: Selection mode flags
  final bool useForReads;
  final bool useForBroadcast;

  // R4/R7: Node selection mode
  final NodeSelectionMode selectionMode;

  // R7: Latency tracking for auto-fastest selection mode
  final int? latencyMs;

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
    'network': network,
    'enabled': enabled,
    'transport': transport.index,
    if (proxyHost != null) 'proxyHost': proxyHost,
    if (proxyPort != null) 'proxyPort': proxyPort,
    if (proxyUser != null) 'proxyUser': proxyUser,
    if (proxyPass != null) 'proxyPass': proxyPass,
    if (authType != NodeAuthType.none) 'authType': authType.index,
    if (authToken != null) 'authToken': authToken,
    if (authUsername != null) 'authUsername': authUsername,
    if (authPassword != null) 'authPassword': authPassword,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
    if (pinnedSpkiHashes.isNotEmpty) 'pinnedSpkiHashes': pinnedSpkiHashes,
    'useForReads': useForReads,
    'useForBroadcast': useForBroadcast,
    'selectionMode': selectionMode.index,
    if (latencyMs != null) 'latencyMs': latencyMs,
  };

  /// Shareable form with every credential removed. Used by the "export phone
  /// book" action, which must never write a proxy password, bearer token or
  /// custom header into a plain-text file or the clipboard.
  Map<String, dynamic> toPublicJson() => {
    'label': label,
    'url': url,
    'network': network,
    'enabled': enabled,
    'transport': transport.index,
    if (proxyHost != null) 'proxyHost': proxyHost,
    if (proxyPort != null) 'proxyPort': proxyPort,
    if (authType != NodeAuthType.none) 'authType': authType.index,
    if (authUsername != null) 'authUsername': authUsername,
    if (pinnedSpkiHashes.isNotEmpty) 'pinnedSpkiHashes': pinnedSpkiHashes,
    'useForReads': useForReads,
    'useForBroadcast': useForBroadcast,
    'selectionMode': selectionMode.index,
    if (latencyMs != null) 'latencyMs': latencyMs,
  };

  /// Credentials that must live in the platform secure store, never in the
  /// plain preferences file.
  Map<String, dynamic> secretFields() => {
    if (proxyUser != null) 'proxyUser': proxyUser,
    if (proxyPass != null) 'proxyPass': proxyPass,
    if (authToken != null) 'authToken': authToken,
    if (authUsername != null) 'authUsername': authUsername,
    if (authPassword != null) 'authPassword': authPassword,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
  };

  factory RpcNode.fromJson(Map<String, dynamic> json) => RpcNode(
    label: (json['label'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    network: (json['network'] ?? 'mainnet').toString(),
    enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    transport:
        NodeTransport.values
            .where((t) => t.index == (json['transport'] as int? ?? 0))
            .firstOrNull ??
        NodeTransport.inherit,
    proxyHost: json['proxyHost']?.toString(),
    proxyPort: (json['proxyPort'] as num?)?.toInt(),
    proxyUser: json['proxyUser']?.toString(),
    proxyPass: json['proxyPass']?.toString(),
    authType:
        NodeAuthType.values
            .where((t) => t.index == (json['authType'] as int? ?? 0))
            .firstOrNull ??
        NodeAuthType.none,
    authToken: json['authToken']?.toString(),
    authUsername: json['authUsername']?.toString(),
    authPassword: json['authPassword']?.toString(),
    customHeaders:
        (json['customHeaders'] as Map?)?.cast<String, String>() ?? const {},
    pinnedSpkiHashes:
        (json['pinnedSpkiHashes'] as List?)?.cast<String>() ?? const [],
    useForReads: json['useForReads'] as bool? ?? true,
    useForBroadcast: json['useForBroadcast'] as bool? ?? true,
    selectionMode:
        NodeSelectionMode.values
            .where((t) => t.index == (json['selectionMode'] as int? ?? 0))
            .firstOrNull ??
        NodeSelectionMode.manual,
    latencyMs: (json['latencyMs'] as num?)?.toInt(),
  );
}

/// Transport mode for a node (or globally). Matches spec §5/§10d.
enum NodeTransport {
  /// Inherit the global transport setting (default).
  inherit,

  /// Direct HTTPS (TLS 1.3, UA scrubbed).
  direct,

  /// Tor via system SOCKS5 (Orbot/Tor daemon).
  tor,

  /// Custom SOCKS5 proxy (with optional auth).
  customProxy,

  /// HTTP CONNECT proxy (RFC 7231 §4.3.6) — for corporate/transparent proxies.
  /// The CONNECT request carries the target hostname, so DNS stays inside the tunnel.
  httpConnect,
}

extension NodeTransportLabel on NodeTransport {
  String get label {
    switch (this) {
      case NodeTransport.inherit:
        return 'Inherit (global)';
      case NodeTransport.direct:
        return 'Direct HTTPS';
      case NodeTransport.tor:
        return 'Tor (SOCKS5)';
      case NodeTransport.customProxy:
        return 'Custom SOCKS5 proxy';
      case NodeTransport.httpConnect:
        return 'HTTP CONNECT proxy';
    }
  }
}

/// HTTP authentication type for a node (R4).
enum NodeAuthType {
  /// No authentication.
  none,

  /// Bearer token in Authorization header.
  bearer,

  /// HTTP Basic authentication.
  basic,
}

/// Node selection mode (§10d): how the wallet picks which node to talk to.
enum NodeSelectionMode {
  /// Always use the same node (manual pick or active).
  manual,

  /// Always pick the fastest-responding node (by measured latency).
  autoFastest,

  /// Rotate through enabled nodes in book order (privacy).
  roundRobin,

  /// Query N nodes and cross-check answers; mismatch → warning.
  quorum,
}

extension NodeSelectionModeLabel on NodeSelectionMode {
  String get label {
    switch (this) {
      case NodeSelectionMode.manual:
        return 'Manual';
      case NodeSelectionMode.autoFastest:
        return 'Auto-fastest';
      case NodeSelectionMode.roundRobin:
        return 'Round-robin / random';
      case NodeSelectionMode.quorum:
        return 'Quorum';
    }
  }
}

/// Node-URL policy (spec §10d): HTTPS everywhere, with HTTP allowed only for
/// loopback / LAN addresses or `.onion` endpoints (which are only ever
/// reached through the Tor SOCKS5 route). Pure and unit-tested.
bool nodeUrlAllowed(String url) {
  try {
    final uri = Uri.parse(url.trim());
    if (uri.host.isEmpty) return false;
    // Credentials in a URL leak into logs, history and the raw-RPC panel.
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.scheme == 'https' || uri.scheme == 'wss') {
      final host = uri.host.toLowerCase();
      // Cloud metadata / link-local targets are never a user's RPC node and
      // are a classic SSRF target for a malicious imported configuration.
      if (host == '169.254.169.254' || host == 'metadata.google.internal') {
        return false;
      }
      final v4 = host.split('.');
      if (v4.length == 4 && v4.every((p) => int.tryParse(p) != null)) {
        if (int.parse(v4[0]) == 169 && int.parse(v4[1]) == 254) return false;
      }
      return true;
    }
    if (uri.scheme != 'http') return false;
    var host = uri.host.toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host == 'localhost' || host == '::1' || host == '0.0.0.0') return true;
    if (host.endsWith('.onion')) return true;
    final v4 = host.split('.');
    if (v4.length == 4 && v4.every((p) => int.tryParse(p) != null)) {
      final a = int.parse(v4[0]);
      if (a == 127 || a == 10) return true;
      if (a == 192 && int.tryParse(v4[1]) == 168) return true;
      if (a == 172) {
        final b = int.tryParse(v4[1]) ?? -1;
        if (b >= 16 && b <= 31) return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// One line of the "Test node" checklist (§10d) — label, result, and what
/// was actually seen. Pure data; the RPC layer and the dialog both use it.
@immutable
class NodeCheckRow {
  const NodeCheckRow(this.label, this.ok, this.detail);
  final String label;
  final bool ok;
  final String detail;
}

/// Reorders a phone-book entry inside the SAME side of the network. Returns
/// the new full-list index (or the input when the move is impossible), so
/// the UI arrow buttons and the tests share one pure function.
int moveNodeIndex(List<RpcNode> nodes, int index, int delta) {
  if (index < 0 || index >= nodes.length) return index;
  final side = nodes[index].network;
  var target = index;
  if (delta < 0) {
    for (var i = index - 1; i >= 0; i--) {
      if (nodes[i].network == side) {
        target = i;
        break;
      }
    }
  } else {
    for (var i = index + 1; i < nodes.length; i++) {
      if (nodes[i].network == side) {
        target = i;
        break;
      }
    }
  }
  return target;
}

/// One urgency tier offered before a transfer.
@immutable
class FeePreset {
  const FeePreset({
    required this.label,
    required this.target,
    required this.priorityFeePerGas,
    required this.maxFeePerGas,
    required this.expectedFeePerGas,
    this.gasPrice,
    this.mode = 'eip1559',
    this.source = '',
    this.warning,
    this.recommended = false,
    this.etaSecondsLow,
    this.etaSecondsHigh,
    this.expectedBlocks,
  });

  final String label;
  final String target;
  final BigInt priorityFeePerGas;
  final BigInt maxFeePerGas;
  final BigInt expectedFeePerGas;
  final BigInt? gasPrice;
  final String mode;
  final String source;

  /// Plain-words caution for this tier (raised to the live floor, congested
  /// blocks, …). Null when there is nothing to warn about.
  final String? warning;

  /// True for the tier the engine recommends in the current conditions.
  final bool recommended;

  /// Measured ETA range in seconds; null when block time was unmeasurable.
  final int? etaSecondsLow;
  final int? etaSecondsHigh;

  /// Roughly how many blocks this tier expects to wait (measured).
  final int? expectedBlocks;

  FeePreset copyWith({String? label, bool? recommended}) => FeePreset(
    label: label ?? this.label,
    target: target,
    priorityFeePerGas: priorityFeePerGas,
    maxFeePerGas: maxFeePerGas,
    expectedFeePerGas: expectedFeePerGas,
    gasPrice: gasPrice,
    mode: mode,
    source: source,
    warning: warning,
    recommended: recommended ?? this.recommended,
    etaSecondsLow: etaSecondsLow,
    etaSecondsHigh: etaSecondsHigh,
    expectedBlocks: expectedBlocks,
  );
}

/// A decrypted local vault account.
@immutable
class VaultAccount {
  const VaultAccount({
    required this.label,
    required this.address,
    required this.keystoreJson,
    this.mnemonic,
    this.savedAt,
  });

  final String label;
  final String address;
  final String keystoreJson;
  final String? mnemonic;
  final String? savedAt;
}

/// A public transaction-history row from BscScan.
@immutable
class HistoryTx {
  const HistoryTx({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.timestamp,
    required this.isError,
  });

  final String hash;
  final String from;
  final String to;
  final String value;
  final String timestamp;
  final bool isError;
}

/// One locally kept receipt, built from chain data after a send. Stored
/// encrypted (outside the vault file, keyed by wallet + device secret) so the
/// history works offline without asking the explorer who you paid.
@immutable
class LocalReceipt {
  const LocalReceipt({
    required this.hash,
    required this.network,
    required this.chainId,
    required this.status,
    required this.from,
    required this.to,
    required this.assetSymbol,
    required this.assetAddress,
    required this.amountHuman,
    required this.amountRaw,
    required this.decimals,
    required this.nonce,
    required this.gasLimit,
    required this.gasUsed,
    required this.feeWei,
    required this.blockNumber,
    required this.confirmations,
    required this.verifiedNodes,
    required this.finalized,
    required this.tierLabel,
    required this.reason,
    required this.nodeUsed,
    required this.transport,
    required this.savedAt,
    this.blockTimestamp,
    this.effectiveGasPriceWei,
    this.rawTxHex,
    this.note,
    this.revertReason,
    this.balanceBeforeWei,
    this.balanceAfterWei,
    this.blockHash,
    this.transactionIndex,
    this.txType,
    this.inputData,
    this.eventLogs = const [],
  });

  final String hash;
  final String network;
  final int chainId;
  final String status; // 'success' | 'reverted'
  final String from;
  final String to;
  final String assetSymbol;
  final String assetAddress; // '' for native BNB
  final String amountHuman;
  final String amountRaw;
  final int decimals;
  final int nonce;
  final String gasLimit;
  final String gasUsed;
  final String feeWei; // actually charged
  final int blockNumber;
  final int confirmations;
  final int verifiedNodes;
  final bool finalized;
  final String tierLabel;
  final String reason;
  final String nodeUsed;
  final String transport;
  final String savedAt; // ISO
  final String? blockTimestamp; // ISO
  final String? effectiveGasPriceWei;
  final String? rawTxHex;
  final String? note; // fee-on-transfer finding, unknown outcome, …
  final String? revertReason;
  final String? balanceBeforeWei;
  final String? balanceAfterWei;
  final String? blockHash;
  final int? transactionIndex;
  final String? txType; // 'legacy' | 'eip1559'
  final String? inputData; // calldata as 0x-hex, when this send carried any
  final List<Map<String, dynamic>> eventLogs; // already-public receipt logs

  LocalReceipt copyWith({int? confirmations, bool? finalized}) => LocalReceipt(
    hash: hash,
    network: network,
    chainId: chainId,
    status: status,
    from: from,
    to: to,
    assetSymbol: assetSymbol,
    assetAddress: assetAddress,
    amountHuman: amountHuman,
    amountRaw: amountRaw,
    decimals: decimals,
    nonce: nonce,
    gasLimit: gasLimit,
    gasUsed: gasUsed,
    feeWei: feeWei,
    blockNumber: blockNumber,
    confirmations: confirmations ?? this.confirmations,
    verifiedNodes: verifiedNodes,
    finalized: finalized ?? this.finalized,
    tierLabel: tierLabel,
    reason: reason,
    nodeUsed: nodeUsed,
    transport: transport,
    savedAt: savedAt,
    blockTimestamp: blockTimestamp,
    effectiveGasPriceWei: effectiveGasPriceWei,
    rawTxHex: rawTxHex,
    note: note,
    revertReason: revertReason,
    balanceBeforeWei: balanceBeforeWei,
    balanceAfterWei: balanceAfterWei,
    blockHash: blockHash,
    transactionIndex: transactionIndex,
    txType: txType,
    inputData: inputData,
    eventLogs: eventLogs,
  );

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'network': network,
    'chainId': chainId,
    'status': status,
    'from': from,
    'to': to,
    'assetSymbol': assetSymbol,
    'assetAddress': assetAddress,
    'amountHuman': amountHuman,
    'amountRaw': amountRaw,
    'decimals': decimals,
    'nonce': nonce,
    'gasLimit': gasLimit,
    'gasUsed': gasUsed,
    'feeWei': feeWei,
    'blockNumber': blockNumber,
    'confirmations': confirmations,
    'verifiedNodes': verifiedNodes,
    'finalized': finalized,
    'tierLabel': tierLabel,
    'reason': reason,
    'nodeUsed': nodeUsed,
    'transport': transport,
    'savedAt': savedAt,
    if (blockTimestamp != null) 'blockTimestamp': blockTimestamp,
    if (effectiveGasPriceWei != null)
      'effectiveGasPriceWei': effectiveGasPriceWei,
    if (rawTxHex != null) 'rawTxHex': rawTxHex,
    if (note != null) 'note': note,
    if (revertReason != null) 'revertReason': revertReason,
    if (balanceBeforeWei != null) 'balanceBeforeWei': balanceBeforeWei,
    if (balanceAfterWei != null) 'balanceAfterWei': balanceAfterWei,
    if (blockHash != null) 'blockHash': blockHash,
    if (transactionIndex != null) 'transactionIndex': transactionIndex,
    if (txType != null) 'txType': txType,
    if (inputData != null) 'inputData': inputData,
    if (eventLogs.isNotEmpty) 'eventLogs': eventLogs,
  };

  static LocalReceipt fromJson(Map<String, dynamic> json) => LocalReceipt(
    hash: '${json['hash'] ?? ''}',
    network: '${json['network'] ?? 'mainnet'}',
    chainId: (json['chainId'] as num?)?.toInt() ?? 56,
    status: '${json['status'] ?? 'unknown'}',
    from: '${json['from'] ?? ''}',
    to: '${json['to'] ?? ''}',
    assetSymbol: '${json['assetSymbol'] ?? 'BNB'}',
    assetAddress: '${json['assetAddress'] ?? ''}',
    amountHuman: '${json['amountHuman'] ?? ''}',
    amountRaw: '${json['amountRaw'] ?? '0'}',
    decimals: (json['decimals'] as num?)?.toInt() ?? 18,
    nonce: (json['nonce'] as num?)?.toInt() ?? 0,
    gasLimit: '${json['gasLimit'] ?? '0'}',
    gasUsed: '${json['gasUsed'] ?? '0'}',
    feeWei: '${json['feeWei'] ?? '0'}',
    blockNumber: (json['blockNumber'] as num?)?.toInt() ?? 0,
    confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
    verifiedNodes: (json['verifiedNodes'] as num?)?.toInt() ?? 1,
    finalized: json['finalized'] == true,
    tierLabel: '${json['tierLabel'] ?? ''}',
    reason: '${json['reason'] ?? ''}',
    nodeUsed: '${json['nodeUsed'] ?? ''}',
    transport: '${json['transport'] ?? ''}',
    savedAt: '${json['savedAt'] ?? ''}',
    blockTimestamp: json['blockTimestamp']?.toString(),
    effectiveGasPriceWei: json['effectiveGasPriceWei']?.toString(),
    rawTxHex: json['rawTxHex']?.toString(),
    note: json['note']?.toString(),
    revertReason: json['revertReason']?.toString(),
    balanceBeforeWei: json['balanceBeforeWei']?.toString(),
    balanceAfterWei: json['balanceAfterWei']?.toString(),
    blockHash: json['blockHash']?.toString(),
    transactionIndex: (json['transactionIndex'] as num?)?.toInt(),
    txType: json['txType']?.toString(),
    inputData: json['inputData']?.toString(),
    eventLogs: [
      for (final log in (json['eventLogs'] as List? ?? const []))
        if (log is Map) Map<String, dynamic>.from(log),
    ],
  );
}

/// One registered vault file. Labels and paths are not secrets; the accounts
/// and their keys remain inside the encrypted envelope.
@immutable
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.label,
    required this.file,
    required this.createdAt,
  });

  final String id;
  final String label;
  final String file;
  final String createdAt;

  VaultEntry copyWith({String? label, String? file}) => VaultEntry(
    id: id,
    label: label ?? this.label,
    file: file ?? this.file,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'file': file,
    'createdAt': createdAt,
  };

  static VaultEntry fromJson(Map<String, dynamic> json) => VaultEntry(
    id: '${json['id'] ?? ''}',
    label: '${json['label'] ?? 'Vault'}',
    file: '${json['file'] ?? ''}',
    createdAt: '${json['createdAt'] ?? ''}',
  );
}

/// One locally tracked outgoing transaction that is not yet confirmed.
/// Only public chain facts live here — no keys, no secrets.
@immutable
class PendingTx {
  const PendingTx({
    required this.hash,
    required this.network,
    required this.from,
    required this.to,
    required this.native,
    required this.assetSymbol,
    required this.assetAddress,
    required this.amountRaw,
    required this.amountHuman,
    required this.decimals,
    required this.gasLimit,
    required this.nonce,
    required this.mode,
    required this.priorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasPrice,
    required this.sentAt,
    required this.tierLabel,
    this.replacedBy,
    this.note,
    this.rawHex,
    this.status = 'broadcast',
    this.vaultId,
  });

  final String hash;
  final String network;
  final String from;
  final String to;
  final bool native;
  final String assetSymbol;
  final String assetAddress;
  final String amountRaw;
  final String amountHuman;
  final int decimals;
  final String gasLimit;
  final int nonce;
  final String mode; // 'eip1559' | 'legacy'
  final String priorityFeePerGas;
  final String maxFeePerGas;
  final String gasPrice;
  final String sentAt; // ISO
  final String tierLabel;
  final String? replacedBy; // hash of the replacement, when known
  final String? note; // 'speed-up' | 'cancel' marker

  /// The exact signed bytes, retained so an uncertain broadcast can be
  /// re-submitted unchanged instead of re-signed with a new nonce.
  final String? rawHex;

  /// 'signed' (persisted before broadcast), 'broadcast', or 'unknown'.
  final String status;

  /// Which vault produced this transaction (multi-vault isolation).
  final String? vaultId;

  PendingTx copyWith({
    String? replacedBy,
    String? note,
    String? status,
    String? vaultId,
  }) => PendingTx(
    hash: hash,
    network: network,
    from: from,
    to: to,
    native: native,
    assetSymbol: assetSymbol,
    assetAddress: assetAddress,
    amountRaw: amountRaw,
    amountHuman: amountHuman,
    decimals: decimals,
    gasLimit: gasLimit,
    nonce: nonce,
    mode: mode,
    priorityFeePerGas: priorityFeePerGas,
    maxFeePerGas: maxFeePerGas,
    gasPrice: gasPrice,
    sentAt: sentAt,
    tierLabel: tierLabel,
    replacedBy: replacedBy ?? this.replacedBy,
    note: note ?? this.note,
    rawHex: rawHex,
    status: status ?? this.status,
    vaultId: vaultId ?? this.vaultId,
  );

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'network': network,
    'from': from,
    'to': to,
    'native': native,
    'assetSymbol': assetSymbol,
    'assetAddress': assetAddress,
    'amountRaw': amountRaw,
    'amountHuman': amountHuman,
    'decimals': decimals,
    'gasLimit': gasLimit,
    'nonce': nonce,
    'mode': mode,
    'priorityFeePerGas': priorityFeePerGas,
    'maxFeePerGas': maxFeePerGas,
    'gasPrice': gasPrice,
    'sentAt': sentAt,
    'tierLabel': tierLabel,
    if (replacedBy != null) 'replacedBy': replacedBy,
    if (note != null) 'note': note,
    if (rawHex != null) 'rawHex': rawHex,
    'status': status,
    if (vaultId != null) 'vaultId': vaultId,
  };

  static PendingTx fromJson(Map<String, dynamic> json) => PendingTx(
    hash: '${json['hash'] ?? ''}',
    network: '${json['network'] ?? 'mainnet'}',
    from: '${json['from'] ?? ''}',
    to: '${json['to'] ?? ''}',
    native: json['native'] == true,
    assetSymbol: '${json['assetSymbol'] ?? 'BNB'}',
    assetAddress: '${json['assetAddress'] ?? ''}',
    amountRaw: '${json['amountRaw'] ?? '0'}',
    amountHuman: '${json['amountHuman'] ?? ''}',
    decimals: (json['decimals'] as num?)?.toInt() ?? 18,
    gasLimit: '${json['gasLimit'] ?? '0'}',
    nonce: (json['nonce'] as num?)?.toInt() ?? 0,
    mode: '${json['mode'] ?? 'eip1559'}',
    priorityFeePerGas: '${json['priorityFeePerGas'] ?? '0'}',
    maxFeePerGas: '${json['maxFeePerGas'] ?? '0'}',
    gasPrice: '${json['gasPrice'] ?? '0'}',
    sentAt: '${json['sentAt'] ?? ''}',
    tierLabel: '${json['tierLabel'] ?? ''}',
    replacedBy: json['replacedBy']?.toString(),
    note: json['note']?.toString(),
    rawHex: json['rawHex']?.toString(),
    status: '${json['status'] ?? 'broadcast'}',
    vaultId: json['vaultId']?.toString(),
  );
}

/// =====================================================================
/// R5: Cold Wallet Mode (offline signing) — §10f
/// =====================================================================

/// The wallet's operating mode. Default is [WalletMode.hot] (normal hot wallet).
/// [WalletMode.cold] = offline signer (holds seed, no network).
/// [WalletMode.online] = watch-only companion (no secrets, broadcasts for cold).
enum WalletMode { hot, cold, online }

extension WalletModeLabel on WalletMode {
  String get label {
    switch (this) {
      case WalletMode.hot:
        return 'Normal (hot wallet)';
      case WalletMode.cold:
        return 'Cold (offline signer)';
      case WalletMode.online:
        return 'Online (watch-only companion)';
    }
  }

  String get shortLabel {
    switch (this) {
      case WalletMode.hot:
        return 'Hot';
      case WalletMode.cold:
        return 'Cold';
      case WalletMode.online:
        return 'Online';
    }
  }
}

/// Global proxy type for RPC/BscScan traffic. Tor is a separate mode and uses
/// the same SOCKS5 engine, but it is not listed here because it carries its
/// own bridge/bootstrap UI.
enum ProxyType { none, socks5, socks5h, httpConnect }

extension ProxyTypeLabel on ProxyType {
  String get label {
    switch (this) {
      case ProxyType.none:
        return 'Direct (no proxy)';
      case ProxyType.socks5:
        return 'SOCKS5';
      case ProxyType.socks5h:
        return 'SOCKS5h (remote DNS)';
      case ProxyType.httpConnect:
        return 'HTTP CONNECT';
    }
  }

  String get shortLabel {
    switch (this) {
      case ProxyType.none:
        return 'Direct';
      case ProxyType.socks5:
        return 'SOCKS5';
      case ProxyType.socks5h:
        return 'SOCKS5h';
      case ProxyType.httpConnect:
        return 'HTTP CONNECT';
    }
  }
}

/// A validated global proxy configuration. Password is kept out of
/// SharedPreferences; [AppStorage] stores it in the platform secure store.
class GlobalProxyConfig {
  const GlobalProxyConfig({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  const GlobalProxyConfig.disabled()
    : type = ProxyType.none,
      host = '',
      port = 1080,
      username = null,
      password = null;

  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  bool get enabled => type != ProxyType.none && host.trim().isNotEmpty;

  String get endpoint => '$host:$port';

  String get description {
    if (!enabled) return 'Direct HTTPS';
    final auth = (username != null && username!.isNotEmpty) ? ' (auth)' : '';
    return '${type.label} $endpoint$auth';
  }

  GlobalProxyConfig copyWith({
    ProxyType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    bool clearPassword = false,
  }) {
    return GlobalProxyConfig(
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: clearPassword ? null : (password ?? this.password),
    );
  }

  /// Parses `socks5://user:pass@host:1080`, `socks5h://...`,
  /// `http://...`, `https://...`, or a bare `host:port` (SOCKS5).
  /// Returns null for an unsupported or malformed value.
  static GlobalProxyConfig? fromUrl(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    // Uri normalizes an explicit :0 away, which would silently turn an
    // invalid port into the default. Reject it before parsing.
    if (RegExp(r':0(?:/|$)').hasMatch(text)) return null;
    if (!text.contains('://')) text = 'socks5://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;

    ProxyType type;
    switch (uri.scheme.toLowerCase()) {
      case 'socks5':
        type = ProxyType.socks5;
        break;
      case 'socks5h':
        type = ProxyType.socks5h;
        break;
      case 'http':
      case 'https':
        // Both mean "reach HTTPS destinations through an HTTP CONNECT
        // proxy". The hop to the proxy itself is not TLS.
        type = ProxyType.httpConnect;
        break;
      default:
        return null;
    }
    final port = uri.hasPort
        ? uri.port
        : (type == ProxyType.httpConnect ? 8080 : 1080);
    if (port <= 0 || port > 65535) return null;

    String? username;
    String? password;
    if (uri.userInfo.isNotEmpty) {
      final split = uri.userInfo.indexOf(':');
      if (split >= 0) {
        username = Uri.decodeComponent(uri.userInfo.substring(0, split));
        password = Uri.decodeComponent(uri.userInfo.substring(split + 1));
      } else {
        username = Uri.decodeComponent(uri.userInfo);
      }
    }
    return GlobalProxyConfig(
      type: type,
      host: uri.host,
      port: port,
      username: (username?.isEmpty ?? true) ? null : username,
      password: (password?.isEmpty ?? true) ? null : password,
    );
  }
}

/// Tor bridge families supported by the managed-Tor UI. The app can only run
/// a transport when its client binary is installed; the UI says so plainly.
enum TorBridgeType { none, obfs4, snowflake, webtunnel, meek, custom }

extension TorBridgeTypeLabel on TorBridgeType {
  String get label {
    switch (this) {
      case TorBridgeType.none:
        return 'No bridge (direct Tor)';
      case TorBridgeType.obfs4:
        return 'obfs4';
      case TorBridgeType.snowflake:
        return 'Snowflake';
      case TorBridgeType.webtunnel:
        return 'WebTunnel';
      case TorBridgeType.meek:
        return 'meek';
      case TorBridgeType.custom:
        return 'Custom bridge line';
    }
  }

  String get binaryName {
    switch (this) {
      case TorBridgeType.obfs4:
        return 'obfs4proxy';
      case TorBridgeType.snowflake:
        return 'snowflake-client';
      case TorBridgeType.webtunnel:
        return 'webtunnel-client';
      case TorBridgeType.meek:
        return 'meek-client';
      case TorBridgeType.none:
      case TorBridgeType.custom:
        return '';
    }
  }

  String get bridgePrefix {
    switch (this) {
      case TorBridgeType.obfs4:
        return 'obfs4 ';
      case TorBridgeType.snowflake:
        return 'snowflake ';
      case TorBridgeType.webtunnel:
        return 'webtunnel ';
      case TorBridgeType.meek:
        return 'meek ';
      case TorBridgeType.none:
      case TorBridgeType.custom:
        return '';
    }
  }
}

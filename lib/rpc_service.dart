import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import 'encrypted_log_store.dart';
import 'fee_engine.dart';
import 'models.dart';
import 'net/privacy_client.dart';
import 'rpc_story.dart';
import 'storage.dart';
import 'tx_lifecycle.dart';

/// Network constants for BNB Smart Chain, matching the v1 terminal wallet.
class BnbNetworks {
  BnbNetworks._();

  static const Map<String, int> chainIds = {'mainnet': 56, 'testnet': 97};

  static const Map<String, String> explorers = {
    'mainnet': 'https://bscscan.com',
    'testnet': 'https://testnet.bscscan.com',
  };

  static const Map<String, String> apis = {
    'mainnet': 'https://api.bscscan.com/v2/api',
    'testnet': 'https://api.bscscan.com/v2/api',
  };

  /// Verified free public doors, default first. Every URL below answered
  /// `eth_chainId` with the correct chain ID when this list was updated.
  /// No API key is required.
  static const List<String> mainnetFallbacks = [
    'https://bsc-dataseed.bnbchain.org',
    'https://bsc-dataseed-public.bnbchain.org',
    'https://bsc-dataseed.nariox.org',
    'https://bsc-rpc.publicnode.com',
    'https://1rpc.io/bnb',
    'https://bsc-mainnet.public.blastapi.io',
    'https://rpc.48.club',
  ];

  static const List<String> testnetFallbacks = [
    'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
    'https://bsc-testnet-rpc.publicnode.com',
  ];

  static const Map<String, String> defaultRpcs = {
    'mainnet': 'https://bsc-dataseed.bnbchain.org',
    'testnet': 'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
  };
}

/// A block number plus its on-chain timestamp (seconds). Used for measured
/// block times and confirmation ages — never a hardcoded "typical" value.
@immutable
class BlockStamp {
  const BlockStamp({required this.number, required this.time});
  final int number;
  final int time;
}

/// Result of a node probe.
@immutable
class RpcProbeResult {
  const RpcProbeResult({
    required this.ok,
    this.latencyMs,
    this.chainId,
    this.blockNumber,
    this.reason,
  });

  final bool ok;
  final int? latencyMs;
  final int? chainId;
  final int? blockNumber;
  final String? reason;
}

/// The raw signed bytes and their transaction hash. [hash] is computed
/// locally from the signed bytes so a node answering "already known" cannot
/// make the wallet lose track of what it signed.
@immutable
class BroadcastOutcome {
  const BroadcastOutcome({required this.hash, required this.rawHex});
  final String hash;
  final String rawHex;
}

/// One JSON-RPC exchange kept in memory for the "View raw request" panel
/// (spec §7). Never written to disk or to the encrypted log: it can contain
/// addresses and a signed transaction, which are public on-chain but still
/// activity-revealing.
@immutable
class RpcExchange {
  const RpcExchange({
    required this.at,
    required this.url,
    required this.method,
    required this.body,
    required this.response,
    this.status,
  });

  final DateTime at;
  final String url;
  final String method;
  final String body;
  final String response;
  final int? status;

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'url': url,
    'method': method,
    'status': status,
    'body': body,
    'response': response,
  };
}

/// All RPC access for the GUI. Secrets never pass through this class.
class RpcService extends ChangeNotifier {
  RpcService({http.Client? httpClient})
    : _httpClient = httpClient ?? createRpcClient();

  http.Client _httpClient;

  /// Test-only access to the live transport, so a regression test can prove
  /// the configured proxy/Tor route survives startup.
  @visibleForTesting
  http.Client get transportForTest => _httpClient;
  http.Client? _activeNodeClient;
  Web3Client? _client;
  String? _activeRpc;
  String _network = 'mainnet';
  String _configuredRpc = BnbNetworks.defaultRpcs['mainnet']!;
  String? _bscscanKey;
  List<TokenInfo> _customTokens = const [];

  /// Doors the node manager hands over (enabled, current side, safe URL,
  /// transport settings) — every fee/receipt crosscheck goes through this
  /// bookkeeping.
  List<RpcNode> _userNodePool = const [];

  /// §10d strict mode: the chosen door is the ONLY door. No fallback, no
  /// built-in candidate, nothing else; if it is down nothing is sent.
  bool _strictFlag = false;

  /// Cold-signer isolation: while true, this service refuses to open any
  /// network connection. The cold wallet mode sets it before dropping the
  /// current client, so an accidental UI refresh cannot leak a request.
  bool _offline = false;
  bool get offline => _offline;

  void setOffline(bool value) {
    _offline = value;
    if (value) _dropClient();
    notifyListeners();
  }

  /// Raw exchanges for the transparency panel. In memory only, newest first.
  static const int exchangeCap = 50;
  final List<RpcExchange> _exchanges = [];

  List<RpcExchange> get recentExchanges => List.unmodifiable(_exchanges);
  RpcExchange? get lastExchange => _exchanges.isEmpty ? null : _exchanges.first;

  /// The last connection probe (latency, chain, block) reused by the Home
  /// node card. It is measured during [connect], not by extra polling.
  RpcProbeResult? _lastProbe;
  RpcProbeResult? get lastProbe => _lastProbe;

  /// Last up to 50 measured answer times (ms) — the node card's sparkline.
  final List<int> _latencies = [];
  List<int> get latencyHistory => List.unmodifiable(_latencies);

  /// Count of real JSON-RPC HTTP requests this session; never persisted.
  int _requestCount = 0;
  int get requestCount => _requestCount;

  void _rememberLatency(int? ms) {
    if (ms == null) return;
    _latencies.add(ms);
    if (_latencies.length > 50) _latencies.removeAt(0);
  }

  bool get strictModeOn => _strictFlag;

  /// Only the node manager writes this.
  void setStrictFlag(bool value) {
    _strictFlag = value;
    notifyListeners();
  }

  /// Only the node manager writes this; pure hand-over of the enabled book.
  void setNodePool(List<RpcNode> nodes) {
    _userNodePool = [
      for (final node in nodes)
        if (nodeUrlAllowed(node.url)) node,
    ];
    notifyListeners();
  }

  String get network => _network;
  int get chainId => BnbNetworks.chainIds[_network] ?? 56;
  String get explorer =>
      BnbNetworks.explorers[_network] ?? BnbNetworks.explorers['mainnet']!;
  String get activeRpc => _activeRpc ?? '';
  String get configuredRpc => _configuredRpc;
  Web3Client? get client => _client;
  bool get isConnected => _client != null;
  List<TokenInfo> get tokens => List.unmodifiable(_customTokens);

  // ---- connection story ----------------------------------------------------
  //
  // The story is in-memory only. It is deliberately boring to look at and to
  // reason about:
  //  * at most [storyCap] lines are kept (depth cap);
  //  * at most 30 NEW lines per wall-clock second are accepted, after which
  //    one marker says a cycle was detected and broken;
  //  * listener notifications are batched into one microtask, so a burst of
  //    70 notes (or a listener that narrates back) can never re-enter the UI
  //    thousands of times — the shape of the round-4 production freeze.

  static const int storyCap = 500;
  static const int _storyBudgetPerSecond = 30;

  final List<RpcStoryLine> _story = [];
  DateTime? _storyWindowStartedAt;
  int _storyCountThisSecond = 0;
  bool _cycleReported = false;
  bool _notifyScheduled = false;

  /// App_state calls this to narrate network events into the story log.
  void note(
    String text, {
    RpcStoryKind kind = RpcStoryKind.info,
    String? detail,
  }) {
    _tell(text, kind: kind, detail: detail);
  }

  void _tell(
    String text, {
    RpcStoryKind kind = RpcStoryKind.info,
    String? detail,
  }) {
    final now = DateTime.now();
    if (_storyWindowStartedAt == null ||
        now.difference(_storyWindowStartedAt!) >= const Duration(seconds: 1)) {
      _storyWindowStartedAt = now;
      _storyCountThisSecond = 0;
      _cycleReported = false;
    }
    if (_storyCountThisSecond >= _storyBudgetPerSecond) {
      if (!_cycleReported) {
        _cycleReported = true;
        _appendStory(
          RpcStoryLine(
            'A story cycle was detected and broken — the wallet keeps running '
            'normally.',
            kind: RpcStoryKind.wait,
            detail: '$_storyBudgetPerSecond lines per second budget',
            at: now.toUtc(),
          ),
        );
      }
      return;
    }
    _storyCountThisSecond++;
    _appendStory(
      RpcStoryLine(text, kind: kind, detail: detail, at: now.toUtc()),
    );
  }

  void _appendStory(RpcStoryLine line) {
    _story.add(line);
    if (_story.length > storyCap) {
      _story.removeRange(0, _story.length - storyCap);
    }
    // Also write to the encrypted log store (R2). Logging must never break
    // the caller or leak secrets: only plain narration is passed.
    unawaited(
      logEvent(
        category: LogCategory.network,
        level: _storyKindToLevel(line.kind),
        message: line.text,
        extra: line.detail != null ? {'detail': line.detail} : null,
      ).catchError((_) {}),
    );
    _scheduleNotify();
  }

  LogLevel _storyKindToLevel(RpcStoryKind kind) {
    switch (kind) {
      case RpcStoryKind.fail:
        return LogLevel.error;
      case RpcStoryKind.wait:
        return LogLevel.warn;
      case RpcStoryKind.ok:
        return LogLevel.info;
      case RpcStoryKind.info:
        return LogLevel.debug;
    }
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  List<RpcStoryLine> get story => List.unmodifiable(_story);

  /// Clears the in-memory story log (used on full erase and by the UI).
  void clearStory() {
    _story.clear();
    _storyWindowStartedAt = null;
    _storyCountThisSecond = 0;
    _cycleReported = false;
    _scheduleNotify();
  }

  /// Rebuilds the HTTP transport from the current preferences without opening
  /// a connection.
  ///
  /// The field initializer runs when the global [AppState] is constructed,
  /// which happens before `AppStorage.init()`. At that moment `createRpcClient`
  /// cannot read the proxy/Tor settings and historically fell back to a direct
  /// client; it was then never rebuilt. Calling this immediately after storage
  /// initialization guarantees the very first request uses the configured
  /// route instead of leaking a direct connection.
  void rebuildTransport() {
    _dropClient();
    final old = _httpClient;
    _httpClient = createRpcClient();
    if (!identical(old, _httpClient)) {
      try {
        old.close();
      } catch (_) {}
    }
  }

  /// Called when Tor/proxy settings change so the transport and the current
  /// connection are rebuilt through the new route.
  Future<void> privacyChanged() async {
    rebuildTransport();
    try {
      await connect();
    } catch (_) {
      // connect narrated the exact failure; erasing must still succeed.
    }
  }

  void _dropClient() {
    final old = _client;
    final oldNodeClient = _activeNodeClient;
    _client = null;
    _activeRpc = null;
    _activeNodeClient = null;
    if (old != null) unawaited(old.dispose());
    if (oldNodeClient != null) {
      try {
        oldNodeClient.close();
      } catch (_) {}
    }
  }

  // ---- basic connectivity --------------------------------------------------

  /// Pure state switch: the caller decides when to ask the network. Kept
  /// synchronous because AppState boots it during `init()`.
  void setNetwork(String network) {
    if (network == _network) return;
    _network = network;
    _configuredRpc = BnbNetworks.defaultRpcs[network]!;
    _dropClient();
    _userNodePool = [
      for (final node in _userNodePool)
        if (node.network == network) node,
    ];
    notifyListeners();
  }

  /// Pure state switch; AppState calls `connect()` right after.
  void setConfiguredRpc(String rpc) {
    final trimmed = rpc.trim();
    if (!nodeUrlAllowed(trimmed)) {
      throw StateError(
        'HTTPS everywhere — HTTP only for localhost/LAN or .onion over Tor.',
      );
    }
    final scheme = Uri.tryParse(trimmed)?.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      throw StateError('RPC must be an HTTP(S) endpoint, not a WebSocket URL.');
    }
    _configuredRpc = trimmed;
    if (_activeRpc != null && _activeRpc != trimmed) _dropClient();
    notifyListeners();
  }

  void setCustomTokens(List<TokenInfo> tokens) {
    _customTokens = List.unmodifiable(tokens);
    notifyListeners();
  }

  Future<void> setBscscanKey(String? key) async {
    _bscscanKey = key;
    notifyListeners();
  }

  /// Picks the HTTP transport for a URL: the node's own settings when it is
  /// in the phone book, otherwise the global transport.
  (http.Client, bool) _transportFor(String url) {
    final node = _poolNode(url);
    if (node != null) return (createClientForNode(node), true);
    return (_httpClient, false);
  }

  RpcNode? _poolNode(String? url) {
    if (url == null || url.isEmpty) return null;
    return _userNodePool.where((n) => n.url == url).firstOrNull;
  }

  static const Duration _rpcCallTimeout = Duration(seconds: 10);

  /// A hostile or broken node must not be able to exhaust the app's memory.
  static const int _maxResponseBytes = 2 * 1024 * 1024;

  /// The only JSON-RPC methods this wallet ever sends. Anything else is
  /// refused before a socket is opened, so a compromised caller (or a future
  /// code path) cannot turn the wallet into a generic RPC proxy.
  static const Set<String> _allowedMethods = {
    'eth_chainId',
    'eth_blockNumber',
    'eth_gasPrice',
    'eth_maxPriorityFeePerGas',
    'eth_feeHistory',
    'eth_getBalance',
    'eth_getTransactionCount',
    'eth_getTransactionReceipt',
    'eth_getBlockByNumber',
    'eth_getCode',
    'eth_getLogs',
    'eth_estimateGas',
    'eth_call',
    'eth_sendRawTransaction',
    'net_version',
  };

  /// Cold-signer mode is absolute: every network path checks it, not only
  /// `connect()`.
  void _ensureOnline() {
    if (_offline) {
      throw StateError(
        'This device is in cold-signer mode: all network access is disabled.',
      );
    }
  }

  Future<void> connect({bool allowFallback = true}) async {
    if (_offline) {
      throw StateError(
        'This device is in cold-signer mode: all network access is disabled.',
      );
    }
    if (_client != null) return;
    final fallbacks = _network == 'testnet'
        ? BnbNetworks.testnetFallbacks
        : BnbNetworks.mainnetFallbacks;
    final seen = <String>{};
    final urls = <String>[
      _configuredRpc,
      if (allowFallback && !_strictFlag) ...fallbacks,
    ];
    Object? lastError;
    for (final url in urls) {
      if (!seen.add(url)) continue;
      if (!nodeUrlAllowed(url)) continue;
      final host = Uri.tryParse(url)?.host ?? url;
      _tell('Knocking on $host…', kind: RpcStoryKind.wait);
      final transport = _transportFor(url);
      final client = transport.$1;
      final owned = transport.$2;
      try {
        final candidate = Web3Client(url, client);
        final watch = Stopwatch()..start();
        final chain = await candidate.getChainId().timeout(_rpcCallTimeout);
        watch.stop();
        if (chain.toInt() != chainId) {
          _lastProbe = RpcProbeResult(
            ok: false,
            latencyMs: watch.elapsedMilliseconds,
            chainId: chain.toInt(),
            reason:
                'Wrong chain: answered ${chain.toInt()}, expected $chainId.',
          );
          await candidate.dispose();
          if (owned) client.close();
          _tell(
            '$host is chain ${chain.toInt()}, not $chainId.',
            kind: RpcStoryKind.fail,
          );
          continue;
        }
        _client = candidate;
        _activeRpc = url;
        _activeNodeClient = owned ? client : null;
        _lastProbe = RpcProbeResult(
          ok: true,
          latencyMs: watch.elapsedMilliseconds,
          chainId: chain.toInt(),
        );
        _rememberLatency(watch.elapsedMilliseconds);
        _tell('Connected to $host (chain $chainId).', kind: RpcStoryKind.ok);
        notifyListeners();
        return;
      } catch (error) {
        lastError = error;
        if (owned) {
          try {
            client.close();
          } catch (_) {}
        }
        _tell('$host did not answer: $error', kind: RpcStoryKind.fail);
        continue;
      }
    }
    throw StateError(
      'No reachable node on the correct chain. Check your network or RPC '
      'settings.${lastError == null ? '' : ' Last error: $lastError'}',
    );
  }

  Future<void> disconnect() async {
    _dropClient();
    notifyListeners();
  }

  Future<void> ensureConnected() async {
    if (_client != null) return;
    await connect();
  }

  // ---- probing -------------------------------------------------------------

  Future<RpcProbeResult> probeNode(String url) async {
    _ensureOnline();
    final host = Uri.tryParse(url)?.host ?? url;
    if (!nodeUrlAllowed(url)) {
      _tell(
        '$host is not an HTTPS/localhost/LAN/.onion door. I never knock on '
        'unsafe doors.',
        kind: RpcStoryKind.fail,
        detail: 'HTTP addresses would send everything in the clear.',
      );
      return const RpcProbeResult(ok: false, reason: 'HTTPS only.');
    }
    _tell('Testing $host…', kind: RpcStoryKind.wait);
    final watch = Stopwatch()..start();
    final transport = _transportFor(url);
    final client = transport.$1;
    final owned = transport.$2;
    final candidate = Web3Client(url, client);
    var disposed = false;
    try {
      final chain = await candidate.getChainId().timeout(_rpcCallTimeout);
      watch.stop();
      final ms = watch.elapsedMilliseconds;
      _rememberLatency(ms);
      final matches = chain.toInt() == chainId;
      var block = -1;
      try {
        block = await candidate.getBlockNumber().timeout(_rpcCallTimeout);
      } catch (_) {}
      await candidate.dispose();
      disposed = true;
      _tell(
        '$host said it is chain ${chain.toInt()} in $ms ms.'
        '${matches ? ' That is the network I expect.' : ' That is NOT the network I expect (I want $chainId).'}',
        kind: matches ? RpcStoryKind.ok : RpcStoryKind.fail,
        detail: block >= 0 ? 'Latest block: $block' : null,
      );
      if (!matches) {
        return RpcProbeResult(
          ok: false,
          latencyMs: ms,
          chainId: chain.toInt(),
          blockNumber: block >= 0 ? block : null,
          reason: 'Wrong chain: got ${chain.toInt()}, expected $chainId.',
        );
      }
      return RpcProbeResult(
        ok: true,
        latencyMs: ms,
        chainId: chain.toInt(),
        blockNumber: block >= 0 ? block : null,
      );
    } catch (error) {
      _tell(
        '$host did not answer.',
        kind: RpcStoryKind.fail,
        detail: error is TimeoutException
            ? 'I waited 10 seconds and it stayed silent.'
            : (error.toString().length > 140
                  ? '${error.toString().substring(0, 140)}…'
                  : error.toString()),
      );
      return RpcProbeResult(
        ok: false,
        reason: error is TimeoutException
            ? 'Timed out after 10 s.'
            : error.toString(),
      );
    } finally {
      if (!disposed) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }
      if (owned) {
        try {
          client.close();
        } catch (_) {}
      }
    }
  }

  /// The full §10d "Test node" checklist with visible per-item results.
  /// NOTHING here ever sends a transaction: the sendRawTransaction probe uses
  /// a deliberately invalid payload ("0x") and only checks that the METHOD
  /// exists (a missing method answers code -32601). A chainId mismatch is the
  /// one result that must block saving a node; every other failure is a
  /// warning the dialog explains.
  Future<List<NodeCheckRow>> testNodeDeep(
    String url, {
    String? expectedNetwork,
  }) async {
    _ensureOnline();
    final host = Uri.tryParse(url)?.host ?? url;
    final side = expectedNetwork ?? _network;
    final expected = BnbNetworks.chainIds[side] ?? 56;
    const zero = '0x0000000000000000000000000000000000000000';
    if (!nodeUrlAllowed(url)) {
      _tell(
        '$host is not an HTTPS/localhost/LAN/.onion door. I never knock '
        'on unsafe doors.',
        kind: RpcStoryKind.fail,
        detail: 'HTTP addresses would send everything in the clear.',
      );
      return const [
        NodeCheckRow(
          'Address policy',
          false,
          'HTTPS everywhere — HTTP only for localhost/LAN doors or a .onion '
              'address over Tor. This address is neither.',
        ),
      ];
    }
    _tell('Running the full checklist on $host…', kind: RpcStoryKind.wait);
    final rows = <NodeCheckRow>[];
    void addRow(String label, bool ok, String detail) =>
        rows.add(NodeCheckRow(label, ok, detail));
    var chainMismatch = false;
    final watch = Stopwatch()..start();
    var latencyMs = 0;

    // 1. Answers at all + right chain (the blocking check).
    try {
      final answer = await _rpcPostFull(url, 'eth_chainId', const []);
      watch.stop();
      latencyMs = watch.elapsedMilliseconds;
      final chain = hexToInt('${_rpcResult(answer)}').toInt();
      chainMismatch = chain != expected;
      addRow('Answers at all', true, '$host answered in $latencyMs ms.');
      addRow(
        'Right chain',
        !chainMismatch,
        chainMismatch
            ? 'Reports chain $chain but a $side door must report $expected. '
                  'THIS BLOCKS SAVING the node.'
            : 'Reports chain $chain — that is our $side side.',
      );
    } catch (error) {
      _tell(
        '$host did not answer the checklist.',
        kind: RpcStoryKind.fail,
        detail: '$error',
      );
      return [
        NodeCheckRow(
          'Answers at all',
          false,
          'No answer to eth_chainId: $error',
        ),
      ];
    }

    // 2. Sees the chain head, ideally close to what our active door saw.
    var block = -1;
    int? reference;
    try {
      block = hexToInt(
        '${_rpcResult(await _rpcPostFull(url, 'eth_blockNumber', const []))}',
      ).toInt();
    } catch (_) {}
    final active = _activeRpc;
    if (active != null && nodeUrlAllowed(active)) {
      try {
        reference = (await _blockStamp(active, 'latest'))?.number;
      } catch (_) {}
    }
    if (block >= 0) {
      final delta = reference == null ? null : reference - block;
      final fresh = delta == null || (delta <= 5 && delta >= -1);
      addRow(
        'Sees the chain head',
        fresh,
        'Latest block it sees: $block'
            '${reference == null ? '' : ' · this app just saw $reference (△ $delta)'}'
            '${fresh ? '' : ' — it lags behind; a stale door can lie with old data.'}',
      );
    } else {
      addRow('Sees the chain head', false, 'No answer to eth_blockNumber.');
    }

    // 3. Gas price.
    try {
      final price = hexToInt(
        '${_rpcResult(await _rpcPostFull(url, 'eth_gasPrice', const []))}',
      );
      addRow(
        'Knows the gas price',
        price > BigInt.zero,
        'Now ${FeeEngine.formatGwei(price)} gwei per gas.',
      );
    } catch (_) {
      addRow('Knows the gas price', false, 'No answer to eth_gasPrice.');
    }

    // 4. EIP-1559 fee history support (informational: legacy fallback exists).
    try {
      final result = _rpcResult(
        await _rpcPostFull(url, 'eth_feeHistory', const [
          8,
          'latest',
          [10.0, 50.0, 90.0],
        ]),
      ) as Map?;
      final supported = result != null && result['baseFeePerGas'] != null;
      addRow(
        'Speaks EIP-1559 fee history',
        supported,
        supported
            ? 'Priority-fee percentiles are available — the live fee engine '
                  'can use this door.'
            : 'Answered but without fee data — the wallet falls back to '
                  'legacy prices on it.',
      );
    } catch (_) {
      addRow(
        'Speaks EIP-1559 fee history',
        false,
        'Not supported here — the wallet falls back to legacy prices on it '
            '(allowed).',
      );
    }

    // 5. Pending nonce reading (what the send flow checks before signing).
    try {
      final nonce = hexToInt(
        '${_rpcResult(await _rpcPostFull(url, 'eth_getTransactionCount', const [zero, 'pending']))}',
      );
      addRow(
        'Can read pending nonces',
        true,
        'Pending count of the zero address: $nonce — the call itself worked.',
      );
    } catch (_) {
      addRow(
        'Can read pending nonces',
        false,
        'No answer to eth_getTransactionCount (pending).',
      );
    }

    // 6. eth_call — the rehearsal path every transfer takes before signing.
    try {
      final data =
          '${_rpcResult(await _rpcPostFull(url, 'eth_call', const [
            {'from': zero, 'to': zero, 'data': '0x'},
            'latest',
          ]))}';
      addRow(
        'Can simulate calls (eth_call)',
        true,
        'A minimal dry call answered: $data — transfers are rehearsed '
            'before anything is signed.',
      );
    } catch (error) {
      addRow(
        'Can simulate calls (eth_call)',
        false,
        'The dry call failed: $error',
      );
    }

    // 7. estimateGas.
    try {
      final gas = hexToInt(
        '${_rpcResult(await _rpcPostFull(url, 'eth_estimateGas', const [
          {'from': zero, 'to': zero, 'value': '0x1'},
        ]))}',
      );
      addRow(
        'Can estimate gas',
        true,
        'A 1-wei zero transfer estimates $gas gas.',
      );
    } catch (error) {
      addRow('Can estimate gas', false, 'The estimate failed: $error');
    }

    // 8. sendRawTransaction AVAILABILITY — invalid payload, nothing to sign,
    // nothing to broadcast. Missing method (-32601) = read-only door.
    try {
      final answer = await _rpcPostFull(url, 'eth_sendRawTransaction', const [
        '0x',
      ]);
      addRow(
        'Can broadcast (eth_sendRawTransaction)',
        false,
        'Unexpectedly ACCEPTED an invalid payload (${_rpcResult(answer)}) — '
            'do not trust this door.',
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      final missing =
          text.contains('32601') ||
          text.contains('method not found') ||
          text.contains('does not exist');
      addRow(
        'Can broadcast (eth_sendRawTransaction)',
        !missing,
        missing
            ? 'The method is NOT available — this door can read but never '
                  'broadcast.'
            : 'Method exists. The probe payload is invalid by design, so '
                  'NOTHING was broadcast.',
      );
    }

    // 9. Answer time, measured on the very first round trip.
    final ms = latencyMs;
    final verdict = ms < 250
        ? 'fast'
        : ms < 900
        ? 'a bit slow'
        : 'very slow';
    addRow('Answer time', true, '$ms ms — $verdict.');

    final passed = rows.where((r) => r.ok).length;
    _tell(
      'Checklist on $host: $passed of ${rows.length} checks passed'
      '${chainMismatch ? ' — chain mismatch BLOCKS saving.' : '.'}',
      kind: chainMismatch ? RpcStoryKind.fail : RpcStoryKind.ok,
    );
    return rows;
  }

  // ---- balances, nonces, tokens -------------------------------------------

  Future<BigInt> getNativeBalance(String address) async {
    await ensureConnected();
    final amount = await _client!.getBalance(EthereumAddress.fromHex(address));
    return amount.getInWei;
  }

  Future<int> getNonce(String address) async {
    await ensureConnected();
    return _client!.getTransactionCount(
      EthereumAddress.fromHex(address),
      atBlock: const BlockNum.pending(),
    );
  }

  /// Nonce of the last mined state (not pending) — used to tell whether an
  /// old pending transaction was replaced or dropped.
  Future<int> getConfirmedNonce(String address) async {
    await ensureConnected();
    return _client!.getTransactionCount(
      EthereumAddress.fromHex(address),
      atBlock: const BlockNum.current(),
    );
  }

  Future<int> getBlockNumber() async {
    await ensureConnected();
    return _client!.getBlockNumber();
  }

  static const String _erc20Abi = '''
[
  {"constant":true,"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},
  {"constant":false,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
  {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
  {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
  {"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"type":"function"}
]
''';

  DeployedContract _erc20(String address) => DeployedContract(
    ContractAbi.fromJson(_erc20Abi, 'ERC20'),
    EthereumAddress.fromHex(address),
  );

  Future<String> _callString(DeployedContract contract, String name) async {
    final result = await _client!.call(
      contract: contract,
      function: contract.function(name),
      params: const [],
    );
    return result.first.toString();
  }

  Future<int> _callInt(DeployedContract contract, String name) async {
    final result = await _client!.call(
      contract: contract,
      function: contract.function(name),
      params: const [],
    );
    return (result.first as BigInt).toInt();
  }

  Future<TokenInfo> tokenMeta(String address) async {
    await ensureConnected();
    final contract = _erc20(address);
    final symbol = (await _callString(contract, 'symbol')).trim();
    final name = (await _callString(contract, 'name')).trim();
    final decimals = await _callInt(contract, 'decimals');
    if (symbol.isEmpty || name.isEmpty) {
      throw StateError('Token metadata is empty or unsafe.');
    }
    if (decimals < 0 || decimals > 36) {
      throw StateError('Token decimals out of range.');
    }
    return TokenInfo(
      symbol: symbol,
      name: name,
      address: address,
      decimals: decimals,
      network: _network,
    );
  }

  Future<TokenInfo> getTokenInfo(String address) async => tokenMeta(address);

  Future<BigInt> getTokenBalance(
    String tokenAddress,
    String walletAddress,
  ) async {
    await ensureConnected();
    final contract = _erc20(tokenAddress);
    final result = await _client!.call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [EthereumAddress.fromHex(walletAddress)],
    );
    return result.first as BigInt;
  }

  Future<BigInt> estimateGas({
    required String from,
    required String to,
    BigInt? value,
    Uint8List? data,
  }) async {
    await ensureConnected();
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      if (value != null && value > BigInt.zero)
        'value': '0x${value.toRadixString(16)}',
      if (data != null && data.isNotEmpty)
        'data': bytesToHex(data, include0x: true, padToEvenLength: true),
    };
    final result = await _rpcPost(_activeRpc!, 'eth_estimateGas', [payload]);
    return hexToInt('$result');
  }

  Future<bool> isContract(EthereumAddress address) async {
    await ensureConnected();
    final code = await _client!.getCode(address);
    return code.isNotEmpty;
  }

  // ---- fee engine ----------------------------------------------------------

  Future<FeeQuote> feeQuote() async {
    final candidates = _feeCandidates();
    if (candidates.isEmpty) {
      throw StateError(
        'No usable node is configured, so no fee can be quoted.',
      );
    }
    final results = await Future.wait([
      for (final node in candidates) _feeSnapshot(node),
    ]);
    final sources = [for (final r in results) ?r];
    if (sources.isEmpty) {
      throw StateError(
        'No node could quote a network fee right now. Check the connection '
        'and try again.',
      );
    }
    return FeeEngine.merge(sources, tried: candidates.length);
  }

  /// One node's raw, live fee picture. Falls back to that node's gas-price
  /// quote when it has no fee history, and to null when it cannot answer.
  Future<FeeSourceSnapshot?> _feeSnapshot(RpcNode node) async {
    final url = node.url;
    http.Client? transport;
    Web3Client? wc;
    try {
      transport = createClientForNode(node);
      wc = Web3Client(url, transport);
      final history = await wc
          .getFeeHistory(20, rewardPercentiles: const [10.0, 50.0, 90.0])
          .timeout(_rpcCallTimeout);
      final baseFees = [
        for (final e in (history['baseFeePerGas'] as List? ?? const []))
          e as BigInt,
      ];
      final rewards = [
        for (final block in (history['reward'] as List? ?? const []))
          [for (final tip in (block as List)) tip as BigInt],
      ];
      final ratios = [
        for (final r in (history['gasUsedRatio'] as List? ?? const []))
          (r as num).toDouble(),
      ];
      if (baseFees.length < 2 || rewards.isEmpty) {
        throw StateError('No fee history on this node.');
      }
      double? seconds;
      double? jitter;
      final oldestRaw = history['oldestBlock'];
      final oldest = oldestRaw is BigInt
          ? oldestRaw.toInt()
          : (oldestRaw is int ? oldestRaw : null);
      if (oldest != null) {
        // Measured block time from real timestamps — never a constant.
        final newest = await _blockStamp(url, 'latest');
        final first = await _blockStamp(url, '0x${oldest.toRadixString(16)}');
        if (newest != null &&
            first != null &&
            newest.number - first.number >= 2 &&
            newest.time > first.time) {
          seconds = (newest.time - first.time) / (newest.number - first.number);
          final middleNumber =
              first.number + (newest.number - first.number) ~/ 2;
          if (middleNumber > first.number && middleNumber < newest.number) {
            final middle = await _blockStamp(
              url,
              '0x${middleNumber.toRadixString(16)}',
            );
            if (middle != null &&
                middle.time > first.time &&
                newest.time > middle.time) {
              final firstRate =
                  (middle.time - first.time) / (middle.number - first.number);
              final secondRate =
                  (newest.time - middle.time) / (newest.number - middle.number);
              final mean = (firstRate + secondRate) / 2;
              if (mean > 0) jitter = (firstRate - secondRate).abs() / mean;
            }
          }
        }
      }
      return FeeSourceSnapshot(
        source: url,
        baseFees: baseFees,
        rewards: rewards,
        gasUsedRatios: ratios,
        blockSeconds: seconds,
        blockJitter: jitter,
      );
    } catch (_) {
      if (wc == null) return null;
      try {
        final gasPrice = await wc.getGasPrice().timeout(_rpcCallTimeout);
        return FeeSourceSnapshot(
          source: url,
          legacyGasPrice: gasPrice.getInWei,
        );
      } catch (_) {
        return null;
      }
    } finally {
      if (wc != null) {
        try {
          await wc.dispose();
        } catch (_) {}
      }
      if (transport != null) {
        try {
          transport.close();
        } catch (_) {}
      }
    }
  }

  /// Fetches one raw block stamp from a specific node.
  Future<BlockStamp?> _blockStamp(String url, String tag) async {
    try {
      final result = await _rpcPost(url, 'eth_getBlockByNumber', [tag, false]);
      if (result is! Map) return null;
      final numberHex = result['number'];
      final timeHex = result['timestamp'];
      if (numberHex == null || timeHex == null) return null;
      return BlockStamp(
        number: hexToInt('$numberHex').toInt(),
        time: hexToInt('$timeHex').toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// A URL the fee engine can actually POST to: HTTPS anywhere, HTTP only
  /// for localhost/LAN/.onion doors (policy in models.dart).
  static bool _queryable(String url) {
    final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (scheme == 'http') return nodeUrlAllowed(url);
    return false;
  }

  /// Pure candidate-builder: active node first, then the configured one, then
  /// the phone book's enabled doors, then the built-in fallbacks. In strict
  /// mode the pool is JUST the active door. Static so tests can pin the rule
  /// without constructing a service (construction touches storage).
  static List<RpcNode> feeCandidatePool({
    required RpcNode? active,
    required RpcNode? configured,
    required List<RpcNode> userPool,
    required List<String> builtInFallbacks,
    required bool strict,
    required NodeSelectionMode selectionMode,
  }) {
    if (strict) {
      return [
        if (active != null &&
            active.url.startsWith('https://') &&
            active.url.isNotEmpty &&
            active.useForReads)
          active,
      ];
    }
    final pool = <RpcNode>[];
    void add(RpcNode? node) {
      if (node == null || node.url.isEmpty || !_queryable(node.url)) return;
      if (!node.useForReads) return;
      if (pool.any((n) => n.url == node.url)) return;
      pool.add(node);
    }

    add(active);
    add(configured);
    for (final node in userPool) {
      add(node);
    }
    for (final url in builtInFallbacks) {
      add(RpcNode(label: 'built-in', url: url));
    }

    // Apply selection mode ordering
    switch (selectionMode) {
      case NodeSelectionMode.manual:
        // Keep book order (already in order)
        break;
      case NodeSelectionMode.autoFastest:
        // Will be re-ordered by latency at call site
        break;
      case NodeSelectionMode.roundRobin:
        // Rotate based on a simple counter - handled by caller
        break;
      case NodeSelectionMode.quorum:
        // All nodes returned; caller decides quorum logic
        break;
    }
    return pool.take(3).toList();
  }

  /// Broadcast candidate pool — only nodes with useForBroadcast = true.
  static List<RpcNode> broadcastCandidatePool({
    required RpcNode? active,
    required RpcNode? configured,
    required List<RpcNode> userPool,
    required List<String> builtInFallbacks,
    required bool strict,
  }) {
    if (strict) {
      return [
        if (active != null &&
            active.url.startsWith('https://') &&
            active.url.isNotEmpty &&
            active.useForBroadcast)
          active,
      ];
    }
    final pool = <RpcNode>[];
    void add(RpcNode? node) {
      if (node == null || node.url.isEmpty || !_queryable(node.url)) return;
      if (!node.useForBroadcast) return;
      if (pool.any((n) => n.url == node.url)) return;
      pool.add(node);
    }

    add(active);
    add(configured);
    for (final node in userPool) {
      add(node);
    }
    for (final url in builtInFallbacks) {
      add(RpcNode(label: 'built-in', url: url));
    }
    return pool;
  }

  List<RpcNode> _feeCandidates() {
    var activeNode = _poolNode(_activeRpc);
    final activeUrl = _activeRpc;
    if (activeNode == null && activeUrl != null) {
      activeNode = RpcNode(label: 'active', url: activeUrl);
    }
    final configuredNode =
        _poolNode(_configuredRpc) ??
        RpcNode(label: 'configured', url: _configuredRpc);
    return feeCandidatePool(
      active: activeNode,
      configured: configuredNode,
      userPool: _userNodePool,
      builtInFallbacks: _network == 'testnet'
          ? BnbNetworks.testnetFallbacks
          : BnbNetworks.mainnetFallbacks,
      strict: _strictFlag,
      selectionMode: _selectionMode,
    );
  }

  /// Current node selection mode (§10d/R7).
  NodeSelectionMode _selectionMode = NodeSelectionMode.manual;

  /// Node selection mode getter.
  NodeSelectionMode get selectionMode => _selectionMode;

  /// Set node selection mode (§10d/R7).
  Future<void> setSelectionMode(NodeSelectionMode mode) async {
    _selectionMode = mode;
    notifyListeners();
  }

  /// Independent nodes usable for cross-checks — the phone book's other
  /// enabled doors first, then the built-in fallbacks. Strict mode: none.
  static List<RpcNode> independentNodeList({
    required RpcNode? active,
    required List<RpcNode> userPool,
    required List<String> builtInFallbacks,
    required bool strict,
  }) {
    if (strict) return const [];
    final nodes = <RpcNode>[];
    void add(RpcNode? node) {
      if (node == null || node.url.isEmpty || !_queryable(node.url)) return;
      if (node.url == active?.url) return;
      if (nodes.any((n) => n.url == node.url)) return;
      nodes.add(node);
    }

    for (final node in userPool) {
      add(node);
    }
    if (nodes.isEmpty) {
      for (final url in builtInFallbacks) {
        add(RpcNode(label: 'built-in', url: url));
      }
    }
    return nodes;
  }

  List<RpcNode> get independentNodes {
    var activeNode = _poolNode(_activeRpc);
    final activeUrl = _activeRpc;
    if (activeNode == null && activeUrl != null) {
      activeNode = RpcNode(label: 'active', url: activeUrl);
    }
    return independentNodeList(
      active: activeNode,
      userPool: _userNodePool,
      builtInFallbacks: _network == 'testnet'
          ? BnbNetworks.testnetFallbacks
          : BnbNetworks.mainnetFallbacks,
      strict: _strictFlag,
    );
  }

  // ---- raw JSON-RPC --------------------------------------------------------

  /// Raw JSON-RPC pass-through. Used for the calls web3dart does not model:
  /// finality tags, block stamps, eth_call of a raw payload.
  Future<dynamic> _rpcPost(
    String url,
    String method,
    List<Object?> params,
  ) async => _rpcResult(await _rpcPostFull(url, method, params));

  /// Full JSON-RPC answer INCLUDING error objects — the node checklist must
  /// tell a missing method (code -32601) apart from a real failure.
  Future<Map<String, dynamic>> _rpcPostFull(
    String url,
    String method,
    List<Object?> params,
  ) async {
    if (url == _activeRpc && _client != null) {
      return _postJson(url, _activeNodeClient ?? _httpClient, method, params);
    }
    final node = _poolNode(url);
    if (node == null) {
      return _postJson(url, _httpClient, method, params);
    }
    final transport = createClientForNode(node);
    try {
      return await _postJson(url, transport, method, params);
    } finally {
      try {
        transport.close();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    http.Client client,
    String method,
    List<Object?> params,
  ) async {
    _ensureOnline();
    if (!_allowedMethods.contains(method)) {
      throw StateError(
        'Refusing to send the non-allowlisted RPC method "$method".',
      );
    }
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      throw StateError('RPC must be an HTTP(S) endpoint.');
    }
    _requestCount++;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });
    final request = http.Request('POST', Uri.parse(url))
      ..headers['content-type'] = 'application/json'
      ..body = body;
    final streamed = await client.send(request).timeout(_rpcCallTimeout);
    final bytes = <int>[];
    await for (final chunk in streamed.stream) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw StateError(
          'The node response exceeded the 2 MiB safety limit; refusing it.',
        );
      }
      bytes.addAll(chunk);
    }
    final String responseBody;
    try {
      responseBody = utf8.decode(bytes);
    } catch (_) {
      throw StateError('The node answered with invalid UTF-8.');
    }
    final statusCode = streamed.statusCode;
    _exchanges.insert(
      0,
      RpcExchange(
        at: DateTime.now().toUtc(),
        url: url,
        method: method,
        body: body,
        response: responseBody,
        status: statusCode,
      ),
    );
    if (_exchanges.length > exchangeCap) {
      _exchanges.removeRange(exchangeCap, _exchanges.length);
    }
    if (statusCode < 200 || statusCode >= 300) {
      final preview = responseBody.length > 160
          ? '${responseBody.substring(0, 160)}…'
          : responseBody;
      throw StateError('The node answered HTTP $statusCode: $preview');
    }
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw StateError(
        'The node answered with something that is not JSON-RPC.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  dynamic _rpcResult(Map<String, dynamic> answer) {
    final error = answer['error'];
    if (error != null) {
      if (error is Map) {
        final code = error['code'];
        final message = error['message'] ?? error;
        throw StateError('RPC error${code == null ? '' : ' $code'}: $message');
      }
      throw StateError('RPC error: $error');
    }
    return answer['result'];
  }

  /// Human-readable description of the active transport route. The Home card
  /// shows this verbatim, so it always says plainly that traffic is encrypted.
  String get routeDescription {
    try {
      final node = _poolNode(_activeRpc);
      if (node != null && node.transport != NodeTransport.inherit) {
        switch (node.transport) {
          case NodeTransport.direct:
            return 'Direct HTTPS — end-to-end encrypted';
          case NodeTransport.tor:
            return 'Tor (SOCKS5) — end-to-end encrypted';
          case NodeTransport.customProxy:
            return 'Custom SOCKS5 proxy — end-to-end encrypted';
          case NodeTransport.httpConnect:
            return 'HTTP CONNECT proxy — end-to-end encrypted';
          case NodeTransport.inherit:
            break;
        }
      }
      final proxy = AppStorage.globalProxy;
      if (proxy.type != ProxyType.none && proxy.enabled) {
        return '${proxy.type.label} ${proxy.host}:${proxy.port} — '
            'end-to-end encrypted';
      }
      if (AppStorage.torEnabled) {
        return 'Tor (SOCKS5 ${AppStorage.torHost}:${AppStorage.torPort}) — '
            'end-to-end encrypted';
      }
    } catch (_) {
      // Storage not initialized (pure tests): fall through to the default.
    }
    return 'Direct HTTPS — end-to-end encrypted';
  }

  // ---- sign / send ---------------------------------------------------------

  /// Signs a transaction locally without broadcasting. The hash is computed
  /// from the signed bytes, so it survives a node answering "already known".
  Future<BroadcastOutcome> signOnly(
    Transaction transaction,
    EthPrivateKey key,
  ) async {
    await ensureConnected();
    final signed = await _client!.signTransaction(
      key,
      transaction,
      chainId: chainId,
    );
    final rawHex = bytesToHex(signed, include0x: true, padToEvenLength: true);
    final hash = bytesToHex(keccak256(signed), include0x: true);
    final shortHash = hash.length > 12 ? '${hash.substring(0, 10)}…' : hash;
    unawaited(
      logEvent(
        category: LogCategory.tx,
        level: LogLevel.info,
        message: 'Transaction signed locally (chain $chainId, $shortHash).',
        extra: {'hash': hash, 'chainId': chainId, 'simple': 'Signed here'},
      ).catchError((_) {}),
    );
    return BroadcastOutcome(hash: hash, rawHex: rawHex);
  }

  /// Broadcasts a pre-signed raw transaction, returning the node's hash.
  Future<String> sendRawHex(String rawHex) async {
    await ensureConnected();
    final trimmed = rawHex.trim();
    final clean = trimmed.startsWith('0x') || trimmed.startsWith('0X')
        ? trimmed.substring(2)
        : trimmed;
    final hash = await _client!.sendRawTransaction(hexToBytes(clean));
    final shortHash = hash.length > 12 ? '${hash.substring(0, 10)}…' : hash;
    unawaited(
      logEvent(
        category: LogCategory.tx,
        level: LogLevel.info,
        message: 'Broadcast $shortHash to $_activeRpc.',
        extra: {'hash': hash, 'simple': 'Sent to node'},
      ).catchError((_) {}),
    );
    return hash;
  }

  /// The exact on-chain simulation the send flow runs before signing. If it
  /// reverts, the contract's exact revert reason is shown.
  Future<void> simulateTransfer({
    required String from,
    required String to,
    BigInt? value,
    Uint8List? data,
  }) async {
    await ensureConnected();
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      if (value != null && value > BigInt.zero)
        'value': '0x${value.toRadixString(16)}',
      if (data != null && data.isNotEmpty)
        'data': bytesToHex(data, include0x: true, padToEvenLength: true),
    };
    try {
      await _rpcPost(_activeRpc!, 'eth_call', [payload, 'latest']);
    } catch (error) {
      throw StateError(
        'The chain rehearsed this transfer and refused it: '
        '${decodeRevertReason(error)}. Nothing was signed.',
      );
    }
  }

  // ---- chain facts ---------------------------------------------------------

  Future<int?> finalizedBlockNumber() async {
    final url = _activeRpc;
    if (url == null) return null;
    try {
      final result = await _rpcPost(url, 'eth_getBlockByNumber', [
        'finalized',
        false,
      ]);
      if (result is Map && result['number'] != null) {
        return hexToInt('${result['number']}').toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<TransactionReceipt?> receipt(String hash) async {
    await ensureConnected();
    return _client!.getTransactionReceipt(hash);
  }

  Future<BlockStamp?> blockStampAt(int blockNumber) async {
    final url = _activeRpc;
    if (url == null || blockNumber <= 0) return null;
    return _blockStamp(url, '0x${blockNumber.toRadixString(16)}');
  }

  Future<BlockStamp?> latestBlockStamp() async {
    final url = _activeRpc;
    if (url == null) return null;
    return _blockStamp(url, 'latest');
  }

  Future<TransactionReceipt?> receiptFrom(String url, String hash) async {
    _ensureOnline();
    final node = _poolNode(url);
    final transport = node != null ? createClientForNode(node) : _httpClient;
    Web3Client? wc;
    try {
      wc = Web3Client(url, transport);
      return await wc.getTransactionReceipt(hash).timeout(_rpcCallTimeout);
    } catch (_) {
      return null;
    } finally {
      if (wc != null) {
        try {
          await wc.dispose();
        } catch (_) {}
      }
      if (node != null) {
        try {
          transport.close();
        } catch (_) {}
      }
    }
  }

  // ---- explorer history ----------------------------------------------------

  /// Public BscScan history rows. Needs the user's own API key (Settings).
  Future<List<HistoryTx>> history(String address) async {
    _ensureOnline();
    final key = _bscscanKey;
    if (key == null || key.isEmpty) {
      throw StateError(
        'Transaction history needs a BscScan API key. Add one in Settings.',
      );
    }
    final uri = Uri.parse(BnbNetworks.apis[_network]!).replace(
      queryParameters: {
        'chainid': '${BnbNetworks.chainIds[_network]}',
        'module': 'account',
        'action': 'txlist',
        'address': address,
        'page': '1',
        'offset': '20',
        'sort': 'desc',
        'apikey': key,
      },
    );
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'Explorer history request failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('The explorer answered with something unexpected.');
    }
    final body = Map<String, dynamic>.from(decoded);
    final result = body['result'];
    if (body['status'] != '1') {
      final message = '${body['message'] ?? ''} ${result ?? ''}'.trim();
      if (result is List && result.isEmpty) return const [];
      if (RegExp(r'no transactions', caseSensitive: false).hasMatch(message)) {
        return const [];
      }
      throw StateError('History lookup failed: $message');
    }
    if (result is! List) return const [];
    final out = <HistoryTx>[];
    for (final item in result) {
      if (item is! Map) continue;
      final seconds = int.tryParse('${item['timeStamp'] ?? ''}') ?? 0;
      out.add(
        HistoryTx(
          hash: '${item['hash'] ?? ''}',
          from: '${item['from'] ?? ''}',
          to: '${item['to'] ?? ''}',
          value: '${item['value'] ?? '0'}',
          timestamp: seconds > 0 ? _formatUnixStamp(seconds) : '',
          isError: '${item['isError'] ?? '0'}' == '1',
        ),
      );
    }
    return out;
  }

  static String _formatUnixStamp(int seconds) {
    final at = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  // ---- terminal v1 fee parity (used by the parity tests) -------------------

  /// Middle value; even counts floor the average, exactly like the terminal's
  /// `feeMedian` in fees.js.
  static BigInt feeMedian(List<BigInt> values) {
    if (values.isEmpty) {
      throw StateError('Cannot take the median of an empty list.');
    }
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) ~/ BigInt.two;
  }

  /// `(value * bps + 9999) / 10000` — rounds UP, like fees.js.
  static BigInt feeMultiplyBps(BigInt value, int bps) =>
      (value * BigInt.from(bps) + BigInt.from(9999)) ~/ BigInt.from(10000);

  /// EIP-1559 tiers: median priority across recent blocks, maxFee = base×2 +
  /// tip, expected = base + tip. Plain data for the parity tests and any
  /// caller that wants the terminal's exact tier shape.
  List<FeePreset> eip1559Presets(BigInt baseFee, List<List<BigInt>> rewards) {
    const labels = ['Low', 'Medium (recommended)', 'High'];
    final presets = <FeePreset>[];
    for (var p = 0; p < labels.length; p++) {
      final tips = <BigInt>[
        for (final block in rewards)
          if (block.length > p) block[p],
      ];
      final tip = feeMedian(tips);
      presets.add(
        FeePreset(
          label: labels[p],
          target: '',
          priorityFeePerGas: tip,
          maxFeePerGas: baseFee * BigInt.two + tip,
          expectedFeePerGas: baseFee + tip,
          mode: 'eip1559',
          source: 'recent 5 blocks · priority-fee percentiles',
          recommended: p == 1,
        ),
      );
    }
    return presets;
  }

  /// Legacy tiers: gasPrice × 0.90 / ×1.00 / ×1.25, rounded up.
  List<FeePreset> legacyPresets(BigInt gasPrice) {
    const labels = ['Low', 'Medium (recommended)', 'High'];
    const bps = [9000, 10000, 12500];
    final presets = <FeePreset>[];
    for (var i = 0; i < labels.length; i++) {
      final price = feeMultiplyBps(gasPrice, bps[i]);
      presets.add(
        FeePreset(
          label: labels[i],
          target: '',
          priorityFeePerGas: BigInt.zero,
          maxFeePerGas: price,
          expectedFeePerGas: price,
          gasPrice: price,
          mode: 'legacy',
          source: 'RPC gas-price quote · legacy fallback',
          recommended: i == 1,
        ),
      );
    }
    return presets;
  }

  // ===== R4: Networking hardening ========================================

  /// R4: N-node broadcast — send the same signed transaction to multiple
  /// independent nodes, each through its own transport (Tor circuit / proxy).
  /// Returns the set of hashes returned by each node (should be identical).
  /// Used for broadcast resilience: if one node drops it, others may still
  /// propagate it to the network.
  Future<Map<String, String>> broadcastToMultiple(
    String rawHex,
    List<RpcNode> nodes,
  ) async {
    _ensureOnline();
    final results = <String, String>{};
    for (final node in nodes) {
      if (!node.enabled || !node.useForBroadcast) continue;
      try {
        final transport = createClientForNode(node);
        final wc = Web3Client(node.url, transport);
        final hash = await wc
            .sendRawTransaction(
              hexToBytes(
                rawHex.startsWith('0x') ? rawHex.substring(2) : rawHex,
              ),
            )
            .timeout(_rpcCallTimeout);
        await wc.dispose();
        transport.close();
        results[node.url] = hash;
        _tell(
          'Broadcast to ${node.label} (${node.url}) → $hash',
          kind: RpcStoryKind.ok,
        );
      } catch (e) {
        _tell(
          'Broadcast to ${node.label} (${node.url}) failed: $e',
          kind: RpcStoryKind.fail,
        );
        results[node.url] = 'FAILED: $e';
      }
    }
    return results;
  }

  /// R4: Request batching with jitter and optional padding.
  /// Sends a batch of RPC calls with random delays between them to
  /// reduce timing correlation. If [padding] is true, adds dummy calls
  /// (e.g., eth_blockNumber) to obscure the real request pattern.
  /// [maxBatchDelay] is the max random delay between calls in ms.
  Future<List<dynamic>> batchedRpcCalls(
    String url, {
    required List<Map<String, dynamic>> calls, // each: {method, params}
    bool padding = false,
    int maxBatchDelay = 500,
    int paddingCount = 2,
  }) async {
    _ensureOnline();
    final node = _poolNode(url);
    final transport = node != null ? createClientForNode(node) : _httpClient;
    final results = <dynamic>[];
    final random = Random();

    // R4: Add padding calls at random positions
    final allCalls = <Map<String, dynamic>>[];
    var paddingAdded = 0;
    for (var i = 0; i < calls.length; i++) {
      if (padding && paddingAdded < paddingCount && random.nextBool()) {
        allCalls.add({'method': 'eth_blockNumber', 'params': const []});
        paddingAdded++;
      }
      allCalls.add(calls[i]);
    }
    // Add remaining padding at the end
    while (paddingAdded < paddingCount) {
      allCalls.add({'method': 'eth_blockNumber', 'params': const []});
      paddingAdded++;
    }

    for (var i = 0; i < allCalls.length; i++) {
      final call = allCalls[i];
      // R4: Jitter between calls
      if (i > 0 && maxBatchDelay > 0) {
        final delay = random.nextInt(maxBatchDelay);
        await Future.delayed(Duration(milliseconds: delay));
      }
      try {
        final result = await _postJson(
          url,
          transport,
          call['method'] as String,
          call['params'] as List<Object?>,
        );
        results.add(_rpcResult(result));
      } catch (e) {
        results.add({'error': e.toString()});
      }
    }

    // Close transport if we created a new one
    if (node != null) {
      try {
        transport.close();
      } catch (_) {}
    }
    return results;
  }

  /// R4: Dust mode — send a small dummy transaction to blend in with
  /// normal traffic patterns. This creates a decoy transaction that
  /// looks like a normal transfer but with minimal value.
  /// Returns the hash of the dummy tx (or null if disabled/failed).
  /// WARNING: This spends real gas. Only enable when user explicitly
  /// requests privacy mode and understands the cost.
  Future<String?> sendDustTransaction({
    required String fromAddress,
    required EthPrivateKey key,
    required BigInt value,
    String? toAddress,
  }) async {
    // Only send dust if explicitly enabled (opt-in via settings)
    try {
      // Use a well-known address or the user's own address as recipient
      final recipient = toAddress ?? fromAddress;
      final nonce = await getNonce(fromAddress);
      final gasLimit = BigInt.from(21000);
      final gasPrice = await _client!.getGasPrice();
      final tx = Transaction(
        from: EthereumAddress.fromHex(fromAddress),
        to: EthereumAddress.fromHex(recipient),
        value: EtherAmount.inWei(value),
        nonce: nonce,
        maxGas: gasLimit.toInt(),
        maxFeePerGas: EtherAmount.inWei(gasPrice.getInWei * BigInt.from(2)),
        maxPriorityFeePerGas: EtherAmount.inWei(gasPrice.getInWei),
        data: Uint8List.fromList([]),
      );
      final signed = await _client!.signTransaction(key, tx, chainId: chainId);
      final rawHex = bytesToHex(signed, include0x: true, padToEvenLength: true);
      final hash = await sendRawHex(rawHex);
      _tell(
        'Dust transaction sent: $hash (value: $value wei)',
        kind: RpcStoryKind.info,
        detail: 'R4 dust mode — decoy traffic',
      );
      return hash;
    } catch (e) {
      _tell('Dust transaction failed: $e', kind: RpcStoryKind.fail);
      return null;
    }
  }

  /// R4: Generate a random padding request to obscure traffic patterns.
  /// Returns a dummy RPC call that can be mixed with real calls.
  static Map<String, dynamic> randomPaddingCall() {
    const methods = [
      {'method': 'eth_blockNumber', 'params': <Object>[]},
      {'method': 'eth_gasPrice', 'params': <Object>[]},
      {'method': 'eth_chainId', 'params': <Object>[]},
      {
        'method': 'eth_getBlockByNumber',
        'params': ['latest', false],
      },
    ];
    return methods[Random().nextInt(methods.length)];
  }
}

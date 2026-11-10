import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import 'cold_wallet.dart' hide WalletMode, WalletModeLabel;
import 'cold_wallet_service.dart';
import 'default_tokens.dart';
import 'encrypted_log_store.dart';
import 'models.dart';
import 'portable_backup.dart';
import 'receipt_store.dart';
import 'rpc_service.dart';
import 'spending_policy.dart';
import 'rpc_story.dart';
import 'security.dart';
import 'storage.dart';
import 'vault.dart';
import 'wallet_core.dart';
import 'workers.dart';

/// Central application state. Secrets live only in memory and are cleared by
/// [lock]. Public preferences are persisted through [AppStorage].
class AppState extends ChangeNotifier {
  AppState() {
    rpc.addListener(_onRpcChanged);
  }

  /// Validates that [base64Blob] is a valid vault envelope by checking
  /// the base64-decoded magic bytes. Returns the version string ('BNBVL004' or 'BNBVL003')
  /// on success, throws [StateError] on failure.
  static String _validateVaultMagic(String base64Blob) {
    Uint8List bytes;
    try {
      bytes = base64Decode(base64Blob);
    } on FormatException {
      throw StateError('Not a valid vault file (invalid base64).');
    }
    if (bytes.length < 8) {
      throw StateError('Not a valid vault file (too short).');
    }
    // Portable disaster-recovery backup (password-only, restorable on a new
    // device). It is not a vault envelope, but the same import path accepts it.
    const portableMagic = 'BNBBKP01';
    final portableBytes = utf8.encode(portableMagic);
    var portable = true;
    for (var i = 0; i < portableBytes.length; i++) {
      if (bytes[i] != portableBytes[i]) {
        portable = false;
        break;
      }
    }
    if (portable) return portableMagic;
    const magicPrefix = 'BNBVL';
    final prefixBytes = utf8.encode(magicPrefix);
    // Check that the blob starts with BNBVL prefix (any version)
    var valid = true;
    for (var i = 0; i < prefixBytes.length; i++) {
      if (bytes[i] != prefixBytes[i]) {
        valid = false;
        break;
      }
    }
    if (!valid) {
      throw StateError('Not a valid vault file (missing magic marker BNBVL).');
    }
    // Check for supported versions
    const magicV2 = 'BNBVL004';
    const magicV1 = 'BNBVL003';
    final magicBytesV2 = utf8.encode(magicV2);
    var validV2 = true;
    for (var i = 0; i < magicBytesV2.length; i++) {
      if (bytes[i] != magicBytesV2[i]) {
        validV2 = false;
        break;
      }
    }
    if (validV2) return magicV2;
    final magicBytesV1 = utf8.encode(magicV1);
    var validV1 = true;
    for (var i = 0; i < magicBytesV1.length; i++) {
      if (bytes[i] != magicBytesV1[i]) {
        validV1 = false;
        break;
      }
    }
    if (validV1) return magicV1;
    // Recognized BNBVL prefix but unsupported version - let decryption handle it
    // so the error message is "Unsupported vault version."
    return utf8.decode(bytes.sublist(0, 8));
  }

  final RpcService rpc = RpcService();
  EthPrivateKey? _key;
  String? _mnemonic;
  List<WalletProfile> _profiles = [];
  List<RpcNode> _nodes = [];
  List<TokenInfo> _customTokens = [];
  Set<String> _hiddenTokens = {};
  bool _liteMode = false;
  String? _bscscanKey;
  String? _watchAddress;
  bool _unlocked = false;
  bool _initialised = false;
  bool _usePin = false;
  bool _appLocked = false;

  // Theme and locale (R6)
  int _themeModeIndex = 0; // 0=system, 1=light, 2=dark, 3=amoled
  String _locale = 'en';

  // §10f Wallet mode: 0=hot, 1=cold, 2=online
  int _walletModeIndex = 0;
  ColdPairingData? _coldPairing;

  WalletMode get walletMode {
    switch (_walletModeIndex) {
      case 1:
        return WalletMode.cold;
      case 2:
        return WalletMode.online;
      default:
        return WalletMode.hot;
    }
  }

  bool get coldMode => _walletModeIndex == 1;
  bool get onlineMode => _walletModeIndex == 2;
  bool get hotMode => _walletModeIndex == 0;
  int get walletModeIndex => _walletModeIndex;
  ColdPairingData? get coldPairing => _coldPairing;

  EthPrivateKey? get privateKey => _key;
  String? get mnemonic => _mnemonic;
  bool get unlocked => _unlocked;
  bool get initialised => _initialised;
  bool get usePin => _usePin;
  bool get appLocked => _appLocked;
  bool get liteMode => _liteMode;

  // Theme and locale (R6)
  int get themeModeIndex => _themeModeIndex;
  ThemeMode get themeMode {
    switch (_themeModeIndex) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 3:
        return ThemeMode.dark; // AMOLED uses dark with custom colors
      default:
        return ThemeMode.system;
    }
  }

  bool get isAmoled => _themeModeIndex == 3;

  String get locale => _locale;
  Locale get localeObj => Locale(_locale);

  String? get address => _watchAddress ?? _key?.address.eip55With0x;
  bool get watchOnly => _watchAddress != null;
  List<WalletProfile> get profiles => List.unmodifiable(_profiles);
  List<RpcNode> get nodes => List.unmodifiable(_nodes);
  List<TokenInfo> get customTokens => List.unmodifiable(_customTokens);

  /// Tokens that belong to the network the RPC is currently on.
  List<TokenInfo> get tokensForNetwork => [
    for (final token in _customTokens)
      if (token.network == rpc.network) token,
  ];
  Set<String> get hiddenTokens => Set.unmodifiable(_hiddenTokens);
  String _tokenKey(TokenInfo token) =>
      '${token.network}:${token.address.toLowerCase()}';
  bool isTokenHidden(TokenInfo token) =>
      !token.native && _hiddenTokens.contains(_tokenKey(token));

  /// Hides/unhides a token in every list (wallet + send asset picker). BNB
  /// itself is never hideable: it pays fees.
  Future<void> setTokenHidden(TokenInfo token, bool hidden) async {
    if (token.native) return;
    final key = _tokenKey(token);
    final next = {..._hiddenTokens};
    if (hidden) {
      next.add(key);
    } else {
      next.remove(key);
    }
    _hiddenTokens = next;
    await AppStorage.setHiddenTokens(_hiddenTokens);
    notifyListeners();
  }

  Future<void> setLiteMode(bool value) async {
    _liteMode = value;
    await AppStorage.setLiteMode(value);
    notifyListeners();
  }

  /// Theme mode (R6): 0=system, 1=light, 2=dark, 3=amoled
  Future<void> setThemeMode(int value) async {
    _themeModeIndex = value.clamp(0, 3);
    await AppStorage.setThemeMode(_themeModeIndex);
    notifyListeners();
  }

  /// The app is English-only. Any stored legacy locale is ignored.
  Future<void> setLocale(String value) async {
    _locale = 'en';
    await AppStorage.setLocale('en');
    notifyListeners();
  }

  /// §10f Wallet mode: 0=hot, 1=cold, 2=online.
  ///
  /// Switching into the cold signer hard-disconnects every network client and
  /// keeps it that way until another mode is chosen. Switching into the online
  /// companion wipes keys from memory and opens the paired watch-only address,
  /// so no signing path can ever see a private key there.
  Future<void> setWalletMode(int value) async {
    final next = value.clamp(0, 2);
    final previous = _walletModeIndex;

    if (next == 1) {
      rpc.setOffline(true);
      await rpc.disconnect();
      _watchAddress = null;
      await AppStorage.setWatchAddress(null);
      // A cold signer may keep its unlocked seed for offline signing. If no
      // seed/key is in memory the user must unlock the vault again.
      _unlocked = _key != null || _mnemonic != null;
    } else {
      rpc.setOffline(false);
      if (next == 2) {
        // Online companion: never retain a private key or seed.
        _key = null;
        _mnemonic = null;
        final pairing = _coldPairing;
        if (pairing != null && pairing.addresses.isNotEmpty) {
          _watchAddress = pairing.addresses.first;
          _unlocked = true;
          await AppStorage.setWatchAddress(_watchAddress);
        } else {
          _watchAddress = null;
          _unlocked = false;
          await AppStorage.setWatchAddress(null);
        }
      } else if (previous == 1) {
        // Leaving the cold signer locks it: a hot wallet must be explicitly
        // unlocked again before it can sign or broadcast.
        _key = null;
        _mnemonic = null;
        _unlocked = false;
      }
      if (next == 0 && _watchAddress != null) {
        // Do not carry the companion's watch-only address into hot mode.
        _watchAddress = null;
        _unlocked = false;
        await AppStorage.setWatchAddress(null);
      }
    }

    _walletModeIndex = next;
    await AppStorage.setWalletMode(_walletModeIndex);
    rpc.note(
      'Wallet mode switched to ${walletMode.label}.',
      kind: RpcStoryKind.info,
    );
    notifyListeners();
    if (next != 1) {
      unawaited(rpc.connect().catchError((_) => null));
    }
  }

  /// Persist a pairing exported by the cold device and make its first address
  /// the online companion's watch-only account. Never imports a secret.
  Future<void> adoptColdPairing(ColdPairingData pairing) async {
    await ColdWalletService.instance.savePairing(pairing);
    _coldPairing = pairing;
    if (onlineMode && pairing.addresses.isNotEmpty) {
      await openWatchOnly(pairing.addresses.first);
    }
    notifyListeners();
  }

  Future<void> forgetColdPairing() async {
    await ColdWalletService.instance.clearPairing();
    _coldPairing = null;
    notifyListeners();
  }

  /// Node selection mode (§10d/R7).
  NodeSelectionMode get selectionMode => rpc.selectionMode;

  /// Set node selection mode (§10d/R7).
  Future<void> setSelectionMode(NodeSelectionMode mode) async {
    await rpc.setSelectionMode(mode);
    notifyListeners();
  }

  String? get bscscanKey => _bscscanKey;
  bool get hasVault => _vaultExists;
  bool _vaultExists = false;

  // Session-only vault state. Cleared by lock(), lockForTest(), and erase.
  // The password is never written to disk and never logged.
  String? _vaultSessionPassword;
  List<VaultAccount>? _vaultAccountsCache;
  Set<String> _vaultKnownAddresses = {};

  bool get vaultUnlocked => _vaultAccountsCache != null;

  /// True when [address] is known to be saved in the vault, even if the
  /// vault list is currently locked for this session.
  bool isSavedInVault(String address) =>
      _vaultKnownAddresses.contains(address.toLowerCase());
  List<VaultAccount>? get vaultAccountsCache => _vaultAccountsCache == null
      ? null
      : List.unmodifiable(_vaultAccountsCache!);

  void lockVaultSession() {
    _vaultSessionPassword = null;
    _vaultAccountsCache = null;
    notifyListeners();
  }

  void _onRpcChanged() => notifyListeners();

  /// Test-only crypto substitution. [kDebugMode] is false in release builds,
  /// so these branches are compiled out of shipped binaries — production
  /// always runs the real Argon2id + XChaCha20-Poly1305 cipher on the worker
  /// isolates. Widget tests use this to exercise the full unlock wiring
  /// without paying for (or destabilizing on) the 64 MB KDF.
  @visibleForTesting
  static Future<String> Function(
    String password,
    String plaintext,
    String device,
  )?
  vaultEncryptOverride;
  @visibleForTesting
  static Future<String> Function(String password, String blob, String device)?
  vaultDecryptOverride;

  Future<void> init() async {
    await AppStorage.init();
    // The global AppState (and its RpcService) is constructed before this
    // method runs, so the transport was built while preferences were still
    // unavailable. Rebuild it now so a configured Tor/proxy route applies to
    // the very first request instead of silently sending it direct.
    rpc.rebuildTransport();
    rpc.setNetwork(AppStorage.network);
    rpc.setConfiguredRpc(AppStorage.rpc);
    rpc.setCustomTokens(AppStorage.customTokens);
    _bscscanKey = await AppStorage.getBscscanKey();
    rpc.setBscscanKey(_bscscanKey);
    _profiles = AppStorage.profiles;
    await AppStorage.loadNodeSecrets();
    _nodes = AppStorage.nodes;
    _customTokens = withDefaultTokens(AppStorage.customTokens);
    await AppStorage.setCustomTokens(_customTokens);
    rpc.setCustomTokens(_customTokens);
    _hiddenTokens = AppStorage.hiddenTokens;
    _liteMode = AppStorage.liteMode;
    _themeModeIndex = AppStorage.themeModeIndex;
    _locale = AppStorage.locale;
    _walletModeIndex = AppStorage.walletModeIndex;
    _coldPairing = await ColdWalletService.instance.loadPairing();
    if (_walletModeIndex == 1) {
      rpc.setOffline(true);
    }
    _strictNode = AppStorage.strictNode;
    rpc.setStrictFlag(_strictNode);
    _syncNodePool();
    _pending = _decodePending(AppStorage.getPendingTxsJson());
    _vaults = AppStorage.getVaultEntries();
    _activeVaultId = AppStorage.activeVaultEntry?.id;
    if (_activeVaultId != null) {
      _pending = [
        for (final tx in _pending)
          if (tx.vaultId == null) tx.copyWith(vaultId: _activeVaultId) else tx,
      ];
    }
    _vaultExists = await AppStorage.vaultExists();
    _usePin = await AppSecurity.hasPin();
    _appLocked = _usePin;
    final savedWatch = AppStorage.watchAddress;
    if (savedWatch != null && WalletCore.isValidAddress(savedWatch)) {
      _watchAddress = WalletCore.checksumAddress(savedWatch);
      _unlocked = true;
    } else if (_walletModeIndex == 2 &&
        _coldPairing != null &&
        _coldPairing!.addresses.isNotEmpty) {
      _watchAddress = _coldPairing!.addresses.first;
      _unlocked = true;
      await AppStorage.setWatchAddress(_watchAddress);
    }
    _initialised = true;
    notifyListeners();
    // The cold signer never opens a socket. Other modes connect in the
    // background so the UI can show status without blocking startup.
    if (_walletModeIndex != 1) {
      rpc.connect().catchError((_) => null);
    }
  }

  Future<void> unlock(EthPrivateKey key, {String? mnemonic}) async {
    _key = key;
    _mnemonic = mnemonic;
    _watchAddress = null;
    _unlocked = true;
    await AppStorage.setWatchAddress(null);
    unawaited(
      logEvent(
        category: LogCategory.security,
        level: LogLevel.info,
        message: 'Wallet unlocked on this device.',
        extra: {'simple': 'Wallet unlocked'},
      ).catchError((_) {}),
    );
    notifyListeners();
  }

  /// Which shell tab is showing: 0 Home · 1 Wallet · 2 Send · 3 Inspect ·
  /// 4 Settings. Kept here so a finished flow can hand the user to its
  /// visible result — a completed import must land on a screen that plainly
  /// shows the wallet, not only flash a message.
  int tab = 0;

  void focusTab(int index) {
    if (tab == index) return;
    tab = index;
    notifyListeners();
  }

  /// §2: watch-only account — a public address with NO key material. Balances
  /// and history are readable; signing, vault export and secret reveal are not
  /// available while this profile is open.
  Future<void> openWatchOnly(String address) async {
    if (!WalletCore.isValidAddress(address.trim())) {
      throw ArgumentError('That is not a valid 0x address.');
    }
    final normalized = WalletCore.checksumAddress(address.trim());
    _key = null;
    _mnemonic = null;
    _watchAddress = normalized;
    _unlocked = true;
    await AppStorage.setWatchAddress(normalized);
    unawaited(
      logEvent(
        category: LogCategory.security,
        level: LogLevel.info,
        message: 'Watch-only profile opened; this device holds no key for it.',
        extra: {'simple': 'Watch-only'},
      ).catchError((_) {}),
    );
    notifyListeners();
  }

  Future<void> closeWatchOnly() async {
    if (_watchAddress == null) return;
    _watchAddress = null;
    _unlocked = false;
    await AppStorage.setWatchAddress(null);
    notifyListeners();
  }

  void lock() {
    if (_key != null) {
      // The append captures the key synchronously before the first await, so
      // this line is readable even though the key is dropped right after.
      unawaited(
        logEvent(
          category: LogCategory.security,
          level: LogLevel.info,
          message: 'Wallet locked; keys cleared from memory.',
          extra: {'simple': 'Wallet locked'},
        ).catchError((_) {}),
      );
    }
    _key = null;
    _mnemonic = null;
    _watchAddress = null;
    _unlocked = false;
    _vaultSessionPassword = null;
    _vaultAccountsCache = null;
    _vaultKnownAddresses = {};
    notifyListeners();
  }

  /// Test-fixture reset only.  It clears in-memory secrets without launching
  /// an asynchronous audit write into a temporary directory being removed.
  @visibleForTesting
  void lockForTest() {
    _key = null;
    _mnemonic = null;
    _watchAddress = null;
    _unlocked = false;
    _vaultSessionPassword = null;
    _vaultAccountsCache = null;
    _vaultKnownAddresses = {};
    notifyListeners();
  }

  Future<void> setNetwork(String network) async {
    rpc.setNetwork(network); // notifies right away: UI flips immediately
    await AppStorage.setNetwork(network);
    await AppStorage.setRpc(rpc.configuredRpc);
    notifyListeners();
    try {
      await rpc.connect();
    } catch (_) {
      // connect narrates the exact failure into the story log; do not
      // surface an unhandled crash on top of it.
    }
  }

  Future<void> setRpc(String url) async {
    rpc.setConfiguredRpc(url);
    await AppStorage.setRpc(url);
    notifyListeners();
    try {
      await rpc.connect(allowFallback: false);
    } catch (_) {
      // Narrated in the story log by connect itself.
    }
  }

  /// Nodes that belong to the side of the network we are on right now,
  /// preserving insertion order.
  List<RpcNode> get currentNetworkNodes => [
    for (final node in _nodes)
      if (node.network == rpc.network) node,
  ];

  bool isNodeActive(RpcNode node) => node.url == rpc.configuredRpc;

  // ---------------------------------------------------- strict node mode ---
  bool _strictNode = false;

  /// §10d: "Use only my node". When on, no built-in candidate, no fallback,
  /// no other door is ever contacted — if the chosen node is down, nothing
  /// is sent and the story says so.
  bool get strictNodeMode => _strictNode;

  Future<void> setStrictNodeMode(bool value) async {
    _strictNode = value;
    rpc.setStrictFlag(value);
    await AppStorage.setStrictNode(value);
    rpc.note(
      value
          ? 'Strict node mode is ON: I will ask ONLY the node you picked — no '
                'other door, ever. If it is down, nothing is sent.'
          : 'Strict node mode is off: I may double-check fees and receipts '
                'with other public doors again.',
      kind: RpcStoryKind.info,
    );
    notifyListeners();
  }

  /// The fee and receipt-crosscheck pools must ALWAYS come from the phone
  /// book (§10d "everything uses the node manager"). Enabled doors of the
  /// current side, in book order, ahead of the built-in doors.
  void _syncNodePool() {
    rpc.setNodePool([
      for (final node in _nodes)
        if (node.enabled &&
            node.network == rpc.network &&
            nodeUrlAllowed(node.url))
          node,
    ]);
  }

  /// Switches one door off or on. A disabled door is never asked anything;
  /// switching the ACTIVE door off falls back to the official door, out loud.
  Future<void> setNodeEnabled(int index, bool enabled) async {
    if (index < 0 || index >= _nodes.length) return;
    final node = _nodes[index];
    if (node.enabled == enabled) return;
    _nodes = [..._nodes]
      ..[index] = RpcNode(
        label: node.label,
        url: node.url,
        network: node.network,
        enabled: enabled,
      );
    rpc.note(
      'Door "${node.label}" is now ${enabled ? 'usable' : 'switched OFF — I will not ask it anything'}.',
    );
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    if (!enabled && node.url.toLowerCase() == rpc.configuredRpc.toLowerCase()) {
      await setRpc(BnbNetworks.defaultRpcs[rpc.network]!);
      rpc.note(
        'It was the door I was talking to, so I went back to the official one.',
        kind: RpcStoryKind.info,
      );
    }
    notifyListeners();
  }

  /// Moves one door up/down within ITS side — book order is priority order.
  Future<void> moveNode(int index, int delta) async {
    final target = moveNodeIndex(_nodes, index, delta);
    if (target == index) return;
    final copy = [..._nodes];
    final moved = copy.removeAt(index);
    copy.insert(target, moved);
    _nodes = copy;
    rpc.note(
      'Door "${moved.label}" moved to position ${target + 1} of ${copy.length}.',
    );
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    notifyListeners();
  }

  /// Sets the per-node transport override (§10d, R2). If custom proxy,
  /// also stores proxy host/port/user/pass.
  Future<void> setNodeTransport(
    int index,
    NodeTransport transport, {
    String? proxyHost,
    int? proxyPort,
    String? proxyUser,
    String? proxyPass,
  }) async {
    if (index < 0 || index >= _nodes.length) return;
    final node = _nodes[index];
    if (node.transport == transport &&
        node.proxyHost == proxyHost &&
        node.proxyPort == proxyPort &&
        node.proxyUser == proxyUser &&
        node.proxyPass == proxyPass) {
      return;
    }
    _nodes = [..._nodes]
      ..[index] = RpcNode(
        label: node.label,
        url: node.url,
        network: node.network,
        enabled: node.enabled,
        transport: transport,
        proxyHost: proxyHost,
        proxyPort: proxyPort,
        proxyUser: proxyUser,
        proxyPass: proxyPass,
        // Changing the route must never wipe HTTP auth, custom headers,
        // certificate pins, selection flags or measured latency.
        authType: node.authType,
        authToken: node.authToken,
        authUsername: node.authUsername,
        authPassword: node.authPassword,
        customHeaders: node.customHeaders,
        pinnedSpkiHashes: node.pinnedSpkiHashes,
        useForReads: node.useForReads,
        useForBroadcast: node.useForBroadcast,
        selectionMode: node.selectionMode,
        latencyMs: node.latencyMs,
      );
    rpc.note(
      'Transport for "${node.label}" changed to ${_transportLabelFromEnum(transport)}.',
    );
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    notifyListeners();
  }

  /// Sets node authentication (Bearer/Basic) — R4.
  Future<void> setNodeAuth(
    int index,
    NodeAuthType authType, {
    String? authToken,
    String? authUsername,
    String? authPassword,
  }) async {
    if (index < 0 || index >= _nodes.length) return;
    final node = _nodes[index];
    if (node.authType == authType &&
        node.authToken == authToken &&
        node.authUsername == authUsername &&
        node.authPassword == authPassword) {
      return;
    }
    _nodes = [..._nodes]
      ..[index] = RpcNode(
        label: node.label,
        url: node.url,
        network: node.network,
        enabled: node.enabled,
        transport: node.transport,
        proxyHost: node.proxyHost,
        proxyPort: node.proxyPort,
        proxyUser: node.proxyUser,
        proxyPass: node.proxyPass,
        authType: authType,
        authToken: authToken,
        authUsername: authUsername,
        authPassword: authPassword,
        customHeaders: node.customHeaders,
        pinnedSpkiHashes: node.pinnedSpkiHashes,
        useForReads: node.useForReads,
        useForBroadcast: node.useForBroadcast,
      );
    rpc.note('Auth for "${node.label}" changed to ${authType.name}.');
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    notifyListeners();
  }

  /// Sets certificate pinning (SPKI hashes) — R4.
  Future<void> setNodePinning(int index, List<String> spkiHashes) async {
    if (index < 0 || index >= _nodes.length) return;
    final node = _nodes[index];
    if (listEquals(node.pinnedSpkiHashes, spkiHashes)) return;
    _nodes = [..._nodes]
      ..[index] = RpcNode(
        label: node.label,
        url: node.url,
        network: node.network,
        enabled: node.enabled,
        transport: node.transport,
        proxyHost: node.proxyHost,
        proxyPort: node.proxyPort,
        proxyUser: node.proxyUser,
        proxyPass: node.proxyPass,
        authType: node.authType,
        authToken: node.authToken,
        authUsername: node.authUsername,
        authPassword: node.authPassword,
        customHeaders: node.customHeaders,
        pinnedSpkiHashes: spkiHashes,
        useForReads: node.useForReads,
        useForBroadcast: node.useForBroadcast,
      );
    rpc.note('Certificate pinning updated for "${node.label}".');
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    notifyListeners();
  }

  /// Sets node selection mode and use-for flags — R4/R10d.
  Future<void> setNodeSelection(
    int index, {
    required bool useForReads,
    required bool useForBroadcast,
    required int
    selectionMode, // 0=manual, 1=auto-fastest, 2=round-robin, 3=quorum
  }) async {
    if (index < 0 || index >= _nodes.length) return;
    final node = _nodes[index];
    if (node.useForReads == useForReads &&
        node.useForBroadcast == useForBroadcast) {
      return;
    }
    _nodes = [..._nodes]
      ..[index] = RpcNode(
        label: node.label,
        url: node.url,
        network: node.network,
        enabled: node.enabled,
        transport: node.transport,
        proxyHost: node.proxyHost,
        proxyPort: node.proxyPort,
        proxyUser: node.proxyUser,
        proxyPass: node.proxyPass,
        authType: node.authType,
        authToken: node.authToken,
        authUsername: node.authUsername,
        authPassword: node.authPassword,
        customHeaders: node.customHeaders,
        pinnedSpkiHashes: node.pinnedSpkiHashes,
        useForReads: useForReads,
        useForBroadcast: useForBroadcast,
      );
    rpc.note(
      'Selection flags for "${node.label}" updated (reads: $useForReads, broadcast: $useForBroadcast).',
    );
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    notifyListeners();
  }

  String _transportLabelFromEnum(NodeTransport t) {
    switch (t) {
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

  /// Exports the book as JSON. Nothing in the book is secret — names and
  /// public addresses only — so the default export is safe to share.
  String exportNodesJson() =>
      jsonEncode([for (final n in _nodes) n.toPublicJson()]);

  /// Imports a node list (JSON array of {label,url,network,enabled}). Any
  /// unusable address refuses the WHOLE import (fail closed), duplicates are
  /// skipped, and the import is narrated. Returns how many doors were added.
  Future<int> importNodes(String rawJson) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw StateError('That text is not a JSON node list.');
    }
    if (decoded is! List) {
      throw StateError('That text is not a JSON node list.');
    }
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final node = RpcNode.fromJson(entry);
      if (node.label.isEmpty) {
        throw StateError(
          'One imported door has no name — fix the file and try again.',
        );
      }
      if (!nodeUrlAllowed(node.url)) {
        throw StateError(
          'Door "${node.label}" has an unusable address: HTTPS everywhere — '
          'HTTP only for localhost/LAN or a .onion door over Tor.',
        );
      }
    }
    var added = 0;
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final node = RpcNode.fromJson(entry);
      if (_nodes.any((n) => n.url.toLowerCase() == node.url.toLowerCase())) {
        continue;
      }
      _nodes = [..._nodes, node];
      added++;
    }
    if (added > 0) {
      rpc.note('$added imported door(s) joined the phone book.');
      await AppStorage.setNodes(_nodes);
      _syncNodePool();
      notifyListeners();
    }
    return added;
  }

  /// The one-time "what a node can see" warning is remembered per URL.
  bool isNodeWarned(String url) => AppStorage.nodeWarnedUrls.any(
    (u) => u.toLowerCase() == url.toLowerCase(),
  );

  Future<void> markNodeWarned(String url) async {
    final kept = AppStorage.nodeWarnedUrls;
    await AppStorage.setNodeWarnedUrls([
      for (final u in kept)
        if (u.toLowerCase() != url.toLowerCase()) u,
      url,
    ]);
  }

  Future<void> addNode(String label, String url, {String? network}) async {
    final node = RpcNode(
      label: label,
      url: url,
      network: network ?? rpc.network,
    );
    if (_nodes.any((n) => n.url.toLowerCase() == node.url.toLowerCase())) {
      throw StateError('That node address is already saved.');
    }
    _nodes = [..._nodes, node];
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    rpc.note(
      'Node "${node.label}" saved to my little phone book (${node.network}).',
    );
    notifyListeners();
  }

  Future<void> editNode(
    int index,
    String label,
    String url, {
    String? network,
  }) async {
    if (index < 0 || index >= _nodes.length) return;
    final old = _nodes[index];
    final edited = RpcNode(
      label: label.trim(),
      url: url.trim(),
      network: network ?? old.network,
    );
    if (_nodes.any(
      (n) => n != old && n.url.toLowerCase() == edited.url.toLowerCase(),
    )) {
      throw StateError('That node address is already saved.');
    }
    _nodes = [..._nodes]..[index] = edited;
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    rpc.note('Node "${old.label}" updated to "${edited.label}".');
    notifyListeners();
  }

  /// Points the whole wallet at this saved node (terminal-style "select").
  /// The switch is narrated and verified by chain id like any other target.
  Future<void> activateNode(RpcNode node) async {
    if (!nodeUrlAllowed(node.url)) {
      throw StateError(
        'HTTPS everywhere — HTTP is only ever allowed for localhost/LAN '
        'doors or a .onion address over Tor, and this address is neither.',
      );
    }
    rpc.note(
      'Everyone I will talk to is now "${node.label}" (${node.network}).',
      kind: RpcStoryKind.wait,
    );
    await setRpc(node.url);
  }

  Future<void> deleteNode(int index) async {
    if (index < 0 || index >= _nodes.length) return;
    final gone = _nodes[index];
    _nodes = [..._nodes]..removeAt(index);
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    rpc.note('Node "${gone.label}" was removed from the phone book.');
    final wasActive = gone.url == rpc.configuredRpc;
    if (wasActive) {
      await setRpc(BnbNetworks.defaultRpcs[rpc.network]!);
      rpc.note(
        'It was the node I was talking to, so I went back to the official one.',
        kind: RpcStoryKind.info,
      );
    }
    notifyListeners();
  }

  /// Wipes the saved phone book back to the official public nodes,
  /// labelled the way the terminal version labels them.
  Future<void> resetNodesToDefaults() async {
    const official = <String, List<String>>{
      'mainnet': [
        'BNB Chain official',
        'BNB Chain public backup',
        'Nariox public',
        'PublicNode mainnet',
        '1RPC public',
        'Blast public',
        '48.club public',
      ],
      'testnet': ['BNB Chain official testnet', 'PublicNode testnet'],
    };
    _nodes = [
      for (final entry in BnbNetworks.defaultRpcs.entries)
        RpcNode(
          label: official[entry.key]!.first,
          url: entry.value,
          network: entry.key,
        ),
      ...[
        for (var i = 1; i < BnbNetworks.mainnetFallbacks.length; i++)
          RpcNode(
            label: official['mainnet']![i],
            url: BnbNetworks.mainnetFallbacks[i],
            network: 'mainnet',
          ),
        for (var i = 1; i < BnbNetworks.testnetFallbacks.length; i++)
          RpcNode(
            label: official['testnet']![i],
            url: BnbNetworks.testnetFallbacks[i],
            network: 'testnet',
          ),
      ],
    ];
    await AppStorage.setNodes(_nodes);
    _syncNodePool();
    rpc.note('Node list reset to the official public list.');
    notifyListeners();
  }

  Future<void> addToken(TokenInfo token) async {
    if (_customTokens.any(
      (t) => t.address.toLowerCase() == token.address.toLowerCase(),
    )) {
      return;
    }
    _customTokens = [..._customTokens, token];
    await AppStorage.setCustomTokens(_customTokens);
    rpc.setCustomTokens(_customTokens);
    notifyListeners();
  }

  Future<void> removeToken(int index) async {
    if (index < 0 || index >= _customTokens.length) return;
    _customTokens = [..._customTokens]..removeAt(index);
    await AppStorage.setCustomTokens(_customTokens);
    rpc.setCustomTokens(_customTokens);
    notifyListeners();
  }

  Future<void> addProfile(WalletProfile profile) async {
    if (_profiles.any(
      (p) => p.address.toLowerCase() == profile.address.toLowerCase(),
    )) {
      return;
    }
    _profiles = [..._profiles, profile];
    await AppStorage.setProfiles(_profiles);
    notifyListeners();
  }

  Future<void> renameProfile(int index, String label) async {
    if (index < 0 || index >= _profiles.length) return;
    final old = _profiles[index];
    _profiles = [..._profiles]
      ..[index] = WalletProfile(
        label: label,
        address: old.address,
        source: old.source,
        createdAt: old.createdAt,
      );
    await AppStorage.setProfiles(_profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(int index) async {
    if (index < 0 || index >= _profiles.length) return;
    _profiles = [..._profiles]..removeAt(index);
    await AppStorage.setProfiles(_profiles);
    notifyListeners();
  }

  Future<void> setBscscanKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      await AppStorage.clearBscscanKey();
      _bscscanKey = null;
    } else {
      await AppStorage.setBscscanKey(key.trim());
      _bscscanKey = key.trim();
    }
    rpc.setBscscanKey(_bscscanKey);
    notifyListeners();
  }

  Future<void> setUsePin(bool value) async {
    _usePin = value;
    if (!value) {
      await AppSecurity.clearPin();
      _appLocked = false;
    } else {
      _appLocked = true;
    }
    unawaited(
      logEvent(
        category: LogCategory.security,
        level: LogLevel.info,
        message: value ? 'App lock enabled.' : 'App lock disabled.',
        extra: {'simple': value ? 'Lock turned on' : 'Lock turned off'},
      ).catchError((_) {}),
    );
    notifyListeners();
  }

  void lockApp() {
    if (!_usePin) return;
    _appLocked = true;
    notifyListeners();
  }

  void unlockApp() {
    _appLocked = false;
    notifyListeners();
  }

  // ---- encrypted local vault ----

  Future<List<VaultAccount>> loadVaultAccounts(String password) async {
    final list = await _readVaultJson(password);
    return _accountsFromJson(list);
  }

  /// Unlocks the vault for this session and caches the account list so the
  /// wallet manager can show, switch, rename, and remove accounts without
  /// asking for the same password on every rebuild.
  Future<List<VaultAccount>> unlockVaultAccounts(String password) async {
    final accounts = await loadVaultAccounts(password);
    _vaultSessionPassword = password;
    _vaultAccountsCache = accounts;
    _vaultKnownAddresses = {
      for (final account in accounts) account.address.toLowerCase(),
    };
    notifyListeners();
    return accounts;
  }

  List<VaultAccount> _accountsFromJson(List<Map<String, dynamic>>? list) {
    if (list == null) return [];
    final addresses = <String>{};
    return [
      for (final item in list)
        () {
          final label = '${item['label'] ?? ''}'.trim();
          final storedAddress = '${item['address'] ?? ''}';
          final key = WalletCore.privateKeyFromVaultHex(
            '${item['privateKeyHex'] ?? ''}',
          );
          final address = key.address.eip55With0x;
          if (label.isEmpty || !WalletCore.isValidAddress(storedAddress)) {
            throw const FormatException(
              'Vault contains an invalid account record.',
            );
          }
          if (address.toLowerCase() != storedAddress.toLowerCase()) {
            throw const FormatException(
              'Vault account address does not match its private key.',
            );
          }
          if (!addresses.add(address.toLowerCase())) {
            throw const FormatException('Vault contains duplicate accounts.');
          }
          return VaultAccount(
            label: label,
            address: address,
            keystoreJson: WalletCore.privateKeyHex(key),
            mnemonic: item['mnemonic']?.toString(),
            savedAt: item['savedAt']?.toString(),
          );
        }(),
    ];
  }

  /// Returns [tokens] plus any missing built-in BSC defaults.
  List<TokenInfo> withDefaultTokens(List<TokenInfo> tokens) {
    final result = [...tokens];
    for (final token in DefaultTokens.bsc) {
      final exists = result.any(
        (item) =>
            item.address.toLowerCase() == token.address.toLowerCase() &&
            item.network == token.network,
      );
      if (!exists) result.add(token);
    }
    return result;
  }

  Future<void> saveVaultAccount(
    String password, {
    required String label,
    required EthPrivateKey key,
    String? mnemonic,
  }) async {
    await withVaultOperationLock(() async {
      final originalBlob = await AppStorage.readVault();
      final existing = await _readVaultJson(password);
      final list = existing == null
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(existing);
      final normalizedLabel = label.trim();
      if (normalizedLabel.isEmpty || normalizedLabel.length > 100) {
        throw ArgumentError(
          'Vault account label must contain 1 to 100 characters.',
        );
      }
      final address = key.address.eip55With0x;
      list.removeWhere(
        (item) => '${item['address']}'.toLowerCase() == address.toLowerCase(),
      );
      list.add({
        'label': normalizedLabel,
        'address': address,
        'privateKeyHex': WalletCore.normalizePrivateKeyHex(
          bytesToHex(key.privateKey, include0x: true),
        ),
        'mnemonic': ?mnemonic,
        'savedAt': DateTime.now().toIso8601String(),
      });
      final blob = await _runVaultEncrypt(
        password,
        jsonEncode(list),
        await AppStorage.getOrGenerateDeviceSecret(),
      );
      await AppStorage.writeVaultAtomic(blob);
      // Never report "saved" until the written envelope decrypts and contains
      // the account we just added. This catches a device-key or encoding
      // mismatch at save time instead of at the next unlock.
      try {
        final verify = await _readVaultJson(password);
        final present = verify?.any(
          (item) => '${item['address']}'.toLowerCase() == address.toLowerCase(),
        );
        if (present != true) {
          throw StateError('Vault save could not be verified.');
        }
      } catch (error) {
        try {
          if (originalBlob != null) {
            await AppStorage.writeVaultAtomic(originalBlob);
          } else {
            await AppStorage.deleteVault();
          }
        } catch (_) {
          // Keep the original verification error; the caller must not report
          // success either way.
        }
        rethrow;
      }
      _vaultExists = true;
      _vaultSessionPassword = password;
      _vaultAccountsCache = _accountsFromJson(
        List<Map<String, dynamic>>.from(list),
      );
      _vaultKnownAddresses = {..._vaultKnownAddresses, address.toLowerCase()};
      notifyListeners();
    });
  }

  Future<void> deleteVaultAccount(String password, String address) async {
    await withVaultOperationLock(() async {
      final existing = await _readVaultJson(password);
      if (existing == null) return;
      final list = List<Map<String, dynamic>>.from(existing)
        ..removeWhere(
          (item) => '${item['address']}'.toLowerCase() == address.toLowerCase(),
        );
      final blob = await _runVaultEncrypt(
        password,
        jsonEncode(list),
        await AppStorage.getOrGenerateDeviceSecret(),
      );
      await AppStorage.writeVaultAtomic(blob);
      _vaultAccountsCache = _accountsFromJson(
        List<Map<String, dynamic>>.from(list),
      );
      _vaultKnownAddresses.remove(address.toLowerCase());
      notifyListeners();
    });
  }

  /// Renames a vault account at [index] to [newLabel]. Requires the vault password.
  Future<void> renameVaultAccount(
    String password,
    int index,
    String newLabel,
  ) async {
    await withVaultOperationLock(() async {
      final existing = await _readVaultJson(password);
      if (existing == null || index < 0 || index >= existing.length) {
        throw StateError('Vault account not found.');
      }
      final normalizedLabel = newLabel.trim();
      if (normalizedLabel.isEmpty || normalizedLabel.length > 100) {
        throw ArgumentError(
          'Vault account label must contain 1 to 100 characters.',
        );
      }
      // Mutate the decrypted record itself rather than rebuilding it from the
      // display model. This preserves mnemonic and future schema fields.
      final updated = List<Map<String, dynamic>>.from(existing);
      updated[index] = Map<String, dynamic>.from(updated[index])
        ..['label'] = normalizedLabel;
      final blob = await _runVaultEncrypt(
        password,
        jsonEncode(updated),
        await AppStorage.getOrGenerateDeviceSecret(),
      );
      await AppStorage.writeVaultAtomic(blob);
      _vaultAccountsCache = _accountsFromJson(updated);
      notifyListeners();
    });
  }

  VaultAccount vaultAccountAt(int index) {
    final cached = _vaultAccountsCache;
    if (cached == null) {
      throw StateError('Unlock the vault first.');
    }
    if (index < 0 || index >= cached.length) {
      throw StateError('Vault account not found.');
    }
    return cached[index];
  }

  Future<void> renameVaultAccountWithSession(int index, String newLabel) {
    final password = _vaultSessionPassword;
    if (password == null) {
      throw StateError('Unlock the vault first.');
    }
    return renameVaultAccount(password, index, newLabel);
  }

  Future<void> saveVaultAccountWithSession({
    required String label,
    required EthPrivateKey key,
    String? mnemonic,
  }) {
    final password = _vaultSessionPassword;
    if (password == null) {
      throw StateError('Unlock the vault first.');
    }
    return saveVaultAccount(
      password,
      label: label,
      key: key,
      mnemonic: mnemonic,
    );
  }

  Future<VaultAccount> unlockVaultAccount(String password, int index) async {
    final cached = _vaultAccountsCache;
    final accounts = cached != null && _vaultSessionPassword == password
        ? cached
        : await loadVaultAccounts(password);
    if (index < 0 || index >= accounts.length) {
      throw StateError('Vault account not found.');
    }
    return accounts[index];
  }

  Future<List<Map<String, dynamic>>?> _readVaultJson(String password) async {
    final blob = await AppStorage.readVault();
    if (blob == null) return null;
    final json = await _runVaultDecrypt(
      password,
      blob,
      await AppStorage.getOrGenerateDeviceSecret(),
    );
    return List<Map<String, dynamic>>.from(jsonDecode(json) as List);
  }

  /// Told once per session, then never repeated: where the device key lives
  /// right now, in plain words. Honest about the keyring being off the hot
  /// path on desktops after the freeze reports.
  void _noteDeviceHome() {
    if (!AppStorage.lastDeviceSecretFromDrawer) return;
    if (_drawerNoteShown) return;
    _drawerNoteShown = true;
    rpc.note(
      'On this computer I keep the second key of your vault in my own '
      'locked drawer (owner-only file, bound to this machine). The desktop '
      'keyring is deliberately off the hot path — its calls froze weak '
      'machines. Your vault stays inert on any other computer without '
      'this device.',
      kind: RpcStoryKind.info,
    );
  }

  bool _drawerNoteShown = false;

  /// The 64 MiB Argon2id work runs on a worker isolate so the window keeps
  /// answering the desktop while it happens (the Ubuntu "Force Quit / Wait"
  /// freeze the taste test caught). Narration keeps multi-second stretches
  /// looking like work — not like a hang.
  Future<String> _runVaultEncrypt(
    String password,
    String plaintext,
    String device,
  ) async {
    if (kDebugMode && vaultEncryptOverride != null) {
      return vaultEncryptOverride!(password, plaintext, device);
    }
    _noteDeviceHome();
    rpc.note(
      'I stretch 64 MB of memory into armor for your vault — one moment…',
      kind: RpcStoryKind.wait,
    );
    final watch = Stopwatch()..start();
    final blob = await compute(vaultEncryptJob, <String>[
      password,
      plaintext,
      device,
    ]);
    watch.stop();
    rpc.note(
      'Vault locked in ${watch.elapsedMilliseconds} ms — the same armor as before, '
      'stretched on a helper worker so this window never freezes.',
      kind: RpcStoryKind.ok,
    );
    return blob;
  }

  Future<String> _runVaultDecrypt(
    String password,
    String blob,
    String device,
  ) async {
    if (kDebugMode && vaultDecryptOverride != null) {
      return vaultDecryptOverride!(password, blob, device);
    }
    _noteDeviceHome();
    rpc.note(
      'Opening the armor: stretching 64 MB of memory — one moment…',
      kind: RpcStoryKind.wait,
    );
    final watch = Stopwatch()..start();
    final json = await compute(vaultDecryptJob, <String>[
      password,
      blob,
      device,
    ]);
    watch.stop();
    rpc.note(
      'Vault opened in ${watch.elapsedMilliseconds} ms. Keys stay in this device only.',
      kind: RpcStoryKind.ok,
    );
    return json;
  }

  // ---- local receipts (encrypted) + pending transactions ----

  List<PendingTx> _pending = [];

  List<VaultEntry> _vaults = [];
  String? _activeVaultId;

  /// Registered vaults, newest last.
  List<VaultEntry> get vaults => List.unmodifiable(_vaults);
  String? get activeVaultId => _activeVaultId;
  String get activeVaultLabel {
    for (final entry in _vaults) {
      if (entry.id == _activeVaultId) return entry.label;
    }
    return _vaults.isEmpty ? 'Main' : _vaults.first.label;
  }

  /// Outgoing transactions this device saw broadcast and not yet resolved.
  /// Public chain facts only — no keys, no secrets. Scoped to the active vault.
  List<PendingTx> get pendingTxs => List.unmodifiable(
    _pending.where((t) => t.vaultId == null || t.vaultId == _activeVaultId),
  );

  static List<PendingTx> _decodePending(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final rows = jsonDecode(json) as List;
      return [
        for (final row in rows)
          if (row is Map<String, dynamic>) PendingTx.fromJson(row),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> addPendingTx(PendingTx tx) async {
    final row = tx.vaultId == null ? tx.copyWith(vaultId: _activeVaultId) : tx;
    _pending = [row, ..._pending.where((t) => t.hash != row.hash)];
    await _persistPending();
  }

  /// True when a previous signed/broadcast transaction for [from] never got a
  /// definitive answer. New sends are blocked until it is checked, because
  /// retrying blindly can sign a second payment with the next nonce.
  bool hasUnresolvedBroadcast(String from) => _pending.any(
    (t) =>
        t.from.toLowerCase() == from.toLowerCase() &&
        (t.vaultId == null || t.vaultId == _activeVaultId) &&
        (t.status == 'unknown' || t.status == 'signed'),
  );

  /// Re-checks an uncertain broadcast against the active node.
  /// Returns true when the transaction is confirmed (the row is removed).
  Future<bool> checkPendingTx(String hash) async {
    PendingTx? row;
    for (final tx in _pending) {
      if (tx.hash == hash) {
        row = tx;
        break;
      }
    }
    if (row == null) return true;
    try {
      final receipt = await rpc.receipt(hash);
      if (receipt != null) {
        await removePendingTx(hash);
        return true;
      }
    } catch (_) {
      // A network failure is not evidence that the transaction failed.
    }
    return false;
  }

  Future<void> updatePendingTx(
    String hash,
    PendingTx Function(PendingTx) change,
  ) async {
    if (!_pending.any((t) => t.hash == hash)) return;
    _pending = [
      for (final t in _pending)
        if (t.hash == hash) change(t) else t,
    ];
    await _persistPending();
  }

  Future<void> removePendingTx(String hash) async {
    final before = _pending.length;
    _pending = [
      for (final t in _pending)
        if (t.hash != hash) t,
    ];
    if (_pending.length != before) await _persistPending();
  }

  Future<void> _persistPending() async {
    await AppStorage.setPendingTxsJson(
      jsonEncode([for (final t in _pending) t.toJson()]),
    );
    notifyListeners();
  }

  /// The locally kept receipts, newest first. Empty when the wallet is
  /// locked or when the file cannot be opened with this wallet's key.
  Future<List<LocalReceipt>> loadLocalReceipts() async {
    final key = _key;
    if (key == null) return [];
    try {
      final encoded = await AppStorage.readReceipts();
      if (encoded == null) return [];
      final storeKey = await ReceiptStore.deriveKey(
        key.privateKey,
        await AppStorage.getOrGenerateDeviceSecret(),
      );
      return await ReceiptStore.decode(storeKey, encoded) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> addLocalReceipt(LocalReceipt receipt) async {
    final key = _key;
    if (key == null) return;
    final existing = await loadLocalReceipts();
    final list = [receipt, ...existing.where((r) => r.hash != receipt.hash)];
    await _saveReceipts(key, list);
  }

  Future<void> updateLocalReceipt(
    String hash,
    LocalReceipt Function(LocalReceipt) change,
  ) async {
    final key = _key;
    if (key == null) return;
    final existing = await loadLocalReceipts();
    if (!existing.any((r) => r.hash == hash)) return;
    final list = [
      for (final r in existing)
        if (r.hash == hash) change(r) else r,
    ];
    await _saveReceipts(key, list);
  }

  Future<void> _saveReceipts(EthPrivateKey key, List<LocalReceipt> list) async {
    try {
      final storeKey = await ReceiptStore.deriveKey(
        key.privateKey,
        await AppStorage.getOrGenerateDeviceSecret(),
      );
      await AppStorage.writeReceiptsAtomic(
        await ReceiptStore.encode(storeKey, list),
      );
      notifyListeners();
    } catch (_) {
      // Best effort: storing a receipt must never break a finished send.
      // The chain itself remains the source of truth.
    }
  }

  // ---- auto lock + full erase ----

  int get autoLockSeconds => AppStorage.autoLockSeconds;

  Future<void> setAutoLockSeconds(int seconds) async {
    await AppStorage.setAutoLockSeconds(seconds);
    notifyListeners();
  }

  int get wipeAfterFailures => AppStorage.wipeAfterFailures;
  Future<void> setWipeAfterFailures(int failures) async {
    await AppStorage.setWipeAfterFailures(failures.clamp(0, 50));
    notifyListeners();
  }

  bool get showUsd => AppStorage.showUsd;
  Future<void> setShowUsd(bool value) async {
    await AppStorage.setShowUsd(value);
    notifyListeners();
  }

  Future<void> setTorEnabled(bool value) async {
    if (value) {
      // Tor and a custom proxy are mutually exclusive. Keeping both selected
      // would make the effective route depend on an internal priority order.
      await AppStorage.clearProxy();
    }
    await AppStorage.setTorEnabled(value);
    await rpc.privacyChanged();
    notifyListeners();
  }

  bool get torEnabled => AppStorage.torEnabled;
  String get torHost => AppStorage.torHost;
  int get torPort => AppStorage.torPort;
  SpendingPolicy get spendingPolicy => SpendingPolicy(
    frozen: AppStorage.spendingFrozen,
    maxPerTxWei: AppStorage.spendingMaxPerTxWei,
    allowlist: AppStorage.spendingAllowlist.toSet(),
  );

  Future<void> setSpendingFrozen(bool value) async {
    await AppStorage.setSpendingFrozen(value);
    notifyListeners();
  }

  Future<void> setSpendingMaxPerTxWei(BigInt value) async {
    await AppStorage.setSpendingMaxPerTxWei(value);
    notifyListeners();
  }

  Future<void> setSpendingAllowlist(List<String> values) async {
    await AppStorage.setSpendingAllowlist(values);
    notifyListeners();
  }

  GlobalProxyConfig get torUpstream => AppStorage.torUpstream;
  int get torChainDepth => AppStorage.torChainDepth;

  Future<void> setTorUpstream(GlobalProxyConfig config) async {
    await AppStorage.setTorUpstream(config);
    await rpc.privacyChanged();
    notifyListeners();
  }

  Future<void> setTorChainDepth(int value) async {
    await AppStorage.setTorChainDepth(value);
    notifyListeners();
  }

  GlobalProxyConfig get globalProxy => AppStorage.globalProxy;

  bool get proxyEnabled => AppStorage.globalProxy.enabled;

  /// Saves and activates a custom proxy. Selecting a usable proxy turns Tor
  /// off, so exactly one privacy route is active at a time.
  Future<void> setGlobalProxy(GlobalProxyConfig config) async {
    if (config.type != ProxyType.none && !config.enabled) {
      throw ArgumentError('Proxy host and port are required.');
    }
    if (config.type != ProxyType.none) {
      await AppStorage.setTorEnabled(false);
    }
    await AppStorage.setGlobalProxy(config);
    await rpc.privacyChanged();
    notifyListeners();
  }

  Future<void> disableProxy() =>
      setGlobalProxy(const GlobalProxyConfig.disabled());

  Future<void> setTorHostPort(String host, int port) async {
    await AppStorage.setTorHost(host.trim());
    await AppStorage.setTorPort(port);
    rpc.privacyChanged();
    notifyListeners();
  }

  /// Move the encrypted vault to a custom path.
  ///
  /// Reads the vault with [password], decrypts it, and writes it to [newPath]
  /// using atomic write. The new path becomes the active vault location.
  ///
  /// Security guarantees:
  /// - Verifies password against active vault
  /// - Uses atomic write with secure temporary file
  /// - Rejects symlink destinations
  /// - Prevents concurrent vault operations
  /// - Verifies written content after move
  Future<void> moveVault(String password, String newPath) async {
    if (!hasVault) throw StateError('No vault exists to move.');
    if (newPath.trim().isEmpty) {
      throw ArgumentError('New path cannot be empty.');
    }

    await withVaultOperationLock(() async {
      final json = await _readVaultJson(password);
      if (json == null) throw StateError('Vault not found or wrong password.');

      final device = await AppStorage.getOrGenerateDeviceSecret();
      final blob = await _runVaultEncrypt(password, jsonEncode(json), device);

      // Write to new location atomically using secure atomic write
      final newFile = File(newPath);
      if (await isSymlink(newPath)) {
        throw StateError('Destination is a symbolic link, refusing to write.');
      }
      await AppStorage.ensureParentDir(newFile);
      final writeResult = await atomicWrite(newFile, blob);
      if (writeResult.state != AtomicWriteState.committedVerified) {
        throw StateError(
          'Vault move was not verified; active vault path was not changed: '
          '${writeResult.error}',
        );
      }

      // Update stored path and verify
      final verifyBlob = await readRegularFileNoFollow(
        newFile.path,
        maxBytes: 5 * 1024 * 1024,
        missingMessage: 'Moved vault disappeared before verification.',
        symlinkMessage:
            'Moved vault became a symbolic link before verification.',
      );
      if (verifyBlob == null || verifyBlob != blob) {
        throw StateError('Vault move verification failed.');
      }
      await AppStorage.setVaultPath(newPath);
      await AppStorage.updateActiveVaultPath(newPath);
      rpc.note('Vault moved to $newPath.', kind: RpcStoryKind.info);
      notifyListeners();
    });
  }

  /// Export the vault to a backup file at [exportPath].
  ///
  /// The exported file is a standard vault envelope (BNBVL004) that can be
  /// restored on this device or another with the same password + device secret.
  ///
  /// Security guarantees:
  /// - Verifies the supplied password against the active vault before export
  /// - Rejects incorrect passwords
  /// - Validates the vault envelope format (magic, version, structure)
  /// - Uses atomic output creation with restrictive permissions (0600)
  /// - Refuses to overwrite an existing file without explicit confirmation
  /// - Reads back and validates the exported file before reporting success
  /// - Never logs passwords, vault contents, seeds, or private keys
  /// - Prevents concurrent vault operations
  /// - Rejects symlink destinations
  /// Returns the validated encrypted vault blob for an Android SAF export.
  ///
  /// The password is verified and the envelope format is checked before the
  /// blob leaves the app. Nothing is written here.
  Future<String> exportVaultBlob(String password) async {
    if (!hasVault) throw StateError('No vault exists to export.');
    if (password.isEmpty) throw ArgumentError('Password cannot be empty.');
    return withVaultOperationLock(() async {
      final json = await _readVaultJson(password);
      if (json == null) {
        throw StateError('Wrong vault password. Export aborted.');
      }
      final blob = await PortableBackup.encrypt(
        password: password,
        accountsJson: jsonEncode(json),
        label: activeVaultLabel,
      );
      if (blob.length > 5 * 1024 * 1024) {
        throw StateError('Backup is too large. Export aborted.');
      }
      return blob;
    });
  }

  Future<void> exportVault(String password, String exportPath) async {
    if (!hasVault) throw StateError('No vault exists to export.');
    if (password.isEmpty) throw ArgumentError('Password cannot be empty.');

    // Acquire lock to prevent concurrent vault operations
    await withVaultOperationLock(() async {
      // Verify the password against the active vault BEFORE exporting.
      // This prevents exporting with a wrong password and ensures the user
      // knows the correct password for the exported vault.
      final json = await _readVaultJson(password);
      if (json == null) {
        throw StateError('Wrong vault password. Export aborted.');
      }

      // The disaster-recovery backup is deliberately portable: it depends on
      // the password only, so it can be restored on a new machine without the
      // old device secret.
      final blob = await PortableBackup.encrypt(
        password: password,
        accountsJson: jsonEncode(json),
        label: activeVaultLabel,
      );
      if (blob.length > 5 * 1024 * 1024) {
        throw StateError('Backup is too large. Export aborted.');
      }

      final exportFile = File(exportPath);

      // Refuse symlink destinations. The no-follow check is independent of
      // exists(), so a BROKEN symlink (over which exists() answers false) is
      // refused exactly like a valid one.
      if (await isSymlink(exportPath)) {
        throw StateError('Destination is a symbolic link, refusing to write.');
      }

      // Refuse to overwrite an existing backup without explicit user action.
      if (await exportFile.exists()) {
        throw StateError(
          'Export file already exists. Remove it first or choose a different path.',
        );
      }

      await AppStorage.ensureParentDir(exportFile);

      // Atomic write with restrictive permissions using secure temp file
      final writeResult = await atomicWrite(exportFile, blob);
      if (writeResult.state != AtomicWriteState.committedVerified) {
        throw StateError('Export was not verified: ${writeResult.error}');
      }

      // Read back and validate the exported file
      final verifyBlob = await readRegularFileNoFollow(
        exportFile.path,
        maxBytes: 5 * 1024 * 1024,
        missingMessage: 'Export disappeared before verification.',
        symlinkMessage: 'Export became a symbolic link before verification.',
      );
      if (verifyBlob == null || verifyBlob != blob) {
        throw StateError('Export verification failed: file content mismatch.');
      }

      // Validate the exported file can be parsed as a valid vault envelope
      _validateVaultMagic(verifyBlob);
      if (verifyBlob.length > 5 * 1024 * 1024) {
        throw StateError('Exported file validation failed.');
      }

      rpc.note('Vault exported to $exportPath.', kind: RpcStoryKind.info);
    });
  }

  /// Import a vault from a backup file at [importPath].
  ///
  /// Validates the envelope format and verifies the password against THE IMPORTED
  /// BACKUP (not the current vault). Replaces the active vault only after full
  /// validation and decryption succeeds.
  ///
  /// Security guarantees:
  /// - Reads and validates the SELECTED BACKUP file, not the current vault
  /// - Enforces regular-file checks, sensible size limits, recognized format/version
  /// - Verifies the supplied password by decrypting THE IMPORTED BACKUP
  /// - Verifies all required cryptographic authentication tags and device-key dependencies
  /// - Rejects truncated, malformed, corrupted, unsupported-version, wrong-password, and tampered files
  /// - Does NOT replace the active vault until validation and decryption succeed completely
  /// - Preserves the original vault if any step fails
  /// - Uses safe atomic replacement with restrictive permissions
  /// - Requires explicit user confirmation before replacing an existing vault
  /// - Reports success only after the new vault has been read back and validated
  /// - Prevents concurrent vault operations
  /// - Rejects symlink sources and destinations
  /// - Uses secure temporary files with restrictive permissions
  Future<void> importVault(
    String importPath, {
    String? password,
    bool verifyPassword = true, // Always verify by default for security
    required bool confirmReplace, // Explicit confirmation required
  }) async {
    if (password == null || password.isEmpty) {
      throw ArgumentError('Password is required to verify the backup.');
    }

    // Acquire lock to prevent concurrent vault operations
    await withVaultOperationLock(() async {
      // No-follow classification first: a symlink entry (valid or broken) at
      // the import path is refused BEFORE any read. The descriptor-pinned
      // re-refusal and O_NOFOLLOW open inside readRegularFileNoFollow close
      // the validate→use window that path-based prechecks cannot.
      if (await isSymlink(importPath)) {
        throw StateError('Import path is a symbolic link, refusing to read.');
      }

      // Pinned read (Linux): missing -> null; symlink/directory/special/
      // unreadable fail closed with honest StateErrors.
      final blob = await readRegularFileNoFollow(
        importPath,
        maxBytes: 5 * 1024 * 1024,
        tooLargeMessage: 'Import file is too large (max 5 MB).',
      );
      if (blob == null) {
        throw StateError('Import file not found: $importPath');
      }
      if (blob.isEmpty) throw StateError('Import file is empty.');

      // Validate the envelope format and version by checking base64-decoded magic bytes.
      final magic = _validateVaultMagic(blob);
      final bool portable = magic == 'BNBBKP01';
      String? portableAccountsJson;

      // Validate the backup can be decrypted with the provided password.
      // A portable backup needs only the password; a vault envelope also needs
      // this device's secret.
      try {
        final String decryptedJson;
        if (portable) {
          final data = await PortableBackup.decrypt(
            encoded: blob,
            password: password,
          );
          portableAccountsJson = data.accountsJson;
          decryptedJson = data.accountsJson;
        } else {
          final device = await AppStorage.getOrGenerateDeviceSecret();
          decryptedJson = await _decryptVaultBlob(blob, password, device);
        }
        final decoded = jsonDecode(decryptedJson) as List;
        if (decoded.isEmpty) {
          throw StateError('Imported vault contains no accounts.');
        }
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) {
            throw StateError('Invalid vault account record format.');
          }
          if (item['label'] == null ||
              item['address'] == null ||
              item['privateKeyHex'] == null) {
            throw StateError(
              'Incomplete vault account record (missing label/address/key).',
            );
          }
        }
      } catch (e) {
        if (e is StateError || e is ArgumentError || e is VaultException) {
          rethrow;
        }
        throw StateError('Wrong password or corrupted/tampered backup file.');
      }

      // Require explicit user confirmation before replacing an existing vault
      if (!confirmReplace) {
        throw StateError(
          'Explicit confirmation required to replace the active vault.',
        );
      }

      // Check for existing vault and symlink destination
      final vaultFile = await AppStorage.vaultFile();
      if (hasVault) {
        if (!confirmReplace) {
          throw StateError(
            'A vault already exists. Explicit confirmation required to replace it.',
          );
        }
        if (await isSymlink(vaultFile.path)) {
          throw StateError(
            'Active vault destination is a symbolic link, refusing to replace.',
          );
        }
      }

      await AppStorage.ensureParentDir(vaultFile);

      // BACKUP ORIGINAL VAULT before replacement (if exists)
      String? originalBlob;
      if (hasVault) {
        originalBlob = await AppStorage.readVault();
        if (originalBlob == null) {
          throw StateError('Failed to read original vault for rollback.');
        }
      }

      try {
        // A portable backup is re-encrypted under this device's secret before
        // it becomes the active vault; a native vault envelope is written as-is.
        final blobToWrite = portable
            ? await _runVaultEncrypt(
                password,
                portableAccountsJson!,
                await AppStorage.getOrGenerateDeviceSecret(),
              )
            : blob;
        // Write the imported vault to a secure temporary location first, validate, then atomically replace
        final writeResult = await atomicWrite(vaultFile, blobToWrite);
        if (!writeResult.committed) {
          throw StateError('Import write failed: ${writeResult.error}');
        }
        if (writeResult.requiresRecovery) {
          throw StateError(
            'Import commit could not be verified: ${writeResult.error}',
          );
        }
        if (writeResult.error != null) {
          rpc.note(
            'Import write completed with durability warning: ${writeResult.error}',
            kind: RpcStoryKind.info,
          );
        }

        // Final validation: ensure the new vault can be opened with the password
        try {
          await _readVaultJson(password);
        } catch (_) {
          throw StateError(
            'Imported vault cannot be opened with the provided password after import.',
          );
        }

        _vaultExists = true;
        notifyListeners();

        rpc.note('Vault imported from $importPath.', kind: RpcStoryKind.info);
      } catch (e) {
        // ROLLBACK: Restore original vault on any failure
        if (originalBlob != null) {
          // Hook: before rollback write - for test injection
          StorageDebugHooks.beforeRollbackWrite?.call(
            vaultFile.path,
            originalBlob,
          );
          try {
            final injectRollbackFailure =
                StorageDebugHooks.injectRollbackWriteFailure;
            StorageDebugHooks.injectRollbackWriteFailure = false;
            final rollbackResult = await atomicWrite(
              vaultFile,
              originalBlob,
              injectPreCommitFailure: injectRollbackFailure,
            );
            StorageDebugHooks.afterRollbackWrite?.call(
              vaultFile.path,
              rollbackResult,
            );
            if (rollbackResult.state != AtomicWriteState.committedVerified) {
              rpc.note(
                'CRITICAL: Rollback was not verified - ${rollbackResult.error}. Manual recovery may be needed.',
                kind: RpcStoryKind.fail,
              );
            } else {
              // Verify rollback succeeded
              final rollbackBlob = await readRegularFileNoFollow(
                vaultFile.path,
                maxBytes: 5 * 1024 * 1024,
                missingMessage:
                    'Rollback destination disappeared before verification.',
                symlinkMessage: 'Rollback destination became a symbolic link before verification.',
              );
              if (rollbackBlob == null || rollbackBlob != originalBlob) {
                rpc.note(
                  'CRITICAL: Rollback failed - original vault may be corrupted!',
                  kind: RpcStoryKind.fail,
                );
              } else if (rollbackResult.error != null) {
                rpc.note(
                  'Import failed, original vault restored with warning: ${rollbackResult.error}',
                  kind: RpcStoryKind.info,
                );
              } else {
                rpc.note(
                  'Import failed, original vault restored successfully.',
                  kind: RpcStoryKind.info,
                );
              }
            }
          } catch (rollbackError) {
            rpc.note(
              'CRITICAL: Rollback failed with error: $rollbackError. Manual recovery may be needed.',
              kind: RpcStoryKind.fail,
            );
          }
        }
        rethrow;
      }
    });
  }

  /// Decrypts and validates a vault blob directly without touching the active vault.
  /// Used for validating imported backups with the provided password.
  Future<String> _decryptVaultBlob(
    String encoded,
    String password,
    String deviceSecret,
  ) async {
    return _runVaultDecrypt(password, encoded, deviceSecret);
  }

  /// Change the vault password.
  ///
  /// Reads the vault with [oldPassword], decrypts it, and re-encrypts with
  /// [newPassword] (new salt, new device KEK). Atomic write.
  ///
  /// Security guarantees:
  /// - Verifies old password against active vault
  /// - Generates new salt and re-encrypts with new password
  /// - Uses atomic write
  /// - Prevents concurrent vault operations
  Future<void> changeVaultPassword(
    String oldPassword,
    String newPassword,
  ) async {
    if (!hasVault) throw StateError('No vault exists.');
    if (oldPassword == newPassword) {
      throw ArgumentError('New password must be different from the old one.');
    }
    if (newPassword.isEmpty) {
      throw ArgumentError('The new password cannot be empty.');
    }

    await withVaultOperationLock(() async {
      final json = await _readVaultJson(oldPassword);
      if (json == null) throw StateError('Wrong password or vault not found.');

      final device = await AppStorage.getOrGenerateDeviceSecret();
      final blob = await _runVaultEncrypt(
        newPassword,
        jsonEncode(json),
        device,
      );

      await AppStorage.writeVaultAtomic(blob);
      _vaultSessionPassword = newPassword;
      rpc.note('Vault password changed.', kind: RpcStoryKind.info);
    });
  }

  /// Get information about the current vault.
  Future<Map<String, dynamic>> getVaultInfo() async {
    final file = await AppStorage.vaultFile();
    final customPath = AppStorage.getVaultPath();
    final exists = await file.exists();
    int? size;
    if (exists) {
      final stat = await file.stat();
      size = stat.size;
    }
    return {
      'path': file.path,
      'customPath': customPath,
      'exists': exists,
      'size': size,
      'isCustom': customPath != null,
    };
  }

  /// At most three independent vaults, each with its own password and file.
  static const int maxVaults = 3;

  VaultEntry? _vaultEntry(String id) {
    for (final entry in _vaults) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> refreshVaults() async {
    _vaults = AppStorage.getVaultEntries();
    _activeVaultId = AppStorage.activeVaultEntry?.id;
    notifyListeners();
  }

  /// Creates an empty vault file and makes it active. The user then adds or
  /// imports the first wallet. The existing vault is left untouched.
  Future<void> createVault(String label, String password) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError('Vault label must contain 1 to 60 characters.');
    }
    if (password.isEmpty) {
      throw ArgumentError('The vault password cannot be empty.');
    }
    if (_vaults.length >= maxVaults) {
      throw StateError(
        'At most $maxVaults vaults are supported on one device.',
      );
    }
    final id = 'v${DateTime.now().microsecondsSinceEpoch}';
    final file = await AppStorage.newVaultFile(id);
    final blob = await _runVaultEncrypt(
      password,
      '[]',
      await AppStorage.getOrGenerateDeviceSecret(),
    );
    final write = await atomicWrite(file, blob);
    if (write.state != AtomicWriteState.committedVerified) {
      throw StateError('New vault was not verified: ${write.error}');
    }
    final entry = VaultEntry(
      id: id,
      label: trimmed,
      file: file.path,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final next = [..._vaults, entry];
    await AppStorage.saveVaultEntries(next, activeId: id);
    _vaults = next;
    _activeVaultId = id;
    _vaultExists = true;
    lock();
    _unlocked = false;
    notifyListeners();
    rpc.note('Vault "$trimmed" created.', kind: RpcStoryKind.info);
  }

  /// Verifies the target vault password, locks the current session, switches
  /// the active file and unlocks its accounts.
  Future<void> switchVault(String id, String password) async {
    final entry = _vaultEntry(id);
    if (entry == null) throw StateError('Vault not found.');
    final blob = await AppStorage.readVaultAt(entry.file);
    if (blob == null) throw StateError('Vault file not found.');
    final device = await AppStorage.getOrGenerateDeviceSecret();
    final json = await _decryptVaultBlob(blob, password, device);
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Vault payload is not an account list.');
    }
    final accounts = _accountsFromJson(
      List<Map<String, dynamic>>.from(decoded),
    );
    lock();
    await AppStorage.setActiveVaultId(id);
    _activeVaultId = id;
    _vaultExists = true;
    _vaultSessionPassword = password;
    _vaultAccountsCache = accounts;
    _vaultKnownAddresses = {
      for (final account in accounts) account.address.toLowerCase(),
    };
    notifyListeners();
    rpc.note('Switched to vault "${entry.label}".', kind: RpcStoryKind.info);
  }

  /// Selects a vault for the next unlock without needing its password.
  Future<void> selectVault(String id) async {
    final entry = _vaultEntry(id);
    if (entry == null) throw StateError('Vault not found.');
    lock();
    await AppStorage.setActiveVaultId(id);
    _activeVaultId = id;
    _vaultExists = await AppStorage.vaultExists();
    notifyListeners();
  }

  Future<void> renameVault(String id, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError('Vault label must contain 1 to 60 characters.');
    }
    if (_vaultEntry(id) == null) throw StateError('Vault not found.');
    final next = [
      for (final entry in _vaults)
        if (entry.id == id) entry.copyWith(label: trimmed) else entry,
    ];
    await AppStorage.saveVaultEntries(next, activeId: _activeVaultId);
    _vaults = next;
    notifyListeners();
  }

  /// Deletes one vault after verifying its password. The file is shredded;
  /// only the recovery phrase or a portable backup can restore it.
  Future<void> deleteVault(String id, String password) async {
    final entry = _vaultEntry(id);
    if (entry == null) throw StateError('Vault not found.');
    if (password.isEmpty) throw ArgumentError('Vault password is required.');
    final blob = await AppStorage.readVaultAt(entry.file);
    if (blob == null) throw StateError('Vault file not found.');
    final device = await AppStorage.getOrGenerateDeviceSecret();
    await _decryptVaultBlob(blob, password, device);
    lock();
    final removed = await AppStorage.deleteVaultAt(entry.file);
    if (!removed) {
      throw StateError('The vault file could not be removed completely.');
    }
    final next = [
      for (final item in _vaults)
        if (item.id != id) item,
    ];
    String? nextActive = _activeVaultId;
    if (_activeVaultId == id) {
      nextActive = next.isEmpty ? null : next.first.id;
    }
    await AppStorage.saveVaultEntries(next, activeId: nextActive);
    _vaults = next;
    _activeVaultId = nextActive;
    _vaultExists = nextActive != null && await AppStorage.vaultExists();
    notifyListeners();
    rpc.note('Vault "${entry.label}" deleted.', kind: RpcStoryKind.info);
  }

  /// Reset vault path to default (system app data directory).
  Future<void> resetVaultPath() async {
    await withVaultOperationLock(() async {
      await AppStorage.setVaultPath(null);
      _vaultExists = await AppStorage.vaultExists();
      notifyListeners();
      rpc.note('Vault path reset to default.', kind: RpcStoryKind.info);
    });
  }

  /// Erases every trace: vault (shredded after random overwrite), secrets in
  /// secure storage, all preferences, the story. Memory copies are dropped;
  /// the restored first-run state is clean. Funds recover only with the seed
  /// phrase. Returns anything the wipe could NOT remove (empty = clean).
  Future<List<String>> eraseAll() async {
    return withVaultOperationLock(() async {
      // Remove the encrypted activity log before preferences (and therefore
      // its key material) are cleared, then let the storage wipe handle the
      // vault, receipts, drawer, log file and atomic temporaries.
      try {
        await EncryptedLogStore.clear();
      } catch (_) {
        // The storage pass below removes the file even if the store was not
        // initialised.
      }
      final leftovers = await AppStorage.eraseAllData();
      _key = null;
      _mnemonic = null;
      _profiles = [];
      _nodes = [];
      _customTokens = [...DefaultTokens.bsc];
      _bscscanKey = null;
      _vaultSessionPassword = null;
      _vaultAccountsCache = null;
      _vaultKnownAddresses = {};
      _pending = [];
      _vaults = [];
      _activeVaultId = null;
      _unlocked = false;
      _vaultExists = false;
      _usePin = false;
      _appLocked = false;
      _drawerNoteShown = false;
      AppStorage.resetDeviceSecretMemo();
      rpc.setBscscanKey(null);
      rpc.setCustomTokens(_customTokens);
      rpc.clearStory();
      await rpc.privacyChanged();
      rpc.note(
        'Everything stored on this device was erased. The wallet starts clean.',
        kind: RpcStoryKind.info,
      );
      notifyListeners();
      return leftovers;
    });
  }
}

/// Shared application state. Import this from any screen.
final AppState appState = AppState();

import 'dart:convert';
import 'dart:io';

import '../localized_text.dart';

import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;

import '../app_state.dart';
import '../models.dart';
import '../net/privacy_client.dart';
import '../rpc_service.dart';
import '../security.dart';
import '../storage.dart';
import '../token_logos.dart';
import '../wallet_core.dart';
import 'backup_quiz_dialog.dart';
import 'cold_wallet_dialogs.dart';
import 'common.dart';
import 'donations_dialog.dart';
import 'logs_page.dart';
import 'privacy_dialogs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _rpcController = TextEditingController();
  final _newTokenAddress = TextEditingController();

  /// §10e trusted signing-list sources, loaded from assets/token_sources.json.
  List<Map<String, dynamic>> _tokenSources = const [];

  @override
  void initState() {
    super.initState();
    _rpcController.text = appState.rpc.configuredRpc;
    appState.addListener(_onStateChanged);
    _loadTokenSources();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTokenSources() async {
    try {
      final raw = await rootBundle.loadString('assets/token_sources.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        setState(() {
          _tokenSources = [
            for (final entry in decoded)
              if (entry is Map<String, dynamic>) entry,
          ];
        });
      }
    } catch (_) {
      // The shipped file is broken or missing — the section shows empty and
      // the build-time checker script is the thing to fix, not the wallet.
    }
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    _rpcController.dispose();
    _newTokenAddress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network & assets')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _networkSection(),
            const SizedBox(height: 18),
            _rpcSection(),
            const SizedBox(height: 18),
            _nodesSection(),
            const SizedBox(height: 18),
            _tokensSection(),
            const SizedBox(height: 18),
            _historyKeySection(),
            const SizedBox(height: 18),
            _storageSection(),
            const SizedBox(height: 18),
            _securitySection(),
            const SizedBox(height: 18),
            _walletModeSection(),
            const SizedBox(height: 18),
            _selectionModeSection(),
            const SizedBox(height: 18),
            _appearanceSection(),
            const SizedBox(height: 18),
            _privacySection(),
            const SizedBox(height: 18),
            _networkPrivacySection(),
            const SizedBox(height: 18),
            _autoLockSection(),
            const SizedBox(height: 18),
            _eraseSection(),
            const SizedBox(height: 18),
            _aboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _privacySection() {
    final proxy = appState.globalProxy;
    final route = appState.torEnabled
        ? 'Tor via ${appState.torHost}:${appState.torPort}'
        : (proxy.type != ProxyType.none
              ? proxy.description
              : 'Direct HTTPS (no proxy)');

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Privacy route'),
          const SizedBox(height: 8),
          const Text(
            'Exactly one route is active for every RPC and explorer request. '
            'There is no direct fallback: if the selected route is down, '
            'requests fail instead of revealing your IP address.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              appState.torEnabled || appState.proxyEnabled
                  ? Icons.vpn_lock
                  : Icons.public,
              color: appState.torEnabled || appState.proxyEnabled
                  ? const Color(0xFFF0B90B)
                  : Color(0xFF6E6E6E),
            ),
            title: const Text('Active route'),
            subtitle: Text(route, style: const TextStyle(fontSize: 12)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final changed = await showProxySettingsDialog(context);
                  if (changed && mounted) setState(() {});
                },
                icon: const Icon(Icons.route),
                label: const Text('Custom proxy…'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final changed = await showTorSettingsDialog(context);
                  if (changed && mounted) setState(() {});
                },
                icon: const Icon(Icons.travel_explore),
                label: const Text('Tor & bridges…'),
              ),
              if (proxy.type != ProxyType.none)
                TextButton(
                  onPressed: () async {
                    await appState.disableProxy();
                    try {
                      await appState.rpc.connect();
                    } catch (_) {}
                    if (mounted) setState(() {});
                  },
                  child: const Text('Disable proxy'),
                ),
              if (appState.torEnabled)
                TextButton(
                  onPressed: () async {
                    await appState.setTorEnabled(false);
                    try {
                      await appState.rpc.connect();
                    } catch (_) {}
                    if (mounted) setState(() {});
                  },
                  child: const Text('Disable Tor'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Custom proxy: SOCKS5, SOCKS5h, or HTTP CONNECT, with domain/IP '
            'hosts, custom ports and optional authentication. Tor: use an '
            'existing Tor/Orbot SOCKS port or let the app start a managed '
            'Tor daemon with obfs4, Snowflake, WebTunnel, meek or custom '
            'bridge lines.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Network Privacy screen (spec §6/§7) — shows exactly what each party
  /// can and cannot see based on the ACTIVE transport configuration.
  Widget _networkPrivacySection() {
    final route = appState
        .rpc
        .routeDescription; // e.g. "Direct HTTPS" / "Tor via 127.0.0.1:9050"
    final isTor = appState.torEnabled;
    final isPrivate = isTor || appState.proxyEnabled;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Network Privacy — what they see'),
          const SizedBox(height: 8),
          Text(
            'Your current route: $route',
            style: const TextStyle(
              color: Color(0xFFF0B90B),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          _privacyCard(
            title: 'Your ISP / DPI (internet provider, firewalls)',
            canSee: isPrivate
                ? [
                    'You connect to a Tor guard relay (public IP).',
                    'Tor TLS-like handshake (DPI often recognises Tor).',
                    'Traffic volume and timing patterns.',
                  ]
                : [
                    'Your real IP address.',
                    'The RPC hostname (SNI in TLS handshake).',
                    'Traffic volume and timing.',
                    'DNS queries for the RPC hostname (unless DoH).',
                  ],
            cannotSee: isPrivate
                ? [
                    'Which RPC you talk to (hidden inside Tor).',
                    'RPC payload (addresses, amounts, signed tx).',
                    'Destination hostname.',
                  ]
                : [
                    'RPC payload — TLS encrypts it.',
                    'Your seed/keys/password (never leave device).',
                    'Device model, OS, app version, locale (never sent).',
                  ],
          ),
          const SizedBox(height: 10),
          _privacyCard(
            title: 'The RPC node (the door you chose)',
            canSee: [
              'Your IP (or Tor exit IP if Tor is on).',
              'Every RPC call: balances, nonces, gas price, broadcasts.',
              'Linkage of addresses you query in the same circuit/connection.',
              'Timing and request patterns.',
            ],
            cannotSee: [
              'Your seed words or private keys (signing is local).',
              'Device info (model, OS, app version, locale).',
              'What a transaction means to you (only on-chain data).',
              'Balances you hold elsewhere.',
            ],
          ),
          const SizedBox(height: 10),
          _privacyCard(
            title: 'Everyone on the blockchain (public forever)',
            canSee: [
              'Your addresses, amounts, timestamps — forever.',
              'Token transfers, contract interactions.',
              'Gas paid, nonce, block position.',
            ],
            cannotSee: [
              'Your real-world identity (unless you link it).',
              'Your IP or location.',
              'Your keys or seed.',
            ],
          ),
          const SizedBox(height: 14),
          if (!isPrivate) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x33FF6B6B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct mode: your ISP sees the RPC hostname and your IP. '
                      'Enable Tor or a proxy to hide both.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => _showRawRequestExample(context),
            icon: const Icon(Icons.code_outlined),
            label: const Text(
              'View example raw request (what the node actually receives)',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testPrivacyRoute,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Test privacy route — who sees what'),
          ),
        ],
      ),
    );
  }

  Future<String> _runPrivacyRouteTest() async {
    final tor = appState.torEnabled;
    final proxy = appState.globalProxy;
    final config = tor
        ? GlobalProxyConfig(
            type: ProxyType.socks5h,
            host: appState.torHost,
            port: appState.torPort,
          )
        : proxy;
    final started = DateTime.now();
    try {
      if (tor || proxy.enabled) {
        final message = await probeProxyRoute(
          config,
          BnbNetworks.mainnetFallbacks.first,
        );
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        return '$message\nLatency: $elapsed ms';
      }
      await appState.rpc.connect();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      return 'Direct HTTPS reached the node. Chain ID: ${appState.rpc.chainId}\n'
          'Latency: $elapsed ms';
    } catch (error) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      return 'Test failed after $elapsed ms: $error';
    }
  }

  String _privacyRouteReport(String testResult) {
    final tor = appState.torEnabled;
    final proxy = appState.globalProxy;
    final upstream = appState.torUpstream;
    final chain = appState.torChainDepth;
    final route = tor
        ? 'Managed/external Tor${upstream.enabled ? ' after ${upstream.description}' : ''}${chain > 1 ? ' · chain depth $chain' : ''}'
        : proxy.enabled
        ? proxy.description
        : 'Direct HTTPS';

    final isp = tor
        ? (upstream.enabled
              ? 'Sees a connection to your VPN/VLESS endpoint, not the RPC host.'
              : 'Sees a connection to a Tor guard relay, not the RPC host.')
        : proxy.enabled
        ? 'Sees a connection to the proxy endpoint, not the RPC host.'
        : 'Sees your real IP, the RPC hostname (SNI), and traffic timing.';
    final vps = upstream.enabled
        ? 'Your VPS sees your real IP and the Tor connection leaving for a guard. It does not see the RPC payload.'
        : 'No VPS is configured before Tor; the Tor guard is the first external hop.';
    final guard = tor
        ? 'The Tor guard sees your VPN/VPS IP (or your real IP in direct Tor). The exit sees the RPC request, but not your keys.'
        : 'No Tor guard is used in this route.';
    final node = tor
        ? 'The RPC node sees the Tor exit IP, the RPC calls, and address query linkage. It never sees your keys or seed.'
        : proxy.enabled
        ? 'The RPC node sees the proxy exit IP, the RPC calls, and address query linkage. It never sees your keys or seed.'
        : 'The RPC node sees your real IP, the RPC calls, and address query linkage. It never sees your keys or seed.';
    final chainView =
        'The public blockchain sees addresses, amounts, timestamps, and contract calls forever. It does not see your IP or identity unless you link them.';

    return 'Route: $route\n\n'
        'REAL TEST RESULT\n$testResult\n\n'
        'WHAT EACH PARTY SEES\n'
        '• Your ISP / DPI: $isp\n'
        '• Your VPN/VPS: $vps\n'
        '• Tor guard/exit: $guard\n'
        '• RPC node: $node\n'
        '• Public blockchain: $chainView\n\n'
        'This report describes the configured route. The app does not expose '
        'the Tor exit IP to itself; only the RPC node sees it.';
  }

  Future<void> _testPrivacyRoute() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy route test'),
        content: SizedBox(
          width: 640,
          child: FutureBuilder<String>(
            future: _runPrivacyRouteTest(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Testing the real route…'),
                );
              }
              final report = _privacyRouteReport(
                snapshot.data ?? 'No result: ${snapshot.error}',
              );
              return SingleChildScrollView(
                child: SelectableText(
                  report,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRawRequestExample(BuildContext context) {
    final example = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'eth_getBalance',
      'params': ['0x1234...your_address...', 'latest'],
    };
    final pretty = const JsonEncoder.withIndent('  ').convert(example);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Example raw request (balance check)'),
        content: SingleChildScrollView(
          child: SelectableText(
            pretty,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              copyText(ctx, pretty, 'Raw request');
              Navigator.pop(ctx);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  /// A card showing what a party CAN see and CANNOT see.
  Widget _privacyCard({
    required String title,
    required List<String> canSee,
    required List<String> cannotSee,
  }) {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '✅ CAN see:',
            style: TextStyle(color: color.error, fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final item in canSee)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• $item',
                style: TextStyle(color: color.onSurfaceVariant, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '❌ CANNOT see:',
            style: TextStyle(color: color.tertiary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final item in cannotSee)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• $item',
                style: TextStyle(color: color.onSurfaceVariant, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _autoLockSection() {
    const choices = <int, String>{
      0: 'Background only',
      60: '60 seconds',
      300: '5 minutes',
    };
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Auto-lock'),
          const SizedBox(height: 8),
          const Text(
            'Locks the wallet when it has been idle. The lock also happens immediately '
            'whenever the app goes to the background. Times are measured with a '
            'monotonic timer, not the wall clock.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              for (final entry in choices.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: appState.autoLockSeconds == entry.key,
                  onSelected: (_) async {
                    await appState.setAutoLockSeconds(entry.key);
                    setState(() {});
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eraseSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Erase all data'),
          const SizedBox(height: 8),
          const Text(
            'Deletes the encrypted vault, the PIN, the device-bound key and every '
            'preference, then resets this app to first-run state. Funds can only be '
            'recovered with your 24-word backup phrase. Overwriting files on flash '
            'storage is best-effort; the security of erase comes from deleting the '
            'device-bound key, which leaves every encrypted byte permanently unreadable.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffB71C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _confirmErase(context),
            icon: const Icon(Icons.local_fire_department),
            label: const Text('Erase everything…'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    final confirmed = await promptText(
      context,
      title: 'Erase all data?',
      label: 'Type ERASE to confirm',
      validator: (v) => v.trim() == 'ERASE' ? null : 'Type ERASE exactly.',
    );
    if (confirmed == null || !context.mounted) return;
    final leftovers = await appState.eraseAll();
    if (!context.mounted) return;
    if (leftovers.isEmpty) {
      showInfo(context, 'All local data erased. The wallet is reset.');
    } else {
      // Never claim success while something survived on disk — say exactly
      // what remained and how to retry.
      await showMessage(
        context,
        'Erase finished with problems',
        'These items could not be removed:\n\n'
            '${leftovers.join('\n')}\n\n'
            'Close any other copies of the app and press Erase again; if it '
            'persists, check file permissions in the app data folder.',
      );
    }
  }

  Widget _networkSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Network'),
          const SizedBox(height: 8),
          const Text(
            'Switching networks verifies the chain ID before any RPC call.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'mainnet', label: Text('Mainnet (56)')),
              ButtonSegment(value: 'testnet', label: Text('Testnet (97)')),
            ],
            selected: {appState.rpc.network},
            onSelectionChanged: (s) async {
              await appState.setNetwork(s.first);
              if (mounted) showInfo(context, 'Switched to ${s.first}.');
            },
          ),
        ],
      ),
    );
  }

  Widget _rpcSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('RPC node (HTTPS only)'),
          const SizedBox(height: 8),
          const Text(
            'Used for balances, nonce, fees, receipts, and broadcast. Chain ID is re-verified before use.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rpcController,
            decoration: InputDecoration(
              labelText: tr(context, 'https://node.example'),
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final url = _rpcController.text.trim();
                  if (!url.startsWith('https://')) {
                    showError(context, 'Use an HTTPS URL.');
                    return;
                  }
                  await appState.setRpc(url);
                  if (mounted) showInfo(context, 'RPC updated.');
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save RPC'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final url = _rpcController.text.trim();
                  final rows = await appState.rpc.testNodeDeep(
                    url,
                    expectedNetwork: appState.rpc.network,
                  );
                  if (!mounted) return;
                  await _showNodeChecklist(
                    context,
                    Uri.tryParse(url)?.host ?? url,
                    rows,
                    onUse: () => appState.setRpc(url),
                    useNote: 'Now talking through $url.',
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Test'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _rpcController.text = appState.rpc.configuredRpc;
                  showInfo(context, 'Reset to default.');
                },
                icon: const Icon(Icons.restore),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nodesSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('RPC nodes — the little phone book of doors'),
          const SizedBox(height: 8),
          const Text(
            'These are the only computers I may ask about balances and blocks. '
            'Each one is pinned to a side: mainnet (real money) or testnet '
            '(practice coins). The switch on every row turns a door off — a '
            'switched-off door is never asked anything. Book order is '
            'priority order: move doors with the ▲▼ actions.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use ONLY my node (strict)'),
            subtitle: Text(
              appState.strictNodeMode
                  ? 'Every network question goes to the chosen door ONLY — '
                        'no built-in door, no fallback, nothing else. If it is '
                        'down, nothing is sent.'
                  : 'The chosen door is preferred, but built-in public doors '
                        'may double-check fees and receipts.',
              style: const TextStyle(fontSize: 12),
            ),
            value: appState.strictNodeMode,
            onChanged: (value) => appState.setStrictNodeMode(value),
            secondary: Icon(
              Icons.looks_one_outlined,
              color: appState.strictNodeMode
                  ? const Color(0xFFF0B90B)
                  : Color(0xFF808080),
            ),
          ),
          const SizedBox(height: 6),
          if (appState.currentNetworkNodes.isEmpty)
            const Text(
              'No phone book entries for this side yet — I will use the '
              'official door until you add one.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            )
          else
            for (var i = 0; i < appState.nodes.length; i++)
              if (appState.nodes[i].network == appState.rpc.network)
                _nodeRow(index: i, node: appState.nodes[i]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _addNodeFlow,
                icon: const Icon(Icons.add),
                label: const Text('Add node…'),
              ),
              OutlinedButton.icon(
                onPressed: _importNodesFlow,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Import doors…'),
              ),
              OutlinedButton.icon(
                onPressed: _exportNodesFlow,
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('Export doors'),
              ),
              OutlinedButton.icon(
                onPressed: _confirmResetNodes,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to official list'),
              ),
            ],
          ),
          if (appState.nodes.length - appState.currentNetworkNodes.length > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${appState.nodes.length - appState.currentNetworkNodes.length} '
                'more door(s) live on the other side — switch the network there '
                'to see them.',
                style: const TextStyle(color: Color(0xFF808080), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addNodeFlow() async {
    final label = await promptText(
      context,
      title: 'Add node',
      label: 'Friendly name (e.g. My home node)',
    );
    if (label == null || !mounted) return;
    final url = await promptText(
      context,
      title: 'Add node',
      label: 'Address — https:// (or http:// for localhost/LAN/.onion)',
      validator: (v) => nodeUrlAllowed(v.trim())
          ? null
          : 'HTTPS everywhere. HTTP is only ever allowed for a localhost/LAN '
                'door or a .onion address reached over Tor.',
    );
    if (url == null || !mounted) return;
    if (!appState.isNodeWarned(url.trim())) {
      final understood = await confirmDialog(
        context,
        title: 'What this door will see',
        message:
            'A node you add can see your IP address (unless you route through '
            'Tor) and every question you ask it — balances, prices, blocks — '
            'and can associate those questions with one another.\n'
            'It can NOT see your keys or seed words, and it never learns '
            'transaction contents.\n'
            'I will not show this notice again for this address.',
        confirmLabel: 'I understand',
      );
      if (!understood) return;
      await appState.markNodeWarned(url.trim());
    }
    try {
      await appState.addNode(label.trim(), url.trim());
      if (mounted) {
        showInfo(
          context,
          'Saved "${label.trim()}". Test it before trusting it.',
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  /// §10d import: paste a JSON node list; safe URLs only, duplicates skipped,
  /// anything malformed refuses the WHOLE import (fail closed).
  Future<void> _importNodesFlow() async {
    final raw = await promptText(
      context,
      title: 'Import doors',
      label: 'Paste the JSON node list',
      keyboardType: TextInputType.url,
    );
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    try {
      final added = await appState.importNodes(raw.trim());
      if (mounted) {
        showInfo(
          context,
          added == 0
              ? 'Nothing new — every door in that list was already saved.'
              : '$added door(s) imported.',
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  /// §10d export: the book holds no secrets, so the JSON goes to the
  /// clipboard with a plain-words heads-up.
  Future<void> _exportNodesFlow() async {
    if (appState.nodes.isEmpty) {
      showInfo(context, 'The phone book is empty — nothing to export.');
      return;
    }
    final json = appState.exportNodesJson();
    if (!mounted) return;
    final understood = await confirmDialog(
      context,
      title: 'Export doors',
      message:
          'Names and public addresses only — the phone book holds no secrets. '
          'The list goes to the clipboard as JSON; paste it into a file or '
          'another device\'s import dialog.',
      confirmLabel: 'Copy JSON',
    );
    if (!understood || !mounted) return;
    await copyText(context, json, 'Node list');
  }

  Future<void> _confirmResetNodes() async {
    final confirmed = await promptText(
      context,
      title: 'Reset node list?',
      label: 'Type RESET to confirm',
      validator: (v) => v.trim() == 'RESET' ? null : 'Type RESET exactly.',
    );
    if (confirmed == null || !mounted) return;
    await appState.resetNodesToDefaults();
    if (mounted) showInfo(context, 'Back to the official doors.');
  }

  /// The §10d "Full test" dialog: every checklist item with ✔/⚠ and what was
  /// actually seen. Blocking rows (address policy / answers / right chain)
  /// gate the use button; the rest explain themselves as warnings. A test
  /// never sends anything. [onUse] is what "Use this door" does (activate a
  /// book entry, or connect to a hand-typed URL); null hides the button.
  Future<void> _showNodeChecklist(
    BuildContext dialogContext,
    String label,
    List<NodeCheckRow> rows, {
    Future<void> Function()? onUse,
    String useNote = 'Now talking through that door.',
  }) {
    final blocking = rows
        .where(
          (r) =>
              !r.ok &&
              (r.label == 'Right chain' ||
                  r.label == 'Answers at all' ||
                  r.label == 'Address policy'),
        )
        .toList();
    return showDialog<bool>(
      context: dialogContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          blocking.isEmpty
              ? '✅ Checklist on $label'
              : '🛑 $label cannot be trusted',
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${row.ok ? '✅' : '⚠️'} ${row.label} — ${row.detail}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: row.ok ? Color(0xFF6E6E6E) : Colors.orangeAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                blocking.isEmpty
                    ? '⚠ marks are warnings, not blockers — each one explains '
                          'itself above. Tests never send anything: the broadcast '
                          'probe uses a deliberately invalid payload.'
                    : 'Fix the blocking check or pick another door — the wallet '
                          'refuses to use a door that is not on our chain or will '
                          'not answer.',
                style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
              ),
              ..._transportNote(),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final report = StringBuffer()
                ..writeln('Node test: $label')
                ..writeln('Result: ${blocking.isEmpty ? 'PASS' : 'BLOCKED'}')
                ..writeln('');
              for (final row in rows) {
                report.writeln('${row.ok ? 'PASS' : 'WARN'} — ${row.label}');
                report.writeln('  ${row.detail}');
              }
              Clipboard.setData(ClipboardData(text: report.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Full node test report copied.')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy full report'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (blocking.isEmpty && onUse != null)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use this door'),
            ),
        ],
      ),
    ).then((use) async {
      if (use == true && onUse != null) {
        try {
          await onUse();
          if (mounted) showInfo(context, useNote);
        } catch (error) {
          if (mounted) showError(context, error);
        }
      }
    });
  }

  List<Widget> _transportNote() => [
    const SizedBox(height: 6),
    Text(
      appState.rpc.routeDescription,
      style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
    ),
  ];

  /// One phone-book row: status, name, host, an on/off switch (a disabled
  /// door is never asked anything), and the actions (test / edit / use /
  /// remove / move up / move down).
  Widget _nodeRow({required int index, required RpcNode node}) {
    final active = appState.isNodeActive(node);
    final transportLabel = _transportLabel(node);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        active
            ? Icons.check_circle
            : node.enabled
            ? Icons.router
            : Icons.link_off,
        color: active
            ? const Color(0xFFF0B90B)
            : node.enabled
            ? Color(0xFF808080)
            : Color(0xFF8E8E8E),
      ),
      title: Text(
        node.label,
        style: TextStyle(
          color: node.enabled
              ? Theme.of(context).colorScheme.onSurface
              : const Color(0xFF808080),
          decoration: node.enabled ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        '${Uri.tryParse(node.url)?.host ?? node.url}'
        '${active ? ' — I talk to THIS one now' : ''}'
        '${node.enabled ? '' : ' — switched OFF, never asked'}'
        '\nTransport: $transportLabel',
        style: TextStyle(
          color: active && node.enabled
              ? Theme.of(context).colorScheme.onSurface
              : const Color(0xFF6E6E6E),
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Per-node transport selector
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: DropdownButton<NodeTransport>(
              value: node.transport,
              underline: Container(),
              dropdownColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF6E6E6E),
                size: 20,
              ),
              items: NodeTransport.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_transportLabelFromEnum(t)),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                if (value == NodeTransport.customProxy ||
                    value == NodeTransport.httpConnect) {
                  // These routes are unusable without an endpoint. Ask for it
                  // now instead of leaving a fail-closed node behind.
                  await _editNodeTransport(index, node, preset: value);
                } else {
                  await appState.setNodeTransport(index, value);
                }
                if (context.mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.72,
            child: Switch(
              value: node.enabled,
              activeThumbColor: const Color(0xFFF0B90B),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => appState.setNodeEnabled(index, value),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (choice) async {
              switch (choice) {
                case 'activate':
                  final ok = await promptText(
                    context,
                    title: 'Use this node for everything?',
                    label: 'Type USE to confirm',
                    validator: (v) =>
                        v.trim() == 'USE' ? null : 'Type USE exactly.',
                  );
                  if (ok == null || !mounted) return;
                  try {
                    await appState.activateNode(node);
                    if (mounted) {
                      showInfo(context, 'Switched to ${node.label}.');
                    }
                  } catch (error) {
                    if (mounted) showError(context, error);
                  }
                  break;
                case 'test':
                  final rows = await appState.rpc.testNodeDeep(
                    node.url,
                    expectedNetwork: node.network,
                  );
                  if (!mounted) return;
                  await _showNodeChecklist(
                    context,
                    Uri.tryParse(node.url)?.host ?? node.url,
                    rows,
                    onUse: () => appState.activateNode(node),
                    useNote: 'Switched to ${node.label}.',
                  );
                  break;
                case 'up':
                  await appState.moveNode(index, -1);
                  break;
                case 'down':
                  await appState.moveNode(index, 1);
                  break;
                case 'edit':
                  final label = await promptText(
                    context,
                    title: 'Edit node',
                    label: 'Friendly name',
                    initialValue: node.label,
                    validator: (v) =>
                        v.trim().isEmpty ? 'Name required.' : null,
                  );
                  if (label == null || !mounted) return;
                  final url = await promptText(
                    context,
                    title: 'Edit node',
                    label: 'Address (https, or http for local/LAN/.onion)',
                    initialValue: node.url,
                    validator: (v) => nodeUrlAllowed(v.trim())
                        ? null
                        : 'HTTPS everywhere — HTTP only for localhost/LAN or '
                              'a .onion address over Tor.',
                  );
                  if (url == null || !mounted) return;
                  try {
                    await appState.editNode(index, label.trim(), url.trim());
                    if (mounted) {
                      showInfo(context, 'Phone book updated.');
                    }
                  } catch (error) {
                    if (mounted) showError(context, error);
                  }
                  break;
                case 'transport':
                  await _editNodeTransport(index, node);
                  break;
                case 'proxy':
                  await _editNodeTransport(
                    index,
                    node,
                    preset:
                        node.transport == NodeTransport.customProxy ||
                            node.transport == NodeTransport.httpConnect
                        ? node.transport
                        : NodeTransport.customProxy,
                  );
                  break;
                case 'auth':
                  await _editNodeAuth(index, node);
                  break;
                case 'pinning':
                  await _editNodePinning(index, node);
                  break;
                case 'selection':
                  await _editNodeSelection(index, node);
                  break;
                case 'remove':
                  final ok = await promptText(
                    context,
                    title: 'Remove "${node.label}"?',
                    label: 'Type DELETE to confirm',
                    validator: (v) =>
                        v.trim() == 'DELETE' ? null : 'Type DELETE exactly.',
                  );
                  if (ok == null || !mounted) return;
                  try {
                    await appState.deleteNode(index);
                    if (mounted) {
                      showInfo(context, '"${node.label}" removed.');
                    }
                  } catch (error) {
                    if (mounted) showError(context, error);
                  }
                  break;
              }
            },
            itemBuilder: (dialogContext) => const [
              PopupMenuItem(
                value: 'activate',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.push_pin_outlined),
                  title: Text('Use this door'),
                ),
              ),
              PopupMenuItem(
                value: 'test',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.checklist),
                  title: Text('Full test'),
                ),
              ),
              PopupMenuItem(
                value: 'up',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.arrow_upward),
                  title: Text('Move up'),
                ),
              ),
              PopupMenuItem(
                value: 'down',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.arrow_downward),
                  title: Text('Move down'),
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'transport',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.router),
                  title: Text('Change transport…'),
                ),
              ),
              PopupMenuItem(
                value: 'proxy',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.route),
                  title: Text('Proxy settings…'),
                ),
              ),
              PopupMenuItem(
                value: 'auth',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.security),
                  title: Text('Authentication (Bearer/Basic)'),
                ),
              ),
              PopupMenuItem(
                value: 'pinning',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.fingerprint),
                  title: Text('Certificate pinning (SPKI)'),
                ),
              ),
              PopupMenuItem(
                value: 'selection',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.tune),
                  title: Text('Selection mode / use for…'),
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testToken() async {
    final raw = _newTokenAddress.text.trim();
    if (!WalletCore.isValidAddress(raw)) {
      showError(context, 'Enter a valid contract address.');
      return;
    }
    final started = DateTime.now();
    final lines = <String>[
      'Token contract: $raw',
      'Network: ${appState.rpc.network} · chain ${appState.rpc.chainId}',
      'Started: ${started.toIso8601String()}',
      '',
    ];
    TokenInfo? meta;
    try {
      meta = await appState.rpc.tokenMeta(raw);
      lines
        ..add('Contract responded: YES')
        ..add('Symbol: ${meta.symbol}')
        ..add('Name: ${meta.name}')
        ..add('Decimals: ${meta.decimals}')
        ..add('Contract address normalized: ${meta.address}');
      final wallet = appState.address;
      if (wallet != null) {
        final balance = await appState.rpc.getTokenBalance(raw, wallet);
        lines
          ..add('Wallet: $wallet')
          ..add('Raw balance: $balance')
          ..add(
            'Formatted: ${WalletCore.formatUnits(balance, meta.decimals)} ${meta.symbol}',
          );
      } else {
        lines.add('Balance: unavailable (no wallet address is loaded).');
      }
      lines
        ..add('')
        ..add('RESULT: PASS — this is a real ERC-20/BEP-20 contract.');
    } catch (error) {
      lines
        ..add('RESULT: FAIL')
        ..add('Reason: $error');
    }
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    lines.add('Elapsed: $elapsed ms');
    final report = lines.join('\n');
    final token = meta;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(token == null ? 'Token test failed' : 'Token test passed'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Full token test log copied.')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy log'),
          ),
          if (token != null)
            FilledButton(
              onPressed: () async {
                await appState.addToken(token);
                _newTokenAddress.clear();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) showInfo(context, '${token.symbol} added.');
              },
              child: const Text('Add this token'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _tokensSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Custom tokens'),
          const SizedBox(height: 8),
          const Text(
            'Adds a token contract address to your balance list. Verified on-chain before saving.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _newTokenAddress,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Contract address'),
                    border: OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final raw = _newTokenAddress.text.trim();
                  if (!WalletCore.isValidAddress(raw)) {
                    showError(context, 'Enter a valid contract address.');
                    return;
                  }
                  try {
                    final meta = await appState.rpc.tokenMeta(raw);
                    await appState.addToken(meta);
                    _newTokenAddress.clear();
                    if (mounted) {
                      showInfo(context, '${meta.symbol} added.');
                    }
                  } catch (error) {
                    if (mounted) showError(context, error);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              OutlinedButton.icon(
                onPressed: _testToken,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Test token'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final token in appState.customTokens)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: TokenLogo(token: token),
              title: Text('${token.symbol} · ${token.decimals} decimals'),
              subtitle: Text(shortAddress(token.address)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () {
                  final index = appState.customTokens.indexOf(token);
                  appState.removeToken(index);
                },
              ),
            ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x33808080)),
          const SizedBox(height: 10),
          const Text(
            'Show or hide tokens',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hiding only changes this screen and the send picker; the token '
            'and its on-chain balance stay exactly where they are. BNB is '
            'always shown because it pays network fees.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          for (final token in [
            const TokenInfo(
              symbol: 'BNB',
              name: 'BNB Smart Chain',
              address: '',
              decimals: 18,
              native: true,
            ),
            ...appState.rpc.tokens,
          ])
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${token.symbol} · ${token.name}'),
              subtitle: token.native
                  ? const Text('Always shown')
                  : Text(shortAddress(token.address)),
              secondary: TokenLogo(token: token, size: 24),
              value: !appState.isTokenHidden(token),
              onChanged: token.native
                  ? null
                  : (visible) => appState.setTokenHidden(token, !visible),
            ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x33808080)),
          const SizedBox(height: 10),
          _tokenSourcesSection(),
        ],
      ),
    );
  }

  /// §10e — where contract addresses may be trusted from: shipped defaults
  /// (assets/token_sources.json), the 3-step checklist, the scam warning,
  /// a one-time notice, and the user's own editable links.
  Widget _tokenSourcesSection() {
    final userLinks = [for (final e in AppStorage.userTokenSources) Map.of(e)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Where can I find contract addresses?'),
        const SizedBox(height: 8),
        if (!AppStorage.tokenSourcesNoticeSeen) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x22F0B90B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These links are starting points, not blessings: the wallet '
                  'ships them so you do not have to trust a search engine. '
                  'Verify on two of them and the issuer\'s own site before '
                  'adding anything.',
                  style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await AppStorage.setTokenSourcesNoticeSeen();
                      setState(() {});
                    },
                    child: const Text(
                      'OK — don\'t show again',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const Text(
          '① Look the token up on BscScan or the issuer\'s OFFICIAL site and '
          'copy the contract address.\n'
          '② Check the name, symbol and logo against the issuer\'s own page.\n'
          '③ Paste the address into the field above — the wallet verifies the '
          'contract on-chain (symbol, decimals, live) before saving it.',
          style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          '⚠️ Fake "official" sites are the most common way tokens are faked. '
          'When two sources disagree, believe neither — check a third. One '
          'verification in the past is not a promise for the future.',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (_tokenSources.isEmpty)
          const Text(
            '(The shipped source list could not be read from the app bundle — '
            'report this to jackh109867@gmail.com.)',
            style: TextStyle(color: Color(0xFF808080), fontSize: 12.5),
          )
        else
          for (final source in _tokenSources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.verified_outlined,
                color: Color(0xFFF0B90B),
              ),
              title: Text(
                '${source['name'] ?? ''}',
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${source['description'] ?? ''}\n${source['url'] ?? ''}',
                style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: tr(context, 'Open in browser'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _openSourceUrl('${source['url'] ?? ''}'),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Copy link'),
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () =>
                        copyText(context, '${source['url'] ?? ''}', 'Link'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 10),
        Text(
          userLinks.isEmpty
              ? 'Your own trusted links: none yet — you can add ones you verified yourself.'
              : 'Your own trusted links (add / reorder / remove):',
          style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
        ),
        for (var i = 0; i < userLinks.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.person, color: Color(0xFF808080)),
            title: Text(
              userLinks[i]['name'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              userLinks[i]['url'] ?? '',
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  onPressed: i == 0
                      ? null
                      : () async {
                          final link = userLinks.removeAt(i);
                          userLinks.insert(i - 1, link);
                          await AppStorage.setUserTokenSources(
                            List.of(userLinks),
                          );
                          setState(() {});
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  onPressed: i == userLinks.length - 1
                      ? null
                      : () async {
                          final link = userLinks.removeAt(i);
                          userLinks.insert(i + 1, link);
                          await AppStorage.setUserTokenSources(
                            List.of(userLinks),
                          );
                          setState(() {});
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () async {
                    userLinks.removeAt(i);
                    await AppStorage.setUserTokenSources(List.of(userLinks));
                    setState(() {});
                    if (mounted) showInfo(context, 'Link removed.');
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            final name = await promptText(
              context,
              title: 'Add your own link',
              label: 'Name (e.g. Company X token page)',
            );
            if (name == null || name.trim().isEmpty || !mounted) return;
            final url = await promptText(
              context,
              title: 'Add your own link',
              label: 'URL (https:// only)',
              keyboardType: TextInputType.url,
              validator: (v) => v.trim().startsWith('https://')
                  ? null
                  : 'Only https:// links are accepted here.',
            );
            if (url == null || !mounted) return;
            final links = [
              for (final e in AppStorage.userTokenSources) Map.of(e),
            ];
            links.add({'name': name.trim(), 'url': url.trim()});
            await AppStorage.setUserTokenSources(List.of(links));
            setState(() {});
            if (mounted) showInfo(context, 'Link added to your own list.');
          },
          icon: const Icon(Icons.add_link),
          label: const Text('Add your own link…'),
        ),
      ],
    );
  }

  /// Opens a trusted source link on Linux; on other platforms (Android for
  /// now) the link is copied so the user has full control of their browser.
  Future<void> _openSourceUrl(String url) async {
    if (url.isEmpty) return;
    if (!url.startsWith('https://')) {
      if (mounted) showInfo(context, 'Only https links can be opened.');
      return;
    }
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        if (mounted) showInfo(context, 'Opened $url in your browser.');
      } else {
        if (mounted) {
          await copyText(context, url, 'Link');
          if (mounted) {
            showInfo(context, 'Link copied — paste it into your browser.');
          }
        }
      }
    } catch (error) {
      if (mounted) showError(context, 'Could not open the link: $error');
    }
  }

  Future<void> _testHistory() async {
    final wallet = appState.address;
    if (wallet == null) {
      showError(context, 'Unlock or load a wallet address first.');
      return;
    }
    if (appState.bscscanKey == null) {
      showError(context, 'Add a BscScan API key first.');
      return;
    }
    final started = DateTime.now();
    try {
      final rows = await appState.rpc.history(wallet);
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final report = StringBuffer()
        ..writeln('BscScan history test')
        ..writeln('Wallet: $wallet')
        ..writeln('Network: ${appState.rpc.network}')
        ..writeln('API: BscScan V1 (Etherscan-compatible)')
        ..writeln('Rows returned: ${rows.length}')
        ..writeln('Elapsed: $elapsed ms')
        ..writeln('');
      for (final row in rows.take(10)) {
        report
          ..writeln('Tx: ${row.hash}')
          ..writeln('  from: ${row.from}')
          ..writeln('  to: ${row.to}')
          ..writeln('  value (wei): ${row.value}')
          ..writeln('  timestamp: ${row.timestamp}')
          ..writeln('  status: ${row.isError ? 'FAILED' : 'OK'}');
      }
      report.writeln('');
      report.writeln('RESULT: PASS — the API key works and history was read.');
      final text = report.toString();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('History test passed'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History test log copied.')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy log'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showError(context, 'History test failed: $error');
    }
  }

  Widget _historyKeySection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Transaction history'),
          const SizedBox(height: 8),
          const Text(
            'History uses the public BscScan API V1 (Etherscan-compatible). '
            'You need a free BscScan API key; the free tier is enough for '
            'normal account history. Create one at bscscan.com/myapikey, then '
            'paste it below. The key is stored in secure on-device storage. '
            'Without a key, the wallet still works; only explorer history is '
            'unavailable.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Process.run('xdg-open', const [
                  'https://bscscan.com/myapikey',
                ]),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open BscScan API keys'),
              ),
              OutlinedButton.icon(
                onPressed: _testHistory,
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('Test history now'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (appState.bscscanKey == null) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final key = await promptText(
                  context,
                  title: 'BscScan API key',
                  label: 'API key (hidden)',
                  obscure: true,
                );
                if (key == null || key.isEmpty || !mounted) return;
                await appState.setBscscanKey(key);
                if (!mounted) return;
                showInfo(context, 'API key saved.');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add API key'),
            ),
          ] else ...[
            Text(
              'API key configured (hidden).',
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => appState.setBscscanKey(null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove API key'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _appearanceSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Display'),
          const SizedBox(height: 4),
          const Text(
            'Lite mode keeps the same facts and honest states but removes the '
            'pulsing animation and shortens list motion — useful on a weak '
            'device or when animations are distracting.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lite mode'),
            subtitle: const Text(
              'No pulse; static state icons and progress bar',
            ),
            value: appState.liteMode,
            onChanged: appState.setLiteMode,
          ),
          const Divider(height: 24),
          const Text(
            'Theme affects the entire app. AMOLED black saves power on OLED screens.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Theme'),
            subtitle: Text(
              _themeLabel(appState.themeModeIndex),
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context),
          ),
          const Divider(height: 24),
          Text(
            'Navigation labels update immediately. Detailed wallet and security '
            'instructions are currently English; they are never presented as translated when they are not.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Language'),
            subtitle: Text(
              _languageLabel(appState.locale),
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),
        ],
      ),
    );
  }

  String _themeLabel(int index) {
    switch (index) {
      case 1:
        return 'Light';
      case 2:
        return 'Dark';
      case 3:
        return 'AMOLED black';
      default:
        return 'System default';
    }
  }

  String _languageLabel(String locale) {
    switch (locale) {
      case 'fa':
        return 'فارسی (Persian)';
      case 'ar':
        return 'العربية (Arabic)';
      case 'zh':
        return '中文 (Chinese)';
      case 'ru':
        return 'Русский (Russian)';
      case 'es':
        return 'Español (Spanish)';
      default:
        return 'English';
    }
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final theme = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select theme'),
        children: [
          RadioGroup<int>(
            groupValue: appState.themeModeIndex,
            onChanged: (value) => Navigator.pop(dialogContext, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  title: const Text('System default'),
                  value: 0,
                ),
                RadioListTile<int>(title: const Text('Light'), value: 1),
                RadioListTile<int>(title: const Text('Dark'), value: 2),
                RadioListTile<int>(title: const Text('AMOLED black'), value: 3),
              ],
            ),
          ),
        ],
      ),
    );
    if (theme != null) {
      await appState.setThemeMode(theme);
    }
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final locale = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select language'),
        children: [
          RadioGroup<String>(
            groupValue: appState.locale,
            onChanged: (value) => Navigator.pop(dialogContext, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                ),
                RadioListTile<String>(
                  title: const Text('فارسی (Persian)'),
                  value: 'fa',
                ),
                RadioListTile<String>(
                  title: const Text('العربية (Arabic)'),
                  value: 'ar',
                ),
                RadioListTile<String>(
                  title: const Text('中文 (Chinese)'),
                  value: 'zh',
                ),
                RadioListTile<String>(
                  title: const Text('Русский (Russian)'),
                  value: 'ru',
                ),
                RadioListTile<String>(
                  title: const Text('Español (Spanish)'),
                  value: 'es',
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (locale != null) {
      await appState.setLocale(locale);
      if (!context.mounted) return;
      showInfo(context, 'Language changed. Navigation labels updated.');
    }
  }

  Future<String?> _pickBackupPath({required bool save}) async {
    final home = Platform.environment['HOME'] ?? '';
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        if (save) '--save',
        if (save) '--confirm-overwrite',
        if (save) '--filename=$home/x-wallet-backup.bnb',
      ]);
      if (result.exitCode == 0) {
        final path = '${result.stdout}'.trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {
      // Fall through to a typed path.
    }
    if (!mounted) return null;
    return promptText(
      context,
      title: save ? 'Backup file path' : 'Backup file to restore',
      label: 'Absolute path',
      hintText: save
          ? '$home/x-wallet-backup.bnb'
          : '$home/x-wallet-backup.bnb',
      validator: (value) => value.trim().isEmpty ? 'Path required' : null,
    );
  }

  Future<void> _exportBackup() async {
    final path = await _pickBackupPath(save: true);
    if (path == null || !mounted) return;
    final password = await promptText(
      context,
      title: 'Export encrypted backup',
      label: 'Vault password',
      obscure: true,
      validator: (value) => value.isEmpty ? 'Password required' : null,
    );
    if (password == null || !mounted) return;
    try {
      await appState.exportVault(password, path);
      if (mounted) showInfo(context, 'Encrypted backup written to $path.');
    } catch (error) {
      if (mounted) showError(context, 'Backup failed: $error');
    }
  }

  Future<void> _restoreBackup() async {
    final path = await _pickBackupPath(save: false);
    if (path == null || !mounted) return;
    final password = await promptText(
      context,
      title: 'Restore encrypted backup',
      label: 'Backup password',
      obscure: true,
      validator: (value) => value.isEmpty ? 'Password required' : null,
    );
    if (password == null || !mounted) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Replace the active vault?',
      message:
          'The selected backup will replace the current vault only after its '
          'password and integrity are verified. Keep a copy of the current '
          'vault if you are unsure.',
      confirmLabel: 'Restore backup',
    );
    if (!confirmed || !mounted) return;
    try {
      await appState.importVault(
        path,
        password: password,
        confirmReplace: true,
      );
      if (mounted) showInfo(context, 'Backup restored from $path.');
    } catch (error) {
      if (mounted) showError(context, 'Restore failed: $error');
    }
  }

  Future<void> _changeVaultPath() async {
    final path = await promptText(
      context,
      title: 'Move encrypted vault',
      label: 'New absolute vault file path',
      hintText: tr(context, '/home/you/secure/x-wallet-vault.bnb'),
      validator: (value) => value.trim().isEmpty ? 'Path required' : null,
    );
    if (path == null || !mounted) return;
    final password = await promptText(
      context,
      title: 'Confirm vault password',
      label: 'Vault password',
      obscure: true,
      validator: (value) => value.isEmpty ? 'Password required' : null,
    );
    if (password == null || !mounted) return;
    try {
      await appState.moveVault(password, path.trim());
      if (mounted) showInfo(context, 'Vault moved to ${path.trim()}.');
    } catch (error) {
      if (mounted) showError(context, 'Vault move failed: $error');
    }
  }

  Future<void> _resetVaultPath() async {
    try {
      await appState.resetVaultPath();
      if (mounted) showInfo(context, 'Vault location reset to the default.');
    } catch (error) {
      if (mounted) showError(context, 'Could not reset vault location: $error');
    }
  }

  Widget _storageSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Storage and data'),
          const SizedBox(height: 8),
          Text(
            'The vault, receipts, and activity log are encrypted at rest. '
            'These paths are local to this device and are never uploaded.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Directory>(
            future: AppStorage.getDataDirectory(),
            builder: (context, dataSnapshot) {
              final dataPath = dataSnapshot.data?.path;
              return FutureBuilder<File>(
                future: AppStorage.vaultFile(),
                builder: (context, vaultSnapshot) {
                  final vaultPath = vaultSnapshot.data?.path;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        'Data folder: ${dataPath ?? 'loading…'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'Vault file: ${vaultPath ?? 'loading…'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: dataPath == null
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(text: dataPath),
                                    );
                                    showInfo(context, 'Data folder copied.');
                                  },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy data path'),
                          ),
                          OutlinedButton.icon(
                            onPressed: vaultPath == null
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(text: vaultPath),
                                    );
                                    showInfo(context, 'Vault path copied.');
                                  },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy vault path'),
                          ),
                          OutlinedButton.icon(
                            onPressed: dataPath == null
                                ? null
                                : () => Process.run('xdg-open', [dataPath]),
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Open data folder'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _changeVaultPath,
                            icon: const Icon(Icons.drive_file_move, size: 16),
                            label: const Text('Move vault'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _resetVaultPath,
                            icon: const Icon(
                              Icons.settings_backup_restore,
                              size: 16,
                            ),
                            label: const Text('Reset vault path'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _exportBackup,
                            icon: const Icon(Icons.save_alt, size: 16),
                            label: const Text('Export encrypted backup'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _restoreBackup,
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restore backup'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'The vault can be moved with the existing vault move flow. '
            'Receipts follow the vault folder; the activity log and device '
            'secret stay in the data folder.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _securitySection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('App lock'),
          const SizedBox(height: 8),
          const Text(
            'Optional PIN or biometrics to reopen the app after it goes to the background.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            title: const Text('Enable app lock'),
            value: appState.usePin,
            onChanged: (value) async {
              if (value) {
                final set = await _askSetPin(context);
                if (!set || !context.mounted) return;
                await appState.setUsePin(true);
              } else {
                await appState.setUsePin(false);
              }
            },
            secondary: appState.usePin
                ? Icon(
                    Icons.lock,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : const Icon(Icons.lock_open, color: Color(0xFF6E6E6E)),
          ),
          if (appState.usePin) ...[
            const SizedBox(height: 4),
            Text(
              'Background lock is active.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
          ],
          const Divider(height: 26),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Verify recovery phrase'),
            subtitle: Text(
              appState.mnemonic == null
                  ? 'Not available for this key import.'
                  : 'Re-type three random words from your paper backup. '
                        'Nothing is revealed on screen.',
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: appState.mnemonic != null,
            onTap: appState.mnemonic == null
                ? null
                : () async {
                    final passed = await runBackupQuiz(
                      context,
                      appState.mnemonic!,
                    );
                    if (!mounted) return;
                    if (passed) {
                      showInfo(context, 'Backup verified.');
                    }
                  },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: const Text('Logs'),
            subtitle: const Text(
              'A plain-words timeline (Simple) and the full technical record '
              '(Expert). Stored encrypted; never sent anywhere.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const LogsPage())),
          ),
        ],
      ),
    );
  }

  Future<bool> _askSetPin(BuildContext context) async {
    final first = await promptText(
      context,
      title: 'Set app PIN',
      label: 'New PIN (hidden)',
      obscure: true,
      keyboardType: TextInputType.number,
      validator: (value) =>
          value.length >= 4 ? null : 'PIN must be at least 4 digits.',
    );
    if (first == null || first.isEmpty || !context.mounted) return false;
    final confirm = await promptText(
      context,
      title: 'Confirm app PIN',
      label: 'Confirm PIN (hidden)',
      obscure: true,
      keyboardType: TextInputType.number,
      validator: (value) => value == first ? null : 'PINs do not match.',
    );
    if (confirm == null || confirm != first || !context.mounted) return false;
    try {
      await AppSecurity.setPin(first);
      if (context.mounted) showInfo(context, 'App PIN set.');
      return true;
    } catch (error) {
      if (context.mounted) showError(context, error);
      return false;
    }
  }

  Widget _aboutSection() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('About'),
          const SizedBox(height: 8),
          const Text(
            'X Wallet 1.1.0',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Local, non-custodial EVM wallet. Version 1.1.0 enables BNB Smart Chain; more EVM networks are planned.',
          ),
          const SizedBox(height: 8),
          const Text(
            'License: AGPL-3.0-or-later (see LICENSE in the app package).',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          const Text(
            'Check the build yourself: verify SHA256SUMS '
            '(sha256sum -c SHA256SUMS). If a signature is published, verify it '
            'against an independently obtained fingerprint before installing.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          const Text(
            'Component inventory: docs/SBOM.json in the app package.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Made by jackh0006',
            style: TextStyle(color: Color(0xFFF0B90B)),
          ),
          const SizedBox(height: 2),
          const Text(
            'jackh109867@gmail.com',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _showAdvantages,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Advantages'),
              ),
              OutlinedButton.icon(
                onPressed: () => Process.run('xdg-open', const [
                  'https://github.com/jackh0006/X-Wallet/blob/main/docs/HIGH_VALUE_CUSTODY.md',
                ]),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Risk controls on GitHub'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDonationsDialog(context),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Project donations'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAdvantages() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Why X Wallet'),
        content: const SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Text(
              '• Your keys and recovery phrase stay on your device.\n\n'
              '• The vault is encrypted with Argon2id and '
              'XChaCha20-Poly1305.\n\n'
              '• Transactions are signed locally and reviewed field by '
              'field before signing.\n\n'
              '• Tor, SOCKS5, SOCKS5h, and HTTP CONNECT are built in, with '
              'fail-closed routing.\n\n'
              '• Cold and offline signing is available in the same app.\n\n'
              '• Activity logs and receipts are encrypted at rest.\n\n'
              '• The wallet is free, open source, and has no ads or '
              'recurring fees.\n\n'
              'Risk controls and custody guidance: '
              'github.com/jackh0006/X-Wallet/blob/main/docs/HIGH_VALUE_CUSTODY.md',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _transportLabel(RpcNode node) {
    final effective = node.transport == NodeTransport.inherit
        ? (appState.torEnabled ? NodeTransport.tor : NodeTransport.direct)
        : node.transport;
    return _transportLabelFromEnum(effective);
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

  Future<void> _editNodeTransport(
    int index,
    RpcNode node, {
    NodeTransport? preset,
  }) async {
    final choice =
        preset ??
        await showDialog<NodeTransport>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text('Transport for "${node.label}"'),
            children: [
              for (final t in NodeTransport.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(_transportLabelFromEnum(t)),
                ),
            ],
          ),
        );
    if (choice == null || !mounted) return;
    if (choice == NodeTransport.customProxy ||
        choice == NodeTransport.httpConnect) {
      final current = node.proxyHost == null
          ? ''
          : '${choice == NodeTransport.httpConnect ? 'http' : 'socks5h'}://'
                '${node.proxyHost}:${node.proxyPort ?? ''}';
      final url = await promptText(
        context,
        title: _transportLabelFromEnum(choice),
        label: 'Paste proxy URL (optional)',
        hintText: tr(
          context,
          'socks5h://user:pass@host:1080 or https://host:8080',
        ),
        initialValue: current,
        validator: (v) {
          final text = v.trim();
          if (text.isEmpty) return null;
          return GlobalProxyConfig.fromUrl(text) == null
              ? 'Not a supported proxy URL.'
              : null;
        },
      );
      if (url == null || !mounted) return;
      if (url.trim().isNotEmpty) {
        final parsed = GlobalProxyConfig.fromUrl(url);
        if (parsed == null) {
          if (mounted) showError(context, 'Unsupported proxy URL.');
          return;
        }
        final effective = parsed.type == ProxyType.httpConnect
            ? NodeTransport.httpConnect
            : NodeTransport.customProxy;
        await appState.setNodeTransport(
          index,
          effective,
          proxyHost: parsed.host,
          proxyPort: parsed.port,
          proxyUser: parsed.username,
          proxyPass: parsed.password,
        );
        if (mounted) showInfo(context, 'Proxy updated for ${node.label}.');
        return;
      }
      final host = await promptText(
        context,
        title: _transportLabelFromEnum(choice),
        label: 'Proxy host (domain or IP)',
        initialValue: node.proxyHost ?? '',
        validator: (v) => v.trim().isEmpty ? 'Host required' : null,
      );
      if (host == null || !mounted) return;
      final port = await promptText(
        context,
        title: _transportLabelFromEnum(choice),
        label: 'Proxy port',
        initialValue:
            '${node.proxyPort ?? (choice == NodeTransport.httpConnect ? 8080 : 1080)}',
        keyboardType: TextInputType.number,
        validator: (v) {
          final p = int.tryParse(v);
          return (p != null && p > 0 && p < 65536)
              ? null
              : 'Valid port required';
        },
      );
      if (port == null || !mounted) return;
      final user = await promptText(
        context,
        title: '${_transportLabelFromEnum(choice)} (optional)',
        label: 'Username (empty for none)',
        initialValue: node.proxyUser ?? '',
      );
      if (user == null || !mounted) return;
      String? pass;
      if (user.isNotEmpty) {
        pass = await promptText(
          context,
          title: _transportLabelFromEnum(choice),
          label: 'Password',
          obscure: true,
        );
        if (pass == null || !mounted) return;
      }
      await appState.setNodeTransport(
        index,
        choice,
        proxyHost: host.trim(),
        proxyPort: int.parse(port.trim()),
        proxyUser: user.isEmpty ? null : user.trim(),
        proxyPass: pass,
      );
    } else {
      await appState.setNodeTransport(index, choice);
    }
    if (mounted) showInfo(context, 'Transport updated for ${node.label}.');
  }

  Future<void> _editNodeAuth(int index, RpcNode node) async {
    final choice = await showDialog<NodeAuthType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Authentication for "${node.label}"'),
        children: [
          for (final t in NodeAuthType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(_authTypeLabel(t)),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    String? token;
    String? username;
    String? password;

    if (choice == NodeAuthType.bearer) {
      token = await promptText(
        context,
        title: 'Bearer token',
        label: 'Token (will be stored encrypted in vault)',
        obscure: true,
        validator: (v) => v.trim().isEmpty ? 'Token required' : null,
      );
      if (token == null || !mounted) return;
    } else if (choice == NodeAuthType.basic) {
      username = await promptText(
        context,
        title: 'Basic auth',
        label: 'Username',
        initialValue: node.authUsername ?? '',
        validator: (v) => v.trim().isEmpty ? 'Username required' : null,
      );
      if (username == null || !mounted) return;
      password = await promptText(
        context,
        title: 'Basic auth',
        label: 'Password (will be stored encrypted in vault)',
        obscure: true,
        validator: (v) => v.trim().isEmpty ? 'Password required' : null,
      );
      if (password == null || !mounted) return;
    }

    await appState.setNodeAuth(
      index,
      choice,
      authToken: token,
      authUsername: username,
      authPassword: password,
    );
    if (mounted) showInfo(context, 'Authentication updated for ${node.label}.');
  }

  Future<void> _editNodePinning(int index, RpcNode node) async {
    final current = node.pinnedSpkiHashes.join('\n');
    final pins = await promptText(
      context,
      title: 'Certificate pinning (SPKI)',
      label: 'Base64 SHA-256 of SPKI (one per line)',
      initialValue: current,
      maxLines: 5,
      hintText: tr(
        context,
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\nBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
      ),
    );
    if (pins == null || !mounted) return;
    final pinList = pins
        .trim()
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    await appState.setNodePinning(index, pinList);
    if (mounted) {
      showInfo(context, 'Certificate pinning updated for ${node.label}.');
    }
  }

  Future<void> _editNodeSelection(int index, RpcNode node) async {
    final useForReads = await _askBool(
      context,
      'Use for reads?',
      'Whether this node should be used for balance queries, token info, etc.',
      initialValue: node.useForReads,
    );
    if (!mounted || useForReads == null) return;
    final useForBroadcast = await _askBool(
      context,
      'Use for broadcast?',
      'Whether this node should be used for sending transactions.',
      initialValue: node.useForBroadcast,
    );
    if (!mounted || useForBroadcast == null) return;

    final selectionMode = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Selection mode'),
        children: [
          for (final entry in const [
            (0, 'Manual'),
            (1, 'Auto-fastest'),
            (2, 'Round-robin / random'),
            (3, 'Quorum'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, entry.$1),
              child: Text(entry.$2),
            ),
        ],
      ),
    );
    if (selectionMode == null || !context.mounted) return;

    await appState.setNodeSelection(
      index,
      useForReads: useForReads,
      useForBroadcast: useForBroadcast,
      selectionMode: selectionMode,
    );
    if (mounted) {
      showInfo(context, 'Selection settings updated for ${node.label}.');
    }
  }

  String _authTypeLabel(NodeAuthType t) {
    switch (t) {
      case NodeAuthType.none:
        return 'None';
      case NodeAuthType.bearer:
        return 'Bearer token';
      case NodeAuthType.basic:
        return 'Basic auth';
    }
  }

  Future<bool?> _askBool(
    BuildContext context,
    String title,
    String message, {
    bool initialValue = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// §10f Wallet mode selector: hot / cold / online.
  Widget _walletModeSection() {
    return InfoCard(
      child: RadioGroup<int>(
        groupValue: appState.walletModeIndex,
        onChanged: (value) {
          if (value != null) appState.setWalletMode(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Wallet mode (§10f)'),
            const SizedBox(height: 4),
            const Text(
              'Hot wallet holds the seed and can sign. Cold (offline signer) holds '
              'the seed but uses no network. Online companion holds no secrets — '
              'it prepares and broadcasts for a cold device.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Normal (hot wallet)'),
              subtitle: const Text('Default — holds seed, signs, broadcasts'),
              value: 0,
              secondary: Icon(
                Icons.wallet,
                color: appState.hotMode ? Colors.amber : Color(0xFF808080),
              ),
            ),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cold (offline signer)'),
              subtitle: const Text(
                'Holds seed, no network — signs requests offline',
              ),
              value: 1,
              secondary: Icon(
                Icons.smartphone,
                color: appState.coldMode ? Colors.amber : Color(0xFF808080),
              ),
            ),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Online (watch-only companion)'),
              subtitle: const Text(
                'No secrets — prepares & broadcasts for cold device',
              ),
              value: 2,
              secondary: Icon(
                Icons.wifi_tethering,
                color: appState.onlineMode ? Colors.amber : Color(0xFF808080),
              ),
            ),
            if (appState.coldMode) ...[
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code, color: Colors.amber),
                title: const Text('Export for online device'),
                subtitle: const Text('QR / file with public addresses only'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldExportPairing(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_document, color: Colors.amber),
                title: const Text('Sign a request offline'),
                subtitle: const Text(
                  'Paste / read the online device\'s request',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldSignPendingRequest(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_2, color: Colors.amber),
                title: const Text('Show last signed response'),
                subtitle: const Text('QR / file to carry back online'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldShowLastSignature(context),
              ),
            ],
            if (appState.onlineMode) ...[
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: Colors.amber),
                title: const Text('Import cold pairing'),
                subtitle: const Text('Verify the fingerprint, then watch only'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldImportPairing(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_2, color: Colors.amber),
                title: const Text('Show pending request'),
                subtitle: const Text('Request to carry to the cold signer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldShowPendingRequest(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user, color: Colors.amber),
                title: const Text('Import signed response'),
                subtitle: const Text('Verify strictly, then broadcast'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => coldImportAndBroadcastSignature(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Node selection mode (global) — R7.
  Widget _selectionModeSection() {
    return InfoCard(
      child: RadioGroup<NodeSelectionMode>(
        groupValue: appState.selectionMode,
        onChanged: (value) {
          if (value != null) appState.setSelectionMode(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Node selection mode'),
            const SizedBox(height: 4),
            const Text(
              'How the wallet picks which RPC node to talk to for reads and '
              'broadcasts. Per-node "use for reads / broadcast" overrides are set '
              'in the node list.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            RadioListTile<NodeSelectionMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Manual'),
              subtitle: const Text('Always use the selected node'),
              value: NodeSelectionMode.manual,
            ),
            RadioListTile<NodeSelectionMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-fastest'),
              subtitle: const Text('Always pick the fastest-responding node'),
              value: NodeSelectionMode.autoFastest,
            ),
            RadioListTile<NodeSelectionMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Round-robin / random'),
              subtitle: const Text('Rotate through enabled nodes for privacy'),
              value: NodeSelectionMode.roundRobin,
            ),
            RadioListTile<NodeSelectionMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quorum'),
              subtitle: const Text('Query N nodes and cross-check answers'),
              value: NodeSelectionMode.quorum,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import '../localized_text.dart';

import '../app_state.dart';
import '../models.dart';
import '../rpc_service.dart';
import '../price_service.dart';
import '../rpc_story.dart';
import '../token_logos.dart';
import '../token_registry.dart';
import 'common.dart';
import 'wallet_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  Map<String, BigInt>? _balances;
  int? _nonce;
  int? _block;
  RpcProbeResult? _manualProbe;
  String? _error;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    _refresh();
  }

  @override
  void dispose() {
    _stateDebounce?.cancel();
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  Timer? _stateDebounce;
  bool _refreshing = false;

  void _onStateChanged() {
    if (!mounted) return;
    // Round-5 freeze fix: the connection-story lines from RPC work notify
    // this same state. Refreshing instantly on every notify re-entered the
    // story bus (81k+ stack frames in production — the Ubuntu "Force
    // Quit / Wait"). Wait for 400 ms of quiet instead.
    _stateDebounce?.cancel();
    _stateDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!appState.unlocked || appState.address == null) {
      setState(() {
        _balances = null;
        _nonce = null;
        _block = null;
        _error = null;
      });
      return;
    }
    // Round-5 freeze fix: never re-enter, and never narrate from inside the
    // refresh — narration notifies this very listener, which used to
    // re-trigger the refresh in an unbounded synchronous cycle
    // (81k+ stack frames in production).
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balances = await loadBalances(appState.address!);
      final rpc = appState.rpc;
      await rpc.ensureConnected();
      final nonce = await rpc.getNonce(appState.address!);
      final block = await rpc.getBlockNumber();
      if (!mounted) return;
      setState(() {
        _balances = balances;
        _nonce = nonce;
        _block = block;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rpc = appState.rpc;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/icon/x-wallet-1024.png',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('X Wallet'),
                Text(
                  'BSC Mainnet · chain 56',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'Refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (!appState.unlocked)
              _welcomeCard()
            else ...[
              AnimatedBuilder(
                animation: PriceService.instance,
                builder: (context, _) => _heroCard(),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: PriceService.instance,
                builder: (context, _) => _assetsCard(),
              ),
            ],
            const SizedBox(height: 14),
            _noticeCard(),
            const SizedBox(height: 14),
            _storyCard(rpc),
            const SizedBox(height: 14),
            _nodeCard(rpc),
          ],
        ),
      ),
    );
  }

  Widget _storyCard(RpcService rpc) {
    final lines = rpc.story;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, color: Color(0xFFF0B90B)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Connection story — what just happened, in plain words',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Forget the story'),
                onPressed: rpc.clearStory,
                icon: const Icon(Icons.clear_all, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            const Text(
              'Nothing yet. Every time I check the blockchain I will write one '
              'line here telling you what I did, whom I asked, how long it '
              'took, and your keys never left this device.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            )
          else
            Container(
              height: 240,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (context, index) => _storyTile(lines[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _storyTile(RpcStoryLine line) {
    final color = switch (line.kind) {
      RpcStoryKind.ok => const Color(0xFF6FCF97),
      RpcStoryKind.fail => Colors.redAccent,
      RpcStoryKind.wait => const Color(0xFFF0B90B),
      RpcStoryKind.info => Color(0xFF6E6E6E),
    };
    final icon = switch (line.kind) {
      RpcStoryKind.ok => Icons.check_circle_outline,
      RpcStoryKind.fail => Icons.error_outline,
      RpcStoryKind.wait => Icons.hourglass_disabled,
      RpcStoryKind.info => Icons.subdirectory_arrow_right,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: line.clock,
                    style: TextStyle(
                      color: Color(0xFF808080),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: line.detail == null
                        ? line.text
                        : '${line.text} · ${line.detail}',
                    style: TextStyle(color: color, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeCard(RpcService rpc) {
    final probe = _manualProbe ?? rpc.lastProbe;
    final ms = probe?.latencyMs;
    final connected = rpc.isConnected;
    final rightChain = probe?.chainId == rpc.chainId;
    final face = !connected
        ? Icons.bedtime_outlined
        : (ms == null
              ? Icons.help_outline
              : (ms < 250
                    ? Icons.sentiment_very_satisfied
                    : (ms < 900
                          ? Icons.sentiment_neutral
                          : Icons.sentiment_dissatisfied)));
    final faceColor = !connected
        ? Color(0xFF808080)
        : (ms == null
              ? Color(0xFF6E6E6E)
              : (ms < 250
                    ? const Color(0xFF69C77A)
                    : (ms < 900
                          ? const Color(0xFFF0B90B)
                          : const Color(0xFFFF8A65))));
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(face, color: faceColor, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rpc.network == 'mainnet' ? 'BNB Smart Chain' : 'BSC Testnet'} · chain ${rpc.chainId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Node: ${_host(rpc.activeRpc)}'
                                '${rpc.strictModeOn ? ' · strict, no fallback' : ' · fallbacks allowed'}'
                          : 'RPC not connected · tap Refresh or check the node',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (rightChain)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69C77A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'right chain',
                    style: TextStyle(color: Color(0xFF69C77A), fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ms == null
                          ? 0
                          : (ms / 1200).clamp(0.02, 1.0).toDouble(),
                      strokeWidth: 4,
                      color: faceColor,
                      backgroundColor: Color(0x33808080),
                    ),
                    Text(
                      ms == null ? '—' : '$ms',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Answer time',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    ms == null
                        ? 'not measured yet'
                        : '$ms ms · ${_speedWord(ms)}',
                    style: const TextStyle(
                      color: Color(0xFF6E6E6E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Latest block',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    _block?.toString() ?? '—',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: tr(context, 'Check this node now'),
                onPressed: connected ? _probeActive : null,
                icon: const Icon(Icons.speed, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showNodeDetails(rpc),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Color(0xFFF0B90B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Privacy route: ${rpc.routeDescription}',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF808080),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _speedWord(int ms) {
    if (ms < 250) return 'fast';
    if (ms < 900) return 'slow';
    return 'trouble';
  }

  Future<void> _probeActive() async {
    final rpc = appState.rpc;
    if (rpc.activeRpc.isEmpty) return;
    final probe = await rpc.probeNode(rpc.activeRpc);
    if (!mounted) return;
    setState(() => _manualProbe = probe);
    if (!mounted) return;
    showInfo(
      context,
      probe.ok
          ? 'Node answered in ${probe.latencyMs} ms on chain ${probe.chainId}.'
          : 'Node check failed: ${probe.reason ?? 'no answer'}',
    );
  }

  /// Asks one independent node the same chain-id question. This is a
  /// point-in-time comparison, not a quorum: it can catch a node that is on
  /// the wrong chain or badly behind, and it never signs or broadcasts.
  Future<void> _compareNode(RpcService rpc) async {
    final others = rpc.independentNodes.where((node) => node.enabled).toList();
    if (others.isEmpty) {
      showInfo(
        context,
        'No second enabled node is available. Add one under Settings → '
        'Network to compare answers.',
      );
      return;
    }
    final other = others.first;
    showInfo(context, 'Asking ${_host(other.url)} the same question…');
    final probe = await rpc.probeNode(other.url);
    if (!mounted) return;
    if (!probe.ok) {
      showInfo(
        context,
        '${_host(other.url)} did not give a usable answer: '
        '${probe.reason ?? 'no answer'}. The active node is unchanged.',
      );
      return;
    }
    final sameChain = probe.chainId == rpc.chainId;
    final mine = _block;
    final theirs = probe.blockNumber;
    final delta = (mine != null && theirs != null)
        ? (mine - theirs).abs()
        : null;
    showInfo(
      context,
      sameChain
          ? 'Same chain (${probe.chainId})'
                '${delta == null ? '.' : '; block difference $delta.'} '
                'The active node was not changed.'
          : 'Different chain: ${_host(other.url)} answered ${probe.chainId}, '
                'the wallet expects ${rpc.chainId}. Do not trust that node.',
    );
  }

  Future<void> _showNodeDetails(RpcService rpc) async {
    final probe = _manualProbe ?? rpc.lastProbe;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Node & privacy details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network: BSC ${rpc.network} · chain id ${rpc.chainId}\n'
                  'Endpoint: ${rpc.activeRpc.isEmpty ? 'none chosen' : rpc.activeRpc}\n'
                  'Route: ${rpc.routeDescription}\n'
                  'Strict mode: ${rpc.strictModeOn ? 'only this node may answer' : 'fallback nodes allowed'}\n'
                  'Last probe: ${probe == null ? 'not measured this session' : '${probe.ok ? 'answered' : 'failed'} · ${probe.latencyMs ?? '—'} ms · chain ${probe.chainId ?? '—'}'}'
                  '${probe?.reason == null ? '' : '\nReason: ${probe!.reason}'}\n'
                  'Latest block: ${_block ?? '—'}\n'
                  'Requests this session: ${rpc.requestCount}\n'
                  'Latency samples: ${rpc.latencyHistory.length} of 50\n\n'
                  'What the badges mean: "right chain" means this node answered with '
                  'the expected chain id. It is not a quorum and not proof of honesty. '
                  'The answer time is one measurement, not a speed guarantee.\n\n'
                  'The node sees the connection it terminates and the public RPC '
                  'payload. It never sees your seed, private key, password or the '
                  'other accounts on this device.',
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
                if (rpc.latencyHistory.length >= 2) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Answer-time history (oldest → newest)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(rpc.latencyHistory),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _compareNode(rpc);
            },
            child: const Text('Compare another'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              appState.focusTab(4);
            },
            child: const Text('Switch node'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _welcomeCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new wallet or import an existing one to see balances, '
            'send the native coin and EVM tokens, and manage your addresses.',
          ),
          const SizedBox(height: 14),
          const Text(
            'Use the Wallet tab to create or import a wallet, then return here '
            'to see balances and send.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: appState.hasVault
                  ? () => showUnlockVaultDialog(context, jumpToWalletTab: true)
                  : () => appState.focusTab(1),
              icon: Icon(appState.hasVault ? Icons.lock_open : Icons.add),
              label: Text(
                appState.hasVault ? 'Open my saved wallet' : 'Create a wallet',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _totalUsd() {
    final balances = _balances;
    if (balances == null) return null;
    var total = 0.0;
    var any = false;

    void add(String symbol, BigInt? raw, int decimals, String priceSymbol) {
      if (raw == null || raw < BigInt.zero) return;
      final value = PriceService.instance.usdValue(
        raw,
        decimals,
        PriceService.instance.price(priceSymbol),
      );
      if (value != null) {
        total += value;
        any = true;
      }
    }

    add('BNB', balances['BNB'], 18, 'BNB');
    for (final token in appState.tokensForNetwork.where(
      (token) => !token.native && !appState.isTokenHidden(token),
    )) {
      add(
        token.symbol,
        balances[token.symbol],
        token.decimals,
        TokenRegistry.of(token).symbol,
      );
    }
    return any ? total : null;
  }

  Widget _heroCard() {
    final address = appState.address!;
    final scheme = Theme.of(context).colorScheme;
    final total = _totalUsd();
    final bnb = _balances?['BNB'];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'BSC MAINNET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr(context, 'Copy address'),
                onPressed: () => copyText(context, address, 'Address'),
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Total balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _loading ? 'Loading…' : (total == null ? '—' : usdLabel(total)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          if (bnb != null && bnb >= BigInt.zero) ...[
            const SizedBox(height: 4),
            Text(
              '${formatToken(bnb, 18)} BNB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shortAddress(address),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => appState.focusTab(2),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showQrDialog(context, address),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Receive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assetsCard() {
    final scheme = Theme.of(context).colorScheme;
    final tokens = [
      const TokenInfo(
        symbol: 'BNB',
        name: 'BNB Smart Chain',
        address: '',
        decimals: 18,
        native: true,
      ),
      ...appState.tokensForNetwork.where(
        (token) => !token.native && !appState.isTokenHidden(token),
      ),
    ];
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'USD · CoinGecko',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'Fetching balances…',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            )
          else if (_balances == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Fetching balances…'),
            )
          else
            for (final token in tokens) _assetTile(token),
          const Divider(height: 26),
          Text(
            'nonce ${_nonce ?? '—'} · block ${_block ?? '—'}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _assetTile(TokenInfo token) {
    final scheme = Theme.of(context).colorScheme;
    final raw = _balances![token.symbol];
    final unavailable = raw == null || raw < BigInt.zero;
    final usd = unavailable
        ? null
        : PriceService.instance.usdValue(
            raw,
            token.decimals,
            PriceService.instance.price(TokenRegistry.of(token).symbol),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          TokenLogo(token: token, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TokenRegistry.of(token).symbol,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  TokenRegistry.of(token).name,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                unavailable
                    ? 'unavailable'
                    : '${formatToken(raw, token.decimals)} ${TokenRegistry.of(token).symbol}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (usd != null)
                Text(
                  usdLabel(usd),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noticeCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety notice',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hot wallet: the signing key exists in memory while unlocked. Back up '
            'your recovery phrase offline and test with small amounts — device '
            'security is part of this wallet\'s security.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'Made by jackh0006 · jackh109867@gmail.com',
            style: const TextStyle(color: Color(0xFFF0B90B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _host(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return 'custom RPC';
    }
  }
}

/// Tiny latency sparkline for the node detail card. No axes, no labels — the
/// numbers live next to it; the shape shows trend only.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(List<int> values) : values = List<int>.of(values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    var low = values.first;
    var high = values.first;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = (high - low).clamp(1, 1 << 30);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final y =
          size.height - ((values[i] - low) / span) * (size.height - 6) - 3;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = const Color(0xFFF0B90B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(path, line);
    final lastX = dx * (values.length - 1);
    final lastY =
        size.height - ((values.last - low) / span) * (size.height - 6) - 3;
    canvas.drawCircle(
      Offset(lastX, lastY),
      2.6,
      Paint()..color = const Color(0xFFF0B90B),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values.length != values.length ||
      (values.isNotEmpty && oldDelegate.values.last != values.last);
}

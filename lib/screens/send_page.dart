import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../app_state.dart';
import '../cold_wallet.dart';
import '../cold_wallet_protocol.dart';
import '../cold_wallet_service.dart';
import '../fee_engine.dart';
import '../models.dart';
import '../rpc_service.dart';
import '../send_intent.dart';
import '../token_logos.dart';
import '../tx_lifecycle.dart';
import '../wallet_core.dart';
import '../widgets/hold_to_confirm.dart';
import '../widgets/journey_map.dart';
import 'cold_wallet_dialogs.dart';
import 'common.dart';
import 'receipt_page.dart';
import 'wallet_page.dart';

/// What the fee dialog returns: the tier (or the custom fee) plus the gas
/// limit to sign with — the advanced mode may override the limit, and the
/// pre-signature verification pins whatever came out of here.
class _FeeChoice {
  const _FeeChoice(this.preset, this.gasLimit);
  final FeePreset preset;
  final BigInt gasLimit;
}

class SendPage extends StatefulWidget {
  const SendPage({super.key});
  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage>
    with AutomaticKeepAliveClientMixin {
  /// One canonical instance for the native token: the dropdown compares values by identity,
  /// so the initial selection must be the very same object the item list
  /// carries (round-7 bug: two equal-looking consts still failed the check).
  static const _nativeAsset = TokenInfo(
    symbol: 'BNB',
    name: 'BNB (native gas token)',
    address: '',
    decimals: 18,
    native: true,
  );
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _suffix = TextEditingController();
  TokenInfo _asset = _nativeAsset;
  bool _sending = false;
  TxStage? _stage;
  String _flowError = '';
  ColdTxRequest? _pendingCold;

  /// The JSON-RPC calls this send actually made, in order — rendered as the
  /// "what the node sees" panel on the review, generated, never hand-copied.
  final List<String> _nodeSees = [];
  @override
  bool get wantKeepAlive => true;

  /// Renders an address in 4-character groups — harder to skim, impossible
  /// to mis-scan flat at a glance.
  String _groupAddress(String address) {
    final clean = address.startsWith('0x') ? address.substring(2) : address;
    final groups = <String>[];
    for (var i = 0; i + 4 <= clean.length; i += 4) {
      groups.add(clean.substring(i, i + 4));
    }
    return ['0x', ...groups].join(' ');
  }

  /// Address-poisoning guard: flags recipients that share a long enough
  /// prefix/suffix (sharesAffixes) with an address the device already knows —
  /// saved profiles, the recipient history of the user — but that is NOT that
  /// address. A classic drip-list attack uses exactly such near-misses.
  String? _findLookalike(String recipient) {
    final normalized = recipient.toLowerCase();
    final known = {
      for (final p in appState.profiles) p.address.toLowerCase(),
      if (appState.address != null) appState.address!.toLowerCase(),
    };
    for (final other in known) {
      if (other == normalized) continue;
      if (WalletCore.sharesAffixes(recipient, other)) return other;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // The gate and the form are two faces of the same page: unlocking from
    // the gate (or anywhere else) must repaint this page the moment the key
    // lands in memory — the Shell's const children never rebuild themselves.
    appState.addListener(_onAppStateChanged);
    _refreshColdDesk();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {});
    _refreshColdDesk();
  }

  Future<void> _refreshColdDesk() async {
    final pending = appState.onlineMode
        ? await ColdWalletService.instance.latestPendingRequest()
        : null;
    if (!mounted) return;
    if (pending?.id != _pendingCold?.id) {
      setState(() => _pendingCold = pending);
    }
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    _to.dispose();
    _amount.dispose();
    _suffix.dispose();
    super.dispose();
  }

  List<TokenInfo> get _assets => [
    _nativeAsset,
    ...appState.rpc.tokens.where((t) => !appState.isTokenHidden(t)),
  ];
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: SafeArea(
        child: appState.coldMode
            ? _coldSignerNotice()
            : appState.onlineMode && appState.address == null
            ? _onlinePairingNotice()
            : appState.watchOnly && !appState.onlineMode
            ? _watchOnlyNotice()
            : appState.unlocked
            ? ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  if (appState.onlineMode) _coldDeskCard(),
                  _pendingCard(),
                  _journeyCard(),
                  _formCard(),
                ],
              )
            : _walletGate(),
      ),
    );
  }

  /// Cold signer: this device has no network and never prepares a request.
  /// It only signs envelopes carried over from the companion.
  Widget _coldSignerNotice() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.smartphone, color: Color(0xFFF0B90B), size: 40),
              const SizedBox(height: 12),
              const Text(
                'Cold signer — offline',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This device holds the key but no network connection. Prepare '
                'the transfer on the online companion, carry its request here, '
                'review it, and carry the signed response back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => coldSignPendingRequest(context),
                icon: const Icon(Icons.edit_document),
                label: const Text('Sign a request offline'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => coldShowLastSignature(context),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Show last signed response'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _onlinePairingNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: InfoCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, color: Color(0xFFF0B90B), size: 40),
              const SizedBox(height: 12),
              const Text(
                'Pair the cold wallet first',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This online companion holds no key. Import the public pairing '
                'from the cold device and verify the fingerprint on both '
                'screens before preparing a transfer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => appState.focusTab(4),
                icon: const Icon(Icons.settings),
                label: const Text('Open settings to pair'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coldDeskCard() {
    final pending = _pendingCold;
    if (pending == null) return const SizedBox.shrink();
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Cold signing request'),
          Text(
            'Ready for the signer. ID ${pending.id} · expires '
            '${pending.expiresAt}',
            style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    coldShowPendingRequest(context, request: pending),
                icon: const Icon(Icons.qr_code_2, size: 17),
                label: const Text('Show request'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await coldImportAndBroadcastSignature(context);
                  await _refreshColdDesk();
                },
                icon: const Icon(Icons.verified_user, size: 17),
                label: const Text('Import signed response'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A watch-only profile is readable on purpose and can never sign. Say that
  /// plainly here instead of failing later at the password prompt.
  Widget _watchOnlyNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: InfoCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: Color(0xFFF0B90B),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'This is a watch-only profile',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No key for this address exists on this device, so it cannot '
                'sign or send. Balances, history and receipts still work. To '
                'send, open the wallet that holds the key, or import the key '
                'or recovery phrase here on purpose.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  await appState.closeWatchOnly();
                  if (!mounted) return;
                  showInfo(context, 'Watch-only profile closed.');
                },
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Close watch profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// No key in memory right now. If there is a vault on this device, offer
  /// to reopen it instead of demanding a fresh import — the vault and the
  /// rest of the app must never feel like disconnected islands.
  Widget _walletGate() {
    if (appState.hasVault) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: InfoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF0B90B),
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'I found your encrypted vault on this device',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell me your vault password and I will open it — then you '
                  'can send right away. Nothing is copied anywhere; the key '
                  'stays in this phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => showUnlockVaultDialog(context),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Open my vault'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Open or import a wallet first. The Wallet tab does it in two taps.',
        ),
      ),
    );
  }

  Widget _formCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send native coin or EVM tokens',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The transaction is rehearsed on the chain first, then reviewed — '
            'recipient, raw units, fees measured from live nodes, and exactly '
            'what the node sees. BNB always pays the network fee.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TokenInfo>(
            initialValue: _asset,
            decoration: const InputDecoration(
              labelText: 'Asset',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final token in _assets)
                DropdownMenuItem(
                  value: token,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TokenLogo(token: token, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        token.native
                            ? 'BNB (native gas token)'
                            : '${token.symbol} — ${shortAddress(token.address)}',
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _asset = value);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _to,
            decoration: const InputDecoration(
              labelText: 'Recipient address',
              hintText: '0x…',
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            decoration: InputDecoration(
              labelText: 'Amount (${_asset.symbol})',
              hintText: '0.02',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _sending ? null : _review,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.preview_outlined),
            label: Text(
              _sending ? (_stage?.label ?? 'Working…') : 'Review transfer',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- journey ---
  /// The send's journey strip: six visible stops (failed is off-strip),
  /// labelled for screen readers and honest about what each stage means.
  Widget _journeyCard() {
    final stage = _stage;
    if (stage == null) return const SizedBox.shrink();
    final failed = stage == TxStage.failed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    failed ? 'Send stopped' : 'Journey: ${stage.label}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_sending)
                  TextButton(
                    onPressed: () => setState(() {
                      _stage = null;
                      _flowError = '';
                    }),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (failed && _flowError.isNotEmpty)
              Text(
                _flowError,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                ),
              )
            else
              Text(
                stage.detail,
                style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
              ),
            const SizedBox(height: 10),
            JourneyMap(
              stops: _journeyStops(stage),
              states: _journeyStates(stage),
              lite: appState.liteMode,
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap any stop for its own detail card and raw lines.',
              style: TextStyle(color: Color(0xFF808080), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  int _problemStop() {
    final message = _flowError.toLowerCase();
    final localProblem =
        message.contains('sign') ||
        message.contains('password') ||
        message.contains('phrase') ||
        message.contains('balance') ||
        message.contains('fee') ||
        message.contains('simulat') ||
        message.contains('revert') ||
        message.contains('amount');
    return localProblem ? 0 : 2;
  }

  List<JourneyState> _journeyStates(TxStage stage) {
    if (stage == TxStage.failed) {
      final problem = _problemStop();
      return [
        for (var i = 0; i < 5; i++)
          i < problem
              ? JourneyState.ok
              : (i == problem ? JourneyState.problem : JourneyState.waiting),
      ];
    }
    if (stage == TxStage.finalized) {
      return List<JourneyState>.filled(5, JourneyState.ok);
    }
    if (stage == TxStage.included) {
      return const [
        JourneyState.ok,
        JourneyState.ok,
        JourneyState.ok,
        JourneyState.working,
        JourneyState.waiting,
      ];
    }
    if (stage == TxStage.broadcast || stage == TxStage.pending) {
      return const [
        JourneyState.ok,
        JourneyState.ok,
        JourneyState.working,
        JourneyState.waiting,
        JourneyState.waiting,
      ];
    }
    if (stage == TxStage.signed) {
      return const [
        JourneyState.ok,
        JourneyState.working,
        JourneyState.waiting,
        JourneyState.waiting,
        JourneyState.waiting,
      ];
    }
    if (stage == TxStage.simulated) {
      return const [
        JourneyState.working,
        JourneyState.ok,
        JourneyState.ok,
        JourneyState.waiting,
        JourneyState.waiting,
      ];
    }
    return const [
      JourneyState.working,
      JourneyState.waiting,
      JourneyState.waiting,
      JourneyState.waiting,
      JourneyState.waiting,
    ];
  }

  List<JourneyStop> _journeyStops(TxStage stage) {
    final rpc = appState.rpc;
    final route = rpc.routeDescription;
    final shortRoute = route.toLowerCase().contains('tor')
        ? 'Tor'
        : (route.toLowerCase().contains('proxy') ? 'proxy' : 'direct');
    final host = Uri.tryParse(rpc.activeRpc)?.host ?? rpc.activeRpc;
    final reachedNode =
        stage == TxStage.simulated ||
        stage == TxStage.broadcast ||
        stage == TxStage.pending ||
        stage == TxStage.included ||
        stage == TxStage.finalized;
    final confirmed = stage == TxStage.included || stage == TxStage.finalized;
    return [
      JourneyStop(
        icon: Icons.phone_android,
        label: 'My phone',
        plainStatus: switch (stage) {
          TxStage.failed => 'stopped',
          TxStage.prepared || TxStage.simulated => 'checking',
          _ => 'signed here',
        },
        technical:
            'Entries are checked on this device and the key signs here; '
            'the seed and private key never leave it.\n'
            'Stage: ${stage.label}\n${stage.detail}',
      ),
      JourneyStop(
        icon: Icons.shield_outlined,
        label: 'Privacy',
        plainStatus: shortRoute,
        technical:
            'Active route: $route\n'
            'No app version, device model or language is sent; only the '
            'minimal RPC call is made.\n'
            'The node sees the connection it terminates, not a browser '
            'fingerprint.',
      ),
      JourneyStop(
        icon: Icons.dns_outlined,
        label: 'Node',
        plainStatus: reachedNode ? host : 'not contacted',
        technical:
            'Endpoint: ${rpc.activeRpc.isEmpty ? 'none chosen' : rpc.activeRpc}\n'
            'Chain id: ${rpc.chainId}\n'
            '${rpc.strictModeOn ? 'Strict mode: only this node may answer.' : 'Fallback nodes are allowed if this one fails.'}',
      ),
      JourneyStop(
        icon: Icons.link,
        label: 'Network',
        plainStatus: confirmed ? 'in a block' : 'waiting',
        technical:
            'Network: BSC ${rpc.network} · chain id ${rpc.chainId}\n'
            'The chain, not the node, decides whether the transaction is '
            'included. Finality is read from the chain.',
      ),
      JourneyStop(
        icon: Icons.check_circle_outline,
        label: 'Done',
        plainStatus: stage == TxStage.finalized ? 'receipt saved' : 'waiting',
        technical: stage == TxStage.finalized
            ? 'Final. The local receipt records the block, fee and the nodes '
                  'that agreed. Open it from the Receipt button.'
            : 'When the transfer is final, its receipt is saved encrypted on '
                  'this device and can be opened offline.',
      ),
    ];
  }

  // ------------------------------------------------------------ fee dialogs ---
  /// The multi-node fee quote turned into one dialog: the plain-words reason,
  /// the source/confidence line, each tier with its measured ETA and any
  /// warning, and an advanced path for a fully custom fee.
  Future<_FeeChoice?> _pickFee(
    FeeQuote quote,
    BigInt gasEstimate,
    BigInt gasLimit,
  ) {
    return showDialog<_FeeChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Network fee speed', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              quote.reason,
              style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Source: ${quote.sourceLabel} · confidence ${quote.confidence}'
              '${quote.blockSeconds != null ? ' · newest blocks ≈ ${quote.blockSeconds!.toStringAsFixed(1)} s each' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E6E6E)),
            ),
          ],
        ),
        children: [
          for (final preset in quote.presets)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(dialogContext, _FeeChoice(preset, gasLimit)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          preset.recommended
                              ? Icons.star
                              : Icons.circle_outlined,
                          size: 16,
                          color: preset.recommended
                              ? const Color(0xFFF0B90B)
                              : Color(0xFF808080),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            preset.label,
                            style: TextStyle(
                              fontWeight: preset.recommended
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _feeLine(preset, gasEstimate),
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12,
                      ),
                    ),
                    if (preset.warning != null)
                      Text(
                        '⚠ ${preset.warning}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final custom = await _customFee(quote, gasEstimate, gasLimit);
                if (custom != null && dialogContext.mounted) {
                  Navigator.pop(dialogContext, custom);
                }
              },
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Advanced: enter my own fee'),
            ),
          ),
        ],
      ),
    );
  }

  /// Custom fee: your own numbers, clearly marked as not a recommendation.
  /// The gas limit can never go below the simulation (terminal v1 rule).
  Future<_FeeChoice?> _customFee(
    FeeQuote quote,
    BigInt gasEstimate,
    BigInt gasLimit,
  ) {
    final basePreset = quote.presets[quote.recommendedIndex];
    final eip = basePreset.mode == 'eip1559';
    final priceController = TextEditingController(
      text: FeeEngine.formatGwei(
        eip
            ? basePreset.priorityFeePerGas
            : (basePreset.gasPrice ?? basePreset.maxFeePerGas),
      ),
    );
    final gasController = TextEditingController(text: gasLimit.toString());
    return showDialog<_FeeChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          String? error;
          void submit() {
            final gwei = double.tryParse(priceController.text.trim());
            final gas = BigInt.tryParse(gasController.text.trim());
            if (gwei == null || gwei <= 0) {
              setState(() => error = 'Enter a fee above zero.');
              return;
            }
            if (gas == null || gas < gasEstimate) {
              setState(
                () => error =
                    'The gas limit can never be below the simulated $gasEstimate.',
              );
              return;
            }
            final wei = BigInt.from((gwei * 1e9).round());
            if (eip) {
              final base =
                  quote.baseFeeWei ??
                  (basePreset.maxFeePerGas - basePreset.priorityFeePerGas) ~/
                      BigInt.two;
              final max = base * BigInt.two + wei;
              Navigator.pop(
                dialogContext,
                _FeeChoice(
                  FeePreset(
                    label: 'Custom',
                    target: 'your own number — not a recommendation',
                    priorityFeePerGas: wei,
                    maxFeePerGas: max,
                    expectedFeePerGas: base + wei,
                    mode: 'eip1559',
                    source: 'fee you entered (advanced)',
                    warning: 'You entered this fee yourself. If it is too small it can wait a long time.',
                  ),
                  gas,
                ),
              );
            } else {
              Navigator.pop(
                dialogContext,
                _FeeChoice(
                  FeePreset(
                    label: 'Custom',
                    target: 'your own number — not a recommendation',
                    priorityFeePerGas: BigInt.zero,
                    maxFeePerGas: wei,
                    expectedFeePerGas: wei,
                    gasPrice: wei,
                    mode: 'legacy',
                    source: 'fee you entered (advanced)',
                    warning: 'You entered this fee yourself. If it is too small it can wait a long time.',
                  ),
                  gas,
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text('Advanced fee'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eip ? 'Priority fee (gwei)' : 'Gas price (gwei)'),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Gas limit'),
                  TextField(
                    controller: gasController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The limit can never go below the simulation. A custom fee is '
                    'your own number — not a live recommendation.',
                    style: const TextStyle(
                      color: Color(0xFF6E6E6E),
                      fontSize: 11,
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Use this fee'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One fee tier rendered terminal-style: gwei rate, expected cost, the
  /// maximum reserved cap when it differs, and the measured ETA.
  String _feeLine(FeePreset preset, BigInt gasEstimate) {
    final rate = preset.maxFeePerGas;
    final expectedFee = gasEstimate * preset.expectedFeePerGas;
    final response =
        '${WalletCore.formatUnits(rate, 9)} gwei · ~${WalletCore.formatEther(expectedFee)} BNB · ${preset.target}';
    return response;
  }

  // ------------------------------------------------------------- send flow ---
  Future<void> _review() async {
    final to = _to.text.trim();
    if (!WalletCore.isValidAddress(to)) {
      showError(context, 'Enter a valid 0x recipient address.');
      return;
    }
    if (WalletCore.isZeroAddress(to)) {
      showError(context, 'The zero address cannot receive a transfer.');
      return;
    }
    final checksummed = WalletCore.checksumAddress(to);
    final from = appState.address!;
    final rpc = appState.rpc;
    // Everything the user is about to review is pinned here. The signature is
    // refused if any of it differs at sign time (terminal v1 parity).
    final reviewChainId = rpc.chainId;
    final assetDecimals = _asset.native ? 18 : _asset.decimals;
    BigInt amount;
    try {
      amount = WalletCore.parseAmount(_amount.text, assetDecimals);
    } catch (error) {
      showError(context, error);
      return;
    }
    if (amount == BigInt.zero) {
      showError(context, 'Amount must be above zero.');
      return;
    }
    setState(() {
      _sending = true;
      _stage = TxStage.prepared;
      _flowError = '';
      _nodeSees.clear();
    });
    _nodeSees.add(
      'the transaction fields (recipient, amount, fee) — checked before anything moves',
    );
    try {
      await rpc.ensureConnected();
      final prepared = sendEventNote(SendEvent.prepared);
      rpc.note(prepared.text, kind: prepared.kind);
      // Token honesty: the contract itself is asked again right before the
      // send. A drifted decimals/symbol refuses the send instead of mispricing.
      if (!_asset.native) {
        final meta = await rpc.tokenMeta(_asset.address);
        if (meta.decimals != _asset.decimals ||
            meta.symbol.toUpperCase() != _asset.symbol.toUpperCase()) {
          throw StateError(
            'The token contract now reports ${meta.symbol} with ${meta.decimals} '
            'decimals, while this wallet has ${_asset.symbol} with '
            '${_asset.decimals}. Refusing to send — remove and re-add the '
            'token in Wallet to refresh it.',
          );
        }
      }
      // Balance pre-check exactly like the terminal: refuse before gas
      // simulation when the amount alone cannot be covered.
      BigInt? balanceBefore;
      if (_asset.native) {
        final balance = await rpc.getNativeBalance(from);
        _nodeSees.add(
          'eth_getBalance — is your BNB enough for the amount and its gas?',
        );
        if (balance < amount) {
          throw StateError(
            'Insufficient BNB balance for this amount (gas also requires BNB).',
          );
        }
        balanceBefore = balance;
      } else {
        final balance = await rpc.getTokenBalance(_asset.address, from);
        _nodeSees.add(
          'eth_call balanceOf (token contract) — is your ${_asset.symbol} enough?',
        );
        if (balance < amount) {
          throw StateError('Insufficient ${_asset.symbol} balance.');
        }
      }
      final data = _asset.native
          ? Uint8List(0)
          : _erc20TransferData(checksummed, amount);
      // 1) Rehearsal of the EXACT transfer via eth_call — the simulation the
      //    spec demands. A revert here blocks with the contract's own words.
      await rpc.simulateTransfer(
        from: from,
        to: _asset.native ? checksummed : _asset.address,
        value: _asset.native ? amount : null,
        data: data,
      );
      _nodeSees.add(
        'eth_call — the exact rehearsal of this transfer (nothing is signed, nothing moves)',
      );
      final simulated = sendEventNote(SendEvent.simulated);
      rpc.note(simulated.text, kind: simulated.kind);
      if (mounted) setState(() => _stage = TxStage.simulated);
      // 2) The gas number the chain itself reports for this payload.
      final gasEstimate = await rpc.estimateGas(
        from: from,
        to: _asset.native ? checksummed : _asset.address,
        value: _asset.native ? amount : null,
        data: data,
      );
      _nodeSees.add(
        'eth_estimateGas — the same payload, asking the chain how much gas it needs',
      );
      // Terminal v1 formula: 20% headroom, rounded UP so the limit can never
      // close below the simulation.
      var gasLimit = SendIntent.gasLimitWithBuffer(gasEstimate);
      // 3) Live fees merged from several independent nodes.
      final quote = await rpc.feeQuote();
      _nodeSees.add(
        'eth_feeHistory + eth_getBlockByNumber — fee statistics and block timing (no address involved)',
      );
      if (!mounted) return;
      final choice = await _pickFee(quote, gasEstimate, gasLimit);
      if (choice == null || !mounted) {
        setState(() {
          _sending = false;
          _stage = null;
        });
        return;
      }
      final selected = choice.preset;
      gasLimit = choice.gasLimit;
      final picked = sendEventNote(SendEvent.feePicked);
      rpc.note(picked.text, kind: picked.kind);
      final expectedFee = gasEstimate * selected.expectedFeePerGas;
      final maxFee = gasLimit * selected.maxFeePerGas;
      // Required-BNB gate: amount (when native) plus the maximum reserved gas
      // cap — the terminal refuses here, before anything gets signed.
      final requiredBnb = (_asset.native ? amount : BigInt.zero) + maxFee;
      final bnbBalance = await rpc.getNativeBalance(from);
      if (bnbBalance < requiredBnb) {
        throw StateError(
          'Insufficient BNB for this transfer and its maximum gas cap '
          '(${WalletCore.formatEther(requiredBnb)} BNB required).',
        );
      }
      balanceBefore ??= bnbBalance;
      // Contract-recipient warning: the send flow is for user-controlled
      // addresses; sending tokens directly to a contract can swallow them.
      var contractWarning = '';
      try {
        if (await rpc.isContract(EthereumAddress.fromHex(checksummed))) {
          contractWarning =
              '⚠ Recipient is a CONTRACT. Check that you are not '
              'sending coins to an address that cannot return them.';
        }
        _nodeSees.add(
          'eth_getCode — checks whether the recipient is a contract',
        );
      } catch (_) {
        // Chain read failed — do not block the review, the simulation above
        // already guards balance/allowance reality.
      }
      final selfTransfer = checksummed.toLowerCase() == from.toLowerCase();
      final lookalike = _findLookalike(checksummed);
      final tokenContract =
          !_asset.native &&
          checksummed.toLowerCase() == _asset.address.toLowerCase();
      var freshRecipient = false;
      try {
        final known = <String>{
          for (final p in appState.profiles) p.address.toLowerCase(),
          from.toLowerCase(),
          for (final r in await appState.loadLocalReceipts())
            r.to.toLowerCase(),
        };
        freshRecipient = !known.contains(checksummed.toLowerCase());
      } catch (_) {
        // If the receipt history cannot be checked we simply do not claim it.
      }
      // 4) The nonce is fetched BEFORE the review so the user sees the exact
      //    number that will be signed (pending block = terminal v1 behaviour).
      final nonce = await rpc.getNonce(from);
      _nodeSees.add('eth_getTransactionCount — your address ↔ the next nonce');
      if (!mounted) return;
      final nodeHost = Uri.tryParse(rpc.activeRpc)?.host ?? rpc.activeRpc;
      final disclosure = [
        'Calls this send has made so far (what each node saw):',
        for (final line in _nodeSees) '• $line',
        '',
        appState.onlineMode
            ? 'Planned next: create an unsigned EIP-1559 request for the cold '
                  'signer. This device cannot sign and will not broadcast yet.'
            : 'Planned next: eth_sendRawTransaction — the signed public bytes '
                  '(recipient, amount, fee, signature). The exact raw bytes appear in the receipt.',
        'Not sent, ever: your name or contacts, device details, your other accounts, your seed or keys.',
        appState.torEnabled
            ? 'Your IP address is hidden behind Tor in this mode.'
            : 'Your IP address is visible to the node in direct mode.',
      ].join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review transaction'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To (full address — verify ALL of it):',
                  style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _groupAddress(checksummed),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                if (selfTransfer)
                  const Text(
                    '⚠ Recipient is THIS wallet. This transfer would only spend gas.',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (lookalike != null)
                  const Text(
                    '⚠ POISONING RISK: a similar saved address exists. Compare EVERY character.',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (tokenContract)
                  Text(
                    '⚠ The recipient IS the ${_asset.symbol} contract itself. Tokens sent to a contract usually cannot be recovered.',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (contractWarning.isNotEmpty)
                  Text(
                    contractWarning,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                if (freshRecipient)
                  const Text(
                    'First time sending to this address on this device — double-check every character.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Text(
                  'From: ${_groupAddress(from)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Amount: ${WalletCore.formatUnits(amount, assetDecimals)} ${_asset.symbol}',
                ),
                Text(
                  'Raw units sent: ${amount.toString()} ($assetDecimals decimals)',
                  style: const TextStyle(
                    color: Color(0xFF6E6E6E),
                    fontSize: 12,
                  ),
                ),
                Text('Nonce: $nonce'),
                Text(
                  'Gas simulation: ${gasEstimate.toString()} units · limit: ${gasLimit.toString()} (20% buffer)',
                ),
                Text(
                  'Expected fee: ~${WalletCore.formatEther(expectedFee)} BNB',
                ),
                Text(
                  'Maximum reserved fee: ${WalletCore.formatEther(maxFee)} BNB',
                ),
                if (maxFee != expectedFee)
                  const Text(
                    'Unused EIP-1559 headroom and gas limit are never charged.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                Text('Fee tier: ${selected.label} · ${selected.target}'),
                if (selected.warning != null)
                  Text(
                    '⚠ ${selected.warning}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  'Fee source: ${selected.source}',
                  style: const TextStyle(
                    color: Color(0xFF6E6E6E),
                    fontSize: 12,
                  ),
                ),
                const Text(
                  'Actual paid fee appears on the receipt when the chain answers.',
                  style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                ),
                Text('Network: BSC ${rpc.network} · chain ${rpc.chainId}'),
                Text(
                  'Node for this send: $nodeHost',
                  style: const TextStyle(
                    color: Color(0xFF6E6E6E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(dialogContext)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'What the node sees',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      const Text(
                        'This panel is generated from the calls this send actually made — not a fixed claim.',
                        style: TextStyle(
                          color: Color(0xFF6E6E6E),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disclosure,
                        style: const TextStyle(
                          color: Color(0xFF6E6E6E),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              copyText(dialogContext, disclosure, 'Disclosure'),
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text('Copy disclosure'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sending is irreversible. Verify the recipient and amount independently.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        setState(() {
          _sending = false;
          _stage = null;
        });
        return;
      }
      final suffix = checksummed.substring(checksummed.length - 6);
      _suffix.clear();
      final typed = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Final address check'),
          content: TextField(
            controller: _suffix,
            decoration: InputDecoration(
              labelText: 'Type the last 6 recipient characters ($suffix)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _suffix.text.trim()),
              child: Text(appState.onlineMode ? 'Continue' : 'Sign'),
            ),
          ],
        ),
      );
      if (typed != suffix) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _stage = null;
        });
        showError(
          context,
          'Recipient suffix does not match. Transaction not signed.',
        );
        return;
      }
      // §9: the final action is a deliberate hold, not a single stray click.
      if (!mounted) return;
      final held = await showHoldToConfirm(
        context,
        title: appState.onlineMode ? 'Hold to create request' : 'Hold to sign',
        message: appState.onlineMode
            ? 'The next step creates an unsigned request for the exact '
                  'transaction shown in the review. No key exists on this '
                  'device, so nothing is signed or sent. Releasing early cancels.'
            : 'The next step signs the exact transaction shown in the review. '
                  'Hold the button until it fills. Releasing early cancels — '
                  'nothing is signed, sent or charged.',
        label: appState.onlineMode ? 'Hold to create request' : 'Hold to sign',
      );
      if (!held) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _stage = null;
        });
        return;
      }
      if (!mounted) return;
      // The exact transaction that will be signed — nothing below may change
      // a field of it (pre-signature verification refuses any drift).
      final transaction = Transaction(
        from: EthereumAddress.fromHex(from),
        to: EthereumAddress.fromHex(
          _asset.native ? checksummed : _asset.address,
        ),
        value: _asset.native ? EtherAmount.inWei(amount) : null,
        data: data,
        maxGas: gasLimit.toInt(),
        nonce: nonce,
        maxFeePerGas: selected.mode == 'eip1559'
            ? EtherAmount.inWei(selected.maxFeePerGas)
            : null,
        maxPriorityFeePerGas: selected.mode == 'eip1559'
            ? EtherAmount.inWei(selected.priorityFeePerGas)
            : null,
        gasPrice: selected.mode == 'legacy'
            ? EtherAmount.inWei(selected.gasPrice ?? BigInt.zero)
            : null,
      );
      // Pre-signature intent verification (terminal v1 parity): the values
      // that WILL be signed are compared against what the user reviewed —
      // chain id, gas limit, recipient, amount, calldata and fee. Any
      // mismatch refuses the signature instead of sending the wrong thing.
      SendIntent.verify(
        chainId: rpc.chainId,
        intendedChainId: reviewChainId,
        native: _asset.native,
        intendedRecipient: checksummed,
        intendedAmount: amount,
        tokenAddress: _asset.address,
        txTo: transaction.to!.with0x,
        txValue: transaction.value?.getInWei,
        txData: transaction.data ?? Uint8List(0),
        txGasLimit: transaction.maxGas == null
            ? null
            : BigInt.from(transaction.maxGas!),
        txGasPrice: transaction.gasPrice?.getInWei,
        txMaxFeePerGas: transaction.maxFeePerGas?.getInWei,
        txMaxPriorityFeePerGas: transaction.maxPriorityFeePerGas?.getInWei,
        feeMode: selected.mode,
        expectedGasPrice: selected.gasPrice ?? BigInt.zero,
        expectedMaxFee: selected.maxFeePerGas,
        expectedPriority: selected.priorityFeePerGas,
      );
      if (appState.onlineMode) {
        if (selected.mode != 'eip1559') {
          throw StateError(
            'Cold requests currently require an EIP-1559 fee quote. The node '
            'did not provide one; try again when fee history is available.',
          );
        }
        final request = ColdWalletService.instance.createRequest(
          chainId: rpc.chainId,
          from: from,
          to: _asset.native ? checksummed : _asset.address,
          value: _asset.native ? amount : BigInt.zero,
          gasLimit: gasLimit,
          maxFeePerGas: selected.maxFeePerGas,
          maxPriorityFeePerGas: selected.priorityFeePerGas,
          nonce: nonce,
          data: bytesToHex(data, include0x: true, padToEvenLength: true),
          assetInfo: ColdTxAssetInfo(
            isNative: _asset.native,
            symbol: _asset.symbol,
            name: _asset.name,
            contractAddress: _asset.native ? null : _asset.address,
            decimals: assetDecimals,
          ),
        );
        await ColdWalletService.instance.storePendingRequest(request);
        if (!mounted) return;
        setState(() {
          _sending = false;
          _stage = null;
          _pendingCold = request;
        });
        await showColdPayloadDialog(
          context,
          title: 'Cold signing request',
          payload: ColdWalletProtocol.encodeRequest(request),
          fileName: 'bnb-cold-request-${request.id}.json',
          note:
              'No key exists on this device, so nothing was signed. Carry this '
              'request to the cold signer. It expires at ${request.expiresAt}.',
        );
        return;
      }
      if (appState.coldMode) {
        throw StateError(
          'The cold signer cannot prepare or broadcast requests.',
        );
      }
      final key = appState.privateKey;
      if (key == null) {
        throw StateError(
          'No private key is in memory. Unlock the wallet before signing.',
        );
      }
      final signedNote = sendEventNote(SendEvent.signed);
      rpc.note(signedNote.text, kind: signedNote.kind);
      _nodeSees.add(
        'eth_sendRawTransaction — the signed public bytes (recipient, amount, fee, signature)',
      );
      if (mounted) setState(() => _stage = TxStage.signed);
      // Sign locally, then broadcast. The signing and the sending are separate
      // steps so a node that answers "already known" cannot lose the hash.
      final signed = await rpc.signOnly(transaction, key);
      String hash;
      var acceptedKnown = false;
      try {
        hash = await rpc.sendRawHex(signed.rawHex);
      } catch (error) {
        final reading = readBroadcastError(error.toString());
        if (reading.verdict == BroadcastVerdict.acceptedKnown) {
          hash = signed.hash;
          acceptedKnown = true;
        } else {
          rpc.note(
            reading.plainWords,
            kind: sendEventNote(SendEvent.refused).kind,
          );
          if (mounted) {
            await showMessage(
              context,
              reading.verdict == BroadcastVerdict.unknownOutcome
                  ? 'Broadcast result is unknown'
                  : 'The node refused the transaction',
              reading.plainWords,
            );
          }
          setState(() {
            _sending = false;
            _stage = TxStage.failed;
            _flowError = reading.plainWords;
          });
          return;
        }
      }
      if (mounted) setState(() => _stage = TxStage.broadcast);
      final broadcastNote = sendEventNote(
        acceptedKnown ? SendEvent.acceptedKnown : SendEvent.broadcast,
      );
      rpc.note(broadcastNote.text, kind: broadcastNote.kind);
      // Track the pending transaction so the user can watch, speed it up or
      // cancel it — never auto-resent.
      await appState.addPendingTx(
        PendingTx(
          hash: hash,
          network: rpc.network,
          from: from,
          to: checksummed,
          native: _asset.native,
          assetSymbol: _asset.symbol,
          assetAddress: _asset.address,
          amountRaw: amount.toString(),
          amountHuman: WalletCore.formatUnits(amount, assetDecimals),
          decimals: assetDecimals,
          gasLimit: gasLimit.toString(),
          nonce: nonce,
          mode: selected.mode,
          priorityFeePerGas: selected.priorityFeePerGas.toString(),
          maxFeePerGas: selected.maxFeePerGas.toString(),
          gasPrice: (selected.gasPrice ?? BigInt.zero).toString(),
          sentAt: DateTime.now().toIso8601String(),
          tierLabel: selected.label,
        ),
      );
      if (mounted) {
        showInfo(context, 'Broadcast: $hash');
        setState(() => _stage = TxStage.pending);
      }
      // Wait for the first confirmation like the terminal does — bounded so a
      // silent node can never pin the button forever (15 × 6 s ≈ 90 s).
      TransactionReceipt? receiptInfo;
      for (var attempt = 0; attempt < 15; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 6));
        if (!mounted) return;
        try {
          receiptInfo = await rpc.receipt(hash);
        } catch (_) {
          receiptInfo = null;
        }
        if (receiptInfo != null) break;
      }
      if (!mounted) return;
      if (receiptInfo == null) {
        final waiting = sendEventNote(SendEvent.pending);
        rpc.note(
          'No confirmation seen yet; the transaction stays valid on-chain. '
          'Use "Check" in the waiting card or the explorer for the truth.',
          kind: waiting.kind,
        );
        showInfo(context, 'Still pending — check ${rpc.explorer}/tx/$hash');
        setState(() {
          _sending = false;
        });
        _to.clear();
        _amount.clear();
        _suffix.clear();
        return;
      }
      // ---- finalize: build the local receipt from chain facts ----
      final success = receiptInfo.status == true;
      final blockNumber = receiptInfo.blockNumber.useAbsolute
          ? receiptInfo.blockNumber.blockNum
          : 0;
      final blockStamp = blockNumber > 0
          ? await rpc.blockStampAt(blockNumber)
          : null;
      final latestStamp = await rpc.latestBlockStamp();
      final confirmations = latestStamp != null && blockNumber > 0
          ? latestStamp.number - blockNumber + 1
          : 0;
      final finalizedNumber = await rpc.finalizedBlockNumber();
      final isFinalized =
          finalizedNumber != null &&
          blockNumber > 0 &&
          finalizedNumber >= blockNumber;
      // Double-check the receipt against an independent node.
      var verifiedNodes = 1;
      for (final node in rpc.independentNodes.take(3)) {
        final other = await rpc.receiptFrom(node.url, hash);
        if (other != null &&
            other.blockNumber.useAbsolute &&
            other.blockNumber.blockNum == blockNumber &&
            other.status == receiptInfo.status) {
          verifiedNodes = 2;
          break;
        }
      }
      final gasUsed = receiptInfo.gasUsed ?? gasEstimate;
      final feeFromNode = receiptInfo.effectiveGasPrice != null;
      final effectivePrice = feeFromNode
          ? receiptInfo.effectiveGasPrice!.getInWei
          : selected.expectedFeePerGas;
      final feeWei = gasUsed * effectivePrice;
      String? note;
      if (!_asset.native && success) {
        final evmLogs = <EvmLog>[
          for (final log in receiptInfo.logs)
            EvmLog(
              address: log.address?.with0x ?? '',
              topics: [
                for (final topic in log.topics ?? const <String?>[]) ?topic,
              ],
              data: log.data ?? '',
            ),
        ];
        final received = findTransferAmount(
          logs: evmLogs,
          token: _asset.address,
          from: from,
          to: checksummed,
        );
        if (received == null) {
          note =
              'No Transfer event was found in the receipt — this token may be '
              'non-standard. Verify the recipient balance on the explorer.';
        } else if (received < amount) {
          note =
              'The token deducted a fee: the recipient received '
              '${WalletCore.formatUnits(received, assetDecimals)} of '
              '${WalletCore.formatUnits(amount, assetDecimals)} ${_asset.symbol}.';
        }
      }
      String? balanceAfterWei;
      try {
        final after = await rpc.getNativeBalance(from);
        balanceAfterWei = after.toString();
      } catch (_) {
        balanceAfterWei = null;
      }
      final receipt = LocalReceipt(
        hash: hash,
        network: rpc.network,
        chainId: rpc.chainId,
        status: success ? 'success' : 'reverted',
        from: from,
        to: checksummed,
        assetSymbol: _asset.symbol,
        assetAddress: _asset.address,
        amountHuman: WalletCore.formatUnits(amount, assetDecimals),
        amountRaw: amount.toString(),
        decimals: assetDecimals,
        nonce: nonce,
        gasLimit: gasLimit.toString(),
        gasUsed: gasUsed.toString(),
        feeWei: feeWei.toString(),
        blockNumber: blockNumber,
        confirmations: confirmations,
        verifiedNodes: verifiedNodes,
        finalized: isFinalized,
        tierLabel: selected.label,
        reason: quote.reason,
        nodeUsed: rpc.activeRpc,
        transport: rpc.routeDescription,
        savedAt: DateTime.now().toIso8601String(),
        blockTimestamp: blockStamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                blockStamp.time * 1000,
                isUtc: true,
              ).toIso8601String(),
        effectiveGasPriceWei: effectivePrice.toString(),
        rawTxHex: signed.rawHex,
        note: note,
        balanceBeforeWei: balanceBefore.toString(),
        balanceAfterWei: balanceAfterWei,
        blockHash: bytesToHex(
          receiptInfo.blockHash,
          include0x: true,
          padToEvenLength: true,
        ),
        transactionIndex: receiptInfo.transactionIndex,
        txType: selected.mode,
        inputData: data.isEmpty
            ? null
            : bytesToHex(data, include0x: true, padToEvenLength: true),
        eventLogs: [
          for (final log in receiptInfo.logs)
            {
              'address': log.address?.with0x ?? '',
              'topics': [
                for (final topic in log.topics ?? const <String?>[]) ?topic,
              ],
              'data': log.data ?? '',
            },
        ],
      );
      await appState.addLocalReceipt(receipt);
      await appState.removePendingTx(hash);
      if (success) {
        unawaited(_notifyConfirmed());
        final included = sendEventNote(SendEvent.included);
        rpc.note(
          'Confirmed in block $blockNumber${isFinalized ? ' — and it is final.' : '.'}',
          kind: included.kind,
        );
      } else {
        final reverted = sendEventNote(SendEvent.reverted);
        rpc.note(reverted.text, kind: reverted.kind);
      }
      if (isFinalized && success) {
        final finalizedNote = sendEventNote(SendEvent.finalized);
        rpc.note(finalizedNote.text, kind: finalizedNote.kind);
      }
      setState(
        () => _stage = success
            ? (isFinalized ? TxStage.finalized : TxStage.included)
            : TxStage.included,
      );
      final explorerUrl = rpc.network == 'testnet'
          ? 'https://testnet.bscscan.com/tx/$hash'
          : 'https://bscscan.com/tx/$hash';
      final summary = StringBuffer()
        ..writeln(
          '${WalletCore.formatUnits(amount, assetDecimals)} ${_asset.symbol} → ${shortAddress(checksummed)}',
        )
        ..writeln(
          'Block $blockNumber · ${confirmations > 0 ? '$confirmations confirmations' : 'confirmations being counted'}',
        )
        ..writeln(
          'Charged fee: ${WalletCore.formatEther(feeWei)} BNB'
          '${feeFromNode ? '' : ' (the node did not report the effective price; this is the fee you approved)'}',
        )
        ..writeln('Tx hash: $hash')
        ..writeln('Explorer: $explorerUrl');
      if (note != null) summary.writeln(note);
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(success ? 'Transfer confirmed' : 'Mined but reverted'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(summary.toString()),
                const SizedBox(height: 12),
                if (success) ...[
                  const Text(
                    'Copy the hash or open in explorer:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    hash,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    explorerUrl,
                    style: const TextStyle(
                      color: Color(0xFFF0B90B),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (success) ...[
              OutlinedButton.icon(
                onPressed: () => copyText(context, hash, 'Transaction hash'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy hash'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await launchUrl(Uri.parse(explorerUrl));
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open in explorer'),
              ),
            ],
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'receipt'),
              child: const Text('View receipt'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'receipt') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReceiptPage(receipt: receipt),
          ),
        );
      }
      setState(() {
        _sending = false;
      });
      _to.clear();
      _amount.clear();
      _suffix.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _stage = TxStage.failed;
        _flowError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '');
      });
      showError(context, error);
    }
  }

  // -------------------------------------------------------------- pending ---
  /// Local pending-transactions card: everything this device broadcast and
  /// cannot yet see as confirmed. Nothing here is ever auto-resent.
  Widget _pendingCard() {
    if (!appState.unlocked) return const SizedBox.shrink();
    final address = appState.address?.toLowerCase();
    final network = appState.rpc.network;
    final mine = [
      for (final tx in appState.pendingTxs)
        if (tx.network == network &&
            (address == null || tx.from.toLowerCase() == address))
          tx,
    ];
    if (mine.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Waiting in the network',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Transactions sent from this device that are not resolved yet. '
              'Nothing here is ever resent on its own.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const SizedBox(height: 6),
            for (final tx in mine) _pendingRow(tx),
          ],
        ),
      ),
    );
  }

  Widget _pendingRow(PendingTx tx) {
    final replaced = tx.replacedBy != null;
    final at = DateTime.tryParse(tx.sentAt);
    final age = at == null ? Duration.zero : DateTime.now().difference(at);
    final long = age.inSeconds > 120;
    final status = replaced ? 'replaced' : (long ? 'taking long' : 'waiting');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tx.amountHuman} ${tx.assetSymbol} → ${shortAddress(tx.to)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'sent ${_ageText(tx.sentAt)} ago · nonce ${tx.nonce} · ${tx.tierLabel} · $status',
            style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
          ),
          if (tx.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tx.note!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            ),
          if (replaced)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Replaced by ${shortAddress(tx.replacedBy!)} — only one of the two same-nonce transactions can confirm.',
                style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 11),
              ),
            ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => _refreshPending(tx),
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Check'),
              ),
              if (!replaced) ...[
                TextButton.icon(
                  onPressed: () => _bump(tx, cancel: false),
                  icon: const Icon(Icons.speed, size: 15),
                  label: const Text('Speed up'),
                ),
                TextButton.icon(
                  onPressed: () => _bump(tx, cancel: true),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Cancel'),
                ),
              ],
              if (replaced || long)
                TextButton.icon(
                  onPressed: () => _removePending(tx),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _ageText(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return '?';
    final waited = DateTime.now().difference(at);
    if (waited.inMinutes < 1) return '${waited.inSeconds}s';
    if (waited.inHours < 1) return '${waited.inMinutes}m';
    return '${waited.inHours}h';
  }

  Future<void> _refreshPending(PendingTx tx) async {
    final rpc = appState.rpc;
    try {
      final found = await rpc.receipt(tx.hash);
      if (!mounted) return;
      if (found != null) {
        await appState.removePendingTx(tx.hash);
        if (!mounted) return;
        showInfo(
          context,
          found.status == true
              ? 'Confirmed in block ${found.blockNumber.toString()}'
              : 'Mined but reverted — the explorer shows why',
        );
        return;
      }
      final confirmed = await rpc.getConfirmedNonce(tx.from);
      if (!mounted) return;
      if (confirmed > tx.nonce) {
        await appState.updatePendingTx(
          tx.hash,
          (p) => p.copyWith(
            note: 'dropped or replaced — the account nonce moved past it; it can never send now',
          ),
        );
        if (!mounted) return;
        showInfo(
          context,
          'The account nonce moved past this one — it was replaced or dropped.',
        );
      } else {
        showInfo(context, 'Still waiting in the network — nothing to do yet.');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _removePending(PendingTx tx) async {
    final sure = await confirmDialog(
      context,
      title: 'Remove from the waiting list?',
      message:
          'This only forgets the entry on this device. It does not stop '
          'the transaction — check the explorer first.',
      confirmLabel: 'Remove',
    );
    if (!sure || !mounted) return;
    await appState.removePendingTx(tx.hash);
  }

  /// Speed up or cancel: the SAME nonce re-signed with a ≥12.5% higher fee.
  /// Only one of the original and the replacement can confirm, and nothing
  /// is auto-resent — the user taps and confirms this on purpose.
  Future<void> _bump(PendingTx tx, {required bool cancel}) async {
    if (appState.coldMode || appState.onlineMode) {
      showError(
        context,
        'Speed-up/cancel signs locally. Do it on the device that holds the key.',
      );
      return;
    }
    final rpc = appState.rpc;
    final key = appState.privateKey;
    if (key == null || _sending) return;
    final eip = tx.mode == 'eip1559';
    final oldPriority = BigInt.tryParse(tx.priorityFeePerGas) ?? BigInt.zero;
    final oldMax = BigInt.tryParse(tx.maxFeePerGas) ?? BigInt.zero;
    final oldPrice = BigInt.tryParse(tx.gasPrice) ?? BigInt.zero;
    // Bump seed (1 gwei) is only used when an old figure was zero — it is a
    // floor for the bump itself, not a claim about the chain.
    const bumpSeed = 1000000000;
    final newPriority = bumpFee(
      oldPriority > BigInt.zero
          ? oldPriority
          : (oldMax > BigInt.zero
                ? oldMax ~/ BigInt.two
                : BigInt.from(bumpSeed)),
    );
    var newMax = bumpFee(
      oldMax > BigInt.zero ? oldMax : newPriority * BigInt.two,
    );
    if (newMax < newPriority * BigInt.two) {
      newMax = newPriority * BigInt.from(3);
    }
    final newPrice = bumpFee(
      oldPrice > BigInt.zero ? oldPrice : BigInt.from(bumpSeed),
    );
    final rateLine = eip
        ? 'priority ${FeeEngine.formatGwei(oldPriority)} → ${FeeEngine.formatGwei(newPriority)} gwei ·'
              ' max ${FeeEngine.formatGwei(oldMax)} → ${FeeEngine.formatGwei(newMax)} gwei'
        : 'gas price ${FeeEngine.formatGwei(oldPrice)} → ${FeeEngine.formatGwei(newPrice)} gwei';
    final sure = await confirmDialog(
      context,
      title: cancel ? 'Cancel this transfer?' : 'Speed this transfer up?',
      message:
          (cancel
              ? 'A cancel is a new transaction with the SAME nonce paying to '
                    'your own address. If IT confirms first, the original cannot. '
                    'The network still charges a fee for it.\n\n'
              : 'A speed-up is the same transfer re-signed with the SAME nonce '
                    'and a ≥12.5% higher fee. Only one of the two can confirm — '
                    'you pay exactly one fee.\n\n') +
          rateLine,
      confirmLabel: cancel ? 'Send cancel' : 'Send replacement',
    );
    if (!sure || !mounted) return;
    setState(() => _sending = true);
    _stage = TxStage.signed;
    try {
      final amountRaw = BigInt.parse(tx.amountRaw);
      final self = appState.address!;
      final data = (!tx.native && !cancel)
          ? _erc20TransferData(tx.to, amountRaw)
          : Uint8List(0);
      final transaction = Transaction(
        from: EthereumAddress.fromHex(self),
        to: EthereumAddress.fromHex(
          cancel ? self : (tx.native ? tx.to : tx.assetAddress),
        ),
        value: (tx.native && !cancel) ? EtherAmount.inWei(amountRaw) : null,
        data: data,
        maxGas: int.parse(tx.gasLimit),
        nonce: tx.nonce,
        maxFeePerGas: eip ? EtherAmount.inWei(newMax) : null,
        maxPriorityFeePerGas: eip ? EtherAmount.inWei(newPriority) : null,
        gasPrice: eip ? null : EtherAmount.inWei(newPrice),
      );
      SendIntent.verify(
        chainId: rpc.chainId,
        intendedChainId: BnbNetworks.chainIds[tx.network] ?? rpc.chainId,
        native: cancel || tx.native,
        intendedRecipient: cancel ? self : tx.to,
        intendedAmount: cancel ? BigInt.zero : amountRaw,
        tokenAddress: cancel ? '' : tx.assetAddress,
        txTo: transaction.to!.with0x,
        txValue: transaction.value?.getInWei,
        txData: transaction.data ?? Uint8List(0),
        txGasLimit: transaction.maxGas == null
            ? null
            : BigInt.from(transaction.maxGas!),
        txGasPrice: transaction.gasPrice?.getInWei,
        txMaxFeePerGas: transaction.maxFeePerGas?.getInWei,
        txMaxPriorityFeePerGas: transaction.maxPriorityFeePerGas?.getInWei,
        feeMode: eip ? 'eip1559' : 'legacy',
        expectedGasPrice: eip ? BigInt.zero : newPrice,
        expectedMaxFee: eip ? newMax : newPrice,
        expectedPriority: eip ? newPriority : BigInt.zero,
      );
      final signed = await rpc.signOnly(transaction, key);
      if (mounted) setState(() => _stage = TxStage.broadcast);
      String hash;
      try {
        hash = await rpc.sendRawHex(signed.rawHex);
      } catch (error) {
        final reading = readBroadcastError(error.toString());
        if (reading.verdict == BroadcastVerdict.acceptedKnown) {
          hash = signed.hash;
        } else {
          rpc.note(
            reading.plainWords,
            kind: sendEventNote(SendEvent.refused).kind,
          );
          if (mounted) {
            showMessage(
              context,
              cancel ? 'Cancel was not sent' : 'Replacement was not sent',
              reading.plainWords,
            );
          }
          return;
        }
      }
      await appState.updatePendingTx(
        tx.hash,
        (p) => p.copyWith(replacedBy: hash),
      );
      await appState.addPendingTx(
        PendingTx(
          hash: hash,
          network: tx.network,
          from: tx.from,
          to: cancel ? self : tx.to,
          native: cancel || tx.native,
          assetSymbol: cancel ? 'BNB' : tx.assetSymbol,
          assetAddress: cancel ? '' : tx.assetAddress,
          amountRaw: cancel ? '0' : tx.amountRaw,
          amountHuman: cancel ? '0' : tx.amountHuman,
          decimals: cancel ? 18 : tx.decimals,
          gasLimit: tx.gasLimit,
          nonce: tx.nonce,
          mode: tx.mode,
          priorityFeePerGas: newPriority.toString(),
          maxFeePerGas: newMax.toString(),
          gasPrice: newPrice.toString(),
          sentAt: DateTime.now().toIso8601String(),
          tierLabel: cancel ? 'cancel (+12.5% fee)' : 'speed-up (+12.5% fee)',
          note: cancel ? 'cancel' : 'speed-up',
        ),
      );
      final bumpNote = sendEventNote(
        cancel ? SendEvent.cancelled : SendEvent.replaced,
      );
      rpc.note(bumpNote.text, kind: bumpNote.kind);
      if (mounted) {
        showInfo(
          context,
          '${cancel ? 'Cancel' : 'Replacement'} sent: ${shortAddress(hash)}',
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _stage = null;
        });
      }
    }
  }

  // ------------------------------------------------------------ data bytes ---
  Uint8List _erc20TransferData(String to, BigInt amount) {
    final data = BytesBuilder();
    data.add(_hexBytes('a9059cbb'));
    data.add(_paddedAddress(to));
    data.add(_paddedUint256(amount));
    return data.toBytes();
  }

  Uint8List _hexBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(out);
  }

  Uint8List _paddedAddress(String address) {
    final body = address.startsWith('0x') ? address.substring(2) : address;
    return _hexBytes(body.padLeft(64, '0'));
  }

  Uint8List _paddedUint256(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    return _hexBytes(hex.padLeft(64, '0'));
  }
}

/// Local completion notification (spec §10c): Linux `notify-send` only, with
/// no amount or address in the text. Never a push service; failures are
/// ignored because a missing notification daemon must not affect the receipt.
Future<void> _notifyConfirmed() async {
  if (!Platform.isLinux) return;
  try {
    await Process.run('notify-send', [
      'X Wallet',
      'Transaction confirmed',
      'Open the app to see the receipt.',
    ]);
  } catch (_) {}
}

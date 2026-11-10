import 'dart:async';
import 'dart:io' show Platform;

import '../localized_text.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web3dart/web3dart.dart';

import '../app_state.dart';
import '../models.dart';
import '../price_service.dart';
import '../storage.dart' show DeviceKeyException;
import '../vault.dart';
import '../token_logos.dart';
import '../token_registry.dart';
import '../wallet_core.dart';
import '../widgets/seed_picker.dart';
import 'backup_quiz_dialog.dart';
import 'common.dart';
import 'receipt_page.dart';
import 'vault_password_dialog.dart';

/// Tile for a single vault account with unlock/delete/rename actions.
class _VaultAccountTile extends StatelessWidget {
  const _VaultAccountTile({
    required this.index,
    required this.account,
    required this.isCurrent,
    required this.onUnlock,
    required this.onDelete,
    required this.onRename,
  });

  final int index;
  final VaultAccount account;
  final bool isCurrent;
  final VoidCallback onUnlock;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCurrent
          ? const Color(0x224CAF50)
          : color.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCurrent
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : const Color(0x33808080),
        ),
      ),
      child: ListTile(
        onTap: isCurrent ? null : onUnlock,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          isCurrent ? Icons.check_circle : Icons.account_balance_wallet,
          color: isCurrent ? Colors.greenAccent : const Color(0xFF9A9A9A),
        ),
        title: Text(
          account.label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          shortAddress(account.address),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent)
              const Text(
                'In use',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              FilledButton(onPressed: onUnlock, child: const Text('Use')),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'rename') onRename();
                if (value == 'remove') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CreateKind { phrase, newPrivateKey, existingPrivateKey }

/// Configuration chosen in the create-wallet dialog.
class _CreateWalletConfig {
  final _CreateKind kind;
  final int wordCount;
  final String passphrase;
  final String derivationPath;
  final String pathLabel;
  final String? existingPrivateKey;

  const _CreateWalletConfig({
    required this.kind,
    this.wordCount = 24,
    this.passphrase = '',
    this.derivationPath = '',
    this.pathLabel = '',
    this.existingPrivateKey,
  });
}

/// Numbered phrase grid. Every word is visible at once, in order, so the
/// screen can never be mistaken for the three-word backup check that follows.
class _MnemonicGrid extends StatelessWidget {
  const _MnemonicGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 38,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                words[index],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

enum _HistoryFilter { all, success, failed, outgoing, incoming, bnb, token }

class _WalletPageState extends State<WalletPage>
    with AutomaticKeepAliveClientMixin {
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  List<LocalReceipt> get _filteredReceipts {
    if (_receipts == null) return const [];
    return _receipts!.where((r) {
      switch (_historyFilter) {
        case _HistoryFilter.success:
          return r.status == 'success';
        case _HistoryFilter.failed:
          return r.status != 'success';
        case _HistoryFilter.outgoing:
          return r.from.toLowerCase() == appState.address?.toLowerCase();
        case _HistoryFilter.incoming:
          return r.to.toLowerCase() == appState.address?.toLowerCase();
        case _HistoryFilter.bnb:
          return r.assetAddress.isEmpty;
        case _HistoryFilter.token:
          return r.assetAddress.isNotEmpty;
        case _HistoryFilter.all:
          return true;
      }
    }).toList();
  }

  List<HistoryTx>? _history;
  String? _historyError;
  bool _loadingHistory = false;
  Timer? _historyDebounce;
  Map<String, BigInt>? _balances;
  List<LocalReceipt>? _receipts;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    _loadHistory();
    _loadBalancesSummary();
    _loadReceipts();
  }

  @override
  void dispose() {
    _historyDebounce?.cancel();
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    // Many notifies can arrive in one burst (connection story lines, RPC
    // transitions). Coalesce them: wait 400 ms of quiet before fetching
    // history again, so the change-notify storm cannot start a fetch per
    // line on weak machines.
    _historyDebounce?.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadHistory();
        _loadBalancesSummary();
        _loadReceipts();
      }
    });
  }

  /// The locally kept receipts (newest first, encrypted at rest). They make
  /// the history work offline — no BscScan key needed for this part.
  Future<void> _loadReceipts() async {
    if (!appState.unlocked) {
      _receipts = null;
      if (mounted) setState(() {});
      return;
    }
    final receipts = await appState.loadLocalReceipts();
    if (mounted) setState(() => _receipts = receipts.isEmpty ? null : receipts);
  }

  /// Terminal v1 prints the wallet dashboard (balances right after unlock).
  /// This is the GUI equivalent: the Wallet screen must plainly show the
  /// wallet the moment one is unlocked — never just a message about it.
  Future<void> _loadBalancesSummary() async {
    if (!appState.unlocked || appState.address == null) {
      if (mounted) setState(() => _balances = null);
      return;
    }
    // Cached for five minutes; the service ignores extra calls.
    unawaited(PriceService.instance.refresh());
    try {
      final balances = await loadBalances(appState.address!);
      if (mounted) setState(() => _balances = balances);
    } catch (_) {
      // Home narrates connection problems into the story card; this summary
      // simply keeps whatever it last showed.
    }
  }

  double? _walletTotalUsd() {
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

  Future<void> _loadHistory() async {
    if (!appState.unlocked ||
        appState.address == null ||
        appState.bscscanKey == null) {
      setState(() {
        _history = null;
        _historyError = null;
      });
      return;
    }
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final history = await appState.rpc.history(appState.address!);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString().replaceFirst('Exception: ', '');
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (!appState.unlocked) ...[
              _lockedCard(),
            ] else if (Platform.isAndroid) ...[
              AnimatedBuilder(
                animation: PriceService.instance,
                builder: (context, _) => _androidDashboard(),
              ),
            ] else ...[
              _unlockedCard(),
              const SizedBox(height: 14),
              _walletsCard(),
              const SizedBox(height: 14),
              _historyCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _androidDashboard() {
    final address = appState.address!;
    final label = _currentWalletLabel(appState.profiles, address);
    final bnb = _balances?['BNB'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [Color(0xFF1D2530), Color(0xFF10151B)]
                  : const [Color(0xFFFFF8E1), Color(0xFFFFFDF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy address',
                    onPressed: () => copyText(context, address, 'Address'),
                    icon: const Icon(Icons.copy, size: 19),
                  ),
                ],
              ),
              Text(
                shortAddress(address),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'BNB balance',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bnb == null || bnb < BigInt.zero
                    ? '—'
                    : '${WalletCore.formatUnits(bnb, 18)} BNB',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final usd = bnb == null || bnb < BigInt.zero
                      ? null
                      : PriceService.instance.usdValue(
                          bnb,
                          18,
                          PriceService.instance.price('BNB'),
                        );
                  return Text(
                    usd == null ? 'BNB · BSC' : '${usdLabel(usd)} · BNB on BSC',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => appState.focusTab(2),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showQrDialog(context, address),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Receive'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!appState.watchOnly)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _currentWalletSaved(address)
                  ? null
                  : () => _saveVault(context),
              icon: Icon(
                _currentWalletSaved(address)
                    ? Icons.check_circle
                    : Icons.save_outlined,
              ),
              label: Text(
                _currentWalletSaved(address)
                    ? 'Saved in vault'
                    : 'Save to vault',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Assets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              'USD · ${PriceService.instance.sourceLabel}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _androidAssetList(),
        const SizedBox(height: 18),
        _walletsCard(),
        const SizedBox(height: 18),
        _androidRecentActivity(),
      ],
    );
  }

  Widget _androidRecentActivity() {
    final receipts = _receipts;
    final pending = appState.pendingTxs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if ((receipts == null || receipts.isEmpty) && pending.isEmpty)
          Text(
            'Your sent transfers and receipts will appear here.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (final tx in pending.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: Colors.amber),
              title: Text(
                '${tx.amountHuman} ${tx.assetSymbol}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Waiting for confirmation'),
            ),
          if (receipts != null)
            for (final receipt in receipts.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  receipt.status == 'success'
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: receipt.status == 'success'
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  '${receipt.amountHuman} ${receipt.assetSymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${receipt.status == 'success' ? 'Confirmed' : 'Failed'} · '
                  'block ${receipt.blockNumber}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReceiptPage(receipt: receipt),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _androidAssetList() {
    if (_balances == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Loading balances…'),
      );
    }
    return AnimatedBuilder(
      animation: PriceService.instance,
      builder: (context, _) {
        final tokens = [
          const TokenInfo(
            symbol: 'BNB',
            name: 'BNB',
            address: '',
            decimals: 18,
            native: true,
          ),
          ...appState.tokensForNetwork.where(
            (token) => !appState.isTokenHidden(token),
          ),
        ];
        return Column(
          children: [
            for (final token in tokens)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    TokenLogo(token: token, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TokenRegistry.of(token).symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            TokenRegistry.of(token).name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final raw = _balances![token.symbol];
                        final price = PriceService.instance.price(
                          TokenRegistry.of(token).symbol,
                        );
                        final usd = raw == null || raw < BigInt.zero
                            ? null
                            : PriceService.instance.usdValue(
                                raw,
                                token.decimals,
                                price,
                              );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              raw == null || raw < BigInt.zero
                                  ? '—'
                                  : '${WalletCore.formatUnits(raw, token.decimals)} ${TokenRegistry.of(token).symbol}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (usd != null)
                              Text(
                                usdLabel(usd),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // Linux desktop wallet card. The Android dashboard is separate.
  Widget _lockedCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
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
                  Image.asset(
                    'assets/icon/x-wallet-1024.png',
                    width: 46,
                    height: 46,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'X Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Your money.\nOnly you hold the keys.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No account. No cloud. Your recovery words stay on this '
                'device and never go to a server.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => showCreateWalletDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a new wallet'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showImportWalletDialog(context),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('I already have a wallet'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (appState.hasVault) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      showUnlockVaultDialog(context, jumpToWalletTab: true),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Open a saved wallet'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Non-custodial · encrypted on this device · no analytics',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unlockedCard() {
    final address = appState.address!;
    final label = _currentWalletLabel(appState.profiles, address);
    final saved = _currentWalletSaved(address);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      shortAddress(address),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF6E6E6E),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Copy address'),
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => copyText(context, address, 'Address'),
              ),
              IconButton(
                tooltip: tr(context, 'Receive QR'),
                icon: const Icon(Icons.qr_code, size: 18),
                onPressed: () => showQrDialog(context, address),
              ),
            ],
          ),
          if (appState.watchOnly) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0B90B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Watch-only · no key on this device',
                style: TextStyle(color: Color(0xFFF0B90B), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (saved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x224CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Saved in vault',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (!appState.watchOnly) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saved ? null : () => _saveVault(context),
                icon: Icon(saved ? Icons.check : Icons.save_outlined),
                label: Text(saved ? 'Saved in vault' : 'Save to vault'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => appState.focusTab(2),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showQrDialog(context, address),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Receive'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      appState.lock();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Lock'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Balances',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_balances != null && _walletTotalUsd() != null) ...[
                const SizedBox(width: 8),
                Text(
                  '≈ ${usdLabel(_walletTotalUsd())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: tr(context, 'Refresh balances'),
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadBalancesSummary,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (!mounted) return;
                  if (value == 'secrets') _revealSecrets(context);
                  if (value == 'rename') _renameCurrentWallet(context);
                  if (value == 'profile') _saveProfile(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'secrets',
                    child: Text('Show recovery phrase / key'),
                  ),
                  PopupMenuItem(value: 'rename', child: Text('Rename wallet')),
                  PopupMenuItem(
                    value: 'profile',
                    child: Text('Save public profile'),
                  ),
                ],
              ),
            ],
          ),
          if (_balances == null)
            const Text(
              'Fetching balances…',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            )
          else
            for (final token in [
              const TokenInfo(
                symbol: 'BNB',
                name: 'BNB Smart Chain',
                address: '',
                decimals: 18,
                native: true,
              ),
              ...appState.tokensForNetwork,
            ])
              if (_balances!.containsKey(token.symbol) &&
                  !appState.isTokenHidden(token))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      TokenLogo(token: token, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TokenRegistry.of(token).symbol,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              TokenRegistry.of(token).name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final raw = _balances![token.symbol]!;
                          final price = PriceService.instance.price(
                            TokenRegistry.of(token).symbol,
                          );
                          final usd = raw < BigInt.zero
                              ? null
                              : PriceService.instance.usdValue(
                                  raw,
                                  token.decimals,
                                  price,
                                );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                raw < BigInt.zero
                                    ? 'unavailable'
                                    : '${WalletCore.formatUnits(raw, token.decimals)} ${TokenRegistry.of(token).symbol}',
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (!token.native)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: tr(
                            context,
                            'Hide ${TokenRegistry.of(token).symbol}',
                          ),
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                          ),
                          onPressed: () async {
                            await appState.setTokenHidden(token, true);
                            if (!mounted) return;
                            showInfo(
                              context,
                              '${token.symbol} hidden. '
                              'Settings → Tokens can bring it back.',
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  bool _currentWalletSaved(String address) => appState.isSavedInVault(address);

  /// Comprehensive wallet management: current wallet, vault accounts, profiles.
  /// Each wallet entry manages its own secrets independently.

  Widget _walletsCard() {
    if (!appState.hasVault) return const SizedBox.shrink();
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved wallets',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (appState.vaultUnlocked)
                TextButton.icon(
                  onPressed: () async {
                    if (mounted) await _showAddWalletDialog(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
            ],
          ),
          _vaultAccountsSection(),
        ],
      ),
    );
  }

  Widget _vaultAccountsSection() {
    final accounts = appState.vaultAccountsCache;
    if (accounts == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _unlockVaultForManagement,
          icon: const Icon(Icons.lock_open),
          label: const Text('Unlock saved wallets'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            textStyle: const TextStyle(fontSize: 15),
          ),
        ),
      );
    }
    if (accounts.isEmpty) {
      return const Text(
        'No saved wallets yet. Use Add, then Save to vault.',
        style: TextStyle(color: Color(0xFF6E6E6E)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < accounts.length; i++)
          _VaultAccountTile(
            index: i,
            account: accounts[i],
            isCurrent:
                appState.address != null &&
                appState.address!.toLowerCase() ==
                    accounts[i].address.toLowerCase(),
            onUnlock: () => _switchVaultAccount(i),
            onDelete: () => _deleteVaultAccount(i, accounts[i]),
            onRename: () => _renameVaultAccount(i, accounts[i]),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              appState.lockVaultSession();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Lock list'),
          ),
        ),
      ],
    );
  }

  Future<void> _unlockVaultForManagement() async {
    final password = await showVaultPasswordDialog(
      context,
      title: 'Unlock encrypted vault',
      label: 'Vault password',
      confirmLabel: 'Unlock',
    );
    if (password == null || !mounted) return;
    try {
      await appState.unlockVaultAccounts(password);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showError(context, _vaultOpenError(error));
    }
  }

  Future<void> _switchVaultAccount(int index) async {
    try {
      final account = appState.vaultAccountAt(index);
      await appState.unlock(
        WalletCore.privateKeyFromHex(account.keystoreJson),
        mnemonic: account.mnemonic,
      );
      appState.focusTab(1);
      if (mounted) {
        showInfo(context, '${account.label} is now active.');
        setState(() {});
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  String _currentWalletLabel(List<WalletProfile> profiles, String address) {
    final match = profiles.firstWhere(
      (p) => p.address.toLowerCase() == address.toLowerCase(),
      orElse: () => WalletProfile(
        label: 'Unnamed wallet',
        address: address,
        source: 'unknown',
      ),
    );
    return match.label;
  }

  Future<void> _deleteVaultAccount(int index, VaultAccount account) async {
    final password = await showVaultPasswordDialog(
      context,
      title: 'Remove wallet from vault',
      label: 'Vault password',
      confirmLabel: 'Continue',
    );
    if (password == null || !mounted) return;
    final confirm = await confirmDialog(
      context,
      title: 'Remove "${account.label}"?',
      message:
          'This permanently removes the account from the encrypted vault. '
          'The secret cannot be recovered unless you have its recovery phrase '
          'or private key.',
      confirmLabel: 'Remove',
    );
    if (!confirm || !mounted) return;
    try {
      await appState.deleteVaultAccount(password, account.address);
      if (appState.address?.toLowerCase() == account.address.toLowerCase()) {
        appState.lock();
      }
      if (mounted) {
        showInfo(context, 'Wallet removed from the vault.');
        setState(() {});
      }
    } catch (error) {
      if (mounted) showError(context, _vaultOpenError(error));
    }
  }

  Future<void> _renameVaultAccount(int index, VaultAccount account) async {
    final password = await showVaultPasswordDialog(
      context,
      title: 'Rename wallet',
      label: 'Vault password',
      confirmLabel: 'Continue',
    );
    if (password == null || !mounted) return;
    final newLabel = await promptText(
      context,
      title: 'Rename wallet',
      label: 'New name',
      initialValue: account.label,
    );
    if (newLabel == null || newLabel.trim().isEmpty || !mounted) return;
    try {
      await appState.renameVaultAccount(password, index, newLabel.trim());
      if (mounted) {
        showInfo(context, 'Wallet renamed.');
        setState(() {});
      }
    } catch (error) {
      if (mounted) showError(context, _vaultOpenError(error));
    }
  }

  Widget _historyCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaction history',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) {
                  if (value == 'all') {
                    setState(() => _historyFilter = _HistoryFilter.all);
                  }
                  if (value == 'success') {
                    setState(() => _historyFilter = _HistoryFilter.success);
                  }
                  if (value == 'failed') {
                    setState(() => _historyFilter = _HistoryFilter.failed);
                  }
                  if (value == 'out') {
                    setState(() => _historyFilter = _HistoryFilter.outgoing);
                  }
                  if (value == 'in') {
                    setState(() => _historyFilter = _HistoryFilter.incoming);
                  }
                  if (value == 'token') {
                    setState(() => _historyFilter = _HistoryFilter.token);
                  }
                  if (value == 'bnb') {
                    setState(() => _historyFilter = _HistoryFilter.bnb);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('All')),
                  PopupMenuItem(
                    value: 'success',
                    child: Text('Successful only'),
                  ),
                  PopupMenuItem(value: 'failed', child: Text('Failed only')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'out', child: Text('Outgoing (sent)')),
                  PopupMenuItem(
                    value: 'in',
                    child: Text('Incoming (received)'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'bnb', child: Text('Native coin only')),
                  PopupMenuItem(
                    value: 'token',
                    child: Text('Tokens (USDT, USDC, etc.)'),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadHistory,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_receipts != null && _receipts!.isNotEmpty) ...[
            const Text(
              'Local receipts (kept encrypted, offline)',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final receipt in _filteredReceipts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  receipt.status == 'success'
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
                  color: receipt.status == 'success'
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
                title: Text(
                  '${receipt.amountHuman} ${receipt.assetSymbol} → ${shortAddress(receipt.to)}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'block ${receipt.blockNumber} · '
                  '${receipt.finalized ? 'final' : 'included'} · '
                  '${receipt.verifiedNodes >= 2 ? '2 nodes ✓' : '1 node'} · '
                  '${receipt.tierLabel}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  onPressed: () =>
                      copyText(context, receipt.hash, 'Transaction hash'),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReceiptPage(receipt: receipt),
                  ),
                ),
              ),
            const Divider(),
          ],
          if (appState.bscscanKey == null)
            const Text(
              'Add a BscScan API key in Settings to enable full history. '
              'Balances and transfers do not need it.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            )
          else if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyError != null)
            Text(
              _historyError!,
              style: const TextStyle(color: Colors.redAccent),
            )
          else if (_history == null || _history!.isEmpty)
            const Text(
              'No normal transactions found.',
              style: TextStyle(color: Color(0xFF6E6E6E)),
            )
          else
            for (final tx in _history!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  tx.from.toLowerCase() == appState.address?.toLowerCase()
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                ),
                title: Text(shortAddress(tx.hash)),
                subtitle: Text(
                  '${tx.from.toLowerCase() == appState.address?.toLowerCase() ? 'OUT' : 'IN'} · ${tx.timestamp}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.content_copy, size: 16),
                  onPressed: () =>
                      copyText(context, tx.hash, 'Transaction hash'),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _revealSecrets(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Reveal secrets?',
      message:
          'Anyone who can see this screen can steal all funds. Only reveal '
          'secrets on a trusted, private device.',
      confirmLabel: 'Reveal',
    );
    if (!confirmed || !context.mounted) return;
    final key = appState.privateKey!;
    final privateKey = WalletCore.privateKeyHex(key);
    final rawKey = privateKey.substring(2);
    final mnemonic = appState.mnemonic;
    final address = appState.address!;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Show private key'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only copy a secret when you are restoring it now. The '
                  'clipboard is cleared after 15 seconds, but other apps may '
                  'read it first.',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  address,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Private key (0x, 66 characters)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  privateKey,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Private key (raw, 64 characters)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  rawKey,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recovery phrase',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(mnemonic ?? 'Not available for this import.'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: dialogContext,
                      builder: (qrContext) => AlertDialog(
                        title: const Text('Private key QR'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(10),
                              child: QrImageView(
                                data: privateKey,
                                size: 260,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Anyone who scans this can take the funds.',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(qrContext),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Show private-key QR'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                _copySecret(dialogContext, privateKey, 'Private key'),
            child: const Text('Copy 0x key'),
          ),
          TextButton(
            onPressed: () => _copySecret(dialogContext, rawKey, 'Raw key'),
            child: const Text('Copy raw key'),
          ),
          if (mnemonic != null)
            TextButton(
              onPressed: () =>
                  _copySecret(dialogContext, mnemonic, 'Recovery phrase'),
              child: const Text('Copy phrase'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySecret(
    BuildContext context,
    String secret,
    String label,
  ) async {
    final copy = await confirmDialog(
      context,
      title: 'Copy $label?',
      message:
          'This puts your $label on the system clipboard for 15 seconds. '
          'Other applications may be able to read it.',
      confirmLabel: 'Copy for 15 seconds',
    );
    if (!copy) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (context.mounted) {
      showInfo(context, '$label copied · clears in 15 seconds');
    }
    Future<void>.delayed(const Duration(seconds: 15), () async {
      try {
        final current = await Clipboard.getData('text/plain');
        if (current?.text == secret) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {
        // Clipboard access can be unavailable after the window closes.
      }
    });
  }

  Future<void> _renameCurrentWallet(BuildContext context) async {
    final address = appState.address;
    if (address == null) return;
    final profiles = appState.profiles;
    final index = profiles.indexWhere(
      (profile) => profile.address.toLowerCase() == address.toLowerCase(),
    );
    final label = await promptText(
      context,
      title: 'Rename wallet',
      label: 'Wallet name',
      initialValue: index >= 0
          ? profiles[index].label
          : 'Wallet ${profiles.length + 1}',
      validator: (value) =>
          value.trim().isEmpty ? 'Enter a wallet name.' : null,
    );
    if (label == null || !context.mounted) return;
    final name = label.trim();
    final accounts = appState.vaultAccountsCache;
    final vaultIndex = accounts?.indexWhere(
      (account) => account.address.toLowerCase() == address.toLowerCase(),
    );
    if (vaultIndex != null && vaultIndex >= 0 && appState.vaultUnlocked) {
      await appState.renameVaultAccountWithSession(vaultIndex, name);
    }
    if (index >= 0) {
      await appState.renameProfile(index, name);
    } else if (vaultIndex == null || vaultIndex < 0) {
      await appState.addProfile(
        WalletProfile(
          label: name,
          address: address,
          source: appState.mnemonic != null ? 'phrase' : 'key',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    if (context.mounted) showInfo(context, 'Wallet name updated.');
  }

  Future<void> _saveVault(BuildContext context) async {
    if (!appState.unlocked || appState.privateKey == null) {
      showError(
        context,
        'Unlock a wallet with a private key first, then save it to the vault.',
      );
      return;
    }
    final address = appState.address!;
    final profileLabel = _currentWalletLabel(appState.profiles, address);
    final label = profileLabel == 'Unnamed wallet'
        ? 'My wallet ${appState.profiles.length + 1}'
        : profileLabel;
    try {
      if (appState.vaultUnlocked) {
        await appState.saveVaultAccountWithSession(
          label: label,
          key: appState.privateKey!,
          mnemonic: appState.mnemonic,
        );
      } else {
        final password = await _requestVaultPasswordForSave(context);
        if (password == null || !context.mounted) return;
        await appState.saveVaultAccount(
          password,
          label: label,
          key: appState.privateKey!,
          mnemonic: appState.mnemonic,
        );
      }
      if (context.mounted) {
        showInfo(
          context,
          'Saved. Lock the wallet, then unlock the vault with the same password.',
        );
        setState(() {});
      }
    } catch (error) {
      if (context.mounted) {
        showError(context, 'Could not save: ${_vaultOpenError(error)}');
      }
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    final label = await promptText(
      context,
      title: 'Save public profile',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label == null || label.isEmpty || !context.mounted) return;
    await appState.addProfile(
      WalletProfile(
        label: label,
        address: appState.address!,
        source: appState.mnemonic != null ? 'phrase' : 'key',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (context.mounted) showInfo(context, 'Public profile saved.');
  }
}

/// Returns the password that should protect a vault save.
///
/// If no vault exists, this is a new password (confirmed and scored). If a
/// vault already exists, it must be the existing vault password: the vault is
/// one encrypted container, so a second password cannot silently create a
/// second container. This is what makes adding a second wallet work.
Future<String?> _requestVaultPasswordForSave(BuildContext context) async {
  if (!appState.hasVault) {
    return showVaultPasswordDialog(
      context,
      title: 'Create vault password',
      label: 'New vault password',
      requireConfirm: true,
      showStrength: true,
      confirmLabel: 'Create vault',
    );
  }
  final password = await showVaultPasswordDialog(
    context,
    title: 'Unlock existing vault',
    label: 'Existing vault password',
    confirmLabel: 'Unlock',
  );
  if (password == null) return null;
  try {
    await appState.unlockVaultAccounts(password);
    return password;
  } catch (_) {
    if (context.mounted) {
      showError(
        context,
        'Wrong vault password, or this device key cannot open the vault. '
        'A vault has one password; use the one set when it was created.',
      );
    }
    return null;
  }
}

/// Turns a vault failure into a precise message instead of blaming the
/// password for every error.
String _vaultOpenError(Object error) {
  if (error is VaultException) {
    return 'Wrong vault password, or this device key cannot open the vault.';
  }
  if (error is DeviceKeyException) {
    return 'This device key is unavailable. Use the same operating-system '
        'account that created the vault.';
  }
  return error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('ArgumentError: ', '')
      .replaceFirst('Exception: ', '');
}

Future<void> _showAddWalletDialog(BuildContext context) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Add wallet'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'create'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_circle_outline),
            title: Text('Create a new wallet'),
            subtitle: Text('New recovery phrase or private key'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'import'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.file_download_outlined),
            title: Text('Import an existing wallet'),
            subtitle: Text(
              'Recovery phrase, private key, keystore, or watch-only',
            ),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'vault'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_open_outlined),
            title: Text('Open encrypted vault'),
            subtitle: Text('Choose another wallet stored on this device'),
          ),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'create':
      await showCreateWalletDialog(context);
      break;
    case 'import':
      await showImportWalletDialog(context);
      break;
    case 'vault':
      await showUnlockVaultDialog(context, jumpToWalletTab: true);
      break;
  }
}

/// Choose one of the standard EVM derivation paths for an imported phrase.
Future<String?> showDerivationPathPicker(BuildContext context) async {
  var label = WalletCore.standardPaths.keys.first;
  final indexController = TextEditingController(text: '0');
  final customController = TextEditingController();
  String? error;
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final index = int.tryParse(indexController.text.trim());
          final path = label == 'Custom'
              ? customController.text.trim()
              : (index != null && index >= 0
                    ? WalletCore.pathForLabel(label, index)
                    : '');
          return AlertDialog(
            title: const Text('Derivation path'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: label,
                          items: [
                            for (final entry in WalletCore.standardPaths.keys)
                              DropdownMenuItem(
                                value: entry,
                                child: Text(
                                  entry,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              label = value;
                              error = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      WalletCore.standardPathDescriptions[label] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8A8A),
                      ),
                    ),
                    if (label != 'Custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: indexController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Wallet / address index',
                          helperText: '0 = first, 1 = second, and so on',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => error = null),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Custom BIP-32 path',
                          hintText: "m/44'/60'/0'/0/0",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => error = null),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SelectableText(
                      path.isEmpty ? 'Enter a valid path.' : path,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!RegExp(r"^m(/\d+'?)+$").hasMatch(path)) {
                    setState(() => error = 'Enter a valid BIP-32 path.');
                    return;
                  }
                  Navigator.pop(dialogContext, path);
                },
                child: const Text('Use this path'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    indexController.dispose();
    customController.dispose();
  }
}

Future<void> showCreateWalletDialog(BuildContext context) async {
  var kind = _CreateKind.phrase;
  var wordCount = 24;
  var pathLabel = WalletCore.standardPaths.keys.first;
  var passphrase = '';
  var obscurePassphrase = true;
  var obscureExistingKey = true;
  var saved = false;
  String? validationError;
  final customPathController = TextEditingController();
  final accountIndexController = TextEditingController(text: '0');
  final existingKeyController = TextEditingController();

  final config = await showDialog<_CreateWalletConfig>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final accountIndex = int.tryParse(accountIndexController.text.trim());
        final resolvedPath = pathLabel == 'Custom'
            ? customPathController.text.trim()
            : (accountIndex != null && accountIndex >= 0
                  ? WalletCore.pathForLabel(pathLabel, accountIndex)
                  : '');
        return AlertDialog(
          title: const Text('Create wallet'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr(context, 'Wallet type'),
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_CreateKind>(
                        isExpanded: true,
                        value: kind,
                        items: const [
                          DropdownMenuItem(
                            value: _CreateKind.phrase,
                            child: Text('Recovery phrase (12 / 24 words)'),
                          ),
                          DropdownMenuItem(
                            value: _CreateKind.newPrivateKey,
                            child: Text('New private key (generated)'),
                          ),
                          DropdownMenuItem(
                            value: _CreateKind.existingPrivateKey,
                            child: Text('Existing private key (paste)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            kind = value;
                            validationError = null;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (kind == _CreateKind.phrase) ...[
                    const Text(
                      'Recovery phrase length',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<int>(value: 12, label: Text('12 words')),
                        ButtonSegment<int>(value: 24, label: Text('24 words')),
                      ],
                      selected: {wordCount},
                      onSelectionChanged: (selection) =>
                          setState(() => wordCount = selection.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      wordCount == 12
                          ? '12 words is standard BIP-39 security.'
                          : '24 words adds 256-bit entropy to the backup.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Derivation path',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: InputDecoration(border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: pathLabel,
                          items: WalletCore.standardPaths.keys
                              .map(
                                (label) => DropdownMenuItem<String>(
                                  value: label,
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              pathLabel = value;
                              validationError = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      WalletCore.standardPathDescriptions[pathLabel] ??
                          'Enter any BIP-32 path.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    if (pathLabel != 'Custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: accountIndexController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr(context, 'Wallet / address index'),
                          helperText: '0 = first, 1 = second, and so on',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => validationError = null),
                      ),
                    ],
                    if (pathLabel == 'Custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customPathController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: tr(context, 'Custom BIP-32 path'),
                          hintText: tr(context, "m/44'/60'/0'/0/0"),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => validationError = null),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SelectableText(
                      resolvedPath.isEmpty
                          ? 'Enter a valid path.'
                          : resolvedPath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'BIP-39 passphrase (25th word) — optional',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If you set one, the exact same passphrase is required '
                      'every time you restore. There is no way to recover it.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: obscurePassphrase,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Passphrase (optional)'),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: obscurePassphrase
                              ? 'Show passphrase'
                              : 'Hide passphrase',
                          icon: Icon(
                            obscurePassphrase
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => obscurePassphrase = !obscurePassphrase,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() {
                        passphrase = value;
                        validationError = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    const _CreateWarning(
                      text:
                          'The phrase is shown only on this screen. Write '
                          'it on paper; never store it digitally or send it '
                          'to anyone.',
                    ),
                  ] else if (kind == _CreateKind.newPrivateKey) ...[
                    const _CreateWarning(
                      text:
                          'A brand-new random private key will be generated '
                          'on this device. There is no recovery phrase. You '
                          'must write down the 0x… key: lose it and the funds '
                          'are gone.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The key is shown once after you press Generate. The app '
                      'does not keep a plain-text copy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Paste or type an existing 0x + 64 hex private key. This '
                      'derives the address and creates the wallet immediately.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: existingKeyController,
                      obscureText: obscureExistingKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Private key (hidden)'),
                        hintText: tr(context, '0x…'),
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: tr(context, 'Paste from clipboard'),
                              icon: const Icon(Icons.content_paste),
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  'text/plain',
                                );
                                final text = data?.text?.trim();
                                if (text == null || text.isEmpty) return;
                                setState(() {
                                  existingKeyController.text = text;
                                  validationError = null;
                                });
                              },
                            ),
                            IconButton(
                              tooltip: obscureExistingKey
                                  ? 'Show private key'
                                  : 'Hide private key',
                              icon: Icon(
                                obscureExistingKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => obscureExistingKey = !obscureExistingKey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (_) => setState(() => validationError = null),
                    ),
                    const SizedBox(height: 16),
                    const _CreateWarning(
                      text:
                          'Anyone with this key can take the funds. Never '
                          'send it to a website, support agent or anyone else.',
                    ),
                  ],
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (kind == _CreateKind.phrase) {
                  final index = int.tryParse(
                    accountIndexController.text.trim(),
                  );
                  final path = pathLabel == 'Custom'
                      ? customPathController.text.trim()
                      : (index != null && index >= 0
                            ? WalletCore.pathForLabel(pathLabel, index)
                            : '');
                  if (!RegExp(r"^m(/\d+'?)+$").hasMatch(path)) {
                    setState(
                      () => validationError =
                          "Enter a valid BIP-32 path, for example "
                          "m/44'/60'/0'/0/0.",
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    _CreateWalletConfig(
                      kind: _CreateKind.phrase,
                      wordCount: wordCount,
                      passphrase: passphrase,
                      derivationPath: path,
                      pathLabel: pathLabel,
                    ),
                  );
                  return;
                }
                if (kind == _CreateKind.newPrivateKey) {
                  Navigator.pop(
                    dialogContext,
                    const _CreateWalletConfig(kind: _CreateKind.newPrivateKey),
                  );
                  return;
                }
                final text = existingKeyController.text.trim();
                try {
                  WalletCore.privateKeyFromHex(text);
                } catch (_) {
                  setState(
                    () => validationError =
                        'Enter a valid 0x + 64 hex private key.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _CreateWalletConfig(
                    kind: _CreateKind.existingPrivateKey,
                    existingPrivateKey: text,
                  ),
                );
              },
              child: Text(
                kind == _CreateKind.phrase
                    ? 'Generate $wordCount words'
                    : kind == _CreateKind.newPrivateKey
                    ? 'Generate private key'
                    : 'Create wallet',
              ),
            ),
          ],
        );
      },
    ),
  );
  // The dialog's exit animation can still rebuild its fields for a few
  // frames. Disposing controllers before that finishes throws in debug.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  customPathController.dispose();
  accountIndexController.dispose();
  existingKeyController.dispose();

  if (config == null || !context.mounted) return;

  if (config.kind == _CreateKind.phrase) {
    final mnemonic = WalletCore.generateMnemonic(wordCount: config.wordCount);
    saved = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Your ${config.wordCount}-word recovery phrase'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Write every word on paper, in this order. This phrase '
                    'controls the wallet; anyone who sees it can take the funds.',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MnemonicGrid(words: mnemonic.split(' ')),
                  const SizedBox(height: 14),
                  _SummaryRow(
                    label: 'Path',
                    value: '${config.pathLabel} · ${config.derivationPath}',
                  ),
                  _SummaryRow(
                    label: 'Passphrase',
                    value: config.passphrase.isEmpty
                        ? 'None'
                        : 'Enabled (25th word)',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: saved,
                    onChanged: (value) => setState(() => saved = value == true),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'I wrote down all ${config.wordCount} words in order.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saved
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Continue to verification'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;

    final verified = await runBackupQuiz(context, mnemonic);
    if (!verified || !context.mounted) return;

    try {
      final key = WalletCore.derivePrivateKey(
        phrase: mnemonic,
        passphrase: config.passphrase,
        path: config.derivationPath,
      );
      await _finishCreatedWallet(
        context,
        key,
        mnemonic: mnemonic,
        summary: config.passphrase.isEmpty
            ? '${config.wordCount} words'
            : '${config.wordCount} words + passphrase',
        path: '${config.pathLabel} · ${config.derivationPath}',
      );
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
    return;
  }

  if (config.kind == _CreateKind.newPrivateKey) {
    final key = WalletCore.generatePrivateKey();
    final backedUp = await _confirmNewPrivateKey(context, key);
    if (backedUp != true || !context.mounted) return;
    await _finishCreatedWallet(
      context,
      key,
      summary: 'Generated private key (no recovery phrase)',
      path: 'No derivation path — raw private key',
    );
    return;
  }

  try {
    final key = WalletCore.privateKeyFromHex(config.existingPrivateKey!);
    await _finishCreatedWallet(
      context,
      key,
      summary: 'Existing private key',
      path: 'No derivation path — raw private key',
      offerVaultSave: false,
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<bool> _confirmNewPrivateKey(
  BuildContext context,
  EthPrivateKey key,
) async {
  var saved = false;
  final keyHex = WalletCore.privateKeyHex(key);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Back up your new private key'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is the ONLY way to restore this wallet. Write the '
                  'whole key on paper now. It is not stored anywhere else.',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(dialogContext).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    keyHex,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'It starts with 0x and has 64 hexadecimal characters after '
                  'it. Do not photograph it or save it in a notes app.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: saved,
                  onChanged: (value) => setState(() => saved = value == true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('I wrote down the whole private key.'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saved ? () => Navigator.pop(dialogContext, true) : null,
            child: const Text('Create wallet'),
          ),
        ],
      ),
    ),
  );
  return result == true;
}

Future<void> _finishCreatedWallet(
  BuildContext context,
  EthPrivateKey key, {
  String? mnemonic,
  required String summary,
  required String path,
  bool offerVaultSave = true,
}) async {
  await appState.unlock(key, mnemonic: mnemonic);
  appState.focusTab(1);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Wallet created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The wallet is unlocked. Compare this address with your other '
            'wallet before sending funds.',
          ),
          const SizedBox(height: 12),
          SelectableText(
            key.address.eip55With0x,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Path', value: path),
          _SummaryRow(label: 'Backup', value: summary),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  // For generated/imported private keys (no mnemonic), skip the vault offer
  // since the raw key is the only backup. User can save to vault later from
  // the wallet manager if desired.
  if (offerVaultSave && mnemonic != null) {
    await showOfferProfileAndVault(context);
  } else if (offerVaultSave) {
    // For private key imports, just offer profile save
    await _offerProfileOnly(context);
  }
}

Future<void> _offerProfileOnly(BuildContext context) async {
  final saveProfile = await confirmDialog(
    context,
    title: 'Save public profile?',
    message: 'Store the label and public address only. No secret is saved.',
    confirmLabel: 'Save',
  );
  if (saveProfile && context.mounted) {
    final label = await promptText(
      context,
      title: 'Profile label',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label != null && label.isNotEmpty && context.mounted) {
      await appState.addProfile(
        WalletProfile(
          label: label,
          address: appState.address!,
          source: appState.mnemonic != null ? 'phrase' : 'key',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }
}

class _CreateWarning extends StatelessWidget {
  const _CreateWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

Future<void> showImportWalletDialog(BuildContext context) async {
  final method = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Import method'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'key'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key),
            title: Text('Private key'),
            subtitle: Text('0x followed by 64 hex characters'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'phrase'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.article_outlined),
            title: Text('Recovery phrase'),
            subtitle: Text('12 or 24 words'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'keystore'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined),
            title: Text('Ethereum V3 keystore'),
            subtitle: Text('Paste the JSON file contents'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'watch'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.visibility_outlined),
            title: Text('Watch an address'),
            subtitle: Text('Read-only: no key is imported or stored'),
          ),
        ),
      ],
    ),
  );
  if (method == null || !context.mounted) return;
  switch (method) {
    case 'key':
      await _importPrivateKey(context);
      break;
    case 'phrase':
      await _importPhrase(context);
      break;
    case 'keystore':
      await _importKeystore(context);
      break;
    case 'watch':
      await _importWatchAddress(context);
      break;
  }
}

Future<void> _importWatchAddress(BuildContext context) async {
  final raw = await promptText(
    context,
    title: 'Watch an address',
    label: 'Public address (0x + 40 hex characters)',
    validator: (value) => WalletCore.isValidAddress(value.trim())
        ? null
        : 'Enter a valid 0x address.',
  );
  if (raw == null || raw.trim().isEmpty || !context.mounted) return;
  try {
    await appState.openWatchOnly(raw.trim());
    appState.focusTab(1);
    if (!context.mounted) return;
    showInfo(
      context,
      'Watch-only profile opened. Balances and history are readable; this '
      'device holds no key for it.',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importPrivateKey(BuildContext context) async {
  final keyText = await promptText(
    context,
    title: 'Import private key',
    label: 'Private key (hidden)',
    obscure: true,
    validator: (value) {
      try {
        WalletCore.privateKeyFromHex(value);
        return null;
      } catch (_) {
        return 'Enter a valid 0x + 64 hex private key.';
      }
    },
  );
  if (keyText == null || !context.mounted) return;
  try {
    final key = WalletCore.privateKeyFromHex(keyText);
    await appState.unlock(key);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Wallet imported and unlocked.');
    if (!context.mounted) return;
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importPhrase(BuildContext context) async {
  // Secure entry: the phrase is built by tapping official BIP-39 words, so
  // the system keyboard/IME never records it. Fall back to paste (also fine:
  // pasted clipboard data never went through the keyboard) via a second
  // action; typing the phrase manually by keyboard is no longer offered.
  var phrase = await showSeedPicker(context, wordCount: 24);
  if (!context.mounted) return;
  phrase ??= await showSeedPicker(context, wordCount: 12);
  if (phrase == null || !context.mounted) return;
  final path = await showDerivationPathPicker(context);
  if (path == null || !context.mounted) return;
  final passphrase = await promptText(
    context,
    title: 'BIP-39 passphrase',
    label: 'Optional passphrase (hidden)',
    obscure: true,
  );
  if (passphrase == null || !context.mounted) return;
  try {
    final key = WalletCore.derivePrivateKey(
      phrase: phrase,
      passphrase: passphrase,
      path: path,
    );
    await appState.unlock(key, mnemonic: phrase);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Wallet imported and unlocked.');
    if (!context.mounted) return;
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> _importKeystore(BuildContext context) async {
  final json = await promptText(
    context,
    title: 'Import V3 keystore',
    label: 'Keystore JSON',
  );
  if (json == null || !context.mounted) return;
  final password = await promptText(
    context,
    title: 'Keystore password',
    label: 'Password (hidden)',
    obscure: true,
  );
  if (password == null || !context.mounted) return;
  try {
    final key = WalletCore.decryptV3Keystore(json, password);
    await appState.unlock(key);
    appState.focusTab(1); // the wallet must visibly appear, not just a message
    if (context.mounted) showInfo(context, 'Keystore imported and unlocked.');
    if (!context.mounted) return;
    await showOfferProfileAndVault(context);
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> showUnlockVaultDialog(
  BuildContext context, {
  bool jumpToWalletTab = false,
}) async {
  if (!appState.hasVault) {
    await showMessage(
      context,
      'No vault',
      'No encrypted local vault exists yet. Create or import a wallet first.',
    );
    return;
  }
  final password = await showVaultPasswordDialog(
    context,
    title: 'Unlock encrypted vault',
    label: 'Vault password',
    confirmLabel: 'Unlock',
  );
  if (password == null || !context.mounted) return;
  List<VaultAccount> accounts;
  try {
    accounts = await appState.unlockVaultAccounts(password);
  } catch (error) {
    if (context.mounted) showError(context, _vaultOpenError(error));
    return;
  }
  if (accounts.isEmpty) {
    if (context.mounted) {
      showMessage(
        context,
        'Empty vault',
        'The vault has no usable accounts. Add a wallet to the vault first.',
      );
    }
    return;
  }
  if (!context.mounted) return;
  final index = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Choose a wallet'),
      children: [
        for (var i = 0; i < accounts.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(accounts[i].label),
              subtitle: Text(shortAddress(accounts[i].address)),
            ),
          ),
      ],
    ),
  );
  if (index == null || !context.mounted) return;
  try {
    final account = appState.vaultAccountAt(index);
    await appState.unlock(
      WalletCore.privateKeyFromHex(account.keystoreJson),
      mnemonic: account.mnemonic,
    );
    if (jumpToWalletTab) appState.focusTab(1);
    if (context.mounted) {
      showInfo(context, '${account.label} is now active.');
    }
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> showOfferProfileAndVault(BuildContext context) async {
  final saveProfile = await confirmDialog(
    context,
    title: 'Save public profile?',
    message: 'Store the label and public address only. No secret is saved.',
    confirmLabel: 'Save',
  );
  if (saveProfile && context.mounted) {
    final label = await promptText(
      context,
      title: 'Profile label',
      label: 'Label',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label != null && label.isNotEmpty && context.mounted) {
      await appState.addProfile(
        WalletProfile(
          label: label,
          address: appState.address!,
          source: appState.mnemonic != null ? 'phrase' : 'key',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }
  if (!context.mounted) return;
  final saveVault = await confirmDialog(
    context,
    title: 'Save this wallet in the encrypted vault?',
    message:
        'The vault uses one password for every wallet. If a vault already '
        'exists, enter its existing password; a new password cannot create a '
        'second vault.',
    confirmLabel: 'Save',
  );
  if (!saveVault || !context.mounted) return;
  try {
    if (appState.vaultUnlocked) {
      await appState.saveVaultAccountWithSession(
        label: 'Wallet ${appState.profiles.length + 1}',
        key: appState.privateKey!,
        mnemonic: appState.mnemonic,
      );
    } else {
      final password = await _requestVaultPasswordForSave(context);
      if (password == null || !context.mounted) return;
      await appState.saveVaultAccount(
        password,
        label: 'Wallet ${appState.profiles.length + 1}',
        key: appState.privateKey!,
        mnemonic: appState.mnemonic,
      );
    }
    if (context.mounted) {
      showInfo(context, 'Wallet saved to the encrypted vault.');
    }
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

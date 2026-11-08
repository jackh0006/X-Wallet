import 'dart:async';

import '../localized_text.dart';

import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

import '../app_state.dart';
import '../models.dart';
import '../token_logos.dart';
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
              : Color(0x33808080),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          isCurrent ? Icons.check_circle : Icons.lock_outline,
          color: isCurrent ? Colors.greenAccent : Color(0xFF808080),
        ),
        title: Text(
          account.label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${shortAddress(account.address)}  •  ${account.savedAt != null ? 'saved ${_formatDate(account.savedAt!)}' : ''}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCurrent)
              IconButton(
                icon: const Icon(Icons.lock_open, size: 18),
                tooltip: tr(context, 'Unlock this account'),
                onPressed: onUnlock,
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: tr(context, 'Rename'),
              onPressed: onRename,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.redAccent,
              ),
              tooltip: tr(context, 'Delete from vault'),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
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
    try {
      final balances = await loadBalances(appState.address!);
      if (mounted) setState(() => _balances = balances);
    } catch (_) {
      // Home narrates connection problems into the story card; this summary
      // simply keeps whatever it last showed.
    }
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
            ] else ...[
              _unlockedCard(),
              const SizedBox(height: 14),
              _walletsCard(),
              const SizedBox(height: 14),
              _historyCard(),
            ],
            const SizedBox(height: 14),
            _dangerCard(),
          ],
        ),
      ),
    );
  }

  Widget _lockedCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wallet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new BIP-39 wallet or import an existing private key, recovery phrase, '
            'Ethereum V3 keystore file, or encrypted local vault.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _showAddWalletDialog(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add wallet'),
              ),
              FilledButton.icon(
                onPressed: () => showCreateWalletDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create wallet'),
              ),
              OutlinedButton.icon(
                onPressed: () => showImportWalletDialog(context),
                icon: const Icon(Icons.file_download),
                label: const Text('Import'),
              ),
              OutlinedButton.icon(
                onPressed: () => showUnlockVaultDialog(context),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock vault'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unlockedCard() {
    final address = appState.address!;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortAddress(address),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
          const SizedBox(height: 6),
          if (appState.watchOnly) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0B90B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Watch-only · this device holds no key for this address',
                style: TextStyle(color: Color(0xFFF0B90B), fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Balances',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Refresh balances'),
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadBalancesSummary,
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
              ...appState.rpc.tokens,
            ])
              if (_balances!.containsKey(token.symbol) &&
                  !appState.isTokenHidden(token))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      TokenLogo(token: token, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _balances![token.symbol]! < BigInt.zero
                              ? '${token.symbol}: unavailable right now'
                              : '${WalletCore.formatUnits(_balances![token.symbol]!, token.decimals)} ${token.symbol}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (!token.native)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: tr(context, 'Hide ${token.symbol}'),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!appState.watchOnly) ...[
                OutlinedButton.icon(
                  onPressed: () => _revealSecrets(context),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Reveal secrets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveVault(context),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save to vault'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () => _saveProfile(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save profile'),
              ),
              if (appState.watchOnly)
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
        ],
      ),
    );
  }

  /// Comprehensive wallet management: current wallet, vault accounts, profiles.
  /// Each wallet entry manages its own secrets independently.

  Widget _walletsCard() {
    final profiles = appState.profiles;
    final currentAddress = appState.address;
    final currentSource = appState.mnemonic != null ? 'phrase' : 'key';

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wallet manager',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add wallet'),
                onPressed: () async {
                  if (appState.hasVault && !appState.vaultUnlocked) {
                    await _unlockVaultForManagement();
                    if (!mounted || !appState.vaultUnlocked) return;
                  }
                  if (mounted) await _showAddWalletDialog(context);
                },
              ),
              if (currentAddress != null) const SizedBox(width: 8),
              if (currentAddress != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Lock'),
                  onPressed: () async {
                    appState.lockVaultSession();
                    appState.lock();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Every wallet keeps its own secret in the encrypted vault. '
            'Unlock once to switch, rename, or remove accounts.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (currentAddress != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x224CAF50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active: ${_currentWalletLabel(profiles, currentAddress)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$currentAddress  •  source: $currentSource',
                          style: const TextStyle(
                            color: Color(0xFF6E6E6E),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.key, size: 18),
                    label: const Text('Show secrets'),
                    onPressed: () => _revealSecrets(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: tr(context, 'Rename wallet'),
                    onPressed: () => _renameCurrentWallet(context),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Storage'),
                    onPressed: () => _chooseSecretStorage(context),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x22FF6B6B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_open, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No wallet unlocked. Create, import, or unlock a vault '
                      'account below.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _vaultAccountsSection(),
          if (profiles.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Public profiles (labels only)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Just labels and addresses for quick reference. No secrets stored.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < profiles.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.bookmark_outline,
                  color: Color(0xFF808080),
                ),
                title: Text(profiles[i].label),
                subtitle: Text(shortAddress(profiles[i].address)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final label = await promptText(
                          context,
                          title: 'Rename profile',
                          initialValue: profiles[i].label,
                          label: 'Label',
                        );
                        if (label != null && label.isNotEmpty) {
                          await appState.renameProfile(i, label);
                          if (mounted) setState(() {});
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => appState.deleteProfile(i),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _vaultAccountsSection() {
    const titleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
    if (!appState.hasVault) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33808080)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF808080)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No encrypted vault yet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Save the unlocked wallet to create a vault. The same '
                    'vault password protects every wallet you add.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create vault'),
              onPressed: () => _createVault(context),
            ),
          ],
        ),
      );
    }

    final accounts = appState.vaultAccountsCache;
    if (accounts == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33808080)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF808080)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encrypted vault is locked',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Unlock once to list, switch, rename, or remove wallets.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Unlock vault'),
              onPressed: _unlockVaultForManagement,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Encrypted vault accounts', style: titleStyle),
            ),
            TextButton.icon(
              onPressed: () async {
                if (mounted) await _showAddWalletDialog(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add wallet'),
            ),
          ],
        ),
        const Text(
          'The same vault password protects every account. Unlock a row to '
          'make it active; rename or remove it without leaving this screen.',
          style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (accounts.isEmpty)
          const Text(
            'Vault has no accounts yet. Use Add wallet to save one.',
            style: TextStyle(color: Color(0xFF6E6E6E)),
          )
        else
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
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              appState.lockVaultSession();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Lock vault list'),
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
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'Wrong vault password, or this device key cannot open the vault. '
          'Use the password set when the first wallet was saved.',
        );
      }
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
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'Wrong vault password, or this device key cannot open the vault.',
        );
      }
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
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'Wrong vault password, or this device key cannot open the vault.',
        );
      }
    }
  }

  Future<void> _createVault(BuildContext context) async {
    if (!appState.unlocked || appState.privateKey == null) {
      showError(
        context,
        'Unlock or create a wallet first, then save it to create the vault.',
      );
      return;
    }
    await _saveVault(context);
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

  Widget _dangerCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sensitive actions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revealing a private key or recovery phrase gives anyone who sees the screen full control. '
            'Never share them, never type them into a website.',
            style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => appState.lock(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Lock wallet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _revealSecrets(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Reveal secrets?',
      message: 'Anyone who can see this screen can steal all funds. Only reveal secrets on a trusted, private device.',
      confirmLabel: 'Reveal',
    );
    if (!confirmed || !context.mounted) return;
    final key = appState.privateKey!;
    final privateKey = WalletCore.privateKeyHex(key);
    final mnemonic = appState.mnemonic;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sensitive export'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only copy a secret when you are restoring it now. '
                'The clipboard may be visible to other applications.',
              ),
              const SizedBox(height: 14),
              const Text(
                'Private key',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                privateKey,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Recovery phrase',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(mnemonic ?? 'Not available for this import.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                _copySecret(dialogContext, privateKey, 'Private key'),
            child: const Text('Copy private key'),
          ),
          if (mnemonic != null)
            TextButton(
              onPressed: () =>
                  _copySecret(dialogContext, mnemonic, 'Recovery phrase'),
              child: const Text('Copy recovery phrase'),
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
    final label = await promptText(
      context,
      title: 'Wallet name in vault',
      label: 'Name',
      initialValue: 'Wallet ${appState.profiles.length + 1}',
    );
    if (label == null || label.trim().isEmpty || !context.mounted) return;
    try {
      if (appState.vaultUnlocked) {
        await appState.saveVaultAccountWithSession(
          label: label.trim(),
          key: appState.privateKey!,
          mnemonic: appState.mnemonic,
        );
      } else {
        final password = await _requestVaultPasswordForSave(context);
        if (password == null || !context.mounted) return;
        await appState.saveVaultAccount(
          password,
          label: label.trim(),
          key: appState.privateKey!,
          mnemonic: appState.mnemonic,
        );
      }
      if (context.mounted) {
        showInfo(context, 'Wallet saved to the encrypted vault.');
        setState(() {});
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _chooseSecretStorage(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Secret storage'),
        content: const Text(
          'Encrypted vault is the only persistent secret storage offered. '
          'It uses your password plus this device’s protected key. Plaintext '
          'private keys on disk are unsafe and are intentionally not supported.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'session'),
            child: const Text('Keep session-only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'vault'),
            child: const Text('Save encrypted vault'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'vault') {
      await _saveVault(context);
    } else {
      showInfo(
        context,
        'Secret remains in memory only and is cleared when locked.',
      );
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
        final resolvedPath = pathLabel == 'Standard EVM'
            ? (accountIndex != null && accountIndex >= 0
                  ? WalletCore.standardPathForAccount(accountIndex)
                  : '')
            : pathLabel == 'Custom'
            ? customPathController.text.trim()
            : WalletCore.standardPaths[pathLabel]!;
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
                      pathLabel == 'Standard EVM'
                          ? "m/44'/60'/0'/0/0 — the same first-account path "
                                'used by MetaMask, Trust Wallet, SafePal, Ledger '
                                'Live and Trezor. Change the account index for '
                                'additional accounts.'
                          : pathLabel == 'Ledger Legacy (MEW)'
                          ? "m/44'/60'/0'/0 — older MEW and Ledger setups."
                          : 'Enter any BIP-32 path, for example '
                                "m/44'/60'/0'/0/0.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    if (pathLabel == 'Standard EVM') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: accountIndexController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr(context, 'Account index'),
                          helperText: '0 = first account, 1 = second account',
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
                  final path = pathLabel == 'Standard EVM'
                      ? (index != null && index >= 0
                            ? WalletCore.standardPathForAccount(index)
                            : '')
                      : pathLabel == 'Custom'
                      ? customPathController.text.trim()
                      : WalletCore.standardPaths[pathLabel]!;
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
    // A raw private key is already the complete backup. Do not add an
    // encrypted secret store without an explicit choice in Wallet manager.
    if (!context.mounted) return;
    await _offerProfileOnly(context);
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
  final path = await promptText(
    context,
    title: 'Derivation path',
    label: 'Path',
    initialValue: WalletCore.defaultPath,
  );
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
  } catch (_) {
    if (context.mounted) {
      showError(
        context,
        'Wrong vault password, or this device key cannot open the vault. '
        'The vault uses the password set when its first wallet was saved.',
      );
    }
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

import 'dart:async';

import '../localized_text.dart';

import '../app_state.dart';
import '../models.dart';
import 'common.dart';
import 'receipt_page.dart';

/// One clean place for everything this device sent or is still waiting on.
///
/// Receipts are encrypted at rest. Pending transactions contain only public
/// transaction data. Nothing here is fetched from a third party unless the
/// user asks for an explorer lookup from the receipt detail.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage>
    with AutomaticKeepAliveClientMixin {
  List<LocalReceipt>? _receipts;
  bool _loading = true;
  int _filter = 0; // 0 all, 1 pending, 2 done, 3 failed

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final receipts = await appState.loadLocalReceipts();
    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final pending = appState.pendingTxs;
    final receipts = _receipts ?? const <LocalReceipt>[];
    final rows = <_ActivityRow>[
      for (final tx in pending) _ActivityRow.pending(tx),
      for (final receipt in receipts) _ActivityRow.receipt(receipt),
    ]..sort((a, b) => b.time.compareTo(a.time));
    final filtered = switch (_filter) {
      1 => rows.where((row) => row.pending != null).toList(),
      2 => rows.where((row) => row.receipt?.status == 'success').toList(),
      3 => rows.where((row) => row.receipt?.status != 'success').toList(),
      _ => rows,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Everything you sent, in one place.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_receipts != null)
                    Text(
                      '${_receipts!.length} saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All', 0, rows.length),
                  _filterChip(
                    'Pending',
                    1,
                    rows.where((r) => r.pending != null).length,
                  ),
                  _filterChip(
                    'Done',
                    2,
                    rows.where((r) => r.receipt?.status == 'success').length,
                  ),
                  _filterChip(
                    'Failed',
                    3,
                    rows
                        .where(
                          (r) =>
                              r.receipt != null &&
                              r.receipt!.status != 'success',
                        )
                        .length,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'Loading activity…',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                _emptyCard()
              else
                for (final row in filtered) _activityTile(row),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int value, int count) {
    return ChoiceChip(
      label: Text('$label${count == 0 ? '' : ' $count'}'),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _emptyCard() {
    final scheme = Theme.of(context).colorScheme;
    return InfoCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 52, color: scheme.primary),
            const SizedBox(height: 12),
            const Text(
              'No activity yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'When you send BNB or a token, its status and receipt appear '
              'here — offline, on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPending(PendingTx tx) async {
    final confirmed = await appState.checkPendingTx(tx.hash);
    if (!mounted) return;
    if (confirmed) {
      showInfo(context, 'Confirmed on-chain. The waiting row was removed.');
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not confirmed yet'),
        content: Text(
          'No receipt was found for:\n\n${tx.hash}\n\n'
          'The node may not have seen it, or it may still be pending. '
          'Do not resend until you have checked this hash on an explorer. '
          'Discarding this row does not cancel anything on-chain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard row'),
          ),
        ],
      ),
    );
    if (discard == true) {
      await appState.removePendingTx(tx.hash);
      if (mounted) {
        showInfo(
          context,
          'Waiting row discarded. The transaction was not cancelled.',
        );
      }
    }
  }

  Widget _activityTile(_ActivityRow row) {
    final scheme = Theme.of(context).colorScheme;
    final receipt = row.receipt;
    final pending = row.pending;
    final symbol = receipt?.assetSymbol ?? pending?.assetSymbol ?? 'BNB';
    final amount = receipt?.amountHuman ?? pending?.amountHuman ?? '—';
    final isPending = pending != null;
    final unknown =
        pending != null &&
        (pending.status == 'unknown' || pending.status == 'signed');
    final failed = receipt != null && receipt.status != 'success';
    final status = unknown
        ? 'Unconfirmed'
        : isPending
        ? 'Pending'
        : failed
        ? 'Failed'
        : 'Done';
    final color = unknown
        ? scheme.error
        : isPending
        ? const Color(0xFFB45309)
        : failed
        ? scheme.error
        : const Color(0xFF15803D);
    final icon = unknown
        ? Icons.help_outline_rounded
        : isPending
        ? Icons.schedule_rounded
        : failed
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          '$amount $symbol',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          unknown
              ? 'Broadcast result unknown — check before resending'
              : isPending
              ? 'Waiting for confirmation'
              : '${row.timeLabel} · ${receipt!.confirmations} confirmation'
                    '${receipt.confirmations == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (receipt != null) ...[
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
            if (unknown) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 28,
                child: TextButton(
                  onPressed: () => _checkPending(pending),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Check', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ],
        ),
        onTap: receipt == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptPage(receipt: receipt),
                ),
              ),
      ),
    );
  }
}

class _ActivityRow {
  _ActivityRow.pending(PendingTx tx)
    : pending = tx,
      receipt = null,
      time =
          DateTime.tryParse(tx.sentAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);

  _ActivityRow.receipt(LocalReceipt value)
    : pending = null,
      receipt = value,
      time =
          DateTime.tryParse(value.savedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);

  final PendingTx? pending;
  final LocalReceipt? receipt;
  final DateTime time;

  String get timeLabel {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

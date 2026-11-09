import 'dart:async';
import 'dart:convert';

import '../localized_text.dart';

import '../app_state.dart';
import '../encrypted_log_store.dart';
import '../log_presenter.dart';
import 'common.dart';

/// §8 / §10b-E: one log source, two presentations.
///
/// Simple mode is a friendly timeline (icon + 2–4 words + time). Expert mode
/// is the structured, filterable record. Both read the same encrypted log
/// file, so they can never disagree.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _search = TextEditingController();
  Timer? _liveTimer;
  bool _live = false;
  bool _simple = true;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = const [];
  String _query = '';
  String? _category;
  String? _level;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _toggleLive() {
    setState(() => _live = !_live);
    _liveTimer?.cancel();
    if (_live) {
      _liveTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _load(silent: true),
      );
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!appState.unlocked) {
      _liveTimer?.cancel();
      if (silent) return;
      setState(() {
        _loading = false;
        _entries = const [];
        _error = 'Unlock the wallet to read its encrypted log.';
      });
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await EncryptedLogStore.readAll();
      if (!mounted) return;
      final unchanged =
          entries.length == _entries.length &&
          (entries.isEmpty || entries.first['ts'] == _entries.first['ts']);
      if (silent && unchanged) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final query = _query.trim().toLowerCase();
    return [
      for (final entry in _entries)
        if ((_category == null || entry['category'] == _category) &&
            (_level == null || entry['level'] == _level) &&
            (query.isEmpty || jsonEncode(entry).toLowerCase().contains(query)))
          entry,
    ];
  }

  /// Flattens entries with session headers (30+ minutes of quiet starts a new
  /// session). Kept as a list of plain objects so the ListView stays
  /// virtualized even with thousands of lines.
  List<Object> get _items {
    final items = <Object>[];
    DateTime? previous;
    for (final entry in _visible) {
      final at = DateTime.tryParse('${entry['ts']}')?.toLocal();
      if (at != null &&
          (previous == null || previous.difference(at).inMinutes.abs() >= 30)) {
        items.add(at);
      }
      items.add(entry);
      previous = at ?? previous;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: tr(context, 'View raw requests'),
            onPressed: _showRawRequests,
            icon: const Icon(Icons.code),
          ),
          IconButton(
            tooltip: _live ? 'Pause live tail' : 'Live tail',
            onPressed: _toggleLive,
            icon: Icon(_live ? Icons.pause_circle : Icons.play_circle_outline),
          ),
          IconButton(
            tooltip: tr(context, 'Refresh logs'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export-text') _export(json: false);
              if (value == 'export-json') _export(json: true);
              if (value == 'clear') _clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export-text',
                child: Text('Export shown as text'),
              ),
              PopupMenuItem(
                value: 'export-json',
                child: Text('Export shown as JSON'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('Clear all logs')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text('Simple'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.table_rows_outlined),
                        label: Text('Expert'),
                      ),
                    ],
                    selected: {_simple},
                    onSelectionChanged: (selection) =>
                        setState(() => _simple = selection.first),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Logs stay on this device, encrypted, and never contain seed '
                    'words or keys. Exporting a log can reveal your activity — '
                    'share it only when you choose to.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: tr(
                        context,
                        'Search messages, category, tx hash…',
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category ?? 'all',
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: tr(context, 'Category'),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All'),
                            ),
                            for (final category in LogCategory.values)
                              DropdownMenuItem(
                                value: category.name,
                                child: Text(category.name),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _category = value == 'all' ? null : value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _level ?? 'all',
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: tr(context, 'Level'),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All'),
                            ),
                            for (final level in LogLevel.values)
                              DropdownMenuItem(
                                value: level.name,
                                child: Text(level.name),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _level = value == 'all' ? null : value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(items)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Object> items) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_loading && items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No log lines yet. Every network action, fee check and transaction '
            'step is written here in plain words.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6E6E6E)),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) return _sessionHeader(item);
        return _entryCard(item as Map<String, dynamic>);
      },
    );
  }

  Widget _sessionHeader(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final stamp = today
        ? 'Today ${two(at.hour)}:${two(at.minute)}'
        : '${at.year}-${two(at.month)}-${two(at.day)} '
              '${two(at.hour)}:${two(at.minute)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: Text(
        '$stamp  ·  session',
        style: const TextStyle(
          color: Color(0xFF6E6E6E),
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final presentation = presentLogEntry(entry);
    final at = DateTime.tryParse('${entry['ts']}')?.toLocal();
    final clock = at == null
        ? ''
        : '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}:'
              '${at.second.toString().padLeft(2, '0')}';
    if (_simple) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: const Color(0xFF161A1E),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showEntry(entry),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(presentation.icon, color: presentation.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      presentation.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    clock,
                    style: const TextStyle(
                      color: Color(0xFF6E6E6E),
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFF12161B),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showEntry(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      clock,
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        presentation.levelLabel,
                        style: TextStyle(
                          color: presentation.color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry['category'] ?? 'system'}',
                      style: const TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry['msg'] ?? ''}',
                  style: const TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRawRequests() async {
    final exchanges = appState.rpc.recentExchanges;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Raw requests this session'),
        content: SizedBox(
          width: 640,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exactly what was sent to the node and what it answered. This '
                'list lives only in memory, newest first, and is never written '
                'to the log file. Addresses and a broadcast transaction are '
                'public on-chain, but they still reveal your activity.',
                style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: exchanges.isEmpty
                    ? const Center(child: Text('No request yet this session.'))
                    : ListView.builder(
                        itemCount: exchanges.length,
                        itemBuilder: (context, index) {
                          final exchange = exchanges[index];
                          final at = exchange.at.toLocal();
                          final clock =
                              '${at.hour.toString().padLeft(2, '0')}:'
                              '${at.minute.toString().padLeft(2, '0')}:'
                              '${at.second.toString().padLeft(2, '0')}';
                          return ExpansionTile(
                            title: Text(
                              '${exchange.method}  ·  '
                              '${exchange.status ?? '—'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '$clock  ·  ${exchange.url}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF6E6E6E),
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            children: [
                              _rawBlock(
                                dialogContext,
                                'Request body',
                                exchange.body,
                              ),
                              const SizedBox(height: 8),
                              _rawBlock(
                                dialogContext,
                                'Node response',
                                exchange.response,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
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

  Widget _rawBlock(BuildContext context, String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => copyText(context, text, label),
              child: const Text('Copy'),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEntry(Map<String, dynamic> entry) async {
    final pretty = const JsonEncoder.withIndent('  ').convert(entry);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => copyText(dialogContext, pretty, 'Log entry'),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _export({required bool json}) async {
    if (!appState.unlocked) {
      showError(context, 'Unlock the wallet before exporting its log.');
      return;
    }
    final entries = _visible;
    if (entries.isEmpty) {
      showInfo(context, 'There is nothing to export with these filters.');
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('This export can reveal your activity'),
        content: const Text(
          'Log lines contain the nodes you talked to, times, and transaction '
          'hashes. They never contain seed words or private keys. Share the '
          'file only with someone you trust, or keep it for your own records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose export'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to clipboard'),
              subtitle: const Text('Clears itself after 30 seconds.'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save as a file'),
              subtitle: const Text('Writes a file in the system temp folder.'),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final text = json
        ? const JsonEncoder.withIndent('  ').convert(entries)
        : entries
              .map((entry) {
                final ts = entry['ts'] ?? '';
                final level = entry['level'] ?? '';
                final category = entry['category'] ?? '';
                final message = entry['msg'] ?? '';
                return '$ts [$level] [$category] $message';
              })
              .join('\n');
    if (choice == 'copy') {
      if (!mounted) return;
      await copyText(context, text, 'Log export');
      return;
    }
    try {
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final path = await exportToFile(
        'x-wallet-log-$stamp.${json ? 'json' : 'txt'}',
        text,
      );
      if (!mounted) return;
      if (path == null) {
        showInfo(context, 'Save cancelled.');
        return;
      }
      showInfo(context, 'Saved to $path');
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    }
  }

  Future<void> _clear() async {
    if (!appState.unlocked) {
      showError(context, 'Unlock the wallet before clearing its log.');
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'Clear all logs?',
      message:
          'Every stored log line on this device will be deleted. Receipts and '
          'funds are not affected.',
      confirmLabel: 'Clear logs',
    );
    if (!confirmed || !mounted) return;
    try {
      await EncryptedLogStore.clear();
      await _load();
      if (!mounted) return;
      showInfo(context, 'Logs cleared.');
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    }
  }
}

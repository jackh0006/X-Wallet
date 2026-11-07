import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import '../localized_text.dart';

import 'package:flutter/services.dart';

/// Place-based BIP-39 word picker for seed ENTRY.
///
/// Why a picker instead of a text field: the system keyboard suggests,
/// caches and cloud-syncs what you type (GBoard/Russian auto-learn etc).
/// Here the only thing the keyboard ever sees is a SEARCH substring for the
/// PUBLIC wordlist — never the assembled phrase, which is built internally
/// from tap order. No gesture-typing traces, no IME dictionary entries.
///
/// Usable with 12 or 24 words; every word must come from the official list.
Future<String?> showSeedPicker(BuildContext context, {required int wordCount}) {
  assert(wordCount == 12 || wordCount == 24, 'BIP-39 supports 12 or 24 words.');
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SeedPickerDialog(wordCount: wordCount),
  );
}

class _SeedPickerDialog extends StatefulWidget {
  const _SeedPickerDialog({required this.wordCount});

  final int wordCount;

  @override
  State<_SeedPickerDialog> createState() => _SeedPickerDialogState();
}

class _SeedPickerDialogState extends State<_SeedPickerDialog> {
  static final List<String> _words = Language.english.list;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  List<String> _picked = [];
  late List<String> _filtered;
  String? _pasteError;

  @override
  void initState() {
    super.initState();
    _filtered = _words;
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      if (q == _query) return;
      _query = q;
      setState(() {
        _filtered = q.isEmpty
            ? <String>[]
            : _words.where((w) => w.startsWith(q)).take(32).toList();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(String word) {
    if (_picked.length >= widget.wordCount) return;
    setState(() {
      _picked = [..._picked, word];
      _search.clear();
      _query = '';
      _filtered = const [];
    });
  }

  void _removeAt(int index) {
    setState(() {
      final list = [..._picked]..removeAt(index);
      _picked = list;
    });
  }

  void _clearAll() => setState(() {
    _picked = [];
    _search.clear();
    _filtered = const [];
    _pasteError = null;
  });

  /// Paste-in is explicit and user-triggered: the clipboard is read only when
  /// this button is tapped, validated against the BIP-39 wordlist/checksum,
  /// and never written to a log.
  Future<void> _pastePhrase() async {
    final data = await Clipboard.getData('text/plain');
    final words = (data?.text ?? '')
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length != widget.wordCount) {
      setState(
        () => _pasteError =
            'The clipboard holds ${words.length} words; this dialog needs '
            '${widget.wordCount}.',
      );
      return;
    }
    try {
      Mnemonic.fromSentence(words.join(' '), Language.english);
    } catch (_) {
      setState(
        () => _pasteError =
            'That is not a valid BIP-39 phrase (wrong word or checksum).',
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, words.join(' '));
  }

  bool get _complete => _picked.length == widget.wordCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Enter seed — word ${_picked.length + 1} of ${widget.wordCount}',
      ),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search the word, then tap it. Only tap-order builds the phrase — '
              'the keyboard never sees the words themselves.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (_pasteError != null) ...[
              Text(
                _pasteError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _search,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: tr(context, 'Search word list'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_filtered.isNotEmpty)
              SizedBox(
                height: 130,
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final word = _filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text('${index + 1}. $word'),
                      onTap: () => _add(word),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _picked.length; i++)
                      InputChip(
                        label: Text('${i + 1} ${_picked[i]}'),
                        deleteIcon: const Icon(
                          Icons.backspace_outlined,
                          size: 16,
                        ),
                        onDeleted: () => _removeAt(i),
                      ),
                    if (_picked.isEmpty)
                      const Text(
                        'No words yet — pick word 1.',
                        style: TextStyle(color: Color(0xFF808080)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _pastePhrase, child: const Text('Paste phrase')),
        TextButton(onPressed: _clearAll, child: const Text('Clear')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _complete
              ? () => Navigator.pop(context, _picked.join(' '))
              : null,
          child: Text(
            _complete ? 'Use phrase' : 'Pick all ${widget.wordCount}',
          ),
        ),
      ],
    );
  }
}

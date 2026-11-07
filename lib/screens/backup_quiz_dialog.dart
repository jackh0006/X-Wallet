import '../localized_text.dart';

import '../backup_quiz.dart';

/// Asks the user to re-type 3 random words of their written phrase. Returns
/// true only when every word matches. No word is shown in this dialog, so a
/// screenshot of it is useless. The answer fields are disposed on close.
Future<bool> runBackupQuiz(BuildContext context, String mnemonic) async {
  final words = mnemonic.trim().split(RegExp(r'\s+'));
  if (words.length < 3) {
    // Imported single-key wallets have no phrase to quiz; nothing to verify.
    return true;
  }
  final positions = BackupQuiz.pickPositions(wordCount: words.length);
  final controllers = <int, TextEditingController>{
    for (final position in positions) position: TextEditingController(),
  };
  String? error;
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Prove you saved the phrase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type these words from the paper backup you just made. The '
                'dialog shows no hints — that is the point. A wrong answer '
                'will not unlock or create the wallet.',
              ),
              const SizedBox(height: 14),
              for (final position in positions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[position],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Word ${position + 1}'),
                      hintText: tr(context, 'from your written backup'),
                    ),
                    onSubmitted: (_) {
                      // Enter anywhere submits; validation stays in one place.
                      final answers = {
                        for (final entry in controllers.entries)
                          entry.key: entry.value.text,
                      };
                      if (BackupQuiz.answersMatch(
                        words: words,
                        answers: answers,
                      )) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setState(
                          () => error =
                              'That does not match. Check your written backup '
                              'and try again.',
                        );
                      }
                    },
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
            onPressed: () {
              final answers = {
                for (final entry in controllers.entries)
                  entry.key: entry.value.text,
              };
              if (BackupQuiz.answersMatch(words: words, answers: answers)) {
                Navigator.pop(dialogContext, true);
              } else {
                setState(
                  () => error =
                      'That does not match. Check your written backup and try '
                      'again.',
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    ),
  );
  for (final controller in controllers.values) {
    controller.dispose();
  }
  return passed == true;
}

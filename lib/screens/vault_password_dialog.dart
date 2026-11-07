import 'package:flutter/material.dart';

import '../password_strength.dart';

/// Password entry for the encrypted vault.
///
/// The vault accepts any non-empty password. This dialog never trims the
/// input, so spaces inside a passphrase are preserved. Creation shows a
/// confirmation field and a live strength score; unlocking only asks once.
Future<String?> showVaultPasswordDialog(
  BuildContext context, {
  required String title,
  String label = 'Vault password',
  bool requireConfirm = false,
  bool showStrength = false,
  String confirmLabel = 'Continue',
}) {
  final controller = TextEditingController();
  final confirmController = TextEditingController();
  var obscure = true;
  String? error;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final value = controller.text;
        final strength = showStrength ? evaluatePassword(value) : null;
        final matches = !requireConfirm || value == confirmController.text;

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => setState(() => error = null),
                    decoration: InputDecoration(
                      labelText: label,
                      errorText: error,
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (requireConfirm) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => setState(() => error = null),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        errorText: matches ? null : 'Passwords do not match.',
                      ),
                    ),
                  ],
                  if (showStrength && strength != null) ...[
                    const SizedBox(height: 12),
                    _StrengthBar(result: strength),
                    const SizedBox(height: 6),
                    Text(
                      strength.advice,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (!showStrength) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'The password is not trimmed and spaces are significant.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
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
                final current = controller.text;
                if (current.isEmpty) {
                  setState(() => error = 'Enter the vault password.');
                  return;
                }
                if (requireConfirm && current != confirmController.text) {
                  setState(() => error = 'Passwords do not match.');
                  return;
                }
                Navigator.pop(dialogContext, current);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.result});

  final PasswordStrengthResult result;

  Color get _color => switch (result.level) {
    PasswordStrength.veryWeak => Colors.redAccent,
    PasswordStrength.weak => Colors.orangeAccent,
    PasswordStrength.fair => Colors.amber,
    PasswordStrength.strong => Colors.lightGreenAccent,
    PasswordStrength.veryStrong => Colors.greenAccent,
  };

  @override
  Widget build(BuildContext context) {
    final filled = (result.score.clamp(0, 7));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Password strength',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              result.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: filled / 7.0,
            minHeight: 7,
            backgroundColor: const Color(0x22808080),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

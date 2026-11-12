import 'dart:async';
import 'dart:io';

import '../localized_text.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../chains.dart';
import '../models.dart';
import '../wallet_core.dart';
import '../platform_files.dart';

/// Small shared UI helpers for every screen.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    ),
  );
}

void showError(BuildContext context, Object error) {
  final message = error is Exception ? error.toString() : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> copyText(BuildContext context, String text, String label) async {
  final lowerLabel = label.toLowerCase();
  final secretLabel =
      lowerLabel.contains('key') ||
      lowerLabel.contains('seed') ||
      lowerLabel.contains('phrase') ||
      lowerLabel.contains('password') ||
      lowerLabel.contains('secret');
  if (secretLabel || !ClipboardGuard.secretFree(text)) {
    if (context.mounted) {
      showError(
        context,
        'I never copy seed words or private keys to the clipboard through '
        'this helper — they stay inside the unlocked wallet only.',
      );
    }
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showInfo(context, '$label copied · clears itself after 30 s');
  }
  // Clipboard auto-clear (spec §7): after 30 s the clipboard is emptied —
  // but ONLY if it still holds what this app copied, so a user who copied
  // something fresh in those 30 s never loses their content.
  _clipboardClearTimer?.cancel();
  _clipboardClearTimer = Timer(const Duration(seconds: 30), () async {
    try {
      final current = await Clipboard.getData('text/plain');
      if (current?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      // Clipboard unreadable on this platform — leaving it alone is the
      // safe move.
    }
  });
}

Timer? _clipboardClearTimer;

String shortAddress(String address) => WalletCore.shortAddress(address);

String formatToken(BigInt value, int decimals) =>
    WalletCore.formatUnits(value, decimals);

Future<void> showQrDialog(BuildContext context, String address) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Receive address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: address,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          SelectableText(address, style: const TextStyle(fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => copyText(context, address, 'Address'),
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String? initialValue,
  bool obscure = false,
  TextInputType? keyboardType,
  String? Function(String)? validator,
  int? maxLines,
  String? hintText,
}) {
  final controller = TextEditingController(text: initialValue);
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            labelText: label == null ? null : tr(context, label),
            hintText: hintText == null ? null : tr(context, hintText),
            errorText: error,
          ),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (validator != null) {
                final result = validator(value);
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
              }
              Navigator.pop(context, value);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showMessage(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Loads the selected chain's native balance and every configured token.
Future<Map<String, BigInt>> loadBalances(String address) async {
  final rpc = appState.rpc;
  await rpc.ensureConnected();
  final native = TokenInfo(
    symbol: rpc.chain.nativeSymbol,
    name: rpc.chain.nativeName,
    address: '',
    decimals: 18,
    network: rpc.network,
    native: true,
  );
  final tokens = <TokenInfo>[native, ...appState.tokensForNetwork];
  final out = <String, BigInt>{};
  for (final token in tokens) {
    try {
      if (token.native) {
        out[token.symbol] = await rpc.getNativeBalance(address);
      } else {
        out[token.symbol] = await rpc.getTokenBalance(token.address, address);
      }
    } catch (_) {
      out[token.symbol] = BigInt.from(-1);
    }
  }
  return out;
}

String explorerUrl(String network, String path) =>
    '${Chains.byKey(network).explorerBase}$path';

/// Writes a secret to a file for the user to export. Used only for explicit
/// backup actions; the file is never uploaded.
Future<String?> exportToFile(String fileName, String content) async {
  if (PlatformFiles.isAndroid) {
    final saved = await PlatformFiles.saveText(fileName, content);
    return saved ? 'the location you chose' : null;
  }
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content, flush: true);
  return file.path;
}

/// Binary sibling of [exportToFile] for receipt images.
Future<String?> exportBytesToFile(String fileName, List<int> bytes) async {
  if (PlatformFiles.isAndroid) {
    final saved = await PlatformFiles.saveBytes(
      fileName,
      Uint8List.fromList(bytes),
    );
    return saved ? 'the location you chose' : null;
  }
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

import 'dart:io';

import '../localized_text.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../cold_wallet.dart';
import '../cold_wallet_protocol.dart';
import '../cold_wallet_service.dart';
import '../models.dart';
import '../wallet_core.dart';
import '../widgets/hold_to_confirm.dart';
import 'common.dart';
import 'wallet_page.dart' show showUnlockVaultDialog;

/// Small, deliberately boring dialogs for the air-gapped workflow.
///
/// The transport is a single JSON envelope shown as a QR code and optionally
/// saved to a file. There is no camera dependency in this Linux build; the
/// import dialog accepts pasted text or a file path, which is the documented
/// fallback. Every payload is public data and is checked by the protocol layer
/// before it reaches the signer.

const String _coldExportNote =
    'This payload contains public transaction data only. Move it to the other '
    'device by QR or by saving the file.';

Future<void> showColdPayloadDialog(
  BuildContext context, {
  required String title,
  required String payload,
  required String fileName,
  String note = _coldExportNote,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note,
                style: const TextStyle(
                  color: Color(0xFF6E6E6E),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 260,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                payload,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final path = await exportToFile(fileName, payload);
            if (!dialogContext.mounted) return;
            showInfo(dialogContext, 'Saved: $path');
          },
          icon: const Icon(Icons.save_alt, size: 17),
          label: const Text('Save file'),
        ),
        TextButton.icon(
          onPressed: () => copyText(dialogContext, payload, 'Payload'),
          icon: const Icon(Icons.copy, size: 17),
          label: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Import a payload from the clipboard or an explicit file path. The user can
/// also paste directly into the text field. No file picker plugin is required.
Future<String?> showColdImportDialog(
  BuildContext context, {
  required String title,
  required String hint,
}) {
  final controller = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: const TextStyle(
                    color: Color(0xFF6E6E6E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    labelText: tr(context, 'Payload'),
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        final text = data?.text?.trim() ?? '';
                        if (text.isEmpty) {
                          setState(() => error = 'The clipboard is empty.');
                          return;
                        }
                        controller.text = text;
                        setState(() => error = null);
                      },
                      icon: const Icon(Icons.content_paste, size: 16),
                      label: const Text('Paste clipboard'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final path = await promptText(
                          dialogContext,
                          title: 'Read payload from file',
                          label: 'Absolute file path',
                        );
                        if (path == null || path.trim().isEmpty) return;
                        try {
                          final text = await File(path.trim()).readAsString();
                          controller.text = text.trim();
                          setState(() => error = null);
                        } catch (e) {
                          setState(() => error = 'Could not read file: $e');
                        }
                      },
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Read file'),
                    ),
                  ],
                ),
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
              final value = controller.text.trim();
              if (value.isEmpty) {
                setState(() => error = 'Paste or read a payload first.');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- pairing --

Future<void> coldExportPairing(BuildContext context) async {
  if (!appState.coldMode) {
    showInfo(context, 'Switch to Cold mode first.');
    return;
  }
  if (!appState.unlocked) {
    await showUnlockVaultDialog(context);
    if (!context.mounted) return;
  }
  final phrase = appState.mnemonic;
  final currentAddress = appState.address;
  if (phrase == null &&
      (currentAddress == null ||
          appState.watchOnly ||
          appState.privateKey == null)) {
    if (context.mounted) {
      showError(
        context,
        'Unlock a wallet with a recovery phrase or private key first. '
        'A watch-only profile cannot export a cold pairing.',
      );
    }
    return;
  }
  try {
    final addresses = phrase != null
        ? WalletCore.deriveAddressList(phrase: phrase, count: 20)
        : <String>[currentAddress!];
    final pairing = ColdWalletProtocol.exportPairing(
      walletName: 'X Wallet cold signer',
      chainId: appState.rpc.chainId,
      addresses: addresses,
    );
    final payload = ColdWalletProtocol.encodePairing(pairing);
    if (!context.mounted) return;
    await showColdPayloadDialog(
      context,
      title: 'Cold pairing data',
      payload: payload,
      fileName: 'bnb-cold-pairing.json',
      note:
          'Public addresses only — no seed or private key. The online device '
          'must show the same fingerprint: ${pairing.fingerprint}.',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> coldImportPairing(BuildContext context) async {
  final text = await showColdImportDialog(
    context,
    title: 'Import cold pairing',
    hint:
        'Scan the cold device\'s QR or open its pairing file. Check the '
        'fingerprint on both screens before accepting.',
  );
  if (text == null || !context.mounted) return;
  try {
    final pairing = ColdWalletProtocol.decodePairingEnvelope(text);
    if (pairing.chainId != appState.rpc.chainId) {
      throw StateError(
        'This pairing is for chain ${pairing.chainId}, but the wallet is on '
        'chain ${appState.rpc.chainId}. Switch network first.',
      );
    }
    final ok = await confirmDialog(
      context,
      title: 'Pair this cold wallet?',
      message:
          '${pairing.walletName}\n\n'
          'First address: ${pairing.addresses.first}\n'
          'Fingerprint: ${pairing.fingerprint}\n'
          'Addresses: ${pairing.addresses.length}\n\n'
          'The cold device must show the same fingerprint. If it does not, '
          'cancel: this is the only moment you can catch a substituted '
          'pairing.',
      confirmLabel: 'Pair',
    );
    if (!ok || !context.mounted) return;
    await appState.adoptColdPairing(pairing);
    if (context.mounted) {
      showInfo(context, 'Cold wallet paired. The first address is watch-only.');
    }
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

// -------------------------------------------------------------- requests ---

Map<String, ColdTxAssetInfo> _knownTokens() => {
  for (final token in appState.rpc.tokens)
    if (!token.native && token.address.isNotEmpty)
      token.address.toLowerCase(): ColdTxAssetInfo(
        isNative: false,
        symbol: token.symbol,
        name: token.name,
        contractAddress: token.address,
        decimals: token.decimals,
      ),
};

String _amountLine(ColdTxDecodeResult decoded) {
  if (decoded.assetInfo.isNative) {
    return '${WalletCore.formatEther(decoded.value)} BNB';
  }
  final decimals = decoded.assetInfo.decimals ?? 18;
  final raw = decoded.decodedValue ?? BigInt.zero;
  return '${WalletCore.formatUnits(raw, decimals)} '
      '${decoded.assetInfo.symbol ?? 'tokens'}';
}

Future<void> coldShowPendingRequest(
  BuildContext context, {
  ColdTxRequest? request,
}) async {
  try {
    final pending =
        request ?? await ColdWalletService.instance.latestPendingRequest();
    if (pending == null) {
      if (context.mounted) showInfo(context, 'No pending cold request.');
      return;
    }
    if (!context.mounted) return;
    await showColdPayloadDialog(
      context,
      title: 'Pending cold request',
      payload: ColdWalletProtocol.encodeRequest(pending),
      fileName: 'bnb-cold-request-${pending.id}.json',
      note:
          'Take this to the cold signer. It is valid until '
          '${pending.expiresAt}.',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> coldSignPendingRequest(
  BuildContext context, {
  ColdTxRequest? request,
}) async {
  if (!appState.coldMode) {
    showInfo(context, 'Switch to Cold mode first.');
    return;
  }
  try {
    final incoming =
        request ??
        await _importRequestPayload(context, title: 'Sign a cold request');
    if (incoming == null || !context.mounted) return;
    if (!appState.unlocked) {
      await showUnlockVaultDialog(context);
      if (!context.mounted) return;
    }
    final phrase = appState.mnemonic;
    final privateKey = appState.privateKey;
    if (phrase == null && privateKey == null) {
      showError(
        context,
        'Unlock a wallet with a recovery phrase or private key first. '
        'A watch-only profile cannot sign offline.',
      );
      return;
    }
    if (incoming.chainId != appState.rpc.chainId) {
      throw StateError(
        'Request is for chain ${incoming.chainId}; this cold device is set to '
        'chain ${appState.rpc.chainId}.',
      );
    }
    final addresses = phrase != null
        ? WalletCore.deriveAddressList(phrase: phrase, count: 20)
        : <String>[privateKey!.address.eip55With0x];
    if (!addresses.any((a) => a.toLowerCase() == incoming.from.toLowerCase())) {
      throw StateError(
        phrase != null
            ? 'The request signer is not one of this recovery phrase\'s first '
                  '20 addresses on the default BIP-44 path.'
            : 'The request signer is not the unlocked private-key address.',
      );
    }
    final decoded = WalletCore.decodeTxRequest(
      request: incoming,
      coldAddresses: addresses,
      knownTokens: _knownTokens(),
    );
    if (!context.mounted) return;
    var passphrase = '';
    if (phrase != null) {
      final entered = await promptText(
        context,
        title: 'BIP-39 passphrase',
        label: 'Optional passphrase (hidden)',
        obscure: true,
        hintText: tr(context, 'Leave empty if the wallet has no passphrase'),
      );
      if (entered == null || !context.mounted) return;
      passphrase = entered;
    }
    final summary = [
      'Network: BSC chain ${decoded.chainId}',
      'From: ${decoded.from}',
      'To: ${decoded.decodedTo ?? decoded.to}',
      if (decoded.functionName != null) 'Function: ${decoded.functionName}',
      'Amount: ${_amountLine(decoded)}',
      'Nonce: ${decoded.nonce}',
      'Gas limit: ${decoded.gasLimit}',
      'Max fee: ${WalletCore.formatEther(decoded.totalPossibleFee)} BNB',
      'Request expires: ${decoded.expiresAt.toIso8601String()}',
      'Request hash: ${ColdWalletProtocol.requestHash(incoming)}',
      if (decoded.warning != null) '⚠ ${decoded.warning}',
    ].join('\n');
    final held = await showHoldToConfirm(
      context,
      title: 'Review offline signing',
      message:
          '$summary\n\nThis device is offline. Signing creates a signed '
          'transaction, not a broadcast. Verify the recipient and amount on '
          'the next screen before you carry the response back.',
      label: 'Hold to sign offline',
    );
    if (!held || !context.mounted) return;
    final signature = phrase != null
        ? await ColdWalletService.instance.signRequest(
            request: incoming,
            phrase: phrase,
            passphrase: passphrase,
          )
        : await ColdWalletService.instance.signRequestWithKey(
            request: incoming,
            key: privateKey!,
          );
    if (!context.mounted) return;
    await showColdPayloadDialog(
      context,
      title: 'Signed response',
      payload: ColdWalletProtocol.encodeSignature(signature),
      fileName: 'bnb-cold-signature-${signature.requestId}.json',
      note:
          'Take this back to the online device. It cannot move funds until '
          'that device verifies and broadcasts it. Tx hash: '
          '${signature.signedTxHash}',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<void> coldShowLastSignature(BuildContext context) async {
  try {
    final signature = await ColdWalletService.instance.latestSignature();
    if (signature == null) {
      if (context.mounted) showInfo(context, 'No signed response stored yet.');
      return;
    }
    if (!context.mounted) return;
    await showColdPayloadDialog(
      context,
      title: 'Last signed response',
      payload: ColdWalletProtocol.encodeSignature(signature),
      fileName: 'bnb-cold-signature-${signature.requestId}.json',
      note:
          'Public signed bytes for request ${signature.requestId}. Tx hash: '
          '${signature.signedTxHash}',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<ColdTxRequest?> _importRequestPayload(
  BuildContext context, {
  required String title,
}) async {
  final text = await showColdImportDialog(
    context,
    title: title,
    hint:
        'Paste the online device\'s request payload. The bundled Linux build '
        'has no camera QR reader; use the QR for visual transfer or save/read '
        'the JSON file.',
  );
  if (text == null) return null;
  return ColdWalletProtocol.decodeRequestEnvelope(text);
}

// ------------------------------------------------------------- broadcast ---

Future<void> coldImportAndBroadcastSignature(BuildContext context) async {
  if (!appState.onlineMode) {
    showInfo(context, 'Switch to Online companion mode first.');
    return;
  }
  final pairing = appState.coldPairing;
  if (pairing == null || pairing.addresses.isEmpty) {
    showError(
      context,
      'Import the cold device pairing first — this device cannot know which '
      'signer to trust.',
    );
    return;
  }
  final text = await showColdImportDialog(
    context,
    title: 'Import signed response',
    hint:
        'Paste the cold device\'s signed payload. It is verified against the '
        'exact pending request before any broadcast is attempted.',
  );
  if (text == null || !context.mounted) return;
  try {
    final signature = ColdWalletProtocol.decodeSignatureEnvelope(text);
    final request = await ColdWalletService.instance.pendingRequestById(
      signature.requestId,
    );
    if (request == null) {
      throw StateError(
        'There is no live pending request with ID ${signature.requestId}. '
        'Expired, already used, or from another wallet.',
      );
    }
    final expectedFrom = appState.address ?? pairing.addresses.first;
    final verified = await ColdWalletService.instance.verifyResponse(
      request: request,
      signature: signature,
      expectedFrom: expectedFrom,
    );
    if (!verified.ok) {
      throw StateError(verified.reason);
    }
    final decoded = WalletCore.decodeTxRequest(
      request: request,
      coldAddresses: pairing.addresses,
      knownTokens: _knownTokens(),
    );
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Broadcast this signed transfer?',
      message:
          'Verified signer: ${verified.from}\n'
          'To: ${decoded.decodedTo ?? decoded.to}\n'
          'Amount: ${_amountLine(decoded)}\n'
          'Nonce: ${decoded.nonce}\n'
          'Tx hash: ${verified.txHash}\n\n'
          'This is the only transaction that can be built from the checked '
          'bytes. Broadcasting cannot be undone.',
      confirmLabel: 'Broadcast',
    );
    if (!ok || !context.mounted) return;
    final hash = await ColdWalletService.instance.broadcastResponse(
      rpc: appState.rpc,
      request: request,
      signature: signature,
      expectedFrom: expectedFrom,
    );
    final rawAmount = decoded.assetInfo.isNative
        ? decoded.value
        : (decoded.decodedValue ?? BigInt.zero);
    final decimals = decoded.assetInfo.decimals ?? 18;
    await appState.addPendingTx(
      PendingTx(
        hash: hash,
        network: request.chainId == 97 ? 'testnet' : 'mainnet',
        from: request.from,
        to: decoded.assetInfo.isNative
            ? request.to
            : (decoded.decodedTo ?? request.to),
        native: decoded.assetInfo.isNative,
        assetSymbol: decoded.assetInfo.isNative
            ? 'BNB'
            : (decoded.assetInfo.symbol ?? 'TOKEN'),
        assetAddress: decoded.assetInfo.contractAddress ?? '',
        amountRaw: rawAmount.toString(),
        amountHuman: WalletCore.formatUnits(rawAmount, decimals),
        decimals: decimals,
        gasLimit: decoded.gasLimit.toString(),
        nonce: decoded.nonce,
        mode: 'eip1559',
        priorityFeePerGas: BigInt.parse(
          request.maxPriorityFeePerGas.substring(2),
          radix: 16,
        ).toString(),
        maxFeePerGas: BigInt.parse(
          request.maxFeePerGas.substring(2),
          radix: 16,
        ).toString(),
        gasPrice: '0',
        sentAt: DateTime.now().toUtc().toIso8601String(),
        tierLabel: 'cold signature',
      ),
    );
    if (!context.mounted) return;
    await showMessage(
      context,
      'Broadcast accepted',
      'The node accepted the exact verified bytes.\n\nTx hash: $hash\n\n'
          'Track it in the waiting list; nothing will be resent automatically.',
    );
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

import 'dart:convert';
import 'dart:io';

import '../localized_text.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../receipt_image.dart';
import '../wallet_core.dart';
import 'common.dart';

/// The local receipt of one finished send: every chain fact that matters,
/// kept on this device (encrypted in the receipts store), readable offline.
class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receipt});

  final LocalReceipt receipt;

  /// 4-character groups — the same view the review used, so the recipient
  /// can be compared by eye between review and receipt.
  String _groupAddress(String address) {
    final clean = address.startsWith('0x') ? address.substring(2) : address;
    final groups = <String>[];
    for (var i = 0; i + 4 <= clean.length; i += 4) {
      groups.add(clean.substring(i, i + 4));
    }
    return ['0x', ...groups].join(' ');
  }

  String _timestamp(String? iso) {
    if (iso == null || iso.isEmpty) return 'unknown';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final explorer = explorerUrl(receipt.network, '/tx/${receipt.hash}');
    final success = receipt.status == 'success';
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        success ? Icons.check_circle : Icons.error_outline,
                        color: success ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          success
                              ? (receipt.finalized
                                    ? 'Transfer final'
                                    : 'Transfer confirmed')
                              : 'Mined but reverted',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (receipt.verifiedNodes >= 2)
                        const Tooltip(
                          message:
                              'The receipt was fetched from two independent '
                              'nodes and they agree',
                          child: Chip(
                            avatar: Icon(Icons.verified, size: 16),
                            label: Text('2 nodes ✓'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${receipt.amountHuman} ${receipt.assetSymbol} sent',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To (full address — verify ALL of it):',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _groupAddress(receipt.to),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'From:',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                  SelectableText(
                    _groupAddress(receipt.from),
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                  if (!success && receipt.revertReason != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'The contract refused it: ${receipt.revertReason}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Only the network fee was spent; the amount was not transferred.',
                      style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chain facts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Network',
                    'BSC ${receipt.network} · chain ${receipt.chainId}',
                  ),
                  _row(
                    'Block',
                    '${receipt.blockNumber} · ${_timestamp(receipt.blockTimestamp)}',
                  ),
                  if (receipt.blockHash != null)
                    _row('Block hash', receipt.blockHash!),
                  if (receipt.transactionIndex != null)
                    _row('Position in block', '${receipt.transactionIndex}'),
                  if (receipt.txType != null)
                    _row(
                      'Transaction type',
                      receipt.txType == 'eip1559' ? 'EIP-1559' : 'legacy',
                    ),
                  _row(
                    'Confirmations',
                    receipt.confirmations > 0
                        ? '${receipt.confirmations}'
                        : 'being counted',
                  ),
                  _row(
                    'Finality',
                    receipt.finalized
                        ? 'final (the chain buried it)'
                        : 'included — waiting for the chain to finalize it',
                  ),
                  _row('Nonce', '${receipt.nonce}'),
                  _row(
                    'Receipt checked against',
                    receipt.verifiedNodes >= 2
                        ? '2 independent nodes (they agree)'
                        : '1 node (no second source answered)',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hash: ${receipt.hash}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            copyText(context, receipt.hash, 'Transaction hash'),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy hash'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            copyText(context, explorer, 'Explorer link'),
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Copy explorer link'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showHashQr(context),
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: const Text('Hash QR'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openExplorer(context, explorer),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open explorer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_decodedCall() != null) ...[
              const SizedBox(height: 12),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What the contract was told',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final field in _decodedCall()!)
                      _row(field.$1, field.$2),
                    const SizedBox(height: 6),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Raw call data',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        SelectableText(
                          receipt.inputData!,
                          style: const TextStyle(fontSize: 10, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => copyText(
                            context,
                            receipt.inputData!,
                            'Call data',
                          ),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy call data'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (receipt.eventLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What the chain recorded (event logs)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final line in _decodedLogs()) ...[
                      Text(line, style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 4),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Raw logs',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(receipt.eventLogs),
                          style: const TextStyle(fontSize: 10, height: 1.35),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What you paid',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Charged fee',
                    '${WalletCore.formatEther(BigInt.parse(receipt.feeWei))} BNB',
                  ),
                  _row(
                    'Gas used / limit',
                    '${receipt.gasUsed} / ${receipt.gasLimit}',
                  ),
                  if (receipt.effectiveGasPriceWei != null)
                    _row(
                      'Effective gas price',
                      '${WalletCore.formatUnits(BigInt.parse(receipt.effectiveGasPriceWei!), 9)} gwei',
                    ),
                  _row(
                    'Tier chosen',
                    receipt.tierLabel.isEmpty ? '—' : receipt.tierLabel,
                  ),
                  if (receipt.reason.isNotEmpty)
                    Text(
                      'Why that fee: ${receipt.reason}',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (receipt.note != null || receipt.balanceBeforeWei != null) ...[
              const SizedBox(height: 12),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Checks & notes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (receipt.note != null)
                      Text(
                        receipt.note!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                        ),
                      ),
                    if (receipt.balanceBeforeWei != null &&
                        receipt.balanceAfterWei != null)
                      Text(
                        'BNB balance at review: '
                        '${WalletCore.formatEther(BigInt.parse(receipt.balanceBeforeWei!))} · '
                        'right after the receipt: '
                        '${WalletCore.formatEther(BigInt.parse(receipt.balanceAfterWei!))} '
                        '(may include other activity in the same gap).',
                        style: const TextStyle(
                          color: Color(0xFF6E6E6E),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Take it with you',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A receipt is a public record of this transaction. Sharing it '
                    'reveals your address and activity, so each option asks first.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => copyText(
                          context,
                          _receiptJson(),
                          'Receipt details',
                        ),
                        icon: const Icon(Icons.copy_all, size: 16),
                        label: const Text('Copy all details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _shareText(context),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share as text'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportJson(context),
                        icon: const Icon(Icons.save_alt, size: 16),
                        label: const Text('Save JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportPng(context),
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: const Text('Save PNG'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What the node knows',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Broadcast through: ${Uri.tryParse(receipt.nodeUsed)?.host ?? receipt.nodeUsed}\n'
                    'Transport: ${receipt.transport}\n'
                    'The node knows the transaction and your IP${receipt.transport.toLowerCase().contains('tor') ? ' — hidden behind Tor here' : ' (unless you use Tor mode)'}. '
                    'It never saw your keys, your seed, or the other accounts on this device.',
                    style: const TextStyle(
                      color: Color(0xFF6E6E6E),
                      fontSize: 12,
                    ),
                  ),
                  if (receipt.rawTxHex != null) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Raw signed transaction',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        const Text(
                          'These public bytes are what went to the network. Anyone can verify them; they contain no secret beyond the transaction itself.',
                          style: TextStyle(
                            color: Color(0xFF6E6E6E),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          receipt.rawTxHex!,
                          style: const TextStyle(fontSize: 10, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => copyText(
                            context,
                            receipt.rawTxHex!,
                            'Raw transaction',
                          ),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy raw transaction'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _receiptJson() =>
      const JsonEncoder.withIndent('  ').convert(receipt.toJson());

  String _shareBody() {
    final lines = [
      'X Wallet receipt',
      '${receipt.amountHuman} ${receipt.assetSymbol}',
      'Status: ${receipt.status}${receipt.finalized ? ' (final)' : ''}',
      'To: ${receipt.to}',
      'From: ${receipt.from}',
      'Network: BSC ${receipt.network} · chain ${receipt.chainId}',
      'Block: ${receipt.blockNumber}',
      'Transaction: ${receipt.hash}',
      if (receipt.blockHash != null) 'Block hash: ${receipt.blockHash}',
      'Charged fee: '
          '${WalletCore.formatEther(BigInt.parse(receipt.feeWei))} BNB',
      'Saved: ${_timestamp(receipt.savedAt)}',
    ];
    return lines.join('\n');
  }

  /// Decodes the two calls this wallet can produce (native send has no
  /// calldata; BEP-20 transfer is `transfer(address,uint256)`). Any other
  /// calldata is shown honestly as a selector, never guessed.
  List<(String, String)>? _decodedCall() {
    final raw = receipt.inputData;
    if (raw == null || raw.isEmpty) return null;
    final hex = raw.toLowerCase().startsWith('0x') ? raw.substring(2) : raw;
    if (hex.startsWith('a9059cbb') && hex.length >= 136) {
      final toWord = hex.substring(8, 72);
      final amountWord = hex.substring(72, 136);
      final to = '0x${toWord.substring(24)}';
      final amount = BigInt.tryParse(amountWord, radix: 16);
      return [
        ('Function', 'transfer(address,uint256) — a token transfer'),
        ('Token contract', receipt.assetAddress),
        ('Recipient in the call', to),
        (
          'Amount in the call',
          amount == null
              ? 'could not decode'
              : '${WalletCore.formatUnits(amount, receipt.decimals)} '
                    '${receipt.assetSymbol}',
        ),
        if (to.toLowerCase() != receipt.to.toLowerCase())
          (
            'Warning',
            'The call recipient differs from the receipt recipient — review '
                'before trusting this record.',
          ),
      ];
    }
    return [
      ('Selector', '0x${hex.length >= 8 ? hex.substring(0, 8) : hex}'),
      (
        'Note',
        'This wallet does not recognise this call, so it shows the raw bytes '
            'instead of guessing what they mean.',
      ),
    ];
  }

  /// Transfer(address,address,uint256) topic.
  static const _transferTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

  List<String> _decodedLogs() {
    final lines = <String>[];
    for (final entry in receipt.eventLogs) {
      final topics = (entry['topics'] as List? ?? const [])
          .map((topic) => '$topic'.toLowerCase())
          .toList();
      final data = '${entry['data'] ?? ''}';
      if (topics.isNotEmpty && topics.first == _transferTopic) {
        if (topics.length >= 3) {
          final from = '0x${topics[1].substring(topics[1].length - 40)}';
          final to = '0x${topics[2].substring(topics[2].length - 40)}';
          final value = BigInt.tryParse(
            data.startsWith('0x') ? data.substring(2) : data,
            radix: 16,
          );
          lines.add(
            'Transfer '
            '${value == null ? '?' : WalletCore.formatUnits(value, receipt.decimals)} '
            '${receipt.assetSymbol} · '
            '${shortAddress(from)} → ${shortAddress(to)}',
          );
          continue;
        }
      }
      final address = '${entry['address'] ?? ''}';
      lines.add(
        'Event from ${address.isEmpty ? 'unknown contract' : shortAddress(address)} '
        '· ${topics.length} topic${topics.length == 1 ? '' : 's'}',
      );
    }
    if (lines.isEmpty) {
      lines.add('The receipt carried no decodable event log.');
    }
    return lines;
  }

  Future<void> _showHashQr(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transaction hash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: receipt.hash,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(receipt.hash, style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                copyText(dialogContext, receipt.hash, 'Transaction hash'),
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

  Future<void> _openExplorer(BuildContext context, String url) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open the block explorer?'),
        content: const Text(
          'The explorer is a third-party website. Opening it tells that site '
          'your IP address and which transaction you are looking at. The '
          'wallet itself never opens it in the background; this only happens '
          'if you say yes now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [url]);
        return;
      } catch (_) {
        // Fall through to the system browser.
      }
    }
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Fall through to a copy so the user still has the link.
    }
    if (!context.mounted) return;
    await copyText(context, url, 'Explorer link');
  }

  Future<void> _shareText(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share this receipt?'),
        content: const Text(
          'The text contains your address, the recipient, the amount, and the '
          'transaction hash. These are public on-chain, but sharing them links '
          'them to you. It never contains your seed or private key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Copy text'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    await copyText(context, _shareBody(), 'Receipt summary');
  }

  Future<void> _exportJson(BuildContext context) async {
    try {
      final clean = receipt.hash.replaceAll(RegExp('[^A-Za-z0-9]'), '');
      final suffix = clean.isEmpty
          ? 'unknown'
          : clean.substring(0, clean.length < 12 ? clean.length : 12);
      final path = await exportToFile(
        'x-wallet-receipt-$suffix.json',
        _receiptJson(),
      );
      if (!context.mounted) return;
      if (path == null) {
        showInfo(context, 'Save cancelled.');
        return;
      }
      showInfo(context, 'Receipt saved to $path');
    } catch (error) {
      if (!context.mounted) return;
      showError(context, error);
    }
  }

  Future<void> _exportPng(BuildContext context) async {
    try {
      final clean = receipt.hash.replaceAll(RegExp('[^A-Za-z0-9]'), '');
      final suffix = clean.isEmpty
          ? 'unknown'
          : clean.substring(0, clean.length < 12 ? clean.length : 12);
      final bytes = await renderReceiptPng(receipt);
      final path = await exportBytesToFile(
        'x-wallet-receipt-$suffix.png',
        bytes,
      );
      if (!context.mounted) return;
      if (path == null) {
        showInfo(context, 'Save cancelled.');
        return;
      }
      showInfo(context, 'Receipt image saved to $path');
    } catch (error) {
      if (!context.mounted) return;
      showError(context, error);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      '$label: $value',
      style: const TextStyle(fontSize: 13, height: 1.3),
    ),
  );
}

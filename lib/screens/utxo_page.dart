import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../utxo/utxo_network.dart';
import '../utxo/utxo_service.dart';
import '../utxo/utxo_transaction.dart';
import '../utxo/utxo_wallet.dart';
import '../wallet_core.dart';
import '../widgets/network_badge.dart';
import 'common.dart';

/// Bitcoin / Litecoin / Dogecoin screen. EVM chains stay on the existing
/// Wallet/Send screens; this page never pretends the protocols are the same.
class UtxoPage extends StatefulWidget {
  const UtxoPage({super.key});

  @override
  State<UtxoPage> createState() => _UtxoPageState();
}

class _UtxoPageState extends State<UtxoPage> {
  UtxoNetworkSpec _network = UtxoNetworks.btcMainnet;
  UtxoAddressKind _kind = UtxoAddressKind.p2wpkh;
  UtxoAccount? _account;
  UtxoAccount? _change;
  List<Utxo> _utxos = const [];
  bool _loading = false;
  String? _error;
  String? _lastTxid;
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _feeRate = TextEditingController(text: '2');

  UtxoService get _service =>
      UtxoService(killSwitch: () => appState.networkKillSwitch);

  @override
  void initState() {
    super.initState();
    _derive();
  }

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    _feeRate.dispose();
    super.dispose();
  }

  void _derive() {
    final phrase = appState.mnemonic;
    if (phrase == null || phrase.isEmpty) {
      setState(() => _error = 'Unlock a wallet with a recovery phrase first.');
      return;
    }
    try {
      final account = UtxoWallet.derive(
        phrase: phrase,
        network: _network,
        kind: _kind,
      );
      final change = UtxoWallet.derive(
        phrase: phrase,
        network: _network,
        kind: _kind,
        change: true,
      );
      setState(() {
        _account = account;
        _change = change;
        _utxos = const [];
        _error = null;
        _lastTxid = null;
      });
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _refresh() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final utxos = await _service.fetchUtxos(_network, account.address);
      if (!mounted) return;
      setState(() => _utxos = utxos);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _balanceSatoshi => _utxos
      .where((utxo) => utxo.confirmed)
      .fold(0, (sum, utxo) => sum + utxo.valueSatoshi);

  Future<void> _reviewAndSend() async {
    final account = _account;
    final change = _change;
    if (account == null || change == null) {
      setState(() => _error = 'Derive an account first.');
      return;
    }
    if (_utxos.isEmpty) {
      setState(() => _error = 'Refresh the UTXO list first.');
      return;
    }
    BigInt amount;
    int feeRate;
    try {
      amount = BtcUtils.toSatoshi(_amount.text.trim());
      feeRate = int.parse(_feeRate.text.trim());
    } catch (_) {
      setState(() => _error = 'Enter a valid amount and fee rate.');
      return;
    }
    if (amount > BigInt.from(0x7fffffffffffffff)) {
      setState(() => _error = 'Amount is too large.');
      return;
    }
    try {
      final plan = UtxoTransactionEngine.planAndSign(
        account: account,
        changeAccount: change,
        recipient: _to.text.trim(),
        amountSatoshi: amount.toInt(),
        feeRateSatPerVbyte: feeRate,
        available: _utxos,
      );
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review UTXO transaction'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  NetworkBadge(network: _network.key),
                  const SizedBox(height: 8),
                  Text('Network: ${_network.name} (${_network.chain.name})'),
                  Text('From: ${account.address}'),
                  Text('To: ${plan.recipient}'),
                  Text(
                    'Amount: ${WalletCore.formatUnits(BigInt.from(plan.amountSatoshi), 8)} ${_network.nativeSymbol}',
                  ),
                  Text(
                    'Network fee: ${WalletCore.formatUnits(BigInt.from(plan.feeSatoshi), 8)} ${_network.nativeSymbol}',
                  ),
                  Text(
                    'Change: ${WalletCore.formatUnits(BigInt.from(plan.changeSatoshi), 8)} ${_network.nativeSymbol}',
                  ),
                  Text(
                    'Total debit: ${WalletCore.formatUnits(BigInt.from(plan.totalDebitSatoshi), 8)} ${_network.nativeSymbol}',
                  ),
                  Text('Estimated size: ${plan.vsize} vB'),
                  Text('Address type: ${account.addressType}'),
                  const SizedBox(height: 10),
                  const Text(
                    'The wallet signs exactly these decoded fields. Verify the '
                    'recipient and amount before approving.',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign and broadcast'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      setState(() => _loading = true);
      final txid = await _service.broadcast(_network, plan.rawHex);
      if (!mounted) return;
      setState(() {
        _lastTxid = txid;
        _loading = false;
      });
      showInfo(context, 'Broadcast accepted by the node. TxID: $txid');
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      appBar: AppBar(title: const Text('Bitcoin, Litecoin & Dogecoin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('UTXO chain'),
                  const SizedBox(height: 8),
                  const Text(
                    'Bitcoin, Litecoin and Dogecoin use UTXOs, not accounts. '
                    'Keys are derived locally with the correct coin type and '
                    'network prefixes. MAINNET means real funds.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _network.key,
                    decoration: const InputDecoration(
                      labelText: 'Network',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final network in UtxoNetworks.all)
                        DropdownMenuItem(
                          value: network.key,
                          child: Text(
                            '${network.name} · ${network.isTestnet ? 'TESTNET' : 'MAINNET'}',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      final network = UtxoNetworks.byKey(value);
                      setState(() {
                        _network = network;
                        _kind = network.addressKinds.first;
                        _account = null;
                        _change = null;
                        _utxos = const [];
                        _lastTxid = null;
                      });
                      _derive();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UtxoAddressKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Address type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final kind in _network.addressKinds)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(switch (kind) {
                            UtxoAddressKind.p2pkh => 'Legacy P2PKH',
                            UtxoAddressKind.p2shP2wpkh =>
                              'Nested SegWit P2SH-P2WPKH',
                            UtxoAddressKind.p2wpkh => 'Native SegWit P2WPKH',
                            UtxoAddressKind.p2tr => 'Taproot P2TR',
                          }),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _kind = value;
                        _account = null;
                        _change = null;
                        _utxos = const [];
                      });
                      _derive();
                    },
                  ),
                  if (_network.isTestnet)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'TESTNET — these coins have no ordinary monetary value.',
                        style: TextStyle(
                          color: Color(0xFFF9A825),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              InfoCard(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFEF5350)),
                ),
              ),
            if (_error != null) const SizedBox(height: 14),
            if (account != null)
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Receive'),
                    const SizedBox(height: 6),
                    SelectableText(
                      account.address,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${account.addressType} · ${account.path}',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              copyText(context, account.address, 'Address'),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showQrDialog(context, account.address),
                          icon: const Icon(Icons.qr_code, size: 16),
                          label: const Text('QR'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _refresh,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh UTXOs'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loading
                          ? 'Checking the chain…'
                          : 'Confirmed balance: '
                                '${WalletCore.formatUnits(BigInt.from(_balanceSatoshi), 8)} '
                                '${_network.nativeSymbol}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_utxos.length} UTXO(s) · kill switch '
                      '${appState.networkKillSwitch ? 'ON' : 'off'}',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12,
                      ),
                    ),
                    if (_lastTxid != null) ...[
                      const SizedBox(height: 8),
                      Text('Last TxID: $_lastTxid'),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(_network.explorerTx(_lastTxid!)),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Open in explorer'),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Send'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _to,
                    decoration: const InputDecoration(
                      labelText: 'Recipient address',
                      border: OutlineInputBorder(),
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (${_network.nativeSymbol})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feeRate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fee rate (sat/vB)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _loading ? null : _reviewAndSend,
                    icon: const Icon(Icons.send),
                    label: const Text('Review and send'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only confirmed UTXOs are spent. Change is paid to the '
                    'next internal address. Dust change is added to the fee. '
                    'A broadcast response is not final confirmation.',
                    style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

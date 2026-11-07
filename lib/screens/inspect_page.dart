import 'package:flutter/material.dart';

import '../app_state.dart';
import '../wallet_core.dart';
import 'common.dart';

class InspectPage extends StatefulWidget {
  const InspectPage({super.key});

  @override
  State<InspectPage> createState() => _InspectPageState();
}

class _InspectPageState extends State<InspectPage>
    with AutomaticKeepAliveClientMixin {
  final _address = TextEditingController();
  String? _error;
  Map<String, BigInt>? _balances;
  int? _nonce;
  int? _block;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final raw = _address.text.trim();
    if (!WalletCore.isValidAddress(raw)) {
      setState(() => _error = 'Enter a valid 0x address.');
      return;
    }
    if (WalletCore.isZeroAddress(raw)) {
      setState(() => _error = 'The zero address cannot be inspected.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
      _balances = null;
      _nonce = null;
      _block = null;
    });
    try {
      final balances = await loadBalances(raw);
      final rpc = appState.rpc;
      await rpc.ensureConnected();
      final nonce = await rpc.getNonce(raw);
      final block = await rpc.getBlockNumber();
      if (!mounted) return;
      setState(() {
        _balances = balances;
        _nonce = nonce;
        _block = block;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final address = appState.address;
    return Scaffold(
      appBar: AppBar(title: const Text('Inspect any address')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            TextField(
              controller: _address,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: '0x…',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _inspect(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _inspect,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Fetching…' : 'Fetch public balances'),
            ),
            const SizedBox(height: 18),
            SectionTitle('Results'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent))
            else if (_balances != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shortAddress(_address.text.trim()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () =>
                            copyText(context, _address.text.trim(), 'Address'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code, size: 18),
                        onPressed: () =>
                            showQrDialog(context, _address.text.trim()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _row('BNB', _balances!['BNB'] ?? BigInt.zero, 18),
                  for (final token in appState.rpc.tokens.where(
                    (t) => !t.native,
                  ))
                    _row(
                      token.symbol,
                      _balances![token.symbol] ?? BigInt.zero,
                      token.decimals,
                    ),
                  const Divider(height: 28),
                  if (_nonce != null && _block != null)
                    Text(
                      'nonce ${_nonce!} · block ${_block!}',
                      style: const TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (address != null &&
                      shortAddress(_address.text.trim()) ==
                          shortAddress(address))
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => showQrDialog(context, address),
                          icon: const Icon(Icons.qr_code),
                          label: const Text('My receive QR'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              copyText(context, address, 'Address'),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy my address'),
                        ),
                      ],
                    ),
                ],
              )
            else
              const Text(
                'Enter an address to see public balances.',
                style: TextStyle(color: Color(0xFF6E6E6E)),
              ),
            const SizedBox(height: 18),
            SectionTitle('Safety'),
            const Text(
              'This only reads public blockchain data. No secrets are accessed.',
              style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String symbol, BigInt value, int decimals) {
    final unavailable = value == BigInt.from(-1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              unavailable
                  ? 'unavailable'
                  : WalletCore.formatUnits(value, decimals),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

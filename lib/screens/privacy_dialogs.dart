import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../net/privacy_client.dart';
import '../rpc_service.dart';
import '../storage.dart';
import '../tor_manager.dart';

/// Opens the global custom-proxy editor. Returns true when a route was saved.
Future<bool> showProxySettingsDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ProxySettingsDialog(),
  );
  return result == true;
}

/// Opens the managed-Tor / external-Tor editor. Returns true when the dialog
/// changed the active privacy route or its configuration.
Future<bool> showTorSettingsDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _TorSettingsDialog(),
  );
  return result == true;
}

class _ProxySettingsDialog extends StatefulWidget {
  const _ProxySettingsDialog();

  @override
  State<_ProxySettingsDialog> createState() => _ProxySettingsDialogState();
}

class _ProxySettingsDialogState extends State<_ProxySettingsDialog> {
  late final TextEditingController _url;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late ProxyType _type;
  late bool _obscurePassword;
  bool _busy = false;
  String? _error;
  String? _status;

  bool get _wasActive => appState.proxyEnabled;

  @override
  void initState() {
    super.initState();
    final current = appState.globalProxy;
    _type = current.type == ProxyType.none ? ProxyType.socks5 : current.type;
    _url = TextEditingController();
    _host = TextEditingController(text: current.host);
    _port = TextEditingController(text: '${current.port}');
    _user = TextEditingController(text: current.username ?? '');
    _password = TextEditingController(text: current.password ?? '');
    _obscurePassword = true;
  }

  @override
  void dispose() {
    _url.dispose();
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  int get _defaultPort => _type == ProxyType.httpConnect ? 8080 : 1080;

  void _changeType(ProxyType? value) {
    if (value == null) return;
    setState(() {
      final oldDefault = _type == ProxyType.httpConnect ? 8080 : 1080;
      _type = value;
      if (_port.text.trim().isEmpty || _port.text.trim() == '$oldDefault') {
        _port.text = '$_defaultPort';
      }
      _error = null;
      _status = null;
    });
  }

  GlobalProxyConfig? _draft() {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty) {
      setState(() => _error = 'Proxy host is required (domain or IP).');
      return null;
    }
    if (host.contains(RegExp(r'[\s/\\]'))) {
      setState(() => _error = 'Proxy host cannot contain spaces or slashes.');
      return null;
    }
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _error = 'Proxy port must be 1–65535.');
      return null;
    }
    return GlobalProxyConfig(
      type: _type,
      host: host,
      port: port,
      username: _user.text.trim().isEmpty ? null : _user.text.trim(),
      password: _password.text.isEmpty ? null : _password.text,
    );
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = 'The clipboard is empty.');
      return;
    }
    _url.text = text;
    _parseUrl();
  }

  void _parseUrl() {
    final parsed = GlobalProxyConfig.fromUrl(_url.text);
    if (parsed == null) {
      setState(
        () => _error =
            'Unsupported proxy URL. Use socks5://, socks5h://, http:// or '
            'https:// with an optional user:password@ part.',
      );
      return;
    }
    setState(() {
      _type = parsed.type;
      _host.text = parsed.host;
      _port.text = '${parsed.port}';
      _user.text = parsed.username ?? '';
      _password.text = parsed.password ?? '';
      _error = null;
      _status = null;
    });
  }

  Future<void> _test() async {
    final config = _draft();
    if (config == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Testing the route…';
    });
    try {
      final message = await probeProxyRoute(
        config,
        BnbNetworks.mainnetFallbacks.first,
      );
      if (!mounted) return;
      setState(() => _status = message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Test failed: $error';
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final config = _draft();
    if (config == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Saving and connecting…';
    });
    try {
      await appState.setGlobalProxy(config);
      await appState.rpc.connect();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Saved, but the RPC connection failed: $error\n'
            'The proxy is active and there is no direct fallback; fix the '
            'proxy or switch to Direct.';
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    await appState.disableProxy();
    try {
      await appState.rpc.connect();
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Custom proxy'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Every RPC and explorer request uses this one route. There is '
                'no direct fallback: if the proxy is down, requests fail '
                'instead of leaking your IP address.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Common proxy setups',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'SSH SOCKS5: ssh -D 1080 -N user@your-vps\n'
                'VLESS/Xray: run a local SOCKS inbound on 127.0.0.1:10808, '
                'then use socks5h://127.0.0.1:10808.\n'
                'HTTP CONNECT: point this dialog at the proxy host and port.\n'
                'Proxy mode is fail-closed: if the route is down, requests '
                'fail instead of falling back to your real IP.',
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'ssh -D 1080 -N user@your-vps',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SSH SOCKS5 command copied.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy SSH SOCKS5'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'xray run -c /path/to/config.json',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('VLESS/Xray command copied.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy VLESS example'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Paste proxy URL',
                        hintText: 'socks5h://user:pass@proxy.example:1080',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _parseUrl(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Paste from clipboard',
                    onPressed: _busy ? null : _pasteUrl,
                    icon: const Icon(Icons.content_paste),
                  ),
                  IconButton(
                    tooltip: 'Use this URL',
                    onPressed: _busy ? null : _parseUrl,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProxyType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Proxy type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ProxyType.socks5,
                    child: Text('SOCKS5 — local DNS'),
                  ),
                  DropdownMenuItem(
                    value: ProxyType.socks5h,
                    child: Text('SOCKS5h — remote DNS (Tor-style)'),
                  ),
                  DropdownMenuItem(
                    value: ProxyType.httpConnect,
                    child: Text('HTTP CONNECT'),
                  ),
                ],
                onChanged: _busy ? null : _changeType,
              ),
              const SizedBox(height: 6),
              Text(
                _type == ProxyType.httpConnect
                    ? 'HTTPS destinations are tunnelled with CONNECT. An '
                          'https:// URL selects this mode; TLS to the proxy '
                          'itself is not supported yet.'
                    : _type == ProxyType.socks5h
                    ? 'The destination hostname is sent to the proxy, '
                          'so DNS happens inside the tunnel.'
                    : 'The destination hostname is resolved on this '
                          'device before the SOCKS connection.',
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Proxy host',
                        hintText: 'proxy.example or 127.0.0.1',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {
                        _error = null;
                        _status = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        hintText: '$_defaultPort',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {
                        _error = null;
                        _status = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _user,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Username (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Password (optional)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Credentials are kept in the OS secure store, never in the '
                'plain preferences file.',
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: color.error, fontSize: 12),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_wasActive)
          TextButton(
            onPressed: _busy ? null : _disable,
            child: const Text('Disable proxy'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _test,
          child: const Text('Test'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save & use'),
        ),
      ],
    );
  }
}

class _TorSettingsDialog extends StatefulWidget {
  const _TorSettingsDialog();

  @override
  State<_TorSettingsDialog> createState() => _TorSettingsDialogState();
}

class _TorSettingsDialogState extends State<_TorSettingsDialog> {
  late final TextEditingController _host;
  late final TextEditingController _managedPort;
  late final TextEditingController _externalPort;
  late final TextEditingController _bridges;
  late final TextEditingController _upstreamHost;
  late final TextEditingController _upstreamPort;
  late final TextEditingController _upstreamUser;
  late final TextEditingController _upstreamPass;
  late ProxyType _upstreamType;
  late int _chainDepth;
  late TorBridgeType _bridgeType;
  TorProbe? _probe;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _status;

  TorManager get _tor => TorManager.instance;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: appState.torHost);
    _managedPort = TextEditingController(text: '${appState.torPort}');
    _externalPort = TextEditingController(text: '${appState.torPort}');
    _bridges = TextEditingController(
      text: AppStorage.torBridgeLines.join('\n'),
    );
    final upstream = appState.torUpstream;
    _upstreamType = upstream.type;
    _upstreamHost = TextEditingController(text: upstream.host);
    _upstreamPort = TextEditingController(text: '${upstream.port}');
    _upstreamUser = TextEditingController(text: upstream.username ?? '');
    _upstreamPass = TextEditingController(text: upstream.password ?? '');
    _chainDepth = appState.torChainDepth;
    _bridgeType = AppStorage.torBridgeType;
    _tor.addListener(_torChanged);
    _refreshProbe();
  }

  @override
  void dispose() {
    _tor.removeListener(_torChanged);
    _host.dispose();
    _managedPort.dispose();
    _externalPort.dispose();
    _bridges.dispose();
    _upstreamHost.dispose();
    _upstreamPort.dispose();
    _upstreamUser.dispose();
    _upstreamPass.dispose();
    super.dispose();
  }

  void _torChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshProbe() async {
    try {
      final probe = await _tor.probe(refresh: true);
      if (mounted) setState(() => _probe = probe);
    } catch (_) {}
  }

  int? _parsePort(TextEditingController controller) {
    final port = int.tryParse(controller.text.trim());
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _error = 'SOCKS port must be 1–65535.');
      return null;
    }
    return port;
  }

  Future<void> _pasteBridges() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = 'The clipboard is empty.');
      return;
    }
    setState(() {
      _bridges.text = text;
      _error = null;
      _status = null;
    });
  }

  Future<void> _saveBridgeConfig() async {
    try {
      final lines = _bridges.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      TorManager.normalizeBridgeLines(_bridgeType, lines);
      await AppStorage.setTorBridge(_bridgeType, lines);
      _changed = true;
      if (mounted) setState(() => _status = 'Bridge configuration saved.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _saveUpstream() async {
    final port = int.tryParse(_upstreamPort.text.trim());
    if (_upstreamType != ProxyType.none &&
        (_upstreamHost.text.trim().isEmpty ||
            port == null ||
            port <= 0 ||
            port > 65535)) {
      setState(() => _error = 'Enter a valid upstream proxy host and port.');
      return;
    }
    try {
      final upstream = _upstreamType == ProxyType.none
          ? const GlobalProxyConfig.disabled()
          : GlobalProxyConfig(
              type: _upstreamType,
              host: _upstreamHost.text.trim(),
              port: port!,
              username: _upstreamUser.text.trim().isEmpty
                  ? null
                  : _upstreamUser.text.trim(),
              password: _upstreamPass.text.isEmpty ? null : _upstreamPass.text,
            );
      await appState.setTorUpstream(upstream);
      await appState.setTorChainDepth(_chainDepth);
      _changed = true;
      if (!mounted) return;
      setState(() {
        _error = null;
        _status = _upstreamType == ProxyType.none
            ? 'Tor upstream disabled and chain depth set to $_chainDepth.'
            : 'Tor upstream saved: ${upstream.description}; chain depth '
                  '$_chainDepth. Start managed Tor to apply it.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _startManaged() async {
    final port = _parsePort(_managedPort);
    if (port == null) return;
    final lines = _bridges.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Starting managed Tor. Bridges can take up to 90 seconds…';
    });
    try {
      await AppStorage.setTorBridge(_bridgeType, lines);
      await _tor.start(
        port: port,
        bridgeType: _bridgeType,
        bridgeLines: lines,
        upstream: appState.torUpstream,
        chainDepth: appState.torChainDepth,
      );
      await appState.setTorHostPort('127.0.0.1', port);
      await appState.setTorEnabled(true);
      await appState.rpc.connect();
      _changed = true;
      if (!mounted) return;
      setState(() {
        _status = 'Managed Tor bootstrapped and the wallet is using it.';
        _busy = false;
      });
    } catch (error) {
      // A failed connection must not leave the wallet pointing at a dead
      // port: stop the daemon and turn the route off.
      await _tor.stop();
      await appState.setTorEnabled(false);
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _stopManaged() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final port = int.tryParse(_managedPort.text.trim());
    await _tor.stop();
    if (appState.torEnabled &&
        appState.torHost == '127.0.0.1' &&
        appState.torPort == port) {
      await appState.setTorEnabled(false);
    }
    _changed = true;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Managed Tor stopped. The Tor route is off.';
    });
  }

  Future<void> _testExternal() async {
    final port = _parsePort(_externalPort);
    if (port == null) return;
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'SOCKS host is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Testing the SOCKS5 route…';
    });
    try {
      final message = await probeProxyRoute(
        GlobalProxyConfig(type: ProxyType.socks5h, host: host, port: port),
        BnbNetworks.mainnetFallbacks.first,
      );
      if (!mounted) return;
      setState(() {
        _status = message;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Test failed: $error';
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _useExternal() async {
    final port = _parsePort(_externalPort);
    if (port == null) return;
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'SOCKS host is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Connecting through $host:$port…';
    });
    try {
      await appState.setTorHostPort(host, port);
      await appState.setTorEnabled(true);
      await appState.rpc.connect();
      _changed = true;
      if (!mounted) return;
      setState(() {
        _status = 'Wallet connected through external Tor at $host:$port.';
        _busy = false;
      });
    } catch (error) {
      await appState.setTorEnabled(false);
      if (!mounted) return;
      setState(() {
        _error =
            'Could not connect through $host:$port: $error\n'
            'The Tor route is off, so the wallet is using direct HTTPS.';
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _disableRoute() async {
    setState(() => _busy = true);
    await appState.setTorEnabled(false);
    try {
      await appState.rpc.connect();
    } catch (_) {}
    _changed = true;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Tor route disabled; direct HTTPS is active.';
    });
  }

  String _bridgeHint() {
    switch (_bridgeType) {
      case TorBridgeType.obfs4:
        return 'One line per bridge, for example:\n'
            'obfs4 192.0.2.10:443 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
            'cert=… iat-mode=0';
      case TorBridgeType.snowflake:
        return 'One line per bridge, for example:\n'
            'snowflake 192.0.2.10:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
            'fingerprint=… url=https://… ice=stun:…';
      case TorBridgeType.webtunnel:
        return 'One line per bridge, for example:\n'
            'webtunnel 192.0.2.10:443 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
            'url=https://…';
      case TorBridgeType.meek:
        return 'One line per bridge, for example:\n'
            'meek 0.0.0.0:1 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
            'url=https://… front=…';
      case TorBridgeType.custom:
        return 'Custom torrc lines. Use Bridge … and, when needed,\n'
            'ClientTransportPlugin transport exec /path/to/client\n'
            'Bridge transport host:port …';
      case TorBridgeType.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final probe = _probe;
    return AlertDialog(
      title: const Text('Tor and bridges'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Managed Tor is started and stopped by this app on Linux. It '
                'only ever signals the process it spawned. On Android use '
                'Orbot and the external SOCKS settings below.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                probe == null
                    ? 'Looking for Tor and bridge clients…'
                    : probe.torPath == null
                    ? 'tor is not installed. Ubuntu/Debian: '
                          'sudo apt install tor obfs4proxy snowflake-client'
                    : '${probe.torVersion ?? 'tor'} · ${probe.torPath}',
                style: TextStyle(
                  fontSize: 12,
                  color: probe?.torPath == null
                      ? color.error
                      : color.onSurfaceVariant,
                ),
              ),
              if (probe != null && probe.torPath != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final entry in probe.availability.entries)
                      if (entry.key != TorBridgeType.none &&
                          entry.key != TorBridgeType.custom)
                        Chip(
                          avatar: Icon(
                            probe.binaryFor(entry.key) == null
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 16,
                            color: probe.binaryFor(entry.key) == null
                                ? color.error
                                : Colors.green,
                          ),
                          label: Text(
                            '${entry.key.label}: ${entry.value}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'WebTunnel and meek need their client binaries; Ubuntu does '
                  'not package them. Custom mode can point at any installed '
                  'transport client.',
                  style: TextStyle(fontSize: 11, color: color.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'VPN / VLESS / proxy before Tor',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'A system VPN (WireGuard or OpenVPN) is used automatically '
                'when it is connected before Tor. For a local VLESS/Xray '
                'client, run a SOCKS inbound on localhost and enter it here. '
                'Traffic then goes: this app → local VLESS client → your VPS '
                '→ Tor. Chain depth 2 or 3 starts additional Tor instances in '
                'front of the final hop; more hops are slower and '
                'experimental.',
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ProxyType>(
                initialValue: _upstreamType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Upstream before Tor',
                  border: OutlineInputBorder(),
                ),
                items: ProxyType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _upstreamType = value;
                          _error = null;
                          _status = null;
                        });
                      },
              ),
              if (_upstreamType != ProxyType.none) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _upstreamHost,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Upstream host',
                          hintText: '127.0.0.1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _upstreamPort,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '10808',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _upstreamUser,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Username (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _upstreamPass,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Password (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _chainDepth,
                decoration: const InputDecoration(
                  labelText: 'Tor chain depth',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 — Tor (normal)')),
                  DropdownMenuItem(value: 2, child: Text('2 — Tor over Tor')),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('3 — Tor over Tor over Tor'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _chainDepth = value);
                      },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : _saveUpstream,
                    child: const Text('Save upstream and chain'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'xray run -c /path/to/config.json',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('VLESS/Xray command copied.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy VLESS example'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'VLESS/Xray example: inbound protocol "socks", listen '
                '"127.0.0.1", port 10808. Start it before managed Tor.',
                style: TextStyle(fontSize: 11, color: color.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Managed Tor',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _managedPort,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SOCKS port',
                        hintText: '9050',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _tor.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: _tor.ready
                            ? Colors.green
                            : color.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TorBridgeType>(
                initialValue: _bridgeType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bridge type',
                  border: OutlineInputBorder(),
                ),
                items: TorBridgeType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _bridgeType = value;
                          _error = null;
                          _status = null;
                        });
                      },
              ),
              if (_bridgeType != TorBridgeType.none) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _bridges,
                  minLines: 3,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Bridge lines',
                    hintText: _bridgeHint(),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pasteBridges,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste lines'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _saveBridgeConfig,
                      child: const Text('Save bridge lines'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || !_tor.supported ? null : _startManaged,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start managed Tor'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || !_tor.running ? null : _stopManaged,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop managed Tor'),
                  ),
                ],
              ),
              if (_tor.logTail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _tor.logTail.reversed
                          .take(24)
                          .toList()
                          .reversed
                          .join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _tor.logTail.join('\n')),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tor log copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy log'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Existing Tor or Orbot',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Point the wallet at a SOCKS port that another Tor instance '
                'already listens on. The wallet does not start or stop it.',
                style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'SOCKS host',
                        hintText: '127.0.0.1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _externalPort,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '9050',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _testExternal,
                    icon: const Icon(Icons.network_check),
                    label: const Text('Test external Tor'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _useExternal,
                    icon: const Icon(Icons.vpn_lock),
                    label: const Text('Use external Tor'),
                  ),
                  if (appState.torEnabled)
                    TextButton(
                      onPressed: _busy ? null : _disableRoute,
                      child: const Text('Disable Tor route'),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: color.error, fontSize: 12),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  _changed = true;
                  Navigator.pop(context, _changed);
                },
          child: const Text('Close'),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:socks5_proxy/socks_client.dart' as socks;

import '../models.dart';
import '../storage.dart';

/// Chooses the HTTP transport for RPC and BscScan traffic.
///
/// Default: the plain [http.Client] with system CA roots, HTTPS-only URLs
/// enforced by its callers.
///
/// Tor mode ([AppStorage.torEnabled]): every request goes through a local
/// SOCKS5 connector, normally the Tor daemon/Orbot listening on 127.0.0.1:9050.
/// This wiring uses the audited socks5_proxy package, which assigns a
/// connection factory to dart:io's HttpClient — so TLS, redirects, chunked
/// encoding and keep-alive are all handled by the standard client. The
/// CONNECT request carries the hostname, so DNS stays inside the tunnel.
///
/// Fail closed: if the SOCKS port is dead, the standard client surfaces the
/// connection error — calls NEVER fall back to a direct connection.
http.Client createRpcClient() {
  // Fingerprint reduction (round 6): dart:io otherwise announces
  // "Dart/<version> (dart:io)" on every request — a software/runtime
  // fingerprint that DPI and RPC operators can read and correlate. A null
  // user agent sends no User-Agent header at all, revealing nothing about
  // the device, OS or runtime.
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 30);
  _applyGlobalRoute(inner);
  return http_io.IOClient(inner);
}

/// Applies the configured global privacy route to [inner]: custom proxy first,
/// then Tor, then direct. A configured proxy that cannot be applied throws —
/// it never silently falls back to a direct connection.
void _applyGlobalRoute(
  HttpClient inner, {
  List<String> pinnedSpkiHashes = const [],
}) {
  GlobalProxyConfig proxy;
  bool torOn;
  try {
    proxy = AppStorage.globalProxy;
    torOn = AppStorage.torEnabled;
  } on StateError {
    // Storage not initialized yet: tests and very early bootstrap only.
    if (pinnedSpkiHashes.isNotEmpty) {
      _installPinnedTlsFactory(inner, pinnedSpkiHashes);
    }
    return;
  }
  if (proxy.type != ProxyType.none) {
    // A selected proxy type with no usable host must not silently become a
    // direct connection: that would leak the real IP exactly when the user
    // asked for privacy.
    if (!proxy.enabled) {
      throw StateError(
        'A proxy type is selected but its host/port is incomplete. '
        'Open Settings and fix it, or choose Direct.',
      );
    }
    _applyGlobalProxy(inner, proxy, pinnedSpkiHashes: pinnedSpkiHashes);
    return;
  }
  if (torOn) {
    _applySocks5(
      inner,
      host: AppStorage.torHost,
      port: AppStorage.torPort,
      remoteDns: true,
      pinnedSpkiHashes: pinnedSpkiHashes,
    );
    return;
  }
  if (pinnedSpkiHashes.isNotEmpty) {
    _installPinnedTlsFactory(inner, pinnedSpkiHashes);
  }
}

void _applyGlobalProxy(
  HttpClient inner,
  GlobalProxyConfig proxy, {
  List<String> pinnedSpkiHashes = const [],
}) {
  switch (proxy.type) {
    case ProxyType.none:
      if (pinnedSpkiHashes.isNotEmpty) {
        _installPinnedTlsFactory(inner, pinnedSpkiHashes);
      }
      return;
    case ProxyType.socks5:
      _applySocks5(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
        remoteDns: false,
        pinnedSpkiHashes: pinnedSpkiHashes,
      );
    case ProxyType.socks5h:
      _applySocks5(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
        remoteDns: true,
        pinnedSpkiHashes: pinnedSpkiHashes,
      );
    case ProxyType.httpConnect:
      if (pinnedSpkiHashes.isNotEmpty) {
        throw StateError(
          'SPKI pinning cannot be combined with HTTP CONNECT in this build. '
          'Use direct HTTPS, SOCKS5/SOCKS5h or Tor for a pinned node.',
        );
      }
      _applyHttpConnect(
        inner,
        host: proxy.host,
        port: proxy.port,
        username: proxy.username,
        password: proxy.password,
      );
  }
}

void _applySocks5(
  HttpClient inner, {
  required String host,
  required int port,
  String? username,
  String? password,
  required bool remoteDns,
  List<String> pinnedSpkiHashes = const [],
}) {
  if (host.trim().isEmpty || port <= 0 || port > 65535) {
    throw StateError('SOCKS5 proxy host/port is incomplete.');
  }
  final proxyHost = host.trim();
  final user = (username?.isEmpty ?? true) ? null : username;
  final pass = (password?.isEmpty ?? true) ? null : password;

  // A custom connection factory is used instead of assignToHttpClient for two
  // reasons: the proxy host may be a domain name (resolved locally only), and
  // SOCKS5 vs SOCKS5h must actually differ. SOCKS5 resolves the RPC hostname
  // on this device; SOCKS5h sends the hostname to the proxy so DNS happens
  // inside the tunnel.
  inner.connectionFactory = (uri, ignoredProxyHost, ignoredProxyPort) async {
    final proxyAddresses = await InternetAddress.lookup(proxyHost);
    if (proxyAddresses.isEmpty) {
      throw SocketException('Proxy host did not resolve: $proxyHost');
    }
    final settings = socks.ProxySettings(
      proxyAddresses.first,
      port,
      username: user,
      password: pass,
    );
    final target = remoteDns
        ? InternetAddress(uri.host, type: InternetAddressType.unix)
        : await _resolveTarget(uri.host);
    final client = await socks.SocksTCPClient.connect(
      [settings],
      target,
      uri.port,
    );
    if (uri.scheme == 'https') {
      // TLS is negotiated end-to-end after the SOCKS tunnel exists, with the
      // destination hostname used for SNI and STANDARD certificate validation.
      // The pin is checked only after that validation succeeds, so a pin can
      // narrow trust but can never replace the public CA chain.
      final secure = await client.secure(uri.host);
      if (!_checkPinnedPeer(secure, pinnedSpkiHashes)) {
        secure.destroy();
        throw const HandshakeException('SPKI pin mismatch');
      }
      return ConnectionTask.fromSocket(
        Future<SecureSocket>.value(secure),
        () => secure.close().ignore(),
      );
    }
    return ConnectionTask.fromSocket(
      Future<Socket>.value(client),
      () => client.close().ignore(),
    );
  };
}

Future<InternetAddress> _resolveTarget(String hostname) async {
  final addresses = await InternetAddress.lookup(hostname);
  if (addresses.isEmpty) {
    throw SocketException('Destination host did not resolve: $hostname');
  }
  return addresses.first;
}

void _applyHttpConnect(
  HttpClient inner, {
  required String host,
  required int port,
  String? username,
  String? password,
}) {
  if (host.trim().isEmpty || port <= 0 || port > 65535) {
    throw StateError('HTTP CONNECT proxy host/port is incomplete.');
  }
  inner.findProxy = (uri) => 'PROXY ${host.trim()}:$port';
  if (username != null && username.isNotEmpty) {
    inner.authenticateProxy =
        (String proxyHost, int proxyPort, String scheme, String? realm) async {
          final uri = Uri.parse('http://$proxyHost:$proxyPort');
          inner.addCredentials(
            uri,
            realm ?? '',
            HttpClientBasicCredentials(username, password ?? ''),
          );
          return true;
        };
  }
}

/// Creates an HTTP client for a specific node with its transport settings.
/// Used by RpcService when querying individual nodes (fee engine, test, etc.).
/// Supports R4: HTTP CONNECT proxy, cert pinning (SPKI), HTTP auth, custom headers.
http.Client createClientForNode(RpcNode node) {
  // Pinning is performed AFTER the standard TLS handshake succeeded. There is
  // deliberately no empty SecurityContext and no permissive
  // badCertificateCallback here: a pin must never become a substitute for
  // hostname + CA-chain validation.
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 30);
  final pins = node.pinnedSpkiHashes;

  switch (node.transport) {
    case NodeTransport.inherit:
      // The global setting is resolved for every node that inherits it, so a
      // newly enabled proxy/Tor route applies to the whole node book.
      _applyGlobalRoute(inner, pinnedSpkiHashes: pins);
      break;
    case NodeTransport.direct:
      if (pins.isNotEmpty) _installPinnedTlsFactory(inner, pins);
      break;
    case NodeTransport.tor:
      _applySocks5(
        inner,
        host: AppStorage.torHost,
        port: AppStorage.torPort,
        remoteDns: true,
        pinnedSpkiHashes: pins,
      );
      break;
    case NodeTransport.customProxy:
      if (node.proxyHost == null ||
          node.proxyHost!.trim().isEmpty ||
          node.proxyPort == null ||
          node.proxyPort! <= 0 ||
          node.proxyPort! > 65535) {
        throw StateError(
          'Node "${node.label}" is set to a custom SOCKS5 proxy but its '
          'host/port is incomplete.',
        );
      }
      _applySocks5(
        inner,
        host: node.proxyHost!,
        port: node.proxyPort!,
        username: node.proxyUser,
        password: node.proxyPass,
        remoteDns: true,
        pinnedSpkiHashes: pins,
      );
      break;
    case NodeTransport.httpConnect:
      if (pins.isNotEmpty) {
        throw StateError(
          'Node "${node.label}" pins a certificate but uses HTTP CONNECT. '
          'That combination is refused; use SOCKS5 or direct HTTPS.',
        );
      }
      if (node.proxyHost == null ||
          node.proxyHost!.trim().isEmpty ||
          node.proxyPort == null ||
          node.proxyPort! <= 0 ||
          node.proxyPort! > 65535) {
        throw StateError(
          'Node "${node.label}" is set to HTTP CONNECT but its proxy '
          'host/port is incomplete.',
        );
      }
      _applyHttpConnect(
        inner,
        host: node.proxyHost!,
        port: node.proxyPort!,
        username: node.proxyUser,
        password: node.proxyPass,
      );
      break;
  }

  return _AuthenticatingHttpClient(inner: http_io.IOClient(inner), node: node);
}

/// Install a connection factory that performs the normal TLS handshake and
/// only then enforces the SPKI pin. Used for direct HTTPS and inherited direct
/// routes. The callback never disables hostname or CA validation.
void _installPinnedTlsFactory(HttpClient inner, List<String> pins) {
  inner.connectionFactory = (uri, ignoredProxyHost, ignoredProxyPort) async {
    if (uri.scheme != 'https') {
      throw const SocketException('Pinned connections must use HTTPS');
    }
    final socket = await openPinnedTlsConnection(uri.host, uri.port, pins);
    return ConnectionTask.fromSocket(
      Future<SecureSocket>.value(socket),
      () => socket.close().ignore(),
    );
  };
}

/// Open a TLS connection with the platform's normal certificate validation,
/// then enforce an SPKI pin on the peer certificate. Exposed for negative
/// tests; production callers use [createClientForNode].
@visibleForTesting
Future<SecureSocket> openPinnedTlsConnection(
  String host,
  int port,
  List<String> pins, {
  SecurityContext? context,
}) async {
  if (pins.isEmpty) {
    throw ArgumentError('A pinned connection needs at least one pin');
  }
  final socket = await SecureSocket.connect(
    host,
    port,
    context: context ?? SecurityContext.defaultContext,
  );
  if (!_checkPinnedPeer(socket, pins)) {
    socket.destroy();
    throw const HandshakeException(
      'The server certificate does not match the configured SPKI pin',
    );
  }
  return socket;
}

/// Check a live socket's peer certificate against [pins]. Empty pin lists are
/// permissive only for code paths that do not pin; a caller that passes a
/// non-empty list must match exactly.
bool _checkPinnedPeer(SecureSocket socket, List<String> pins) {
  if (pins.isEmpty) return true;
  final cert = socket.peerCertificate;
  if (cert == null) return false;
  return verifySpkiPin(cert, pins);
}

/// R4: Verify an SPKI pin against a certificate.
/// [pinnedHashes] are base64-encoded SHA-256 of the SPKI (Subject Public Key Info).
bool verifySpkiPin(X509Certificate cert, List<String> pinnedHashes) {
  if (pinnedHashes.isEmpty) return false;
  try {
    final spkiHash = spkiSha256Base64FromDer(cert.der);
    return pinnedHashes.contains(spkiHash);
  } catch (_) {
    return false;
  }
}

/// Extract SPKI (Subject Public Key Info) from a certificate DER and compute
/// SHA-256 base64. Exposed for tests and pin-generation tools.
String spkiSha256Base64FromDer(Uint8List certDer) {
  final parser = ASN1Parser(certDer);
  final cert = parser.nextObject() as ASN1Sequence;

  // Certificate structure:
  // SEQUENCE {
  //   tbsCertificate TBSCertificate,
  //   signatureAlgorithm AlgorithmIdentifier,
  //   signatureValue BIT STRING
  // }

  final tbsCert = cert.elements[0] as ASN1Sequence;

  // TBSCertificate structure:
  // SEQUENCE {
  //   version [0] EXPLICIT Version,
  //   serialNumber CertificateSerialNumber,
  //   signature AlgorithmIdentifier,
  //   issuer Name,
  //   validity Validity,
  //   subject Name,
  //   subjectPublicKeyInfo SubjectPublicKeyInfo,  // index 6
  //   ...
  // }

  // RFC 5280 TBSCertificate: the explicit [0] version field is OPTIONAL.
  // With it, SPKI is element 6; without it, SPKI is element 5. Do not use a
  // version-present offset of 7: that element is the extensions block, and
  // hashing it would silently pin the wrong bytes.
  final first = tbsCert.elements[0];
  final spkiIndex = first.tag == 0xA0 ? 6 : 5;
  if (tbsCert.elements.length <= spkiIndex) {
    throw const FormatException('Certificate has no subjectPublicKeyInfo');
  }

  final spki = tbsCert.elements[spkiIndex];

  // Get the encoded bytes of the SPKI (includes tag and length)
  final spkiDer = spki.encodedBytes;

  // Compute SHA-256
  final digest = crypto.sha256.convert(spkiDer);
  return base64Encode(digest.bytes);
}

/// R4: Authenticated HTTP client that injects auth headers and custom headers.
class _AuthenticatingHttpClient extends http.BaseClient {
  _AuthenticatingHttpClient({required this.inner, required this.node});

  final http.Client inner;
  final RpcNode node;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // R4: Add authentication headers
    _addAuthHeaders(request);

    // R4: Add custom headers (validated)
    _addCustomHeaders(request);

    return inner.send(request);
  }

  void _addAuthHeaders(http.BaseRequest request) {
    switch (node.authType) {
      case NodeAuthType.bearer:
        if (node.authToken != null && node.authToken!.isNotEmpty) {
          request.headers['authorization'] = 'Bearer ${node.authToken}';
        }
        break;
      case NodeAuthType.basic:
        if (node.authUsername != null &&
            node.authUsername!.isNotEmpty &&
            node.authPassword != null) {
          final credentials = '${node.authUsername}:${node.authPassword}';
          final encoded = base64Encode(utf8.encode(credentials));
          request.headers['authorization'] = 'Basic $encoded';
        }
        break;
      case NodeAuthType.none:
        break;
    }
  }

  void _addCustomHeaders(http.BaseRequest request) {
    // R4: Block headers that could identify the app/device
    const blockedHeaders = {
      'user-agent',
      'x-forwarded-for',
      'x-real-ip',
      'x-client-',
      'x-dev-',
      'x-app-',
      'x-wallet-',
    };

    for (final entry in node.customHeaders.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (blockedHeaders.any((b) => lowerKey.startsWith(b))) {
        // Silently drop identifying headers
        continue;
      }
      request.headers[entry.key] = entry.value;
    }
  }
}

/// Verifies a draft proxy configuration before it is saved. The temporary
/// client is closed even on failure; the saved route is never touched.
/// Returns the public IP that an outside service sees on [config].
///
/// It sends only the GET request — no wallet data. Used by the proxy and Tor
/// test buttons so the user can confirm the exact exit IP.
Future<String> probePublicIp(
  GlobalProxyConfig config, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (AppStorage.walletModeIndex == 1) {
    throw StateError(
      'This device is in cold-signer mode: all network access is disabled.',
    );
  }
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 10);
  _applyGlobalProxy(inner, config);
  final client = http_io.IOClient(inner);
  try {
    final response = await client
        .get(Uri.parse('https://api.ipify.org?format=json'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      return 'unavailable (HTTP ${response.statusCode})';
    }
    final decoded = jsonDecode(response.body);
    final ip = decoded is Map ? '${decoded['ip'] ?? ''}'.trim() : '';
    return ip.isEmpty ? 'unavailable (empty response)' : ip;
  } catch (error) {
    return 'unavailable ($error)';
  } finally {
    client.close();
  }
}

Future<String> probeProxyRoute(
  GlobalProxyConfig config,
  String rpcUrl, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (AppStorage.walletModeIndex == 1) {
    throw StateError(
      'This device is in cold-signer mode: all network access is disabled.',
    );
  }
  if (!config.enabled) {
    throw StateError('Enter a proxy host and port first.');
  }
  final inner = HttpClient()
    ..userAgent = null
    ..idleTimeout = const Duration(seconds: 10);
  _applyGlobalProxy(inner, config);
  final client = http_io.IOClient(inner);
  try {
    final response = await client
        .post(
          Uri.parse(rpcUrl),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'eth_chainId',
            'params': <Object>[],
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Proxy reached the endpoint but it returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! String || !result.startsWith('0x')) {
      throw StateError(
        'The endpoint did not return a chain ID. Check the proxy and node URL.',
      );
    }
    final chainId = int.tryParse(result.substring(2), radix: 16);
    if (chainId == null) {
      throw StateError('The endpoint returned an invalid chain ID.');
    }
    return 'Route works — ${config.type.shortLabel} reached the node; chain ID $chainId.';
  } finally {
    client.close();
  }
}

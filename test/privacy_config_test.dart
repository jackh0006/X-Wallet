import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/tor_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlobalProxyConfig.fromUrl', () {
    test('parses SOCKS5 and SOCKS5h with auth and default ports', () {
      final plain = GlobalProxyConfig.fromUrl('socks5://proxy.example');
      expect(plain, isNotNull);
      expect(plain!.type, ProxyType.socks5);
      expect(plain.host, 'proxy.example');
      expect(plain.port, 1080);

      final remote = GlobalProxyConfig.fromUrl(
        'socks5h://alice:p%40ss@proxy.example:1081',
      );
      expect(remote, isNotNull);
      expect(remote!.type, ProxyType.socks5h);
      expect(remote.host, 'proxy.example');
      expect(remote.port, 1081);
      expect(remote.username, 'alice');
      expect(remote.password, 'p@ss');
      expect(remote.enabled, isTrue);
    });

    test('maps http and https URLs to HTTP CONNECT with port 8080 default', () {
      for (final url in ['http://proxy.example', 'https://proxy.example']) {
        final parsed = GlobalProxyConfig.fromUrl(url);
        expect(parsed, isNotNull, reason: url);
        expect(parsed!.type, ProxyType.httpConnect, reason: url);
        expect(parsed.port, 8080, reason: url);
      }
    });

    test(
      'accepts bare host:port and rejects unsupported or malformed URLs',
      () {
        final bare = GlobalProxyConfig.fromUrl('127.0.0.1:9050');
        expect(bare, isNotNull);
        expect(bare!.type, ProxyType.socks5);
        expect(bare.port, 9050);

        expect(GlobalProxyConfig.fromUrl('ftp://proxy.example'), isNull);
        expect(GlobalProxyConfig.fromUrl('socks5://'), isNull);
        expect(GlobalProxyConfig.fromUrl('socks5://proxy.example:0'), isNull);
        expect(
          GlobalProxyConfig.fromUrl('socks5://proxy.example:70000'),
          isNull,
        );
        expect(GlobalProxyConfig.fromUrl('   '), isNull);
      },
    );
  });

  group('Tor bridge lines', () {
    test('adds the selected built-in transport prefix exactly once', () {
      final lines = TorManager.normalizeBridgeLines(TorBridgeType.obfs4, [
        '192.0.2.1:443 FINGERPRINT cert=abc iat-mode=0',
        'obfs4 192.0.2.2:443 FINGERPRINT cert=def iat-mode=0',
        'Bridge obfs4 192.0.2.3:443 FINGERPRINT cert=ghi iat-mode=0',
        '',
      ]);
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('obfs4 192.0.2.1:443'));
      expect(lines[1], startsWith('obfs4 192.0.2.2:443'));
      expect(lines[2], startsWith('obfs4 192.0.2.3:443'));
    });

    test('refuses lines for another transport and control characters', () {
      expect(
        () => TorManager.normalizeBridgeLines(TorBridgeType.obfs4, [
          'snowflake 192.0.2.1:80 FINGERPRINT',
        ]),
        throwsA(isA<TorStartException>()),
      );
      expect(
        () => TorManager.normalizeBridgeLines(TorBridgeType.obfs4, [
          'obfs4 192.0.2.1:443 cert=abc\nSocksPort 0.0.0.0:1',
        ]),
        throwsA(isA<TorStartException>()),
      );
      expect(
        () => TorManager.normalizeBridgeLines(TorBridgeType.obfs4, const []),
        throwsA(isA<TorStartException>()),
      );
    });

    test('custom mode accepts Bridge and ClientTransportPlugin lines', () {
      final lines = TorManager.normalizeBridgeLines(TorBridgeType.custom, [
        'ClientTransportPlugin mytransport exec /usr/bin/my-client',
        'Bridge mytransport 192.0.2.1:443 FINGERPRINT',
        'mytransport 192.0.2.2:443 FINGERPRINT',
      ]);
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('ClientTransportPlugin'));
      expect(lines[1], startsWith('mytransport 192.0.2.1'));
      expect(lines[2], startsWith('mytransport 192.0.2.2'));
    });
  });

  group('buildTorrc', () {
    test('writes loopback-only SOCKS, owner data dir and obfs4 plugin', () {
      final torrc = TorManager.buildTorrc(
        port: 19050,
        dataDirectory: '/tmp/bnb-tor-test/data',
        bridgeType: TorBridgeType.obfs4,
        bridgeLines: const [
          'obfs4 192.0.2.1:443 FINGERPRINT cert=abc iat-mode=0',
        ],
        transportBinary: '/usr/bin/obfs4proxy',
      );
      expect(torrc, contains('SocksPort 127.0.0.1:19050'));
      expect(torrc, contains('ControlPort 0'));
      expect(torrc, contains('DataDirectory /tmp/bnb-tor-test/data'));
      expect(torrc, contains('UseBridges 1'));
      expect(
        torrc,
        contains('ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy'),
      );
      expect(
        torrc,
        contains('Bridge obfs4 192.0.2.1:443 FINGERPRINT cert=abc'),
      );
      expect(torrc, contains('SafeLogging 1'));
      expect(torrc, isNot(contains('SocksPort 0.0.0.0')));
    });

    test('custom plugin lines are written verbatim, without a fake plugin', () {
      final torrc = TorManager.buildTorrc(
        port: 9050,
        dataDirectory: '/tmp/bnb-tor-test/data',
        bridgeType: TorBridgeType.custom,
        bridgeLines: const [
          'ClientTransportPlugin mytransport exec /opt/my-client',
          'Bridge mytransport 192.0.2.1:443 FINGERPRINT',
        ],
      );
      expect(
        torrc,
        contains('ClientTransportPlugin mytransport exec /opt/my-client'),
      );
      expect(torrc, contains('Bridge mytransport 192.0.2.1:443 FINGERPRINT'));
      expect(torrc, isNot(contains('ClientTransportPlugin custom')));
    });

    test('writes a SOCKS5 upstream for VPN or VLESS before Tor', () {
      final torrc = TorManager.buildTorrc(
        port: 9050,
        dataDirectory: '/tmp/bnb-tor-test/data',
        bridgeType: TorBridgeType.none,
        bridgeLines: const [],
        upstream: const GlobalProxyConfig(
          type: ProxyType.socks5h,
          host: '127.0.0.1',
          port: 10808,
          username: 'vless',
          password: 'secret',
        ),
      );
      expect(torrc, contains('Socks5Proxy 127.0.0.1:10808'));
      expect(torrc, contains('Socks5ProxyUsername vless'));
      expect(torrc, contains('Socks5ProxyPassword secret'));
    });

    test('writes an HTTP CONNECT upstream with auth', () {
      final torrc = TorManager.buildTorrc(
        port: 9050,
        dataDirectory: '/tmp/bnb-tor-test/data',
        bridgeType: TorBridgeType.none,
        bridgeLines: const [],
        upstream: const GlobalProxyConfig(
          type: ProxyType.httpConnect,
          host: 'proxy.example',
          port: 8443,
          username: 'alice',
          password: 'secret',
        ),
      );
      expect(torrc, contains('HTTPSProxy proxy.example:8443'));
      expect(torrc, contains('HTTPSProxyAuthenticator alice:secret'));
    });

    test('rejects control characters in an upstream proxy', () {
      expect(
        () => TorManager.buildTorrc(
          port: 9050,
          dataDirectory: '/tmp/bnb-tor-test/data',
          bridgeType: TorBridgeType.none,
          bridgeLines: const [],
          upstream: const GlobalProxyConfig(
            type: ProxyType.socks5h,
            host: '127.0.0.1\nBadOption 1',
            port: 10808,
          ),
        ),
        throwsA(isA<TorStartException>()),
      );
    });

    test('direct Tor has no UseBridges line', () {
      final torrc = TorManager.buildTorrc(
        port: 9050,
        dataDirectory: '/tmp/bnb-tor-test/data',
        bridgeType: TorBridgeType.none,
        bridgeLines: const [],
      );
      expect(torrc, isNot(contains('UseBridges')));
      expect(torrc, isNot(contains('Bridge ')));
    });
  });
}

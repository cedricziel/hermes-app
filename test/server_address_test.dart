import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/server_address.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

void main() {
  group('isLocalHost', () {
    for (final host in [
      'localhost',
      'dash.localhost',
      '127.0.0.1',
      '127.5.6.7',
      '10.0.0.4',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.1.20',
      '169.254.10.1',
      '100.64.0.1',
      '100.127.255.254',
      '::1',
      '[::1]',
      'fe80::1',
      'fd7a:115c:a1e0::1',
      'fc00::5',
      '::ffff:192.168.1.20',
      'hermes.local',
      'nas.lan',
      'box.home.arpa',
      'hermes.internal',
      'hermes.tail1234.ts.net',
      'hermes',
      'HERMES.LOCAL',
      'fe80::1%en0',
      '0.0.0.0',
      '::',
    ]) {
      test('$host is local', () => expect(isLocalHost(host), isTrue));
    }

    for (final host in [
      'hermes.example.com',
      'example.com.',
      '8.8.8.8',
      '172.32.0.1',
      '192.169.0.1',
      '100.128.0.1',
      '2001:4860:4860::8888',
      '::ffff:8.8.8.8',
      '134744072',
      '0x08080808',
      '',
    ]) {
      test('"$host" is public', () => expect(isLocalHost(host), isFalse));
    }
  });

  group('isLocalHost range boundaries', () {
    // Just inside and just outside each range that allows cleartext without
    // confirmation. Each pair is address, expected.
    const cases = <(String, bool)>[
      // 127/8 loopback, 10/8, 172.16/12 and 192.168/16 private ranges.
      ('127.255.255.255', true),
      ('126.255.255.255', false),
      ('128.0.0.0', false),
      ('10.255.255.255', true),
      ('9.255.255.255', false),
      ('11.0.0.0', false),
      ('172.16.0.0', true),
      ('172.15.255.255', false),
      ('172.32.0.0', false),
      ('192.168.255.255', true),
      ('192.167.255.255', false),
      ('192.169.0.0', false),
      // 169.254.0.0/16 link-local.
      ('169.254.0.1', true),
      ('169.254.255.255', true),
      ('169.253.255.255', false),
      ('169.255.0.0', false),
      ('169.1.2.3', false),
      // 100.64.0.0/10 CGNAT (second octet 64..127).
      ('100.64.0.0', true),
      ('100.127.255.255', true),
      ('100.63.255.255', false),
      ('100.63.0.1', false),
      ('100.128.0.0', false),
      // fe80::/10 IPv6 link-local.
      ('febf::1', true),
      ('fec0::1', false),
      ('fe7f::1', false),
      // fc00::/7 IPv6 unique local.
      ('fc00::1', true),
      ('fdff::1', true),
      ('fe00::1', false),
      ('fbff::1', false),
      // IPv4-mapped ::ffff:a.b.c.d is as local as its IPv4 part.
      ('::ffff:192.168.1.1', true),
      ('::ffff:c0a8:101', true),
      ('::ffff:808:808', false),
      // The same bytes without the ff ff marker are not mapped.
      ('::fffe:c0a8:101', false),
      ('::c0a8:101', false),
      ('::ff:c0a8:101', false),
      ('0:0:0:0:1:ffff:c0a8:101', false),
      // A zone id is dropped before the address is read, so a public IPv6
      // address stays public (the name has no dot, which would otherwise
      // make it a local single-label name).
      ('2001:db8::1%en0', false),
    ];

    for (final (host, local) in cases) {
      test(
        '$host is ${local ? 'local' : 'public'}',
        () => expect(isLocalHost(host), local),
      );
    }
  });

  group('isCleartextToPublicHost', () {
    test('http:// to a public host', () {
      expect(isCleartextToPublicHost('http://hermes.example.com'), isTrue);
      expect(isCleartextToPublicHost('http://8.8.8.8:9119'), isTrue);
      expect(isCleartextToPublicHost('HTTP://hermes.example.com'), isTrue);
      expect(isCleartextToPublicHost('http://[::ffff:8.8.8.8]'), isTrue);
    });

    test('https:// or a local host is fine', () {
      expect(isCleartextToPublicHost('https://hermes.example.com'), isFalse);
      expect(isCleartextToPublicHost('http://192.168.1.20:9119'), isFalse);
      expect(isCleartextToPublicHost('http://100.101.102.103'), isFalse);
      expect(isCleartextToPublicHost('http://[fd7a:115c:a1e0::1]'), isFalse);
    });
  });

  group('redirectsToUnacceptedCleartext', () {
    test('refuses a move to public cleartext', () {
      expect(
        redirectsToUnacceptedCleartext(
          'https://hermes.example.com',
          'http://hermes.example.com',
        ),
        isTrue,
      );
      expect(
        redirectsToUnacceptedCleartext(
          'http://hermes.example.com',
          'http://other.example.com',
        ),
        isTrue,
      );
    });

    test('allows encrypted, local or the accepted address', () {
      expect(
        redirectsToUnacceptedCleartext(
          'http://hermes.example.com',
          'https://hermes.example.com',
        ),
        isFalse,
      );
      expect(
        redirectsToUnacceptedCleartext(
          'http://hermes.example.com',
          'http://hermes.example.com/dash',
        ),
        isFalse,
      );
      expect(
        redirectsToUnacceptedCleartext(
          'http://192.168.1.20:9119',
          'http://192.168.1.20:9119/dash',
        ),
        isFalse,
      );
    });
  });

  group('normalizeServerUrl', () {
    test('a schemeless public host becomes https://', () {
      expect(
        normalizeServerUrl('hermes.example.com'),
        'https://hermes.example.com',
      );
      expect(
        normalizeServerUrl(' hermes.example.com:8443/dash/ '),
        'https://hermes.example.com:8443/dash',
      );
    });

    test('a schemeless local, private or tailnet host stays http://', () {
      expect(
        normalizeServerUrl('192.168.1.20:9119'),
        'http://192.168.1.20:9119',
      );
      expect(normalizeServerUrl('localhost:9119'), 'http://localhost:9119');
      expect(normalizeServerUrl('hermes.local'), 'http://hermes.local');
      expect(normalizeServerUrl('100.64.0.7:9119'), 'http://100.64.0.7:9119');
      expect(normalizeServerUrl('[::1]:9119'), 'http://[::1]:9119');
      expect(normalizeServerUrl('0.0.0.0:9119'), 'http://0.0.0.0:9119');
      expect(normalizeServerUrl('134744072:9119'), 'https://134744072:9119');
    });

    test('keeps a typed scheme', () {
      expect(
        normalizeServerUrl('http://hermes.example.com/'),
        'http://hermes.example.com',
      );
      expect(
        normalizeServerUrl('https://192.168.1.20:9119'),
        'https://192.168.1.20:9119',
      );
    });

    test('refuses other schemes and empty input', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('ftp://hermes.example.com'), isNull);
    });
  });

  group('AuthController.connect', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('refuses http:// to a public host the user did not accept', () async {
      final auth = AuthController(tokenStore: MemoryTokenStore());

      await auth.connect('http://hermes.invalid');

      expect(auth.state, HermesConnectionState.connectionError);
      expect(auth.errorMessage, cleartextRefusedMessage);
      expect(auth.baseUrl, isNull);
    });
  });
}

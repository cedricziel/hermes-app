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
      '',
    ]) {
      test('"$host" is public', () => expect(isLocalHost(host), isFalse));
    }
  });

  group('isCleartextToPublicHost', () {
    test('http:// to a public host', () {
      expect(isCleartextToPublicHost('http://hermes.example.com'), isTrue);
      expect(isCleartextToPublicHost('http://8.8.8.8:9119'), isTrue);
    });

    test('https:// or a local host is fine', () {
      expect(isCleartextToPublicHost('https://hermes.example.com'), isFalse);
      expect(isCleartextToPublicHost('http://192.168.1.20:9119'), isFalse);
      expect(isCleartextToPublicHost('http://100.101.102.103'), isFalse);
      expect(isCleartextToPublicHost('http://[fd7a:115c:a1e0::1]'), isFalse);
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

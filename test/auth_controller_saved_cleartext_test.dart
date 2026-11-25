import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/memory_token_store.dart';

const _publicHttp = 'http://hermes.example.com';

void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': false});
  });

  Future<AuthController> bootstrapped({
    String? saved,
    String? devServerUrl,
  }) async {
    if (saved != null) {
      await SharedPreferencesAsync().setString(kSavedServerUrlKey, saved);
    }
    final transport = server.dio();
    addTearDown(transport.close);
    final controller = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: devServerUrl,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              handler.resolve(await transport.fetch<dynamic>(options), true);
            } on DioException catch (error) {
              handler.reject(error, true);
            }
          },
        ),
      ],
    );
    addTearDown(controller.dispose);
    await controller.bootstrap();
    return controller;
  }

  test('a saved public http:// server with no acceptance is asked about, '
      'and still connects meanwhile', () async {
    final controller = await bootstrapped(saved: _publicHttp);

    expect(controller.state, HermesConnectionState.ready);
    expect(controller.unconfirmedCleartextServer, _publicHttp);
  });

  test(
    'keeping http:// is remembered, so a later launch does not ask',
    () async {
      final first = await bootstrapped(saved: _publicHttp);
      await first.keepCleartextServer();

      expect(first.unconfirmedCleartextServer, isNull);

      final next = await bootstrapped();
      expect(next.state, HermesConnectionState.ready);
      expect(next.unconfirmedCleartextServer, isNull);
    },
  );

  test(
    'keeping is per server: another public http:// server is asked',
    () async {
      final first = await bootstrapped(saved: _publicHttp);
      await first.keepCleartextServer();

      await SharedPreferencesAsync().setString(
        kSavedServerUrlKey,
        'http://other.example.org',
      );
      final next = await bootstrapped();

      expect(next.unconfirmedCleartextServer, 'http://other.example.org');
    },
  );

  test('using https:// reconnects there and saves it', () async {
    final controller = await bootstrapped(
      saved: 'http://hermes.example.com:9119',
    );

    await controller.useHttpsForCleartextServer();

    expect(controller.unconfirmedCleartextServer, isNull);
    expect(controller.baseUrl, 'https://hermes.example.com:9119');
    expect(controller.state, HermesConnectionState.ready);
    expect(
      await SharedPreferencesAsync().getString(kSavedServerUrlKey),
      'https://hermes.example.com:9119',
    );
  });

  test(
    'typing a public http:// address and accepting it is remembered',
    () async {
      final controller = await bootstrapped();
      await controller.connect(_publicHttp, allowCleartext: true);

      final next = await bootstrapped();
      expect(next.baseUrl, _publicHttp);
      expect(next.unconfirmedCleartextServer, isNull);
    },
  );

  for (final local in [
    'http://192.168.1.20:9119',
    'http://127.0.0.1:9119',
    'http://100.101.102.103',
    'http://[fd7a:115c:a1e0::1]',
    'http://hermes.local',
    'http://hermes',
    'https://hermes.example.com',
  ]) {
    test('$local is never asked about', () async {
      final controller = await bootstrapped(saved: local);

      expect(controller.state, HermesConnectionState.ready);
      expect(controller.unconfirmedCleartextServer, isNull);
    });
  }

  test('a dev server override is never asked about', () async {
    final controller = await bootstrapped(devServerUrl: _publicHttp);

    expect(controller.unconfirmedCleartextServer, isNull);
  });

  test('changing the server drops the question', () async {
    final controller = await bootstrapped(saved: _publicHttp);

    await controller.changeServer();

    expect(controller.unconfirmedCleartextServer, isNull);
  });

  test('connecting to another server drops the question', () async {
    final controller = await bootstrapped(saved: _publicHttp);

    await controller.connect('https://hermes.example.org');

    expect(controller.unconfirmedCleartextServer, isNull);
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/native_login_flow.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
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
    bool httpsDown = false,
    bool redirectsToHttps = false,
    bool httpsRedirectsBack = false,
    Future<void>? httpsGate,
    MemoryTokenStore? tokens,
    NativeLogin? login,
  }) async {
    if (saved != null) {
      await SharedPreferencesAsync().setString(kSavedServerUrlKey, saved);
    }
    final transport = server.dio();
    addTearDown(transport.close);
    final controller = AuthController(
      tokenStore: tokens ?? MemoryTokenStore(),
      devServerUrl: devServerUrl,
      login: login ?? runNativeLogin,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (httpsDown && options.uri.scheme == 'https') {
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'no https listener',
                ),
                true,
              );
              return;
            }
            if (options.uri.scheme == 'https') await httpsGate;
            try {
              final response = await transport.fetch<dynamic>(options);
              if (httpsRedirectsBack && options.uri.scheme == 'https') {
                response
                  ..isRedirect = true
                  ..redirects = [
                    RedirectRecord(
                      301,
                      'GET',
                      options.uri.replace(scheme: 'http'),
                    ),
                  ];
              }
              if (redirectsToHttps && options.uri.scheme == 'http') {
                response
                  ..isRedirect = true
                  ..redirects = [
                    RedirectRecord(
                      301,
                      'GET',
                      options.uri.replace(scheme: 'https'),
                    ),
                  ];
              }
              handler.resolve(response, true);
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

  test('connecting to another public http:// server drops the question '
      'about the saved one', () async {
    final controller = await bootstrapped(saved: _publicHttp);

    await controller.connect('http://other.example.org', allowCleartext: true);

    expect(controller.unconfirmedCleartextServer, isNull);
  });

  test('using https:// when nothing answers there keeps the saved connection '
      'and drops the question', () async {
    final controller = await bootstrapped(saved: _publicHttp, httpsDown: true);

    final outcome = await controller.useHttpsForCleartextServer();

    expect(outcome, HttpsSwitch.unavailable);
    expect(controller.state, HermesConnectionState.ready);
    expect(controller.baseUrl, _publicHttp);
    expect(controller.unconfirmedCleartextServer, isNull);
    expect(
      await SharedPreferencesAsync().getString(kSavedServerUrlKey),
      _publicHttp,
    );
    expect(
      await SharedPreferencesAsync().getStringList(
        kAcceptedCleartextServersKey,
      ),
      isNull,
    );
  });

  test('using https:// on a server that needs sign-in asks for the sign-in '
      'again, since the http:// address issued the session', () async {
    server
      ..on('GET', '/api/status', {'auth_required': true})
      ..on('GET', '/api/auth/providers', {'providers': []})
      ..on('GET', '/api/auth/me', {'user_id': 'u1', 'provider': 'oidc'});
    final tokens = MemoryTokenStore(
      const HermesSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: 4102444800,
        provider: 'oidc',
        userId: 'u1',
        serverUrl: _publicHttp,
      ),
    );
    final controller = await bootstrapped(saved: _publicHttp, tokens: tokens);
    expect(controller.state, HermesConnectionState.ready);

    expect(await controller.useHttpsForCleartextServer(), HttpsSwitch.switched);

    expect(controller.baseUrl, 'https://hermes.example.com');
    expect(controller.state, HermesConnectionState.needsLogin);
  });

  test(
    'a refused or failed Connect Anyway is not recorded as accepted',
    () async {
      final controller = await bootstrapped(httpsDown: true);
      server.on('GET', '/api/status', {'detail': 'down'}, status: 503);

      await controller.connect(_publicHttp, allowCleartext: true);

      expect(controller.state, HermesConnectionState.connectionError);
      expect(
        await SharedPreferencesAsync().getStringList(
          kAcceptedCleartextServersKey,
        ),
        isNull,
      );
    },
  );

  test('a saved http:// address that now redirects to https is not asked '
      'about', () async {
    final controller = await bootstrapped(
      saved: _publicHttp,
      redirectsToHttps: true,
    );

    expect(controller.baseUrl, 'https://hermes.example.com');
    expect(controller.unconfirmedCleartextServer, isNull);
  });

  test('an https:// address that sends the app back to http:// is no answer, '
      'and the saved connection stays', () async {
    final controller = await bootstrapped(
      saved: _publicHttp,
      httpsRedirectsBack: true,
    );

    expect(
      await controller.useHttpsForCleartextServer(),
      HttpsSwitch.unavailable,
    );

    expect(controller.state, HermesConnectionState.ready);
    expect(controller.baseUrl, _publicHttp);
  });

  test('changing the server while https:// is probed does not connect to the '
      'old server', () async {
    final gate = Completer<void>();
    final controller = await bootstrapped(
      saved: _publicHttp,
      httpsGate: gate.future,
    );

    final switching = controller.useHttpsForCleartextServer();
    await controller.changeServer();
    gate.complete();

    expect(await switching, HttpsSwitch.superseded);
    expect(controller.baseUrl, isNull);
    expect(controller.state, HermesConnectionState.needsServerUrl);
  });

  test(
    'a failing preferences write does not fail the connect or the answer',
    () async {
      SharedPreferencesAsyncPlatform.instance = _FailingListWrites();
      final controller = await bootstrapped();

      await controller.connect(_publicHttp, allowCleartext: true);

      expect(controller.state, HermesConnectionState.ready);

      final saved = await bootstrapped(saved: 'http://other.example.org');
      await saved.keepCleartextServer();
      expect(saved.unconfirmedCleartextServer, isNull);
    },
  );

  test('a sign-in started while https:// is probed is not overrun', () async {
    server
      ..on('GET', '/api/status', {'auth_required': true})
      ..on('GET', '/api/auth/providers', {
        'providers': [
          {'name': 'oidc', 'display_name': 'SSO'},
        ],
      });
    final gate = Completer<void>();
    final controller = await bootstrapped(
      saved: _publicHttp,
      httpsGate: gate.future,
      login: (url, {provider, httpClient, cancelled}) =>
          Completer<HermesSession>().future,
    );
    expect(controller.state, HermesConnectionState.needsLogin);

    final switching = controller.useHttpsForCleartextServer();
    unawaited(controller.signInWithProvider(controller.providers.single));
    await pumpEventQueue();
    expect(controller.state, HermesConnectionState.signingIn);
    gate.complete();

    expect(await switching, HttpsSwitch.superseded);
    expect(controller.baseUrl, _publicHttp);
    expect(controller.state, HermesConnectionState.signingIn);
  });

  test('a sign-in that finishes while https:// is probed is not thrown '
      'away', () async {
    server
      ..on('GET', '/api/status', {'auth_required': true})
      ..on('GET', '/api/auth/me', {'user_id': 'u1', 'provider': 'oidc'})
      ..on('GET', '/api/auth/providers', {
        'providers': [
          {'name': 'oidc', 'display_name': 'SSO'},
        ],
      });
    final gate = Completer<void>();
    final controller = await bootstrapped(
      saved: _publicHttp,
      httpsGate: gate.future,
      login: (url, {provider, httpClient, cancelled}) async =>
          const HermesSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            expiresAt: 4102444800,
            provider: 'oidc',
            userId: 'u1',
          ),
    );

    final switching = controller.useHttpsForCleartextServer();
    await controller.signInWithProvider(controller.providers.single);
    expect(controller.state, HermesConnectionState.ready);
    gate.complete();

    expect(await switching, HttpsSwitch.superseded);
    expect(controller.baseUrl, _publicHttp);
    expect(controller.state, HermesConnectionState.ready);
  });

  test('an unreadable accepted list asks, and still connects', () async {
    SharedPreferencesAsyncPlatform.instance = _FailingListReads();
    final controller = await bootstrapped(saved: _publicHttp);

    expect(controller.state, HermesConnectionState.ready);
    expect(controller.unconfirmedCleartextServer, _publicHttp);
  });
}

base class _FailingListWrites extends InMemorySharedPreferencesAsync {
  _FailingListWrites() : super.empty();

  @override
  Future<bool> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) => throw StateError('disk full');
}

base class _FailingListReads extends InMemorySharedPreferencesAsync {
  _FailingListReads() : super.empty();

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) => throw StateError('unreadable');
}

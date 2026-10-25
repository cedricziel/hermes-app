import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

const _baseUrl = 'http://hermes.test';
const _identity = {'user_id': 'u1', 'provider': 'oidc'};
const _unauthorized = {'detail': 'Unauthorized'};
const _storedSession = HermesSession(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  expiresAt: 4102444800,
  provider: 'oidc',
  userId: 'u1',
  serverUrl: _baseUrl,
);

void main() {
  late FakeHermesServer server;
  late MemoryTokenStore tokens;
  late RecordedEvents events;
  late AuthController controller;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': true})
      ..on('GET', '/api/auth/providers', {'providers': []})
      ..on('GET', '/api/auth/me', _identity)
      ..onRequest('POST', '/auth/native/refresh', (request) {
        final body = jsonBody(request) as Map;
        final next = switch (body['refresh_token']) {
          'refresh-1' => 2,
          'refresh-2' => 3,
          _ => throw StateError('Unexpected refresh token'),
        };
        return (
          status: 200,
          body: {
            'access_token': 'access-$next',
            'refresh_token': 'refresh-$next',
            'expires_at': 4102444800,
            ..._identity,
          },
        );
      });
    tokens = MemoryTokenStore(_storedSession);
    events = RecordedEvents();
    final transport = server.dio();
    addTearDown(transport.close);
    controller = AuthController(
      tokenStore: tokens,
      devServerUrl: _baseUrl,
      telemetry: events.connection,
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
  });

  test(
    'an unavailable keychain during restore keeps the session for retry',
    () async {
      tokens.unreadable = true;

      await controller.bootstrap();

      expect(controller.state, HermesConnectionState.connectionError);
      expect(controller.errorMessage, contains('saved sign-in'));
      expect(tokens.session, same(_storedSession));
      expect(events.named('auth.session.restore_failed'), [
        {'reason': 'keychain_unavailable', 'locked': true},
      ]);

      tokens.unreadable = false;
      await controller.connect(_baseUrl);

      expect(controller.state, HermesConnectionState.ready);
      expect(controller.identity?.userId, 'u1');
    },
  );

  test('a delayed retried 401 preserves a newer session', () async {
    await controller.bootstrap();
    final retryStarted = Completer<void>();
    final held = Completer<void>();
    addTearDown(() {
      if (!held.isCompleted) held.complete();
    });
    server.onRequest('GET', '/api/auth/me', (request) async {
      switch (request.headers['Authorization']) {
        case 'Bearer access-1':
          return (status: 401, body: _unauthorized);
        case 'Bearer access-2':
          retryStarted.complete();
          await held.future;
          return (status: 401, body: _unauthorized);
        case 'Bearer access-3':
          return (status: 200, body: _identity);
        default:
          return (status: 401, body: _unauthorized);
      }
    });
    final pending = expectLater(
      controller.api!.fetchMe(),
      throwsA(isA<DioException>()),
    );
    await retryStarted.future.timeout(const Duration(seconds: 5));
    await controller.windowAuthHeaders(
      rejected: {'Authorization': 'Bearer access-2'},
    );
    held.complete();
    await pending;

    expect(controller.state, HermesConnectionState.ready);
    expect(tokens.session?.accessToken, 'access-3');
    expect(events.named('auth.session.expired'), isEmpty);
    expect((await controller.api!.fetchMe()).userId, 'u1');
  });

  test('a retried 401 for the current token expires the session', () async {
    await controller.bootstrap();
    server.on('GET', '/api/auth/me', _unauthorized, status: 401);

    await expectLater(controller.api!.fetchMe(), throwsA(isA<DioException>()));

    expect(controller.state, HermesConnectionState.needsLogin);
    expect(tokens.session, isNull);
    expect(events.named('auth.session.expired'), [
      {'cause': 'unauthorized_after_retry'},
    ]);
  });
}

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
  late RecordedEvents events;
  late AuthController controller;
  late List<Duration> slept;
  late int unreachable;
  Future<void> Function()? onRetryWait;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    slept = [];
    unreachable = 0;
    onRetryWait = null;
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': true})
      ..on('GET', '/api/auth/providers', {'providers': []})
      ..on('GET', '/api/auth/me', _identity)
      ..on('POST', '/api/auth/ws-ticket', {'detail': 'no'}, status: 401)
      ..on('POST', '/auth/native/refresh', {
        'access_token': 'access-2',
        'refresh_token': 'refresh-2',
        'expires_at': 4102444800,
        ..._identity,
      });
    events = RecordedEvents();
    final transport = server.dio();
    addTearDown(transport.close);
    controller = AuthController(
      tokenStore: MemoryTokenStore(_storedSession),
      devServerUrl: _baseUrl,
      telemetry: events.connection,
      rejectionRecheck: Duration.zero,
      getRetryDelay: (delay) async {
        slept.add(delay);
        await onRetryWait?.call();
      },
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // The network is down for the first `unreachable` requests.
            if (unreachable > 0 && options.path != '/auth/native/refresh') {
              unreachable--;
              return handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'down',
                ),
                true,
              );
            }
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

  test('a GET that cannot connect is sent again, twice at most', () async {
    await controller.bootstrap();
    unreachable = 2;

    final me = await controller.api!.fetchMe();

    expect(me.userId, 'u1');
    expect(slept, hasLength(2));
    expect(controller.state, HermesConnectionState.ready);
  });

  test('a GET that keeps failing to connect gives up after two retries and '
      'does not sign the user out', () async {
    await controller.bootstrap();
    unreachable = 10;

    await expectLater(controller.api!.fetchMe(), throwsA(isA<DioException>()));

    expect(unreachable, 7);
    expect(slept, hasLength(2));
    expect(controller.state, HermesConnectionState.ready);
  });

  test('a GET waiting to be sent again is dropped when the user signs out '
      'meanwhile', () async {
    await controller.bootstrap();
    unreachable = 10;
    onRetryWait = controller.signOut;

    await expectLater(
      controller.api!.fetchMe(),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );

    expect(unreachable, 9);
    expect(slept, hasLength(1));
  });

  test('a POST that cannot connect is not sent again', () async {
    await controller.bootstrap();
    unreachable = 1;

    await expectLater(
      controller.api!.raw.authWsTicketApiAuthWsTicketPost(),
      throwsA(isA<DioException>()),
    );

    expect(unreachable, 0);
    expect(slept, isEmpty);
  });

  test('a 401 on a POST costs one refresh and one more try, then ends the '
      'session instead of looping', () async {
    await controller.bootstrap();

    await expectLater(
      controller.api!.raw.authWsTicketApiAuthWsTicketPost(),
      throwsA(isA<DioException>()),
    );
    // Whoever called asks again, as a reconnecting socket would.
    for (var i = 0; i < 5; i++) {
      await expectLater(
        controller.api!.raw.authWsTicketApiAuthWsTicketPost(),
        throwsA(isA<DioException>()),
      );
    }

    expect(server.requestsTo('POST', '/auth/native/refresh'), hasLength(1));
    expect(server.requestsTo('POST', '/api/auth/ws-ticket'), hasLength(2));
    expect(controller.state, HermesConnectionState.needsLogin);
    expect(events.named('auth.session.expired'), [
      {'cause': 'unauthorized_after_retry'},
    ]);
  });
}

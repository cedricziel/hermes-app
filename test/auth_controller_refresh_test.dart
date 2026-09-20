import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

/// A gated dashboard whose refresh tokens rotate: each one works once.
class _GatedDashboard {
  _GatedDashboard._(this._server);

  static Future<_GatedDashboard> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dashboard = _GatedDashboard._(server);
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  String validAccess = 'access-1';
  String validRefresh = 'refresh-1';
  int rotations = 0;

  /// Status the refresh route answers with instead of rotating, if set.
  int? refreshFailure;

  /// How long the refresh route takes before answering.
  Duration refreshDelay = Duration.zero;

  /// Delays applied, in order, to the next 401 answers, so one request's
  /// rejection can land after a concurrent request has rotated the tokens.
  final List<Duration> unauthorizedDelays = [];

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    switch (request.uri.path) {
      case '/api/status':
        return _json(request, 200, {
          'auth_required': true,
          'auth_flows': ['native_pkce'],
        });
      case '/api/auth/providers':
        return _json(request, 200, {'providers': []});
      case '/auth/native/refresh':
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        await Future<void>.delayed(refreshDelay);
        final failure = refreshFailure;
        if (failure != null) {
          return _json(request, failure, {'detail': 'refresh failed'});
        }
        if (body['refresh_token'] != validRefresh) {
          return _json(request, 401, {'detail': 'session_expired'});
        }
        rotations++;
        validAccess = 'access-${rotations + 1}';
        validRefresh = 'refresh-${rotations + 1}';
        return _json(request, 200, {
          'access_token': validAccess,
          'refresh_token': validRefresh,
          'expires_at': _farFuture,
          'provider': 'oidc',
          'user_id': 'u1',
        });
      default:
        return _authed(request);
    }
  }

  Future<void> _authed(HttpRequest request) async {
    final bearer = request.headers.value('Authorization');
    if (bearer != 'Bearer $validAccess') {
      if (unauthorizedDelays.isNotEmpty) {
        await Future<void>.delayed(unauthorizedDelays.removeAt(0));
      }
      _json(request, 401, {'detail': 'Unauthorized'});
      return;
    }
    _json(request, 200, {'user_id': 'u1', 'ok': true});
  }

  void _json(HttpRequest request, int status, Object body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}

final _farFuture =
    DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

HermesSession _session({String access = 'access-1', String? refresh}) =>
    HermesSession(
      accessToken: access,
      refreshToken: refresh ?? 'refresh-1',
      expiresAt: _farFuture,
      provider: 'oidc',
      userId: 'u1',
    );

void main() {
  late _GatedDashboard dashboard;
  late MemoryTokenStore store;
  late AuthController controller;
  late RecordedEvents events;
  late List<String> requestedPaths;

  Future<void> bootstrapWith(HermesSession session) async {
    store = MemoryTokenStore(session);
    controller = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPaths.add(options.path);
            handler.next(options);
          },
        ),
      ],
      events: events.call,
    );
    await controller.bootstrap();
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = await _GatedDashboard.start();
    events = RecordedEvents();
    requestedPaths = [];
  });

  tearDown(() => dashboard.close());

  test('a 401 for a token another request already rotated retries with the '
      'new token instead of spending the used refresh token', () async {
    await bootstrapWith(_session());
    dashboard
      ..validAccess = 'revoked'
      ..unauthorizedDelays.addAll([
        Duration.zero,
        const Duration(milliseconds: 300),
      ]);

    await Future.wait([controller.api!.fetchMe(), controller.api!.fetchMe()]);

    expect(controller.state, HermesConnectionState.ready);
    expect(dashboard.rotations, 1);
    expect(store.session?.accessToken, 'access-2');
    expect(events.named('auth.session.refreshed'), [
      {'trigger': 'after_401'},
    ]);
    expect(requestedPaths, contains('/auth/native/refresh'));
  });

  test('keeps the session when the refresh endpoint is unavailable', () async {
    await bootstrapWith(_session());
    dashboard
      ..validAccess = 'revoked'
      ..refreshFailure = 503;

    await expectLater(controller.api!.fetchMe(), throwsA(isA<DioException>()));

    expect(controller.state, HermesConnectionState.ready);
    expect(store.session?.refreshToken, 'refresh-1');
    expect(events.named('auth.session.refresh_failed'), [
      {'trigger': 'after_401', 'rejected': false, 'http.status_code': 503},
    ]);
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('signs the user out when the refresh token is rejected', () async {
    await bootstrapWith(_session());
    dashboard
      ..validAccess = 'revoked'
      ..validRefresh = 'something-else';

    await expectLater(controller.api!.fetchMe(), throwsA(isA<DioException>()));

    expect(controller.state, HermesConnectionState.needsLogin);
    expect(store.session, isNull);
    expect(events.named('auth.session.refresh_failed'), [
      {'trigger': 'after_401', 'rejected': true, 'http.status_code': 401},
    ]);
    expect(events.named('auth.session.expired'), [
      {'cause': 'refresh_rejected'},
    ]);
    expect(events.named('auth.state').last, {'state': 'needsLogin'});
  });

  test('keeps stored tokens when the session check fails for a transient '
      'reason at startup', () async {
    dashboard
      ..validAccess = 'revoked'
      ..refreshFailure = 503;

    await bootstrapWith(_session());

    expect(controller.state, HermesConnectionState.connectionError);
    expect(store.session?.refreshToken, 'refresh-1');
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('a refresh that finishes after sign-out does not restore the '
      'session', () async {
    await bootstrapWith(_session());
    dashboard
      ..validAccess = 'revoked'
      ..refreshDelay = const Duration(milliseconds: 300);

    final request = controller.api!.fetchMe();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await controller.signOut();

    await expectLater(request, throwsA(isA<DioException>()));
    expect(store.session, isNull);
  });
}

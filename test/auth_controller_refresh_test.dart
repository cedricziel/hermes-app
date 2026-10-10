import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

  /// Whether the refresh route leaves `expires_at` out of its answer.
  bool omitExpiresAt = false;

  /// The `expires_at` the refresh route answers with, when not an hour ahead.
  int? refreshExpiresAt;

  /// How long the refresh route takes before answering.
  Duration refreshDelay = Duration.zero;

  /// Whether the next rotation drops the connection instead of answering,
  /// like a response lost on the way back to the app.
  bool dropNextRefreshAnswer = false;

  /// Whether the refresh token just rotated away still answers with the set
  /// it was rotated into, like Hermes' short cache of refresh results.
  bool replayLastRotation = false;

  String? _rotatedAway;

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
        final replay =
            replayLastRotation && body['refresh_token'] == _rotatedAway;
        if (body['refresh_token'] != validRefresh && !replay) {
          return _json(request, 401, {'detail': 'session_expired'});
        }
        if (!replay) {
          rotations++;
          _rotatedAway = validRefresh;
          validAccess = 'access-${rotations + 1}';
          validRefresh = 'refresh-${rotations + 1}';
        }
        if (dropNextRefreshAnswer) {
          dropNextRefreshAnswer = false;
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
          return;
        }
        return _json(request, 200, {
          'access_token': validAccess,
          'refresh_token': validRefresh,
          if (!omitExpiresAt) 'expires_at': refreshExpiresAt ?? _farFuture,
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

/// A store whose [clear] empties it at once but reports back only after
/// [releaseClear], like a keychain that is slow to answer.
class _SlowClearTokenStore extends MemoryTokenStore {
  _SlowClearTokenStore(super.session);

  final _released = Completer<void>();

  void releaseClear() => _released.complete();

  @override
  Future<void> clear() async {
    session = null;
    await _released.future;
  }
}

final _farFuture =
    DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

HermesSession _session({
  String access = 'access-1',
  String? refresh,
  int? expiresAt,
  bool unknownExpiry = false,
}) => HermesSession(
  accessToken: access,
  refreshToken: refresh ?? 'refresh-1',
  expiresAt: unknownExpiry ? null : expiresAt ?? _farFuture,
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
      telemetry: events.connection,
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

  test(
    'a session with no known expiry is not refreshed before each request',
    () async {
      await bootstrapWith(_session(unknownExpiry: true));

      await controller.api!.fetchMe();
      await controller.api!.fetchMe();
      await controller.api!.fetchMe();

      expect(dashboard.rotations, 0);
      expect(requestedPaths, isNot(contains('/auth/native/refresh')));
      expect(events.named('auth.session.refreshed'), isEmpty);
    },
  );

  test('a session with no known expiry refreshes once on a 401 and then '
      'stops refreshing', () async {
    await bootstrapWith(_session(unknownExpiry: true));
    dashboard
      ..validAccess = 'revoked'
      ..omitExpiresAt = true;

    await controller.api!.fetchMe();
    await controller.api!.fetchMe();
    await controller.api!.fetchMe();

    expect(dashboard.rotations, 1);
    expect(store.session?.accessToken, 'access-2');
    expect(events.named('auth.session.refreshed'), [
      {'trigger': 'after_401'},
    ]);
  });

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
      {
        'trigger': 'after_401',
        'rejected': false,
        'http.response.status_code': 503,
      },
    ]);
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('a proactive refresh that fails sends the request with the current '
      'token and keeps the session', () async {
    dashboard.refreshExpiresAt = 1;
    await bootstrapWith(_session(expiresAt: 1));
    dashboard.refreshFailure = 503;

    await controller.api!.fetchMe();

    expect(controller.state, HermesConnectionState.ready);
    expect(store.session?.refreshToken, 'refresh-2');
    expect(events.named('auth.session.refresh_failed'), [
      {
        'trigger': 'proactive',
        'rejected': false,
        'http.response.status_code': 503,
      },
    ]);
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('a refreshed session that cannot be stored is still used', () async {
    store = MemoryTokenStore(_session(expiresAt: 1))..failWrites = true;
    controller = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      telemetry: events.connection,
    );
    await controller.bootstrap();

    await controller.api!.fetchMe();

    expect(controller.state, HermesConnectionState.ready);
    expect(dashboard.rotations, 1);
    expect(events.named('auth.session.store_failed'), [
      {'error.type': 'UnsupportedError'},
    ]);
  });

  test('a refresh whose answer is lost is asked again at once and keeps the '
      'rotated session', () async {
    dashboard
      ..dropNextRefreshAnswer = true
      ..replayLastRotation = true;
    await bootstrapWith(_session(expiresAt: 1));

    expect(controller.state, HermesConnectionState.ready);
    expect(dashboard.rotations, 1);
    expect(store.session?.refreshToken, 'refresh-2');
    expect(events.named('auth.session.refresh_retried'), [
      {'trigger': 'proactive'},
    ]);
    expect(events.named('auth.session.refreshed'), [
      {'trigger': 'proactive'},
    ]);
  });

  test('a refresh that lands after the same session was read again is '
      'kept', () async {
    store = MemoryTokenStore(_session(), true);
    controller = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      telemetry: events.connection,
    );
    await controller.bootstrap();
    dashboard
      ..validAccess = 'revoked'
      ..refreshDelay = const Duration(milliseconds: 300);

    final request = controller.api!.fetchMe();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await controller.connect(dashboard.url, remember: false);
    await request.then<void>((_) {}, onError: (_) {});

    expect(store.session?.refreshToken, 'refresh-2');
    expect(events.named('auth.session.refreshed'), [
      {'trigger': 'after_401'},
    ]);
  });

  test('a rejected refresh adopts the pair another isolate stored', () async {
    await bootstrapWith(_session());
    // A second controller on the same keychain, as in the notification
    // isolate, holding the pair both read at start.
    final other = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
    );
    addTearDown(other.dispose);
    await other.bootstrap();
    dashboard.validAccess = 'expired';
    await controller.api!.fetchMe();
    expect(store.session?.refreshToken, 'refresh-2');

    await other.api!.fetchMe();

    expect(other.state, HermesConnectionState.ready);
    expect(store.session?.refreshToken, 'refresh-2');
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
      {
        'trigger': 'after_401',
        'rejected': true,
        'http.response.status_code': 401,
      },
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

  group('a refresh that lands while the token store is still clearing', () {
    late _SlowClearTokenStore slowStore;

    Future<Future<void> Function()> startSlowClear(
      Future<void> Function() leave,
    ) async {
      slowStore = _SlowClearTokenStore(_session());
      store = slowStore;
      controller = AuthController(
        tokenStore: slowStore,
        devServerUrl: dashboard.url,
        telemetry: events.connection,
      );
      await controller.bootstrap();
      dashboard
        ..validAccess = 'revoked'
        ..refreshDelay = const Duration(milliseconds: 200);

      final request = controller.api!.fetchMe().then<void>(
        (_) {},
        onError: (_) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final leaving = leave();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return () async {
        slowStore.releaseClear();
        await leaving;
        await request;
      };
    }

    test('does not write the tokens back after sign-out', () async {
      final finish = await startSlowClear(() => controller.signOut());
      await finish();

      expect(slowStore.session, isNull);
      expect(controller.state, HermesConnectionState.needsLogin);
    });

    test('does not write the tokens back after changing the server', () async {
      final finish = await startSlowClear(() => controller.changeServer());
      await finish();

      expect(slowStore.session, isNull);
      expect(controller.state, HermesConnectionState.needsServerUrl);
    });
  });

  group('signedOut', () {
    late int signedOut;
    final expired = <bool>[];
    setUp(expired.clear);

    Future<void> listen(HermesSession session) async {
      await bootstrapWith(session);
      signedOut = 0;
      controller.signedOut.listen((_) {
        signedOut++;
        expired.add(controller.sessionExpired);
      });
    }

    test('fires when the user signs out', () async {
      await listen(_session());

      await controller.signOut();

      expect(signedOut, 1);
      expect(expired, [false]);
    });

    test('fires when the user removes the server', () async {
      await listen(_session());

      await controller.changeServer();

      expect(signedOut, 1);
      expect(expired, [false]);
    });

    test('fires when the server rejects the refresh token', () async {
      await listen(_session());
      dashboard
        ..validAccess = 'revoked'
        ..validRefresh = 'something-else';

      await expectLater(
        controller.api!.fetchMe(),
        throwsA(isA<DioException>()),
      );

      expect(signedOut, 1);
      expect(expired, [true]);
    });

    test('stays quiet while requests race to refresh the session', () async {
      await listen(_session());
      dashboard
        ..validAccess = 'revoked'
        ..unauthorizedDelays.addAll([
          Duration.zero,
          const Duration(milliseconds: 300),
        ]);

      await Future.wait([controller.api!.fetchMe(), controller.api!.fetchMe()]);

      expect(controller.state, HermesConnectionState.ready);
      expect(signedOut, 0);
    });

    test('stays quiet when the refresh endpoint is unavailable', () async {
      await listen(_session());
      dashboard
        ..validAccess = 'revoked'
        ..refreshFailure = 503;

      await expectLater(
        controller.api!.fetchMe(),
        throwsA(isA<DioException>()),
      );

      expect(signedOut, 0);
    });
  });
  group('windowAuthHeaders', () {
    test('hands out the current token without refreshing', () async {
      await bootstrapWith(_session());

      final headers = await controller.windowAuthHeaders();

      expect(headers, {'Authorization': 'Bearer access-1'});
      expect(dashboard.rotations, 0);
    });

    test(
      'refreshes once for windows that report the current token rejected',
      () async {
        await bootstrapWith(_session());
        dashboard.refreshDelay = const Duration(milliseconds: 50);
        const rejected = {'Authorization': 'Bearer access-1'};

        final answers = await Future.wait([
          controller.windowAuthHeaders(rejected: rejected),
          controller.windowAuthHeaders(rejected: rejected),
        ]);

        expect(dashboard.rotations, 1);
        expect(answers, everyElement({'Authorization': 'Bearer access-2'}));
        expect(store.session?.refreshToken, 'refresh-2');
      },
    );

    test('a rejected token that was already rotated away is not refreshed '
        'again', () async {
      await bootstrapWith(_session());

      final headers = await controller.windowAuthHeaders(
        rejected: {'Authorization': 'Bearer access-0'},
      );

      expect(headers, {'Authorization': 'Bearer access-1'});
      expect(dashboard.rotations, 0);
    });

    test(
      'a refresh the server rejects signs out and hands out nothing',
      () async {
        await bootstrapWith(_session(refresh: 'spent'));

        final headers = await controller.windowAuthHeaders(
          rejected: {'Authorization': 'Bearer access-1'},
        );

        expect(headers, isEmpty);
        expect(controller.state, HermesConnectionState.needsLogin);
      },
    );
  });
}

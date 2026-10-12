import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/native_login_flow.dart';
import 'package:hermes_app/src/models/auth_provider_info.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String userId = 'u1';
  String organization = '';
  String identityProvider = 'oidc';
  bool gated = true;
  Completer<void>? statusGate;
  Completer<void>? statusStarted;
  Completer<void>? pageGate;
  Completer<void>? pageStarted;
  int authRequests = 0;
  final authResponseGates = <Future<void>>[];
  final forcedAuthStatuses = <int>[];
  Completer<void>? refreshGate;
  Completer<void>? refreshStarted;
  int rotations = 0;

  /// Every call to the refresh route, rotated or not.
  int refreshCalls = 0;

  /// Status the refresh route answers with instead of rotating, if set.
  int? refreshFailure;

  /// Whether the refresh route leaves `expires_at` out of its answer.
  bool omitExpiresAt = false;

  /// Whether the refresh route leaves `user_id` and `provider` out.
  bool omitIdentity = false;

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
      case '/':
        if (!(pageStarted?.isCompleted ?? true)) pageStarted!.complete();
        if (pageGate != null) await pageGate!.future;
        request.response.write(
          'window.__HERMES_SESSION_TOKEN__ = "test-token";',
        );
        await request.response.close();
        return;
      case '/api/status':
        if (!(statusStarted?.isCompleted ?? true)) statusStarted!.complete();
        if (statusGate != null) await statusGate!.future;
        return _json(request, 200, {
          'auth_required': gated,
          'auth_flows': ['native_pkce'],
        });
      case '/api/auth/providers':
        return _json(request, 200, {'providers': []});
      case '/auth/native/refresh':
        refreshCalls++;
        if (!(refreshStarted?.isCompleted ?? true)) refreshStarted!.complete();
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        final gate = refreshGate;
        if (gate != null) await gate.future;
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
          if (!omitIdentity) 'provider': 'oidc',
          if (!omitIdentity) 'user_id': 'u1',
        });
      default:
        return _authed(request);
    }
  }

  Future<void> _authed(HttpRequest request) async {
    authRequests++;
    final bearer = request.headers.value('Authorization');
    final user = userId;
    final org = organization;
    final provider = identityProvider;
    final authorized = forcedAuthStatuses.isEmpty
        ? !gated || bearer == 'Bearer $validAccess'
        : forcedAuthStatuses.removeAt(0) == 200;
    if (authResponseGates.isNotEmpty) await authResponseGates.removeAt(0);
    if (!authorized) {
      if (unauthorizedDelays.isNotEmpty) {
        await Future<void>.delayed(unauthorizedDelays.removeAt(0));
      }
      _json(request, 401, {'detail': 'Unauthorized'});
      return;
    }
    _json(request, 200, {
      'user_id': user,
      'org_id': org,
      'provider': provider,
      'ok': true,
    });
  }

  void _json(HttpRequest request, int status, Object body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}

/// A store whose [write] lands only after [delay], like a keychain another
/// isolate is still writing to.
class _SlowWriteTokenStore extends MemoryTokenStore {
  _SlowWriteTokenStore(super.session);

  Duration delay = const Duration(milliseconds: 40);

  @override
  Future<void> write(HermesSession next) async {
    await Future<void>.delayed(delay);
    session = next;
  }
}

/// A store whose [clear] empties it at once but reports back only after
/// [releaseClear], like a keychain that is slow to answer.
class _SlowClearTokenStore extends MemoryTokenStore {
  _SlowClearTokenStore(super.session);

  final _released = Completer<void>();
  final clearStarted = Completer<void>();

  void releaseClear() => _released.complete();

  @override
  Future<void> clear() async {
    session = null;
    if (!clearStarted.isCompleted) clearStarted.complete();
    await _released.future;
  }
}

class _FailingForgetPreferences extends SharedPreferencesAsync {
  @override
  Future<void> remove(String key) async =>
      throw StateError('test preference deletion failed');
}

class _FailingClearTokenStore extends MemoryTokenStore {
  _FailingClearTokenStore(super.session);
  @override
  Future<void> clear() async => throw StateError('test deletion failed');
}

class _DeferredDeleteTokenStore extends MemoryTokenStore {
  _DeferredDeleteTokenStore(super.session);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> clear() async {
    if (!started.isCompleted) started.complete();
    await release.future;
    session = null;
  }
}

final _farFuture =
    DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

HermesSession _session({
  String access = 'access-1',
  String? refresh,
  int? expiresAt,
  bool unknownExpiry = false,
  String userId = 'u1',
  String? serverUrl,
  int? mintedAt,
}) => HermesSession(
  accessToken: access,
  refreshToken: refresh ?? 'refresh-1',
  expiresAt: unknownExpiry ? null : expiresAt ?? _farFuture,
  provider: 'oidc',
  userId: userId,
  serverUrl: serverUrl,
  mintedAt: mintedAt,
);

void main() {
  late _GatedDashboard dashboard;
  late MemoryTokenStore store;
  late AuthController controller;
  late RecordedEvents events;
  late List<String> requestedPaths;

  Future<void> bootstrapWith(
    HermesSession session, {
    bool nativeSignIn = false,
  }) async {
    store = MemoryTokenStore(session);
    controller = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      login: nativeSignIn
          ? (url, {provider, httpClient, cancelled}) async => _session(
              access: dashboard.validAccess,
              refresh: dashboard.validRefresh,
              userId: dashboard.userId,
            )
          : runNativeLogin,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPaths.add(options.path);
            handler.next(options);
          },
        ),
      ],
      telemetry: events.connection,
      rejectionRecheck: const Duration(milliseconds: 20),
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

  test('requests rejected together all adopt the stored pair', () async {
    await bootstrapWith(_session());
    final other = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
    );
    addTearDown(other.dispose);
    await other.bootstrap();
    dashboard.validAccess = 'expired';
    await controller.api!.fetchMe();

    await Future.wait([other.api!.fetchMe(), other.api!.fetchMe()]);

    expect(other.state, HermesConnectionState.ready);
    expect(store.session?.refreshToken, 'refresh-2');
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('takes a newer pair from the store instead of refreshing', () async {
    await bootstrapWith(_session());
    store.session = _session(
      access: 'access-2',
      refresh: 'refresh-2',
      serverUrl: dashboard.url,
      mintedAt: DateTime.now().millisecondsSinceEpoch,
    );
    dashboard
      ..validAccess = 'access-2'
      ..validRefresh = 'refresh-2';

    await controller.api!.fetchMe();

    expect(dashboard.refreshCalls, 0);
    expect(controller.state, HermesConnectionState.ready);
  });

  test('a proactive refresh never sends a refresh token another isolate '
      'spent', () async {
    // Fresh at start, however slow it is, and due for a refresh after.
    final soon =
        DateTime.now()
            .add(const Duration(seconds: 63))
            .millisecondsSinceEpoch ~/
        1000;
    await bootstrapWith(_session(expiresAt: soon));
    final due = DateTime.fromMillisecondsSinceEpoch((soon - 60) * 1000);
    await Future<void>.delayed(
      due.difference(DateTime.now()) + const Duration(milliseconds: 200),
    );
    store.session = _session(
      access: 'access-2',
      refresh: 'refresh-2',
      serverUrl: dashboard.url,
      mintedAt: DateTime.now().millisecondsSinceEpoch,
    );
    dashboard
      ..validAccess = 'access-2'
      ..validRefresh = 'refresh-2';

    await controller.api!.fetchMe();

    expect(dashboard.refreshCalls, 0);
    expect(store.session?.refreshToken, 'refresh-2');
  });

  test('refreshes at the same moment as another isolate without signing '
      'out', () async {
    final slow = _SlowWriteTokenStore(_session());
    AuthController controllerOn() => AuthController(
      tokenStore: slow,
      devServerUrl: dashboard.url,
      telemetry: events.connection,
      rejectionRecheck: const Duration(milliseconds: 150),
    );
    final first = controllerOn();
    final second = controllerOn();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.bootstrap();
    await second.bootstrap();
    dashboard.validAccess = 'expired';

    await Future.wait([first.api!.fetchMe(), second.api!.fetchMe()]);

    expect(first.state, HermesConnectionState.ready);
    expect(second.state, HermesConnectionState.ready);
    expect(dashboard.rotations, 1);
    expect(events.named('auth.session.expired'), isEmpty);
  });

  for (final (whose, foreign) in <(String, HermesSession Function(String))>[
    (
      "another server's",
      (_) => _session(
        refresh: 'refresh-9',
        serverUrl: 'http://elsewhere:9119',
        mintedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ),
    (
      "another user's",
      (url) => _session(
        refresh: 'refresh-9',
        userId: 'u2',
        serverUrl: url,
        mintedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ),
  ]) {
    test('never takes over $whose pair', () async {
      await bootstrapWith(_session());
      store.session = foreign(dashboard.url);
      dashboard
        ..validAccess = 'expired'
        ..validRefresh = 'refresh-9';

      await expectLater(
        controller.api!.fetchMe(),
        throwsA(isA<DioException>()),
      );

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(dashboard.refreshCalls, 1);
    });
  }

  test('a refresh whose answer could not be stored keeps the user signed in '
      'through the next one', () async {
    await bootstrapWith(_session());
    store.failWrites = true;
    dashboard.validAccess = 'expired';
    await controller.api!.fetchMe();
    // The store still holds the spent pair the failed write left behind.
    expect(store.session?.refreshToken, 'refresh-1');

    store.failWrites = false;
    dashboard.validAccess = 'expired-again';
    await controller.api!.fetchMe();

    expect(controller.state, HermesConnectionState.ready);
    expect(store.session?.refreshToken, 'refresh-3');
    expect(events.named('auth.session.expired'), isEmpty);
  });

  test('a session stored before the server was recorded still works after '
      'the upgrade, and is recorded on its next refresh', () async {
    await bootstrapWith(_session());
    expect(store.session?.serverUrl, isNull);

    dashboard.validAccess = 'expired';
    await controller.api!.fetchMe();

    expect(controller.state, HermesConnectionState.ready);
    expect(store.session?.serverUrl, controller.baseUrl);
    expect(store.session?.mintedAt, isNotNull);
  });

  test('a refresh answer without the user keeps the one it replaced', () async {
    await bootstrapWith(_session());
    dashboard
      ..omitIdentity = true
      ..validAccess = 'expired';

    await controller.api!.fetchMe();

    expect(store.session?.userId, 'u1');
    expect(store.session?.provider, 'oidc');
  });

  test('a changed redirect does not ask for a new sign-in', () async {
    // The user saved this address; it now redirects to the dashboard.
    final front = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => front.close(force: true));
    front.listen((request) {
      request.response
        ..statusCode = HttpStatus.movedPermanently
        ..headers.set('Location', '${dashboard.url}${request.uri.path}')
        ..close();
    });
    final saved = 'http://127.0.0.1:${front.port}';
    store = MemoryTokenStore(_session(serverUrl: saved));
    controller = AuthController(
      tokenStore: store,
      devServerUrl: saved,
      telemetry: events.connection,
    );

    await controller.bootstrap();

    expect(controller.state, HermesConnectionState.ready);
    expect(controller.baseUrl, dashboard.url);
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

  group('protected client boundaries', () {
    final cancelled = throwsA(
      isA<DioException>().having(
        (error) => error.type,
        'type',
        DioExceptionType.cancel,
      ),
    );
    const provider = AuthProviderInfo(
      name: 'oidc',
      displayName: 'SSO',
      supportsPassword: false,
    );

    test(
      'anonymous clients retire when the same server enables auth',
      () async {
        dashboard.gated = false;
        await bootstrapWith(_session(), nativeSignIn: true);
        final old = controller.api!;
        dashboard.gated = true;
        await controller.connect(dashboard.url, remember: false);
        await controller.signInWithProvider(provider);
        final before = dashboard.authRequests;
        await expectLater(old.fetchMe(), cancelled);
        expect(dashboard.authRequests, before);
        expect((await controller.api!.fetchMe()).userId, 'u1');
      },
    );

    test(
      'departure during page token lookup prevents protected dispatch',
      () async {
        dashboard
          ..gated = false
          ..pageGate = Completer<void>()
          ..pageStarted = Completer<void>();
        await bootstrapWith(_session());
        final old = controller.api!;
        final pending = expectLater(old.fetchMe(), cancelled);
        await dashboard.pageStarted!.future;
        await controller.changeServer();
        dashboard.pageGate!.complete();
        await pending;
        expect(dashboard.authRequests, 0);
      },
    );

    test(
      'late browser cancellation cannot replace the server picker',
      () async {
        final result = Completer<HermesSession>();
        controller = AuthController(
          tokenStore: MemoryTokenStore(null),
          devServerUrl: dashboard.url,
          login: (url, {provider, httpClient, cancelled}) => result.future,
        );
        await controller.bootstrap();
        final login = controller.signInWithProvider(provider);
        await Future<void>.delayed(Duration.zero);
        await controller.changeServer();
        result.completeError(const NativeLoginCancelled());
        await login;
        expect(controller.state, HermesConnectionState.needsServerUrl);
      },
    );

    test('sign-out invalidates a connect waiting for server status', () async {
      final deferred = _DeferredDeleteTokenStore(_session());
      controller = AuthController(
        tokenStore: deferred,
        devServerUrl: dashboard.url,
      );
      await controller.bootstrap();
      dashboard
        ..statusGate = Completer<void>()
        ..statusStarted = Completer<void>();
      final connecting = controller.connect(dashboard.url, remember: false);
      await dashboard.statusStarted!.future;
      final leaving = controller.signOut();
      await deferred.started.future;
      final before = dashboard.authRequests;
      try {
        dashboard.statusGate!.complete();
        await connecting;
        expect(controller.protectedRequestsAllowed, isFalse);
        expect(dashboard.authRequests, before);
      } finally {
        deferred.release.complete();
        await leaving;
      }
      expect(controller.state, HermesConnectionState.needsLogin);
    });

    test('expiry remains recoverable when credential deletion fails', () async {
      final failing = _FailingClearTokenStore(_session(refresh: ''));
      controller = AuthController(
        tokenStore: failing,
        devServerUrl: dashboard.url,
        login: (url, {provider, httpClient, cancelled}) async => _session(),
      );
      await controller.bootstrap();
      var cleanupNotifications = 0;
      final subscription = controller.signedOut.listen(
        (_) => cleanupNotifications++,
      );
      addTearDown(subscription.cancel);
      final old = controller.api!;
      dashboard.validAccess = 'revoked';
      await expectLater(
        old.fetchMe().timeout(const Duration(seconds: 1)),
        throwsA(isA<DioException>()),
      );
      expect(controller.protectedRequestsAllowed, isFalse);
      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, contains('could not remove'));
      expect(cleanupNotifications, 1);
      final before = dashboard.authRequests;
      await expectLater(old.fetchMe(), cancelled);
      expect(dashboard.authRequests, before);
      dashboard.validAccess = 'access-1';
      await controller.signInWithProvider(provider);
      expect(controller.state, HermesConnectionState.ready);
      expect(failing.session?.accessToken, 'access-1');
    });

    for (final removeServer in [false, true]) {
      test(
        'departure recovers after deletion failure (remove server: $removeServer)',
        () async {
          controller = AuthController(
            tokenStore: _FailingClearTokenStore(_session()),
            devServerUrl: dashboard.url,
          );
          await controller.bootstrap();
          final old = controller.api!;
          var cleanupNotifications = 0;
          final subscription = controller.signedOut.listen(
            (_) => cleanupNotifications++,
          );
          addTearDown(subscription.cancel);
          if (removeServer) {
            await controller.changeServer();
          } else {
            await controller.signOut();
          }
          expect(
            controller.state,
            removeServer
                ? HermesConnectionState.needsServerUrl
                : HermesConnectionState.needsLogin,
          );
          expect(controller.errorMessage, contains('could not remove'));
          expect(cleanupNotifications, 1);
          final before = dashboard.authRequests;
          await expectLater(old.fetchMe(), cancelled);
          expect(dashboard.authRequests, before);
          await controller.connect(dashboard.url, remember: false);
          expect(controller.state, HermesConnectionState.needsLogin);
          expect(dashboard.authRequests, before);
        },
      );
    }

    test('failed preference deletion still leaves the old server', () async {
      controller = AuthController(
        tokenStore: MemoryTokenStore(_session()),
        prefs: _FailingForgetPreferences(),
        devServerUrl: dashboard.url,
      );
      await controller.bootstrap();
      final old = controller.api!;
      var cleanups = 0;
      final subscription = controller.signedOut.listen((_) => cleanups++);
      addTearDown(subscription.cancel);
      await controller.changeServer();
      expect(controller.state, HermesConnectionState.needsServerUrl);
      expect(controller.baseUrl, isNull);
      expect(controller.api, isNull);
      expect(controller.errorMessage, contains('could not forget'));
      expect(cleanups, 1);
      final before = dashboard.authRequests;
      await expectLater(old.fetchMe(), cancelled);
      expect(dashboard.authRequests, before);
    });

    test('old requests stay local while sign-out cleanup is pending', () async {
      final slow = _SlowClearTokenStore(_session());
      controller = AuthController(
        tokenStore: slow,
        devServerUrl: dashboard.url,
      );
      await controller.bootstrap();
      final old = controller.api!;
      final before = dashboard.authRequests;
      final leaving = controller.signOut();
      try {
        await expectLater(old.fetchMe(), cancelled);
        expect(dashboard.authRequests, before);
      } finally {
        slow.releaseClear();
        await leaving;
      }
    });

    test('sign-in waits for expired-session cleanup to finish', () async {
      final slow = _SlowClearTokenStore(_session());
      var loginStarted = false;
      controller = AuthController(
        tokenStore: slow,
        devServerUrl: dashboard.url,
        rejectionRecheck: const Duration(milliseconds: 20),
        login: (url, {provider, httpClient, cancelled}) async {
          loginStarted = true;
          return _session(access: 'fresh-access');
        },
      );
      await controller.bootstrap();
      dashboard
        ..validAccess = 'revoked'
        ..refreshFailure = 401;
      final expired = expectLater(
        controller.api!.fetchMe(),
        throwsA(isA<DioException>()),
      );
      await slow.clearStarted.future;
      dashboard.validAccess = 'fresh-access';
      final login = controller.signInWithProvider(provider);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(loginStarted, isFalse);
      } finally {
        slow.releaseClear();
        await expired;
        await login;
      }
      expect(controller.state, HermesConnectionState.ready);
      expect(slow.session?.accessToken, 'fresh-access');
    });

    test(
      'an old client cannot use another server even with identical tokens',
      () async {
        await bootstrapWith(_session());
        final old = controller.api!;
        final before = dashboard.authRequests;
        final other = await _GatedDashboard.start();
        addTearDown(other.close);
        await controller.changeServer();
        store.session = _session(serverUrl: other.url);
        await controller.connect(other.url, remember: false);
        expect(controller.state, HermesConnectionState.ready);
        await expectLater(old.fetchMe(), cancelled);
        expect(dashboard.authRequests, before);
        expect(controller.state, HermesConnectionState.ready);
      },
    );

    Future<void> expireAndSignIn(String user) async {
      dashboard
        ..validAccess = 'revoked'
        ..refreshFailure = 401;
      await expectLater(
        controller.api!.fetchMe(),
        throwsA(isA<DioException>()),
      );
      expect(controller.state, HermesConnectionState.needsLogin);
      dashboard
        ..validAccess = 'fresh-access'
        ..validRefresh = 'fresh-refresh'
        ..refreshFailure = null
        ..userId = user;
      await controller.signInWithProvider(provider);
      expect(controller.state, HermesConnectionState.ready);
    }

    for (final scope in ['organization', 'provider', 'missing user']) {
      test('retained clients reject changed $scope proof', () async {
        await bootstrapWith(_session(), nativeSignIn: true);
        final old = controller.api!;
        final owner = controller.verifiedOwner;
        if (scope == 'organization') dashboard.organization = 'another-org';
        if (scope == 'provider') {
          dashboard.identityProvider = 'another-provider';
        }
        await expireAndSignIn(scope == 'missing user' ? ' ' : 'u1');
        expect(controller.expiredOwner, owner);
        expect(controller.verifiedOwner, isNot(owner));
        if (scope == 'missing user') expect(controller.verifiedOwner, isNull);
        final before = dashboard.authRequests;
        await expectLater(old.fetchMe(), cancelled);
        expect(dashboard.authRequests, before);
        expect(events.named('auth.client.retired'), [
          {'reason': 'owner_changed'},
        ]);
      });
    }

    test('departure telemetry contains only a fixed reason', () async {
      await bootstrapWith(_session());
      await controller.signOut();
      expect(events.named('auth.client.retired'), [
        {'reason': 'sign_out'},
      ]);
    });

    Future<void> waitForAuth(int count) async {
      while (dashboard.authRequests < count) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    test(
      'a pre-expiry response stays cancelled after same-owner sign-in',
      () async {
        await bootstrapWith(_session(), nativeSignIn: true);
        final old = controller.api!;
        final held = Completer<void>();
        dashboard.authResponseGates.add(held.future);
        final before = dashboard.authRequests;
        final pending = expectLater(old.fetchMe(), cancelled);
        await waitForAuth(before + 1).timeout(const Duration(seconds: 5));
        await expireAndSignIn('u1');
        held.complete();
        await pending;
        expect((await old.fetchMe()).userId, 'u1');
      },
    );

    test('a delayed retried 401 cannot expire the new account', () async {
      await bootstrapWith(_session(), nativeSignIn: true);
      final old = controller.api!;
      final held = Completer<void>();
      dashboard.authResponseGates.addAll([Future.value(), held.future]);
      dashboard.forcedAuthStatuses.addAll([401, 401]);
      final before = dashboard.authRequests;
      final pending = expectLater(old.fetchMe(), cancelled);
      await waitForAuth(before + 2).timeout(const Duration(seconds: 5));
      await expireAndSignIn('u2');
      held.complete();
      await pending;
      expect(controller.state, HermesConnectionState.ready);
      expect(controller.identity!.userId, 'u2');
    });

    test(
      'a proactive refresh finishing after departure cannot dispatch',
      () async {
        final started = dashboard.refreshStarted = Completer<void>();
        final release = dashboard.refreshGate = Completer<void>();
        final boot = bootstrapWith(_session(expiresAt: 1));
        await started.future;
        await controller.signOut();
        release.complete();
        await boot;
        expect(dashboard.authRequests, 0);
        expect(store.session, isNull);
        expect(controller.state, HermesConnectionState.needsLogin);
      },
    );

    test(
      'a retained client resumes only for the same verified owner',
      () async {
        await bootstrapWith(_session(), nativeSignIn: true);
        final old = controller.api!;
        await expireAndSignIn('u1');
        expect((await old.fetchMe()).userId, 'u1');
      },
    );

    test(
      'a retained client cannot attach a different account credential',
      () async {
        await bootstrapWith(_session(), nativeSignIn: true);
        final old = controller.api!;
        await expireAndSignIn('u2');
        final before = dashboard.authRequests;
        await expectLater(old.fetchMe(), cancelled);
        expect(dashboard.authRequests, before);
        expect(controller.identity!.userId, 'u2');
      },
    );
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

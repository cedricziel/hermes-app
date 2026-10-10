import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/memory_token_store.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';

HermesSession _session({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int? expiresAt = 4102444800,
  int mintedAt = 1000,
  String? serverUrl = _url,
}) => HermesSession(
  accessToken: access,
  refreshToken: refresh,
  expiresAt: expiresAt,
  provider: 'basic',
  userId: 'u1',
  serverUrl: serverUrl,
  mintedAt: mintedAt,
);

/// A store whose reads can be intercepted, to change what it holds the way
/// the app does between two reads of the background run.
class _Store extends MemoryTokenStore {
  _Store([super.session]);

  int reads = 0;
  void Function(int read)? beforeRead;
  int writes = 0;

  @override
  Future<SessionRead> readState({bool repair = true}) {
    beforeRead?.call(reads++);
    return super.readState(repair: repair);
  }

  @override
  Future<void> write(HermesSession next) async {
    writes++;
    await super.write(next);
  }
}

/// A dashboard whose access tokens work until rotated, and whose refresh
/// tokens work once.
class _Dashboard {
  _Dashboard({bool authRequired = true}) {
    server
      ..on('GET', '/api/status', {
        'auth_required': authRequired,
        'version': '0.9.0',
      })
      ..on(
        'GET',
        '/',
        '<script>window.__HERMES_SESSION_TOKEN__="page-token"</script>',
      )
      ..on('POST', '/api/auth/ws-ticket', {'ticket': 'tkt'})
      ..onRequest('GET', '/api/profiles', (request) {
        final header = authRequired
            ? request.headers['Authorization']
            : request.headers['X-Hermes-Session-Token'];
        final expected = authRequired ? 'Bearer $validAccess' : 'page-token';
        if (header != expected) {
          return (status: 401, body: {'detail': 'Unauthorized'});
        }
        return (
          status: 200,
          body: profileListBody([
            profileRow(name: 'default', isDefault: true),
            profileRow(name: 'work'),
          ]),
        );
      })
      ..onRequest('POST', '/auth/native/refresh', (request) async {
        refreshes++;
        await duringRefresh?.call();
        if (refreshFailure case final DioException error) throw error;
        if (refreshStatus case final status?) {
          return (status: status, body: {'detail': 'invalid refresh token'});
        }
        if ((request.data as Map)['refresh_token'] != validRefresh) {
          return (status: 401, body: {'detail': 'spent refresh token'});
        }
        final n = refreshes + 1;
        if (rotateAccess) validAccess = 'access-$n';
        validRefresh = 'refresh-$n';
        return (
          status: 200,
          body: {
            'access_token': 'access-$n',
            'refresh_token': 'refresh-$n',
            'expires_at': 4102444800,
            'provider': 'basic',
            'user_id': 'u1',
          },
        );
      });
  }

  final server = FakeHermesServer();
  String validAccess = 'access-1';
  String validRefresh = 'refresh-1';
  int refreshes = 0;
  int? refreshStatus;
  DioException? refreshFailure;
  bool rotateAccess = true;
  Future<void> Function()? duringRefresh;
}

void main() {
  late _Dashboard dashboard;
  late _Store store;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late FakeGateway gateway;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    dashboard = _Dashboard();
    store = _Store(_session());
    events = RecordedEvents();
    tracer = RecordingTracer();
    gateway = FakeGateway();
  });

  HeadlessDeps deps({String devServerUrl = ''}) => HeadlessDeps(
    tokenStore: store,
    prefs: SharedPreferencesAsync(),
    devServerUrl: devServerUrl,
    adapter: dashboard.server,
    openSocket: (_) => gateway.connect(),
    telemetry: (attributes) => ConnectionTelemetry(
      events: events.connection(attributes).events,
      tracer: tracer,
      serverAttributes: attributes,
    ),
  );

  Future<HeadlessOutcome<T>> run<T>(
    Future<T> Function(HeadlessHermes hermes) body, {
    Duration timeout = const Duration(seconds: 5),
    String task = 'test_task',
  }) => withHeadlessHermes(body, task: task, timeout: timeout, deps: deps());

  Future<List<String?>> readProfiles(HeadlessHermes hermes) =>
      hermes.profiles();

  RecordingSpan taskSpan() =>
      tracer.spans.singleWhere((span) => span.name == 'background.task');

  String spanOutcome() => taskSpan().attributes['outcome']! as String;

  group('which session it uses', () {
    test('reaches the server with the stored session', () async {
      final outcome = await run(readProfiles);

      expect((outcome as HeadlessDone).value, ['default', 'work']);
      expect(
        dashboard.server.requestsTo('GET', '/api/profiles').single.headers,
        containsPair('Authorization', 'Bearer access-1'),
      );
      expect(spanOutcome(), 'ok');
    });

    test('is signed out when no server is saved', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      expect(await run(readProfiles), isA<HeadlessSignedOut<List<String?>>>());
      expect(dashboard.server.requests, isEmpty);
      expect(spanOutcome(), 'no_server');
    });

    test('uses the server given at build time over the saved one', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      final outcome = await withHeadlessHermes(
        readProfiles,
        task: 'dev',
        deps: deps(devServerUrl: _url),
      );

      expect(outcome, isA<HeadlessDone<List<String?>>>());
    });

    test('is signed out when no session is stored', () async {
      store.session = null;

      expect(await run(readProfiles), isA<HeadlessSignedOut<List<String?>>>());
      expect(dashboard.server.requestsTo('GET', '/api/profiles'), isEmpty);
      expect(spanOutcome(), 'no_session');
    });

    test('is signed out when another dashboard minted the session', () async {
      store.session = _session(serverUrl: 'http://other.test');

      expect(await run(readProfiles), isA<HeadlessSignedOut<List<String?>>>());
      expect(dashboard.server.requestsTo('GET', '/api/profiles'), isEmpty);
    });

    test(
      'is locked, without a request, while the keychain is unreadable',
      () async {
        store.unreadable = true;
        final before = store.session;

        expect(await run(readProfiles), isA<HeadlessLocked<List<String?>>>());
        expect(dashboard.server.requests, isEmpty);
        expect(store.session, same(before));
        expect(spanOutcome(), 'locked');
      },
    );

    test('is unreachable when the server does not answer its status', () async {
      dashboard.server.on('GET', '/api/status', {}, status: 503);

      expect(
        await run(readProfiles),
        isA<HeadlessUnreachable<List<String?>>>(),
      );
      expect(store.session, isNotNull);
      expect(spanOutcome(), 'unreachable');
    });

    test('needs no session when the server needs no sign-in', () async {
      dashboard = _Dashboard(authRequired: false);
      store.session = null;

      final outcome = await run(readProfiles);

      expect((outcome as HeadlessDone).value, ['default', 'work']);
    });
  });

  group('the same data as the app', () {
    test('falls back to the default profile when the list fails', () async {
      dashboard.server.on('GET', '/api/profiles', {}, status: 500);

      final outcome = await run(readProfiles);

      expect((outcome as HeadlessDone).value, [null]);
    });

    test('skips profile rows the app skips', () async {
      dashboard.server.on('GET', '/api/profiles', {
        'profiles': [
          {'name': 'default'},
          {'name': 7},
          'junk',
        ],
      });

      final outcome = await run(readProfiles);

      expect((outcome as HeadlessDone).value, ['default']);
    });

    test('gives the repositories the app builds', () async {
      final outcome = await run((hermes) async {
        return (await hermes.repositories.profiles.list()).length;
      });

      expect((outcome as HeadlessDone).value, 2);
    });
  });

  group('the time budget and failures', () {
    test('a failing body is unreachable and not rethrown', () async {
      final outcome = await run<int>((_) async => throw StateError('boom'));

      expect(outcome, isA<HeadlessUnreachable<int>>());
      expect(spanOutcome(), 'failed');
      expect(taskSpan().attributes['error.type'], 'StateError');
    });

    test('a slow body is unreachable and its socket is closed', () async {
      gateway.deaf = true;
      final stuck = Completer<void>();
      addTearDown(() {
        if (!stuck.isCompleted) stuck.complete();
      });

      final outcome = await run<void>((hermes) async {
        unawaited(
          hermes
              .transport()
              .request('session.list')
              .catchError((_) => <String, Object?>{}),
        );
        await stuck.future;
      }, timeout: const Duration(milliseconds: 300));

      expect(outcome, isA<HeadlessUnreachable<void>>());
      await gateway.closedByClient.timeout(const Duration(seconds: 2));
      expect(spanOutcome(), 'timeout');
    });

    test('closes the sockets it opened when the body ends', () async {
      gateway.activeSessions = {};

      final outcome = await run((hermes) async {
        await hermes.transport().request('session.active_list');
        return 'done';
      });

      expect((outcome as HeadlessDone).value, 'done');
      await gateway.closedByClient.timeout(const Duration(seconds: 2));
    });
  });

  group('tokens', () {
    test(
      'refreshes an expired access token and writes the pair back',
      () async {
        store.session = _session(expiresAt: 1);

        final outcome = await run(readProfiles);

        expect(outcome, isA<HeadlessDone<List<String?>>>());
        expect(dashboard.refreshes, 1);
        final stored = store.session!;
        expect(stored.accessToken, 'access-2');
        expect(stored.refreshToken, 'refresh-2');
        expect(stored.serverUrl, _url);
        expect(stored.mintedAt, greaterThan(1000));
        expect(
          dashboard.server.requestsTo('GET', '/api/profiles').single.headers,
          containsPair('Authorization', 'Bearer access-2'),
        );
      },
    );

    test('refreshes after a 401 and retries the request once', () async {
      dashboard.validAccess = 'access-9';

      final outcome = await run(readProfiles);

      expect((outcome as HeadlessDone).value, ['default', 'work']);
      expect(dashboard.refreshes, 1);
      expect(dashboard.server.requestsTo('GET', '/api/profiles'), hasLength(2));
    });

    test(
      'adopts a pair rotated in storage meanwhile instead of refreshing',
      () async {
        store.session = _session(expiresAt: 1);
        final rotated = _session(
          access: 'access-7',
          refresh: 'refresh-7',
          mintedAt: 5000,
        );
        dashboard.validAccess = 'access-7';
        store.beforeRead = (read) {
          if (read == 1) store.session = rotated;
        };

        final outcome = await run(readProfiles);

        expect(outcome, isA<HeadlessDone<List<String?>>>());
        expect(dashboard.refreshes, 0);
        expect(store.session, same(rotated));
        expect(store.writes, 0);
      },
    );

    test('does not adopt an older pair', () async {
      store.session = _session(expiresAt: 1, mintedAt: 5000);
      store.beforeRead = (read) {
        if (read == 1) store.session = _session(refresh: 'old', mintedAt: 10);
      };

      await run(readProfiles);

      expect(dashboard.refreshes, 1);
    });

    test(
      'leaves storage alone when the app changed it during the refresh',
      () async {
        store.session = _session(expiresAt: 1);
        final fromApp = _session(
          access: 'app-access',
          refresh: 'app-refresh',
          mintedAt: DateTime.now().millisecondsSinceEpoch + 60000,
        );
        dashboard.duringRefresh = () async => store.session = fromApp;

        final outcome = await run(readProfiles);

        expect(outcome, isA<HeadlessDone<List<String?>>>());
        expect(store.session, same(fromApp));
        expect(store.writes, 0);
      },
    );

    test(
      'does not bring back a session the user signed out of meanwhile',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard.duringRefresh = () async => store.session = null;

        await run(readProfiles);

        expect(store.session, isNull);
      },
    );

    test(
      'a rejected refresh is signed out and leaves storage as it was',
      () async {
        store.session = _session(expiresAt: 1);
        final before = store.session;
        dashboard.refreshStatus = 401;

        final outcome = await run(readProfiles);

        expect(outcome, isA<HeadlessSignedOut<List<String?>>>());
        expect(store.session, same(before));
        expect(dashboard.refreshes, 1);
        expect(spanOutcome(), 'auth_failed');
        expect(events.named('background.refresh_conflict'), isEmpty);
      },
    );

    test(
      'a rejected refresh after the app rotated the pair is a conflict',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard.refreshStatus = 401;
        final fromApp = _session(refresh: 'app-refresh', mintedAt: 9000);
        dashboard.duringRefresh = () async => store.session = fromApp;

        final outcome = await run(readProfiles);

        expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
        expect(store.session, same(fromApp));
        expect(events.named('background.refresh_conflict'), [isEmpty]);
        expect(spanOutcome(), 'auth_failed');
      },
    );

    test('a network error during the refresh is unreachable', () async {
      store.session = _session(expiresAt: 1);
      final before = store.session;
      dashboard.refreshFailure = DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      );

      final outcome = await run(readProfiles);

      expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
      expect(store.session, same(before));
      expect(spanOutcome(), 'auth_failed');
    });

    test('refreshes at most once per run', () async {
      dashboard
        ..validAccess = 'never-matches'
        ..rotateAccess = false;
      store.session = _session(expiresAt: 1);

      await run((hermes) async {
        for (var i = 0; i < 3; i++) {
          try {
            await hermes.repositories.profiles.list();
          } on Object {
            // The server keeps refusing; only the refresh count matters.
          }
        }
      });

      expect(dashboard.refreshes, 1);
    });

    test('concurrent requests share one refresh', () async {
      store.session = _session(expiresAt: 1);

      await run((hermes) async {
        await Future.wait([
          hermes.repositories.profiles.list(),
          hermes.repositories.profiles.list(),
          hermes.repositories.profiles.list(),
        ]);
      });

      expect(dashboard.refreshes, 1);
    });

    test('never clears the stored session', () async {
      store.session = _session(expiresAt: 1);
      dashboard.refreshStatus = 403;
      var cleared = false;
      final probe = _ClearTrackingStore(store.session, () => cleared = true);

      await withHeadlessHermes(
        readProfiles,
        task: 'test_task',
        deps: HeadlessDeps(
          tokenStore: probe,
          prefs: SharedPreferencesAsync(),
          devServerUrl: '',
          adapter: dashboard.server,
        ),
      );

      expect(cleared, isFalse);
    });
  });

  group('telemetry', () {
    test(
      'records one background.task span with the server attributes',
      () async {
        await run(readProfiles, task: 'refresh_snapshot');

        final span = taskSpan();
        expect(span.name, 'background.task');
        expect(span.attributes['task'], 'refresh_snapshot');
        expect(span.attributes['outcome'], 'ok');
        expect(span.attributes['hermes.version'], '0.9.0');
        expect(span.ended, isTrue);
        for (final value in span.attributes.values) {
          expect('$value', isNot(contains('access-1')));
          expect('$value', isNot(contains('refresh-1')));
          expect('$value', isNot(contains('hermes.test')));
        }
      },
    );

    test('a tracer that throws does not stop the work', () async {
      tracer = ThrowingTracer();

      final outcome = await run(readProfiles);

      expect(outcome, isA<HeadlessDone<List<String?>>>());
    });
  });
}

class _ClearTrackingStore extends MemoryTokenStore {
  _ClearTrackingStore(super.session, this.onClear);

  final void Function() onClear;

  @override
  Future<void> clear() async {
    onClear();
    await super.clear();
  }
}

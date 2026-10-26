import 'dart:async';

import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
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

  /// How long a write takes, as a busy keychain would.
  Duration writeDelay = Duration.zero;

  /// When the latest write finished.
  DateTime? wroteAt;

  @override
  Future<SessionRead> readState({bool repair = true}) {
    final read = reads++;
    beforeRead?.call(read);
    return super.readState(repair: repair);
  }

  @override
  Future<void> write(HermesSession next) async {
    writes++;
    await Future<void>.delayed(writeDelay);
    await super.write(next);
    wroteAt = DateTime.now();
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
      ..onRequest('GET', '/api/profiles', (request) async {
        final header = authRequired
            ? request.headers['Authorization']
            : request.headers['X-Hermes-Session-Token'];
        final expected = authRequired ? 'Bearer $validAccess' : 'page-token';
        if (header != expected) {
          if (unauthorizedDelays.isNotEmpty) {
            await Future<void>.delayed(unauthorizedDelays.removeAt(0));
          }
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
        await Future<void>.delayed(refreshDelay);
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
            'expires_at': refreshExpiresAt,
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
  Duration refreshDelay = Duration.zero;
  int refreshExpiresAt = 4102444800;

  /// How long the next 401 answers of the profiles route wait, in order.
  final unauthorizedDelays = <Duration>[];
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
    dashboard.server.honourReceiveTimeouts = true;
    store = _Store(_session());
    events = RecordedEvents();
    tracer = RecordingTracer();
    gateway = FakeGateway();
  });

  ConnectionTelemetry recorded(Map<String, Object> attributes) =>
      ConnectionTelemetry(
        events: events.connection(attributes).events,
        tracer: tracer,
        serverAttributes: attributes,
      );

  HeadlessDeps deps({
    String devServerUrl = '',
    ConnectionTelemetryFactory? telemetry,
    Duration minRefreshBudget = Duration.zero,
    Duration rejectionRecheck = Duration.zero,
    Duration closeGrace = const Duration(seconds: 3),
  }) => HeadlessDeps(
    tokenStore: store,
    prefs: SharedPreferencesAsync(),
    devServerUrl: devServerUrl,
    adapter: dashboard.server,
    openSocket: (_) => gateway.connect(),
    telemetry: telemetry ?? recorded,
    minRefreshBudget: minRefreshBudget,
    rejectionRecheck: rejectionRecheck,
    closeGrace: closeGrace,
  );

  Future<HeadlessOutcome<T>> run<T>(
    Future<T> Function(HeadlessHermes hermes) body, {
    Duration timeout = const Duration(seconds: 5),
    String task = 'test_task',
    HeadlessDeps? with_,
  }) => withHeadlessHermes(
    body,
    task: task,
    timeout: timeout,
    deps: with_ ?? deps(),
  );

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

    test('reads the profile names once per run', () async {
      final outcome = await run((hermes) async {
        final first = await hermes.profiles();
        final second = await hermes.profiles();
        return [first, second];
      });

      expect((outcome as HeadlessDone).value, [
        ['default', 'work'],
        ['default', 'work'],
      ]);
      expect(dashboard.server.requestsTo('GET', '/api/profiles'), hasLength(1));
    });

    test('tries the profile names again after a fallback', () async {
      dashboard.server.on('GET', '/api/profiles', {
        'detail': 'down',
      }, status: 500);

      final outcome = await run((hermes) async {
        final first = await hermes.profiles();
        dashboard.server.on(
          'GET',
          '/api/profiles',
          profileListBody([profileRow(name: 'default', isDefault: true)]),
        );
        final second = await hermes.profiles();
        final third = await hermes.profiles();
        return [first, second, third];
      });

      expect((outcome as HeadlessDone).value, [
        [null],
        ['default'],
        ['default'],
      ]);
      expect(dashboard.server.requestsTo('GET', '/api/profiles'), hasLength(2));
    });

    test('rethrows a stopped session without asking again', () async {
      store.session = _session(expiresAt: 1);
      dashboard.refreshStatus = 401;
      var thrown = 0;

      await run((hermes) async {
        for (var i = 0; i < 2; i++) {
          try {
            await hermes.profiles();
          } on Object {
            thrown++;
          }
        }
        return const <String?>[];
      });

      expect(thrown, 2);
      expect(dashboard.refreshes, 1);
    });

    test('is signed out when no server is saved', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      final outcome = await run(readProfiles);

      expect(outcome, isA<HeadlessSignedOut<List<String?>>>());
      final signedOut = outcome as HeadlessSignedOut<List<String?>>;
      expect(signedOut.reason, SignedOutReason.noServer);
      expect(signedOut.nothingStored, isTrue);
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

      final outcome = await run(readProfiles);

      expect(outcome, isA<HeadlessSignedOut<List<String?>>>());
      final signedOut = outcome as HeadlessSignedOut<List<String?>>;
      expect(signedOut.reason, SignedOutReason.noSession);
      expect(signedOut.nothingStored, isTrue);
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
        // The server's refusal is not proof that nobody is signed in.
        final signedOut = outcome as HeadlessSignedOut<List<String?>>;
        expect(signedOut.reason, SignedOutReason.rejected);
        expect(signedOut.nothingStored, isFalse);
        expect(store.session, same(before));
        expect(dashboard.refreshes, 1);
        expect(spanOutcome(), 'auth_failed');
        expect(events.named('background.refresh_conflict'), isEmpty);
      },
    );

    test(
      'a rejected refresh with a different pair in storage is a conflict',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard.refreshStatus = 401;
        final fromApp = _session(refresh: 'app-refresh', mintedAt: 10);
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

  group('ending the run', () {
    test(
      'an in-flight refresh that outlasts the budget still writes its pair',
      () async {
        store.session = _session(expiresAt: 1);
        store.writeDelay = const Duration(milliseconds: 500);

        final outcome = await run(
          readProfiles,
          timeout: const Duration(milliseconds: 300),
        );

        expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
        expect(spanOutcome(), 'timeout');
        expect(store.session!.refreshToken, 'refresh-2');
      },
    );

    test('a refresh slower than half the budget is cut off, twice', () async {
      store.session = _session(expiresAt: 1);
      dashboard.refreshDelay = const Duration(milliseconds: 700);
      final before = store.session;

      final outcome = await run(
        readProfiles,
        timeout: const Duration(seconds: 1),
      );

      expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
      expect(dashboard.refreshes, 2);
      expect(store.writes, 0);
      expect(store.session, same(before));
    });

    test('a body stuck after the session failed is waited for once', () async {
      store.session = _session(expiresAt: 1);
      dashboard.refreshStatus = 401;
      final stuck = Completer<void>();
      addTearDown(() {
        if (!stuck.isCompleted) stuck.complete();
      });
      final watch = Stopwatch()..start();

      final outcome = await run<void>((hermes) async {
        unawaited(
          hermes.repositories.profiles.list().then<void>(
            (_) {},
            onError: (Object _) {},
          ),
        );
        await stuck.future;
      }, with_: deps(closeGrace: const Duration(milliseconds: 500)));

      expect(outcome, isA<HeadlessSignedOut<void>>());
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 900)));
    });

    test(
      'closes the gateway socket while a refresh still stores its pair',
      () async {
        dashboard.validAccess = 'access-9';
        store.writeDelay = const Duration(milliseconds: 700);
        gateway.activeSessions = {};
        DateTime? closedAt;
        unawaited(
          gateway.closedByClient.then((_) => closedAt = DateTime.now()),
        );

        await run<void>((hermes) async {
          await hermes.transport().request('session.active_list');
          await hermes.repositories.profiles.list();
        }, timeout: const Duration(milliseconds: 300));

        await gateway.closedByClient.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(closedAt!.isBefore(store.wroteAt!), isTrue);
      },
    );

    test(
      'a refresh still storing its pair is waited for only so long',
      () async {
        store.session = _session(expiresAt: 1);
        store.writeDelay = const Duration(seconds: 2);
        final stuck = Completer<void>();
        addTearDown(() {
          if (!stuck.isCompleted) stuck.complete();
        });
        final watch = Stopwatch()..start();

        final outcome = await run<void>(
          (hermes) async {
            unawaited(
              hermes.repositories.profiles.list().then<void>(
                (_) {},
                onError: (Object _) {},
              ),
            );
            await stuck.future;
          },
          timeout: const Duration(milliseconds: 300),
          with_: deps(closeGrace: const Duration(milliseconds: 500)),
        );

        expect(outcome, isA<HeadlessUnreachable<void>>());
        expect(watch.elapsed, lessThan(const Duration(milliseconds: 1100)));
      },
    );

    test('does not start a refresh it cannot finish', () async {
      store.session = _session(expiresAt: 1);
      final before = store.session;

      final outcome = await run(
        readProfiles,
        timeout: const Duration(seconds: 1),
        with_: deps(minRefreshBudget: const Duration(seconds: 4)),
      );

      expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
      expect(dashboard.refreshes, 0);
      expect(store.session, same(before));
    });

    test(
      'a body that outlives the budget can no longer refresh or write',
      () async {
        store.session = _session(expiresAt: 1);
        final before = store.session;
        final late = Completer<void>();

        final outcome = await run<void>((hermes) async {
          await late.future;
          await hermes.repositories.profiles.list();
        }, timeout: const Duration(milliseconds: 100));
        late.complete();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(outcome, isA<HeadlessUnreachable<void>>());
        expect(dashboard.refreshes, 0);
        expect(store.writes, 0);
        expect(store.session, same(before));
        expect(dashboard.server.requestsTo('GET', '/api/profiles'), isEmpty);
      },
    );

    test(
      'a body that recovers from a failed refresh keeps its result',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard.refreshStatus = 401;

        final outcome = await run((hermes) async {
          try {
            await hermes.repositories.profiles.list();
          } on Object {
            return 'recovered';
          }
          return 'unexpected';
        });

        expect((outcome as HeadlessDone).value, 'recovered');
      },
    );
  });

  group('storage around a refresh', () {
    test(
      'a rejected refresh adopts a newer pair that lands a moment later',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard
          ..refreshStatus = 401
          ..validAccess = 'access-7';
        final fromApp = _session(
          access: 'access-7',
          refresh: 'refresh-7',
          mintedAt: 9000,
        );
        store.beforeRead = (read) {
          if (read == 3) store.session = fromApp;
        };

        final outcome = await run(
          readProfiles,
          with_: deps(rejectionRecheck: const Duration(milliseconds: 20)),
        );

        expect(outcome, isA<HeadlessDone<List<String?>>>());
        expect(store.session, same(fromApp));
        expect(dashboard.refreshes, 1);
      },
    );

    test(
      'unreadable writeback never overwrites a replacement account',
      () async {
        store.session = _session(expiresAt: 1);
        final replacement = HermesSession.fromStorageJson({
          ..._session().toStorageJson(),
          'userId': 'other',
          'refreshToken': 'other-refresh',
        });
        store.beforeRead = (read) {
          if (read == 2) {
            store.session = replacement;
            store.unreadable = true;
          }
        };
        await run(readProfiles);
        expect(store.session, same(replacement));
        expect(store.writes, 0);
      },
    );

    test(
      'transient write failure retries the same pair without refreshing again',
      () async {
        store.session = _session(expiresAt: 1);
        store.beforeRead = (read) {
          if (read == 2) store.failWrites = true;
          if (read == 3) store.failWrites = false;
        };
        await run(readProfiles);
        expect(store.session?.refreshToken, 'refresh-2');
        expect(store.writes, 2);
        expect(dashboard.refreshes, 1);
      },
    );

    test('a failed write is logged and does not fail the run', () async {
      store.session = _session(expiresAt: 1);
      store.failWrites = true;

      final outcome = await run(readProfiles);

      expect(outcome, isA<HeadlessDone<List<String?>>>());
      expect(events.named('auth.session.store_failed'), [
        {'error.type': 'UnsupportedError'},
      ]);
    });

    test('a read error before the write does not skip it', () async {
      store.session = _session(expiresAt: 1);
      store.beforeRead = (read) {
        if (read == 2) throw StateError('keychain');
      };

      await run(readProfiles);

      expect(store.session!.refreshToken, 'refresh-2');
    });

    test(
      'concurrent 401s refresh once and the late ones reuse the new token',
      () async {
        dashboard
          ..validAccess = 'access-9'
          ..unauthorizedDelays.addAll([
            Duration.zero,
            const Duration(milliseconds: 300),
            const Duration(milliseconds: 300),
          ]);

        final outcome = await run((hermes) async {
          final lists = await Future.wait([
            hermes.repositories.profiles.list(),
            hermes.repositories.profiles.list(),
            hermes.repositories.profiles.list(),
          ]);
          return lists.map((profiles) => profiles.length).toList();
        });

        expect((outcome as HeadlessDone).value, [2, 2, 2]);
        expect(dashboard.refreshes, 1);
      },
    );

    test('a refreshed pair that is already expired is not re-read for every request', () async {
      store.session = _session(expiresAt: 1);
      dashboard.refreshExpiresAt = 1;

      await run((hermes) async {
        for (var i = 0; i < 5; i++) {
          await hermes.repositories.profiles.list();
        }
      });

      expect(store.reads, 3);
    });
  });

  group('a keychain that cannot be read', () {
    test('another read error is unreachable, not locked', () async {
      store.unreadable = true;
      store.unreadableLocked = false;

      expect(
        await run(readProfiles),
        isA<HeadlessUnreachable<List<String?>>>(),
      );
      expect(dashboard.server.requests, isEmpty);
    });
  });

  group('telemetry that breaks', () {
    test(
      'a factory that throws for the connection does not stop the work',
      () async {
        final outcome = await run(
          readProfiles,
          with_: deps(
            telemetry: (attributes) {
              if (attributes.isNotEmpty) throw StateError('telemetry');
              return recorded(attributes);
            },
          ),
        );

        expect(outcome, isA<HeadlessDone<List<String?>>>());
      },
    );

    test('gateway telemetry that throws does not stop a transport', () async {
      gateway.activeSessions = {};

      final outcome = await run((hermes) async {
        await hermes.transport().request('session.active_list');
        return 'done';
      }, with_: deps(telemetry: (_) => const _BrokenGatewayTelemetry()));

      expect((outcome as HeadlessDone).value, 'done');
    });

    test(
      'an events logger that throws does not stop the conflict path',
      () async {
        store.session = _session(expiresAt: 1);
        dashboard.refreshStatus = 401;
        dashboard.duringRefresh = () async =>
            store.session = _session(refresh: 'app-refresh', mintedAt: 10);

        final outcome = await run(
          readProfiles,
          with_: deps(
            telemetry: (_) => ConnectionTelemetry(
              events: (name, [attributes = const {}]) =>
                  throw StateError('logger'),
            ),
          ),
        );

        expect(outcome, isA<HeadlessUnreachable<List<String?>>>());
      },
    );
  });

  group('telemetry', () {
    test('the body can add counts to the span', () async {
      await run((hermes) async {
        hermes
          ..annotate('requests.new', 2)
          ..annotate('steps_failed', 0);
      });

      expect(taskSpan().attributes['requests.new'], 2);
      expect(taskSpan().attributes['steps_failed'], 0);
    });

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

class _BrokenGatewayTelemetry extends ConnectionTelemetry {
  const _BrokenGatewayTelemetry();

  @override
  MessagingConnectionTracer? gateway() => throw StateError('tracer');
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/background/background_refresh.dart';
import 'package:hermes_app/src/background/entry_points.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/fake_surface_storage.dart';
import '../support/memory_token_store.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';
const _command = 'rm -rf /srv/secret-project';

Map<String, Object?> _session(
  String key, {
  String title = 'Trip plan',
  String status = 'waiting',
  String? id,
  double lastActive = 1780000000,
}) => {
  'id': id ?? 'rt-$key',
  'session_key': key,
  'title': title,
  'status': status,
  'last_active': lastActive,
  'current': false,
  'message_count': 2,
  'model': 'hermes-4',
  'preview': 'private words',
  'started_at': 1780000000.0,
};

Map<String, Object?> _approval(
  String id, {
  List<String> choices = const ['once', 'session', 'deny'],
}) => {
  'request_id': id,
  'command': _command,
  'description': 'Deletes the project',
  'choices': choices,
};

void main() {
  late FakeHermesServer server;
  late FakeGateway gateway;
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late FakeNotificationService notifications;
  late AnnouncedRequests announced;
  late RecordingTracer tracer;
  late MemoryTokenStore tokens;
  late int cancelled;
  var notificationsOn = true;
  var lockOn = false;

  /// What `session.active_list` answers, by profile.
  late Map<String?, List<Map<String, Object?>>> sessions;

  /// What `approval.pending` answers, by runtime session id.
  late Map<String, List<Map<String, Object?>>> approvals;

  setUp(() {
    notificationsOn = true;
    lockOn = false;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': false, 'version': '0.9.0'})
      ..on(
        'GET',
        '/',
        '<script>window.__HERMES_SESSION_TOKEN__="page-token"</script>',
      )
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'd1', title: 'Trip plan', lastActive: 1780000100),
        ]),
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'w1', title: 'Numbers', lastActive: 1780000200),
        ]),
        query: {'profile': 'work'},
      )
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
      ..on('GET', '/api/cron/jobs', []);
    gateway = FakeGateway();
    sessions = {};
    approvals = {};
    gateway.handlers['session.active_list'] = (params) => {
      'sessions': sessions[params['profile']] ?? [],
    };
    gateway.handlers['approval.pending'] = (params) => {
      'approvals': approvals[params['session_id']] ?? [],
    };
    storage = FakeSurfaceStorage();
    store = SurfaceSnapshotStore(storage: storage);
    notifications = FakeNotificationService();
    announced = AnnouncedRequests();
    tracer = RecordingTracer();
    tokens = MemoryTokenStore();
    cancelled = 0;
  });

  tearDown(() => store.dispose());

  HeadlessDeps headless() => HeadlessDeps(
    tokenStore: tokens,
    prefs: SharedPreferencesAsync(),
    devServerUrl: '',
    adapter: server,
    openSocket: (_) => gateway.connect(),
    telemetry: (attributes) =>
        ConnectionTelemetry(tracer: tracer, serverAttributes: attributes),
    snapshotStore: store,
    appLockOn: () async => lockOn,
  );

  BackgroundRefreshDeps deps({
    List<BackgroundStep> Function()? steps,
    HeadlessDeps? wiring,
    Duration timeout = const Duration(seconds: 5),
    Duration stepTimeout = const Duration(seconds: 3),
  }) => BackgroundRefreshDeps(
    headless: wiring ?? headless(),
    notifications: notifications,
    announced: announced,
    notificationsEnabled: () async => notificationsOn,
    appLockOn: () async => lockOn,
    cancelSchedule: () async => cancelled++,
    steps: steps,
    timeout: timeout,
    stepTimeout: stepTimeout,
  );

  Future<HeadlessOutcome<void>> refresh({BackgroundRefreshDeps? with_}) =>
      runBackgroundRefresh(deps: with_ ?? deps());

  List<Map<String, Object?>> rpcs(String method) => [
    for (final request in gateway.requests)
      if (request['method'] == method)
        request['params']! as Map<String, Object?>,
  ];

  Map<String, Object?> storedSnapshot() =>
      jsonDecode(storage.saved.last) as Map<String, Object?>;

  RecordingSpan taskSpan() =>
      tracer.spans.singleWhere((span) => span.name == 'background.task');

  group('open requests', () {
    test('lists the live sessions once per profile', () async {
      await refresh();

      expect(rpcs('session.active_list').map((p) => p['profile']), [
        'default',
        'work',
      ]);
    });

    test('reads approvals only of sessions that wait', () async {
      sessions = {
        'default': [
          _session('a', status: 'waiting'),
          _session('b', status: 'working'),
          _session('c', status: 'idle'),
        ],
      };

      await refresh();

      expect(rpcs('approval.pending'), [
        {'session_id': 'rt-a', 'profile': 'default'},
      ]);
    });

    test(
      'announces each new approval on its chat, without the command',
      () async {
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };

        await refresh();

        final shown = notifications.shown.single;
        expect(shown.threadId, 'chat-a');
        expect(shown.profile, 'work');
        expect(shown.title, 'Trip plan');
        expect(shown.body, kApprovalBody);
        final everything = [
          shown.title,
          shown.body,
          shown.category?.placeholder,
          shown.request?.toJson().toString(),
          storage.saved.join(),
        ].join(' ');
        expect(everything, isNot(contains('rm -rf')));
        expect(everything, isNot(contains('secret-project')));
        expect(everything, isNot(contains('Deletes the project')));
      },
    );

    test('posts an approval under #587 category and buttons', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();

      final shown = notifications.shown.single;
      expect(shown.category?.id, 'hermes.request.approval.once-session-deny');
      expect(shown.category?.actions.map((a) => a.id), [
        'hermes.action.allow-once',
        'hermes.action.allow-session',
        'hermes.action.deny',
      ]);
      expect(shown.request?.requestId, 'r1');
    });

    test('gives an approval no buttons while App Lock is on', () async {
      lockOn = true;
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();

      final shown = notifications.shown.single;
      expect(shown.category?.id, 'hermes.request.approval');
      expect(shown.category?.actions, isEmpty);
      expect(shown.request, isNull);
    });

    test('says a session waits when it lists no approval', () async {
      sessions = {
        'default': [_session('chat-q')],
      };

      await refresh();

      final shown = notifications.shown.single;
      expect(shown.body, kNeedsYouBody);
      expect(shown.category, isNull);
      expect(shown.threadId, 'chat-q');
    });

    test('treats a server without approval.pending as listing none', () async {
      gateway.handlers['approval.pending'] = (_) =>
          throw const FakeRpcError(-32601, 'unknown method');
      sessions = {
        'default': [_session('chat-q')],
      };

      final outcome = await refresh();

      expect(outcome, isA<HeadlessDone<void>>());
      expect(notifications.shown.single.body, kNeedsYouBody);
    });

    test('posts one notification for a chat with several approvals', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1'), _approval('r2')],
      };

      await refresh();

      expect(notifications.shown, hasLength(1));
      expect(await announced.read(), {'r1', 'r2'});
      expect(taskSpan().attributes['requests.new'], 2);
    });

    test('names an unnamed chat generically', () async {
      sessions = {
        'work': [_session('chat-a', title: '')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();

      expect(notifications.shown.single.title, 'New chat');
    });

    test('does not announce a request an earlier run announced', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();
      await refresh();

      expect(notifications.shown, hasLength(1));
    });

    test('announces a second wait of the same session again', () async {
      sessions = {
        'default': [_session('chat-q', lastActive: 1780000000)],
      };
      await refresh();
      sessions = {
        'default': [_session('chat-q', lastActive: 1780000900)],
      };

      await refresh();

      expect(notifications.shown, hasLength(2));
    });

    test('remembers the newest 200 ids', () async {
      await announced.add([for (var i = 0; i < 195; i++) 'old-$i']);
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [for (var i = 0; i < 10; i++) _approval('new-$i')],
      };

      await refresh();

      final kept = await announced.read();
      expect(kept, hasLength(kMaxAnnouncedRequests));
      expect(kept, containsAll([for (var i = 0; i < 10; i++) 'new-$i']));
      expect(kept, isNot(contains('old-0')));
      expect(kept, contains('old-194'));
    });

    test(
      'posts nothing, and remembers nothing, while notifications are off',
      () async {
        notificationsOn = false;
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };

        await refresh();

        expect(notifications.shown, isEmpty);
        expect(await announced.read(), isEmpty);
        expect(taskSpan().attributes['requests.new'], 0);
      },
    );

    test('reads a server without profiles with no profile parameter', () async {
      server.on('GET', '/api/profiles', {'detail': 'nope'}, status: 404);
      sessions = {
        null: [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();

      expect(rpcs('session.active_list'), [<String, Object?>{}]);
      expect(rpcs('approval.pending'), [
        {'session_id': 'rt-chat-a'},
      ]);
      expect(notifications.shown.single.profile, isNull);
      expect(storedSnapshot()['pending'], [containsPair('profile', 'default')]);
    });
  });

  group('the snapshot', () {
    test('lists the requests found in every profile as pending', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();

      final snapshot = storedSnapshot();
      expect(snapshot['pending'], [
        allOf(
          containsPair('profile', 'work'),
          containsPair('threadId', 'chat-a'),
          containsPair('kind', 'approval'),
          containsPair('requestId', 'r1'),
          containsPair('url', 'hermes://chat?profile=work&id=chat-a'),
        ),
      ]);
      expect((snapshot['recentChats']! as List).map((c) => (c as Map)['id']), [
        'w1',
        'd1',
      ]);
      expect(jsonEncode(snapshot), isNot(contains('rm -rf')));
    });

    test('drops another profile\'s request that is no longer open', () async {
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 10),
          profile: 'default',
          pending: [
            PendingRequest(
              profile: 'work',
              threadId: 'gone',
              threadTitle: 'Old',
              kind: PendingKind.approval,
              requestId: 'stale',
              createdAt: DateTime.utc(2026, 10, 10),
            ),
          ],
        ),
      );

      await refresh();

      expect(storedSnapshot()['pending'], isEmpty);
    });

    test('keeps when a request was first seen', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      await refresh();
      final first = (storedSnapshot()['pending']! as List).single as Map;

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await refresh();

      final again = (storedSnapshot()['pending']! as List).single as Map;
      expect(again['createdAt'], first['createdAt']);
    });

    test('keeps the stored requests when the gateway cannot be read', () async {
      final previous = SurfaceSnapshot(
        updatedAt: DateTime.utc(2026, 10, 10),
        profile: 'default',
        pending: [
          PendingRequest(
            profile: 'work',
            threadId: 'chat-a',
            threadTitle: 'Trip plan',
            kind: PendingKind.approval,
            requestId: 'r-old',
            createdAt: DateTime.utc(2026, 10, 10),
          ),
        ],
      );
      await store.write(previous);
      final wiring = HeadlessDeps(
        tokenStore: tokens,
        prefs: SharedPreferencesAsync(),
        devServerUrl: '',
        adapter: server,
        openSocket: (_) => throw const SocketException('down'),
        telemetry: (attributes) =>
            ConnectionTelemetry(tracer: tracer, serverAttributes: attributes),
        snapshotStore: store,
        appLockOn: () async => false,
      );

      final outcome = await refresh(with_: deps(wiring: wiring));

      expect(outcome, isA<HeadlessDone<void>>());
      final snapshot = storedSnapshot();
      expect(snapshot['pending'], [containsPair('requestId', 'r-old')]);
      expect((snapshot['recentChats']! as List), isNotEmpty);
      expect(taskSpan().attributes['steps_failed'], 1);
    });

    test('keeps the stored requests when one profile cannot be read', () async {
      gateway.handlers['session.active_list'] = (params) {
        if (params['profile'] == 'work') {
          throw const FakeRpcError(-32000, 'profile gone');
        }
        return {
          'sessions': [_session('chat-q')],
        };
      };

      await refresh();

      // The profile that answered is still announced.
      expect(notifications.shown.single.threadId, 'chat-q');
      expect(storedSnapshot()['pending'], isEmpty);
      expect(taskSpan().attributes['steps_failed'], 1);
    });

    test('leaves titles and snippets out while App Lock is on', () async {
      lockOn = true;
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      final written = <SurfaceSnapshot>[];
      final listener = store.writes.listen(written.add);
      addTearDown(listener.cancel);

      await refresh();
      await Future<void>.delayed(Duration.zero);

      final snapshot = storedSnapshot();
      expect(snapshot['pending'], [containsPair('threadTitle', '')]);
      expect(snapshot['recentChats'], isNotEmpty);
      for (final chat in snapshot['recentChats']! as List) {
        expect((chat as Map)['title'], '');
        expect(chat.containsKey('snippet'), isFalse);
      }
      expect(written.single.recentChats.every((c) => c.title.isEmpty), isTrue);
    });

    test('tells the readers registered for snapshot writes', () async {
      final written = <SurfaceSnapshot>[];
      final listener = store.writes.listen(written.add);
      addTearDown(listener.cancel);

      await refresh();
      await Future<void>.delayed(Duration.zero);

      expect(written, hasLength(1));
      expect(written.single.signedIn, isTrue);
    });
  });

  group('the run', () {
    test(
      'runs the steps together, and one failing does not stop the rest',
      () async {
        final order = <String>[];
        final release = Completer<void>();
        final steps = [
          _Step((_) async {
            order.add('slow:start');
            await release.future;
            order.add('slow:end');
            return const StepCounts(newRequests: 2);
          }),
          _Step((_) async {
            order.add('failing');
            release.complete();
            throw StateError('boom');
          }),
          _Step((_) async {
            order.add('quick');
            return const StepCounts(newRequests: 1);
          }),
        ];

        final outcome = await refresh(with_: deps(steps: () => steps));

        expect(outcome, isA<HeadlessDone<void>>());
        expect(order, ['slow:start', 'failing', 'quick', 'slow:end']);
        expect(taskSpan().attributes['requests.new'], 3);
        expect(taskSpan().attributes['steps_failed'], 1);
      },
    );

    test('counts a step that takes too long as failed and goes on', () async {
      final never = Completer<void>();
      addTearDown(() {
        if (!never.isCompleted) never.complete();
      });
      final watch = Stopwatch()..start();

      final outcome = await refresh(
        with_: deps(
          steps: () => [
            _Step((_) async {
              await never.future;
              return const StepCounts();
            }),
            _Step((_) async => const StepCounts(newRequests: 1)),
          ],
          stepTimeout: const Duration(milliseconds: 100),
        ),
      );

      expect(outcome, isA<HeadlessDone<void>>());
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(taskSpan().attributes['steps_failed'], 1);
      expect(taskSpan().attributes['requests.new'], 1);
    });

    test('ends within its budget when nothing answers', () async {
      gateway.deaf = true;
      final watch = Stopwatch()..start();

      final outcome = await refresh(
        with_: deps(
          timeout: const Duration(milliseconds: 400),
          stepTimeout: const Duration(seconds: 10),
        ),
      );

      expect(outcome, isA<HeadlessUnreachable<void>>());
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test(
      'cancels the periodic run and posts nothing when signed out',
      () async {
        server.on('GET', '/api/status', {
          'auth_required': true,
          'version': '0.9.0',
        });

        final outcome = await refresh();

        expect(outcome, isA<HeadlessSignedOut<void>>());
        expect(cancelled, 1);
        expect(notifications.shown, isEmpty);
        expect(storage.saved, isEmpty);
      },
    );

    test('changes nothing before the first unlock', () async {
      tokens.unreadable = true;
      server.on('GET', '/api/status', {
        'auth_required': true,
        'version': '0.9.0',
      });

      final outcome = await refresh();

      expect(outcome, isA<HeadlessLocked<void>>());
      expect(cancelled, 0);
      expect(notifications.shown, isEmpty);
      expect(storage.saved, isEmpty);
    });

    test('changes nothing while the server is down', () async {
      server.on('GET', '/api/status', {'detail': 'down'}, status: 503);

      final outcome = await refresh();

      expect(outcome, isA<HeadlessUnreachable<void>>());
      expect(cancelled, 0);
      expect(notifications.shown, isEmpty);
      expect(storage.saved, isEmpty);
    });

    test('records the task and counts without ids or text', () async {
      sessions = {
        'work': [_session('chat-secret', title: 'Merger plans')],
      };
      approvals = {
        'rt-chat-secret': [_approval('r-secret')],
      };

      await refresh();

      final span = taskSpan();
      expect(span.attributes['task'], 'refresh');
      expect(span.attributes['outcome'], 'ok');
      expect(span.attributes['requests.new'], 1);
      expect(span.attributes['steps_failed'], 0);
      expect(span.ended, isTrue);
      final recorded = span.attributes.toString();
      for (final secret in ['chat-secret', 'r-secret', 'Merger', 'rm -rf']) {
        expect(recorded, isNot(contains(secret)));
      }
    });
  });

  group('the task the system starts', () {
    test('succeeds whatever the run did, and sends telemetry last', () async {
      final calls = <String>[];

      final ok = await backgroundRefreshTask(
        prepare: () async => calls.add('prepare'),
        run: () async {
          calls.add('run');
          throw StateError('boom');
        },
        flush: () async => calls.add('flush'),
      );

      expect(ok, isTrue);
      expect(calls, ['prepare', 'run', 'flush']);
    });

    test('succeeds when the isolate could not be readied', () async {
      final calls = <String>[];

      final ok = await backgroundRefreshTask(
        prepare: () async => throw StateError('no plugins'),
        run: () async => calls.add('run'),
        flush: () async => calls.add('flush'),
      );

      expect(ok, isTrue);
      expect(calls, ['flush']);
    });
  });
}

class _Step extends BackgroundStep {
  const _Step(this._run);

  final Future<StepCounts> Function(BackgroundContext context) _run;

  @override
  Future<StepCounts> run(BackgroundContext context) => _run(context);
}

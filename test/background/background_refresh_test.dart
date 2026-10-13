import 'package:hermes_app/src/auth/account_key.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/background/app_presence.dart';
import 'package:hermes_app/src/background/background_refresh.dart';
import 'package:hermes_app/src/background/background_check_status.dart';
import 'package:hermes_app/src/background/entry_points.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_posting.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
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
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';
const _command = 'rm -rf /srv/secret-project';

Map<String, Object?> _session(
  String key, {
  String title = 'Trip plan',
  String status = 'waiting',
  String? id,
  double? lastActive = 1780000000,
  int? messageCount = 2,
}) => {
  'id': id ?? 'rt-$key',
  'session_key': key,
  'title': title,
  'status': status,
  'last_active': ?lastActive,
  'current': false,
  'message_count': ?messageCount,
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
  late RecordedEvents events;
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
    events = RecordedEvents();
    store = SurfaceSnapshotStore(storage: storage, events: events.call);
    notifications = FakeNotificationService();
    announced = AnnouncedRequests();
    tracer = RecordingTracer();
    tokens = MemoryTokenStore();
    cancelled = 0;
  });

  tearDown(() => store.dispose());

  HeadlessDeps headless({
    bool failEvents = false,
    Duration closeGrace = const Duration(seconds: 3),
    Duration rejectionRecheck = const Duration(seconds: 1),
  }) => HeadlessDeps(
    tokenStore: tokens,
    prefs: SharedPreferencesAsync(),
    devServerUrl: '',
    adapter: server,
    openSocket: (_) => gateway.connect(),
    telemetry: (attributes) => ConnectionTelemetry(
      tracer: tracer,
      events: failEvents
          ? (name, [attributes = const {}]) => throw StateError('private text')
          : events.connection(attributes).events,
      serverAttributes: attributes,
    ),
    snapshotStore: store,
    appLockOn: () async => lockOn,
    closeGrace: closeGrace,
    rejectionRecheck: rejectionRecheck,
  );

  BackgroundRefreshDeps deps({
    List<BackgroundStep> Function()? steps,
    HeadlessDeps? wiring,
    BackgroundCheckStore? statusStore,
    Duration timeout = const Duration(seconds: 5),
    Duration stepTimeout = const Duration(seconds: 3),
    bool appOpen = false,
    Future<Map<String, Object?>> Function(
      HermesGatewayTransport transport,
      String method,
      Map<String, Object?> params,
    )?
    request,
  }) => BackgroundRefreshDeps(
    headless: wiring ?? headless(),
    statusStore: statusStore,
    notifications: notifications,
    announced: announced,
    notificationsEnabled: () async => notificationsOn,
    appLockOn: () async => lockOn,
    cancelSchedule: () async => cancelled++,
    appInFront: () async => appOpen,
    request: request,
    steps: steps,
    timeout: timeout,
    stepTimeout: stepTimeout,
  );

  Future<HeadlessOutcome<void>> refresh({BackgroundRefreshDeps? with_}) =>
      runBackgroundRefresh(deps: with_ ?? deps());

  test('stalled attempt bookkeeping cannot prevent the refresh work', () async {
    var ran = false;
    final outcome = await refresh(
      with_: deps(
        statusStore: BackgroundCheckStore(prefs: _StalledStatusBeginPrefs()),
        steps: () => [
          _Step((_) async {
            ran = true;
            return const StepCounts();
          }),
        ],
      ),
    ).timeout(const Duration(seconds: 5));

    expect(outcome, isA<HeadlessDone<void>>());
    expect(ran, isTrue);
  });

  test(
    'stalled completion bookkeeping cannot prevent signed-out cancellation',
    () async {
      final prefs = _StalledStatusFinishPrefs();
      final status = BackgroundCheckStore(prefs: prefs);
      await status.activate(accountKeyFor(_url, null));
      server.on('GET', '/api/status', {
        'auth_required': true,
        'version': '0.9.0',
      });
      final refreshing = refresh(with_: deps(statusStore: status));
      await prefs.entered.future.timeout(const Duration(seconds: 5));
      expect(cancelled, 1);
      final outcome = await refreshing.timeout(const Duration(seconds: 5));

      expect(outcome, isA<HeadlessSignedOut<void>>());
    },
  );

  test('records completed status without additional backend calls', () async {
    final status = BackgroundCheckStore();
    final account = accountKeyFor(_url, null);
    await refresh(with_: deps(steps: () => []));
    final baselineCalls = server.requests
        .map((request) => request.path)
        .toList();
    server.requests.clear();
    await status.activate(account);
    await refresh(with_: deps(steps: () => []));
    expect(
      server.requests.map((request) => request.path).toList(),
      baselineCalls,
    );
    expect(
      (await status.read(account))?.outcome,
      BackgroundCheckOutcome.completed,
    );
  });
  test('records partial status when an independent step fails', () async {
    final status = BackgroundCheckStore();
    final account = accountKeyFor(_url, null);
    await status.activate(account);
    await refresh(
      with_: deps(
        steps: () => [_Step((_) async => throw StateError('failed'))],
      ),
    );
    expect(
      (await status.read(account))?.outcome,
      BackgroundCheckOutcome.partial,
    );
  });
  test('records locked status without probing the backend', () async {
    final status = BackgroundCheckStore();
    final account = accountKeyFor(_url, null);
    await status.activate(account);
    tokens.unreadable = true;
    await refresh();
    expect(
      (await status.read(account))?.outcome,
      BackgroundCheckOutcome.locked,
    );
    expect(server.requests, isEmpty);
  });
  test(
    'records unreachable status when the backend refuses its probe',
    () async {
      final status = BackgroundCheckStore();
      final account = accountKeyFor(_url, null);
      await status.activate(account);
      server.on('GET', '/api/status', {'detail': 'down'}, status: 503);
      await refresh();
      expect(
        (await status.read(account))?.outcome,
        BackgroundCheckOutcome.unreachable,
      );
    },
  );
  test(
    'records signed-out status without changing cancellation behavior',
    () async {
      final status = BackgroundCheckStore();
      final account = accountKeyFor(_url, null);
      await status.activate(account);
      server.on('GET', '/api/status', {
        'auth_required': true,
        'version': '0.9.0',
      });
      await refresh();
      expect(
        (await status.read(account))?.outcome,
        BackgroundCheckOutcome.signedOut,
      );
      expect(cancelled, 1);
    },
  );

  test('status storage failure does not change refresh result', () async {
    final outcome = await refresh(
      with_: deps(
        steps: () => [],
        statusStore: BackgroundCheckStore(prefs: _UnavailableStatusPrefs()),
      ),
    );
    expect(outcome, isA<HeadlessDone<void>>());
    expect(cancelled, 0);
  });

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
      expect(await announced.read(), containsAll(['r1', 'r2']));
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
        'default': [_session('chat-q', messageCount: 2)],
      };
      await refresh();
      sessions = {
        'default': [_session('chat-q', messageCount: 5)],
      };

      await refresh();

      expect(notifications.shown, hasLength(2));
    });

    test('does not announce one wait again when the session moved', () async {
      sessions = {
        'default': [_session('chat-q', lastActive: 1780000000)],
      };
      await refresh();
      sessions = {
        'default': [_session('chat-q', lastActive: 1780000900)],
      };

      await refresh();

      expect(notifications.shown, hasLength(1));
    });

    test('tells a wait with no turn marker once an hour', () async {
      sessions = {
        'default': [_session('chat-q', lastActive: null, messageCount: null)],
      };
      var now = DateTime.utc(2026, 10, 11, 8, 10);
      List<BackgroundStep> steps() {
        final requests = OpenRequestsStep(now: () => now);
        return [requests, SnapshotStep(requests)];
      }

      await refresh(with_: deps(steps: steps));
      now = DateTime.utc(2026, 10, 11, 8, 50);
      await refresh(with_: deps(steps: steps));
      expect(notifications.shown, hasLength(1));

      now = DateTime.utc(2026, 10, 11, 9, 20);
      await refresh(with_: deps(steps: steps));
      expect(notifications.shown, hasLength(2));
    });

    test(
      'counts an approval.pending the server refused, by code only',
      () async {
        gateway.handlers['approval.pending'] = (_) =>
            throw const FakeRpcError(5032, 'secret-project has no provider');
        sessions = {
          'default': [_session('chat-q')],
        };

        await refresh();

        expect(events.named('background.requests_unreadable'), [
          {'code': 5032},
        ]);
        expect(
          events.named('background.requests_unreadable').toString(),
          isNot(contains('secret-project')),
        );
      },
    );

    test(
      'does not announce a wait generically and then by its approval',
      () async {
        gateway.handlers['approval.pending'] = (_) =>
            throw const FakeRpcError(5032, 'no provider');
        sessions = {
          'work': [_session('chat-a')],
        };
        await refresh();
        gateway.handlers['approval.pending'] = (params) => {
          'approvals': [_approval('r1')],
        };

        await refresh();

        expect(notifications.shown, hasLength(1));
        expect(notifications.shown.single.body, kNeedsYouBody);
      },
    );

    test(
      'does not announce a wait by its approval and then generically',
      () async {
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };
        await refresh();
        gateway.handlers['approval.pending'] = (_) =>
            throw const FakeRpcError(5032, 'no provider');

        await refresh();

        expect(notifications.shown, hasLength(1));
        expect(notifications.shown.single.body, kApprovalBody);
      },
    );

    test('announces a second approval of the same turn', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      await refresh();
      approvals = {
        'rt-chat-a': [_approval('r1'), _approval('r2')],
      };

      await refresh();

      expect(notifications.shown, hasLength(2));
    });

    test(
      'leaves announcing to the open app but still reads the requests',
      () async {
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };

        await refresh(with_: deps(appOpen: true));

        expect(notifications.shown, isEmpty);
        expect(await announced.read(), isEmpty);
        expect(storedSnapshot()['pending'], [containsPair('requestId', 'r1')]);

        await refresh();

        expect(notifications.shown, hasLength(1));
      },
    );

    test('announces while the app is alive but not in front', () async {
      final presence = AppPresence(
        name: 'test-run-presence',
        resumed: () => false,
      )..start();
      addTearDown(presence.dispose);
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh(
        with_: BackgroundRefreshDeps(
          headless: headless(),
          notifications: notifications,
          announced: announced,
          notificationsEnabled: () async => true,
          appLockOn: () async => false,
          cancelSchedule: () async {},
          appInFront: () => appInFront(name: 'test-run-presence'),
        ),
      );

      expect(notifications.shown, hasLength(1));
    });

    test(
      'remembers a request only after the notification is accepted',
      () async {
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };
        final seenWhenShown = <Set<String>>[];
        notifications = _SpyNotifications(
          () async => seenWhenShown.add(await announced.read()),
        );

        await refresh();

        expect(seenWhenShown.single, isNot(contains('r1')));
        expect(await announced.read(), contains('r1'));
      },
    );

    test('replaces an accepted alert when remembering failed', () async {
      announced = _UnwritableAnnounced();
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };

      await refresh();
      await refresh();

      expect(notifications.shown, hasLength(2));
      expect(await announced.read(), isEmpty);
    });

    test('a failed mark cannot suppress another chat notification', () async {
      announced = _FailingFirstMark();
      sessions = {
        'work': [_session('chat-a'), _session('chat-b')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
        'rt-chat-b': [_approval('r2')],
      };

      await refresh();

      expect(notifications.shown.map((note) => note.threadId), [
        'chat-a',
        'chat-b',
      ]);
      expect(await announced.read(), isNot(contains('r1')));
      expect(await announced.read(), contains('r2'));
      expect(taskSpan().attributes['requests.post_accepted'], 2);
      expect(taskSpan().attributes['requests.post_failed'], 0);
      expect(taskSpan().attributes['requests.mark_failed'], 1);
      expect(taskSpan().attributes['requests.new'], 1);
      expect(events.named('background.request_alert.mark_failed'), [
        {'error.type': 'StateError'},
      ]);
    });

    test('leaves a failed post eligible for the next live check', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      notifications.postResult = const NotificationPostResult(
        NotificationPostStatus.failed,
        errorType: 'PlatformException',
      );

      await refresh();

      expect(await announced.read(), isEmpty);
      expect(notifications.shown, isEmpty);
      expect(events.named('background.request_alert.post_failed'), [
        {'reason': 'failed', 'error.type': 'PlatformException'},
      ]);
      expect(taskSpan().attributes['requests.post_failed'], 1);
      expect(storedSnapshot()['pending'], hasLength(1));

      notifications.postResult = const NotificationPostResult(
        NotificationPostStatus.accepted,
      );
      await refresh();

      expect(notifications.shown, hasLength(1));
      expect(await announced.read(), contains('r1'));
    });

    test('marks only chats whose notification was accepted', () async {
      sessions = {
        'work': [_session('chat-a'), _session('chat-b')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
        'rt-chat-b': [_approval('r2')],
      };
      notifications.postResults['chat-a'] = const NotificationPostResult(
        NotificationPostStatus.denied,
      );

      await refresh();

      expect(notifications.shown.single.threadId, 'chat-b');
      expect(await announced.read(), contains('r2'));
      expect(await announced.read(), isNot(contains('r1')));
      expect(taskSpan().attributes['requests.post_accepted'], 1);
      expect(taskSpan().attributes['requests.post_failed'], 1);
    });

    test('does not retry a failed alert after the request resolves', () async {
      sessions = {
        'work': [_session('chat-a')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      notifications.postResult = const NotificationPostResult(
        NotificationPostStatus.unsupported,
      );
      await refresh();

      sessions = {
        'work': [_session('chat-a', status: 'idle')],
      };
      notifications.postResult = const NotificationPostResult(
        NotificationPostStatus.accepted,
      );
      await refresh();

      expect(notifications.shown, isEmpty);
      expect(await announced.read(), isEmpty);
    });

    test(
      'replaces the same notification after an accepted mark is lost',
      () async {
        announced = _UnwritableAnnounced();
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };
        await refresh();

        announced = AnnouncedRequests();
        await refresh();

        expect(notifications.shown, hasLength(2));
        final first = notifications.shown.first;
        final retried = notifications.shown.last;
        expect(
          notificationIdFor(first.threadId, profile: first.profile),
          notificationIdFor(retried.threadId, profile: retried.profile),
        );
        expect(await announced.read(), contains('r1'));
      },
    );

    test('post failure telemetry cannot prevent later chat alerts', () async {
      sessions = {
        'work': [_session('chat-a'), _session('chat-b')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
        'rt-chat-b': [_approval('r2')],
      };
      notifications.postResults['chat-a'] = const NotificationPostResult(
        NotificationPostStatus.failed,
        errorType: 'PlatformException',
      );
      await refresh(with_: deps(wiring: headless(failEvents: true)));

      expect(notifications.shown.single.threadId, 'chat-b');
      expect(await announced.read(), contains('r2'));
    });

    test('keeps the other profiles when one profile errors out', () async {
      sessions = {
        'default': [_session('chat-q')],
      };

      final outcome = await refresh(
        with_: deps(
          request: (transport, method, params) async {
            if (params['profile'] == 'work') throw TimeoutException('slow');
            return transport.request(method, params);
          },
        ),
      );

      expect(outcome, isA<HeadlessDone<void>>());
      expect(notifications.shown.single.threadId, 'chat-q');
      expect(taskSpan().attributes['steps_failed'], 1);
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
    /// Holds the snapshot build at its Kanban check until released, so a
    /// test can act while the background run is under way.
    Completer<void> holdBuild() {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/dashboard/plugins', (_) async {
        await gate.future;
        return (status: 200, body: <Object?>[]);
      });
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      return gate;
    }

    test(
      'is dropped whole when the app wrote while the run was under way',
      () async {
        final gate = holdBuild();
        sessions = {
          'work': [_session('chat-a')],
        };
        approvals = {
          'rt-chat-a': [_approval('r1')],
        };
        final run = refresh();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        await store.write(
          SurfaceSnapshot(
            updatedAt: DateTime.utc(2026, 10, 11, 9),
            profile: 'work',
            kanban: const KanbanSummary(blocked: 2, review: 0),
          ),
        );
        gate.complete();
        await run;

        expect(storage.saved, hasLength(1));
        expect(storedSnapshot()['profile'], 'work');
        expect(storedSnapshot()['pending'], isEmpty);
        expect(events.named('surface.snapshot.write_skipped'), [
          {'reason': 'revision_changed'},
        ]);
        // What was posted stays posted.
        expect(notifications.shown, hasLength(1));
      },
    );

    test('never writes over a snapshot that says signed out', () async {
      await store.write(SurfaceSnapshot.signedOut(DateTime.utc(2026, 10, 11)));

      await refresh();

      expect(storage.saved, hasLength(1));
      expect(storedSnapshot()['signedIn'], isFalse);
      expect(events.named('surface.snapshot.write_skipped'), [
        {'reason': 'signed_out'},
      ]);
    });

    test('hides titles when App Lock went on while it was built', () async {
      final gate = holdBuild();
      sessions = {
        'work': [_session('chat-a', title: 'Merger plans')],
      };
      approvals = {
        'rt-chat-a': [_approval('r1')],
      };
      final run = refresh();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      lockOn = true;
      gate.complete();
      await run;

      final snapshot = storedSnapshot();
      expect(snapshot['pending'], [containsPair('threadTitle', '')]);
      for (final chat in snapshot['recentChats']! as List) {
        expect((chat as Map)['title'], '');
      }
    });

    test('is not written by a body that outlived the run', () async {
      final gate = holdBuild();

      final outcome = await refresh(
        with_: deps(timeout: const Duration(milliseconds: 400)),
      );
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(outcome, isA<HeadlessUnreachable<void>>());
      expect(storage.saved, isEmpty);
      expect(events.named('surface.snapshot.write_skipped'), [
        {'reason': 'cancelled'},
      ]);
    });

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
          wiring: headless(closeGrace: const Duration(milliseconds: 100)),
        ),
      );

      expect(outcome, isA<HeadlessUnreachable<void>>());
      // The timeout and one grace, not a step's own limit.
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 750)));
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

    test(
      'keeps the periodic run when the refresh token was rejected',
      () async {
        server
          ..on('GET', '/api/status', {
            'auth_required': true,
            'version': '0.9.0',
          })
          ..on('POST', '/auth/native/refresh', {
            'detail': 'invalid refresh token',
          }, status: 401);
        tokens.session = HermesSession(
          accessToken: 'old',
          refreshToken: 'spent',
          expiresAt: 1,
          provider: 'basic',
          userId: 'u1',
          serverUrl: _url,
          mintedAt: 1000,
        );

        final outcome = await refresh(
          with_: deps(wiring: headless(rejectionRecheck: Duration.zero)),
        );

        // The steps swallow the failure, so the run ends as done; whatever
        // the outcome, a rejected token does not end the schedule.
        expect(outcome, isA<HeadlessDone<void>>());
        expect(cancelled, 0);
        expect(notifications.shown, isEmpty);
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
        run: (_, _) async {
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
        run: (_, _) async => calls.add('run'),
        flush: () async => calls.add('flush'),
      );

      expect(ok, isTrue);
      expect(calls, ['flush']);
    });

    test('keeps the readying, the run, its wind-down and the flush inside '
        'one budget', () async {
      gateway.deaf = true;
      Duration? given;
      Duration? givenGrace;
      final watch = Stopwatch()..start();

      final ok = await backgroundRefreshTask(
        budget: const Duration(milliseconds: 1500),
        closeGrace: const Duration(milliseconds: 200),
        flushBudget: const Duration(milliseconds: 200),
        prepare: () => Future<void>.delayed(const Duration(milliseconds: 300)),
        run: (timeout, grace) async {
          given = timeout;
          givenGrace = grace;
          await runBackgroundRefresh(
            deps: deps(
              timeout: timeout,
              wiring: headless(closeGrace: grace),
            ),
          );
        },
        flush: () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );

      expect(ok, isTrue);
      expect(given, lessThanOrEqualTo(const Duration(milliseconds: 800)));
      expect(givenGrace, const Duration(milliseconds: 200));
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
    });

    test('cuts a flush that outlasts its share', () async {
      final watch = Stopwatch()..start();

      final ok = await backgroundRefreshTask(
        flushBudget: const Duration(milliseconds: 100),
        prepare: () async {},
        run: (_, _) async {},
        flush: () => Future<void>.delayed(const Duration(seconds: 5)),
      );

      expect(ok, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });
  });
}

class _SpyNotifications extends FakeNotificationService {
  _SpyNotifications(this._onShow);

  final Future<void> Function() _onShow;

  @override
  Future<void> show(AttentionNotification notification) async {
    await _onShow();
    await super.show(notification);
  }
}

class _UnwritableAnnounced extends AnnouncedRequests {
  @override
  Future<void> persist(Set<String> ids) async =>
      throw StateError('preferences are read-only');
}

class _FailingFirstMark extends AnnouncedRequests {
  var _fail = true;

  @override
  Future<void> add(Iterable<String> ids) async {
    if (_fail) {
      _fail = false;
      throw StateError('private storage failure');
    }
    await super.add(ids);
  }
}

class _Step extends BackgroundStep {
  const _Step(this._run);

  final Future<StepCounts> Function(BackgroundContext context) _run;

  @override
  Future<StepCounts> run(BackgroundContext context) => _run(context);
}

class _UnavailableStatusPrefs extends SharedPreferencesAsync {
  @override
  Future<String?> getString(String key) async =>
      throw StateError('status unavailable');
}

class _StalledStatusBeginPrefs extends SharedPreferencesAsync {
  final _read = Completer<String?>();
  @override
  Future<String?> getString(String key) => _read.future;
}

class _StalledStatusFinishPrefs extends SharedPreferencesAsync {
  final entered = Completer<void>();
  final _write = Completer<void>();
  @override
  Future<void> setString(String key, String value) {
    if (value.contains('"outcome":"signedOut"')) {
      entered.complete();
      return _write.future;
    }
    return super.setString(key, value);
  }
}

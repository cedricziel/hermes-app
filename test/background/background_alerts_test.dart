import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_record.dart';
import 'package:hermes_app/src/agent_messages/agent_message_watcher.dart';
import 'package:hermes_app/src/agent_messages/message_alerts.dart'
    show kMessageFallbackTitle;
import 'package:hermes_app/src/auth/account_key.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/background/background_alerts.dart';
import 'package:hermes_app/src/background/background_refresh.dart';
import 'package:hermes_app/src/background/background_spotlight.dart';
import 'package:hermes_app/src/background/background_surfaces.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/intents/intent_shortcuts.dart'
    show kShortcutsChannel;
import 'package:hermes_app/src/intents/ask_hermes.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/badge_controller.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/schedule_alerts.dart';
import 'package:hermes_app/src/spotlight/spotlight_index.dart';
import 'package:hermes_app/src/spotlight/spotlight_settings.dart';
import 'package:hermes_app/src/schedules/schedule_baseline.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/fake_spotlight_index.dart';
import '../support/fake_surface_storage.dart';
import '../support/memory_token_store.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';

final _now = DateTime.utc(2026, 10, 11, 12);

class _FakeBadge implements BadgeService {
  final counts = <int>[];

  @override
  Future<void> update(int count) async => counts.add(count);
}

/// The account the fake server's runs belong to.
final _account = accountKeyFor(_url, null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeGateway gateway;
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late FakeNotificationService notifications;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late MemoryTokenStore tokens;
  late RunningReplies running;
  late ScheduleBaseline baseline;
  var notificationsOn = true;
  var appOpen = false;
  var replyPreviewsLocked = false;

  /// Runs where the snapshot write checks App Lock, just before it reads what
  /// is stored: a stand-in for another engine writing meanwhile.
  Future<void> Function()? beforeSnapshotWrite;

  /// What `session.active_list` answers, by profile.
  late Map<String?, Object> sessions;

  setUp(() {
    notificationsOn = true;
    appOpen = false;
    replyPreviewsLocked = false;
    beforeSnapshotWrite = null;
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
      ..on('GET', '/api/profiles/active', {
        'active': 'default',
        'current': 'default',
      })
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
      ..on('GET', '/api/cron/jobs', []);
    gateway = FakeGateway();
    sessions = {};
    gateway.handlers['session.active_list'] = (params) {
      final answer = sessions[params['profile']];
      if (answer is Exception) throw answer;
      return {'sessions': answer ?? []};
    };
    storage = FakeSurfaceStorage();
    events = RecordedEvents();
    store = SurfaceSnapshotStore(storage: storage, events: events.call);
    notifications = FakeNotificationService();
    tracer = RecordingTracer();
    tokens = MemoryTokenStore();
    running = RunningReplies();
    baseline = ScheduleBaseline();
  });

  tearDown(() => store.dispose());

  HeadlessDeps headless() => HeadlessDeps(
    tokenStore: tokens,
    prefs: SharedPreferencesAsync(),
    devServerUrl: '',
    adapter: server,
    openSocket: (_) => gateway.connect(),
    telemetry: (attributes) => ConnectionTelemetry(
      tracer: tracer,
      events: events.connection(attributes).events,
      serverAttributes: attributes,
    ),
    snapshotStore: store,
    appLockOn: () async {
      await beforeSnapshotWrite?.call();
      return false;
    },
  );

  BackgroundRefreshDeps deps(List<BackgroundStep> Function()? steps) =>
      BackgroundRefreshDeps(
        headless: headless(),
        notifications: notifications,
        announced: AnnouncedRequests(),
        notificationsEnabled: () async => notificationsOn,
        appLockOn: () async => replyPreviewsLocked,
        cancelSchedule: () async {},
        appInFront: () async => appOpen,
        steps: steps,
        timeout: const Duration(seconds: 5),
        stepTimeout: const Duration(seconds: 3),
      );

  Future<HeadlessOutcome<void>> refresh(
    List<BackgroundStep> Function()? steps,
  ) => runBackgroundRefresh(deps: deps(steps));

  RecordingSpan taskSpan() =>
      tracer.spans.singleWhere((span) => span.name == 'background.task');

  group('finished replies', () {
    RunningReply left(
      String id, {
      String? profile = 'work',
      Duration ago = const Duration(minutes: 5),
    }) =>
        RunningReply(profile: profile, threadId: id, since: _now.subtract(ago));

    RunningRepliesStep step() =>
        RunningRepliesStep(running: running, now: () => _now);

    Map<String, Object?> listed(String id, String status) => {
      'id': 'rt-$id',
      'session_key': id,
      'status': status,
    };

    /// The session of [id] ended its turn and is still listed.
    void idle(String id, {String profile = 'work'}) {
      final rows = sessions[profile] as List<Object?>? ?? [];
      sessions = {
        ...sessions,
        profile: [...rows, listed(id, 'idle')],
      };
    }

    void stored(
      String id, {
      String profile = 'work',
      String title = 'Trip plan',
      List<Map<String, Object?>>? messages,
    }) {
      server
        ..on(
          'GET',
          '/api/sessions/$id',
          sessionRow(id: id, title: title),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/$id/messages',
          messageListBody(
            id,
            messages ??
                [
                  messageRow(id: 1, role: 'user', content: 'Plan my trip'),
                  messageRow(
                    id: 2,
                    role: 'assistant',
                    content: 'Booked the flights.\n\nHotel is next.',
                  ),
                ],
          ),
          query: {'profile': profile},
        );
    }

    List<Map<String, Object?>> activeLists() => [
      for (final request in gateway.requests)
        if (request['method'] == 'session.active_list')
          request['params']! as Map<String, Object?>,
    ];

    test(
      'announces a reply that finished, with the start of its text',
      () async {
        await running.replace([left('c1')]);
        idle('c1');
        stored('c1');

        await refresh(() => [step()]);

        final shown = notifications.shown.single;
        expect(shown.threadId, 'c1');
        expect(shown.profile, 'work');
        expect(shown.title, 'Trip plan');
        expect(shown.body, 'Booked the flights.\n\nHotel is next.');
        expect(await running.read(), isEmpty);
        expect(activeLists(), [
          {'profile': 'work'},
        ]);
      },
    );

    test('background reply previews remain generic with App Lock', () async {
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');
      replyPreviewsLocked = true;
      await refresh(() => [step()]);
      final shown = notifications.shown.single;
      expect(shown.body, kReplyReadyBody);
      expect(shown.category?.placeholder, kReplyReadyBody);
      expect(shown.timeSensitive, isFalse);
    });

    test(
      'announces the reply of an ask that ran out of time before it ended',
      () async {
        final transport = FakeChatTransport()..promptAccepted = true;
        final ask = AskHermes(
          engine: AskEngine.headless,
          notifications: notifications,
          running: running,
          appLockOn: () async => false,
          transportFor: (_) => transport,
          deps: headless(),
        );
        final run = ask.start(
          const AskRequest(
            question: 'Plan my trip',
            profile: 'work',
            answerWithin: Duration.zero,
          ),
        );
        for (var i = 0; i < 200 && transport.sends.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        transport.sends.single.emit(const ThreadBound('c1'));
        expect((await run.answer).outcome, AskOutcome.stillWorking);

        run.expire();
        await run.finished;
        expect(notifications.shown, isEmpty);

        // Meanwhile the server finished the turn; a background run notices.
        idle('c1');
        stored('c1');
        await refresh(() => [RunningRepliesStep(running: running)]);

        final shown = notifications.shown.single;
        expect(shown.threadId, 'c1');
        expect(shown.profile, 'work');
        expect(shown.body, 'Booked the flights.\n\nHotel is next.');
        expect(await running.read(), isEmpty);
      },
    );

    test('announces the reply of an ask although the app opened and left meanwhile', () async {
      final transport = FakeChatTransport()..promptAccepted = true;
      final ask = AskHermes(
        engine: AskEngine.headless,
        notifications: notifications,
        running: running,
        appLockOn: () async => false,
        transportFor: (_) => transport,
        deps: headless(),
      );
      final run = ask.start(
        const AskRequest(
          question: 'Plan my trip',
          profile: 'work',
          answerWithin: Duration.zero,
        ),
      );
      for (var i = 0; i < 200 && transport.sends.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      transport.sends.single.emit(const ThreadBound('c1'));
      await run.answer;
      run.expire();
      await run.finished;

      // The app comes to the front and leaves again without ever showing
      // that chat: what the chat screen does on a return and on a pause.
      await running.clear();
      await running.replace(const []);

      idle('c1');
      stored('c1');
      await refresh(() => [RunningRepliesStep(running: running)]);

      expect(
        notifications.shown.single.body,
        'Booked the flights.\n\nHotel is next.',
      );
    });

    test('names the notification as the app in front does', () async {
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');
      final inFront = attentionFor(
        event: const ReplyCompleted('Booked the flights.\n\nHotel is next.'),
        thread: ChatThread(id: 'c1', title: 'Trip plan', updatedAt: _now),
        appFocused: false,
        selectedThreadId: null,
        enabled: true,
        profile: 'work',
      )!;

      await refresh(() => [step()]);

      final shown = notifications.shown.single;
      expect(shown.threadId, inFront.threadId);
      expect(shown.profile, inFront.profile);
      expect(shown.title, inFront.title);
      expect(shown.body, inFront.body);
    });

    test('records the announcement for the app to find on return', () async {
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');

      await refresh(() => [step()]);

      expect((await running.readAnnounced()).map((r) => r.threadId), ['c1']);
    });

    test('reads the chat of the profile it ran in', () async {
      await running.replace([left('c1', profile: 'default')]);
      idle('c1', profile: 'default');
      stored('c1', profile: 'default');

      await refresh(() => [step()]);

      expect(notifications.shown.single.profile, 'default');
      expect(
        server
            .requestsTo('GET', '/api/sessions/c1/messages')
            .single
            .queryParameters,
        containsPair('profile', 'default'),
      );
    });

    group('posts nothing and forgets the chat', () {
      test(
        'when the chat ends on the prompt, as a cut-off turn does',
        () async {
          await running.replace([left('c1')]);
          idle('c1');
          stored(
            'c1',
            messages: [
              messageRow(id: 1, role: 'user', content: 'Plan my trip'),
            ],
          );

          await refresh(() => [step()]);

          expect(notifications.shown, isEmpty);
          expect(await running.read(), isEmpty);
        },
      );

      test('when the turn was cut off after a tool call', () async {
        await running.replace([left('c1')]);
        idle('c1');
        stored(
          'c1',
          messages: [
            messageRow(id: 1, role: 'user', content: 'Plan my trip'),
            messageRow(
              id: 2,
              role: 'assistant',
              content: '',
              toolCalls: [functionCall('search', '{}')],
            ),
          ],
        );

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(await running.read(), isEmpty);
      });

      test('when the reply has no text', () async {
        await running.replace([left('c1')]);
        idle('c1');
        stored(
          'c1',
          messages: [
            messageRow(id: 1, role: 'user', content: 'Plan my trip'),
            messageRow(id: 2, role: 'assistant', content: '  '),
          ],
        );

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(await running.read(), isEmpty);
      });

      test('when the session is no longer listed', () async {
        await running.replace([left('c1')]);
        stored('c1');

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(await running.read(), isEmpty);
        expect(server.requestsTo('GET', '/api/sessions/c1/messages'), isEmpty);
      });

      test('when the session reports a status it does not know', () async {
        await running.replace([left('c1')]);
        sessions = {
          'work': [listed('c1', 'mysterious')],
        };
        stored('c1');

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(await running.read(), isEmpty);
      });
    });

    test('keeps the chat when its history cannot be read', () async {
      await running.replace([left('c1')]);
      idle('c1');
      server
        ..on('GET', '/api/sessions/c1', {'detail': 'down'}, status: 500)
        ..on('GET', '/api/sessions/c1/messages', {
          'detail': 'down',
        }, status: 500);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });

    test('says "New chat" when only the title cannot be read', () async {
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');
      server.on(
        'GET',
        '/api/sessions/c1',
        {'detail': 'down'},
        status: 500,
        query: {'profile': 'work'},
      );

      await refresh(() => [step()]);

      expect(notifications.shown.single.title, 'New chat');
    });

    for (final status in [
      'starting',
      'waiting',
      'working',
      'streaming',
      'resuming',
    ]) {
      test('keeps a chat whose session is $status', () async {
        await running.replace([left('c1')]);
        sessions = {
          'work': [listed('c1', status)],
        };
        stored('c1');

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(await running.read(), hasLength(1));
        expect(server.requestsTo('GET', '/api/sessions/c1/messages'), isEmpty);
      });
    }

    test('announces only the chats that finished', () async {
      await running.replace([left('c1'), left('c2')]);
      sessions = {
        'work': [listed('c1', 'idle'), listed('c2', 'working')],
      };
      stored('c1');
      stored('c2');

      await refresh(() => [step()]);

      expect(notifications.shown.map((n) => n.threadId), ['c1']);
      expect((await running.read()).map((r) => r.threadId), ['c2']);
    });

    test('asks each profile once', () async {
      await running.replace([
        left('c1'),
        left('c2'),
        left('c3', profile: 'default'),
      ]);
      idle('c1');
      idle('c2');
      idle('c3', profile: 'default');
      stored('c1');
      stored('c2');
      stored('c3', profile: 'default');

      await refresh(() => [step()]);

      expect(
        activeLists().map((p) => p['profile']),
        unorderedEquals(['work', 'default']),
      );
      expect(notifications.shown, hasLength(3));
    });

    test('drops a chat remembered for more than a day', () async {
      await running.replace([left('old', ago: const Duration(hours: 25))]);
      idle('old');
      stored('old');

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await running.read(), isEmpty);
      expect(activeLists(), isEmpty);
    });

    test('changes nothing when the live sessions cannot be read', () async {
      await running.replace([left('c1')]);
      sessions = {'work': const FakeRpcError(-32000, 'down')};
      stored('c1');

      final outcome = await refresh(() => [step()]);

      expect(outcome, isA<HeadlessDone<void>>());
      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });

    test('still announces the profiles that could be read', () async {
      await running.replace([left('c1'), left('c2', profile: 'default')]);
      idle('c1');
      sessions = {...sessions, 'default': const FakeRpcError(-32000, 'down')};
      stored('c1');
      stored('c2', profile: 'default');

      await refresh(() => [step()]);

      expect(notifications.shown.map((n) => n.threadId), ['c1']);
      expect((await running.read()).map((r) => r.threadId), ['c2']);
    });

    test('posts nothing while notifications are off', () async {
      notificationsOn = false;
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
      expect(activeLists(), isEmpty);
    });

    test('leaves the announcing to the app while it is in front', () async {
      appOpen = true;
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });

    test('posts before it forgets the chat, so a cut run repeats', () async {
      await running.replace([left('c1')]);
      idle('c1');
      stored('c1');
      final remembered = <int>[];
      final service = _OrderedService(() async {
        remembered.add((await running.read()).length);
      });

      await runBackgroundRefresh(
        deps: BackgroundRefreshDeps(
          headless: headless(),
          notifications: service,
          announced: AnnouncedRequests(),
          notificationsEnabled: () async => true,
          appLockOn: () async => false,
          cancelSchedule: () async {},
          appInFront: () async => false,
          steps: () => [step()],
        ),
      );

      expect(remembered, [1]);
      expect(await running.read(), isEmpty);
    });

    for (final (name, arrange, expected)
        in <(String, void Function(), Matcher)>[
          (
            'locked',
            () => tokens.unreadable = true,
            isA<HeadlessLocked<void>>(),
          ),
          (
            'server down',
            () => server.on('GET', '/api/status', {
              'detail': 'down',
            }, status: 503),
            isA<HeadlessUnreachable<void>>(),
          ),
          (
            'signed out',
            () => server.on('GET', '/api/status', {
              'auth_required': true,
              'version': '0.9.0',
            }),
            isA<HeadlessSignedOut<void>>(),
          ),
        ]) {
      test('does not run and keeps its list when $name', () async {
        await running.replace([left('c1')]);
        await baseline.write(_account, {
          'work/job1': DateTime.utc(2026, 9, 20),
        });
        idle('c1');
        stored('c1');
        arrange();

        final outcome = await refresh(
          () => [step(), ScheduleAlertsStep(baseline: baseline)],
        );

        expect(outcome, expected);
        expect(notifications.shown, isEmpty);
        expect(await running.read(), hasLength(1));
        expect(await baseline.read(_account), {
          'work/job1': DateTime.utc(2026, 9, 20),
        });
      });
    }

    test(
      'counts the replies it announced, and nothing else, on the span',
      () async {
        await running.replace([left('secret-chat')]);
        idle('secret-chat');
        stored('secret-chat', title: 'Merger plans');

        await refresh(() => [step()]);

        final span = taskSpan();
        expect(span.attributes['replies.finished'], 1);
        final recorded = span.attributes.toString();
        for (final secret in ['secret-chat', 'Merger', 'Booked']) {
          expect(recorded, isNot(contains(secret)));
        }
      },
    );
  });

  group('scheduled tasks', () {
    ScheduleAlertsStep step() => ScheduleAlertsStep(baseline: baseline);

    void jobs(List<Map<String, Object?>> rows) =>
        server.on('GET', '/api/cron/jobs', rows);

    Map<String, Object?> ran(
      String at, {
      String id = 'job1',
      String status = 'ok',
      String profile = 'work',
    }) => cronJobRow(
      id: id,
      name: 'Morning brief',
      lastRunAt: at,
      lastStatus: status,
      profile: profile,
    );

    final seen = {'work/job1': DateTime.utc(2026, 9, 20, 8)};

    test('announces the runs since the stored baseline', () async {
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00', status: 'error')]);

      await refresh(() => [step()]);

      final shown = notifications.shown.single;
      expect(shown.jobId, 'job1');
      expect(shown.title, 'Morning brief (work)');
      expect(shown.body, kJobFailedBody);
      expect(await baseline.read(_account), {
        'work/job1': DateTime.utc(2026, 9, 21, 8),
      });
    });

    test('announces a run once across two runs', () async {
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);
      await refresh(() => [step()]);

      expect(notifications.shown, hasLength(1));
    });

    test('only records the run times on the first run', () async {
      jobs([ran('2026-09-21T08:00:00+00:00', status: 'error')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), {
        'work/job1': DateTime.utc(2026, 9, 21, 8),
      });
    });

    test('follows the schedule setting', () async {
      await NotificationSettings().setScheduleAlerts(false);
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), seen);
      expect(server.requestsTo('GET', '/api/cron/jobs'), isEmpty);
    });

    test('is silent for a muted job but moves its baseline', () async {
      await NotificationSettings().setMuted('work/job1', true);
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), {
        'work/job1': DateTime.utc(2026, 9, 21, 8),
      });
    });

    test('does nothing while notifications are off', () async {
      notificationsOn = false;
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), seen);
    });

    test('does nothing while the app is in front', () async {
      appOpen = true;
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), seen);
    });

    test('does nothing without the cron routes', () async {
      server.on('GET', '/api/cron/delivery-targets', {
        'detail': 'no',
      }, status: 404);
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), seen);
      expect(server.requestsTo('GET', '/api/cron/jobs'), isEmpty);
    });

    test('saves the baseline after it posts, so a cut run repeats', () async {
      await baseline.write(_account, seen);
      jobs([ran('2026-09-21T08:00:00+00:00')]);
      final stored = <Map<String, DateTime>?>[];
      final service = _OrderedService(() async {
        stored.add(await baseline.read(_account));
      });

      await runBackgroundRefresh(
        deps: BackgroundRefreshDeps(
          headless: headless(),
          notifications: service,
          announced: AnnouncedRequests(),
          notificationsEnabled: () async => true,
          appLockOn: () async => false,
          cancelSchedule: () async {},
          appInFront: () async => false,
          steps: () => [step()],
        ),
      );

      expect(stored, [seen]);
      expect(await baseline.read(_account), {
        'work/job1': DateTime.utc(2026, 9, 21, 8),
      });
    });

    test('does not use the baseline of another account', () async {
      await baseline.write('someone-else', seen);
      jobs([ran('2026-09-21T08:00:00+00:00', status: 'error')]);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), isNotNull);
    });

    test('announces nothing when the jobs cannot be read', () async {
      await baseline.write(_account, seen);
      server.on('GET', '/api/cron/jobs', {'detail': 'down'}, status: 500);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await baseline.read(_account), seen);
      expect(taskSpan().attributes['steps_failed'], 1);
    });

    test('folds a burst into one notification as the app does', () async {
      await baseline.write(_account, {
        for (var i = 0; i < 7; i++) 'work/j$i': DateTime.utc(2026, 9, 20),
      });
      jobs([
        for (var i = 0; i < 7; i++) ran('2026-09-21T08:00:00+00:00', id: 'j$i'),
      ]);

      await refresh(() => [step()]);

      expect(notifications.shown.single.body, '7 scheduled tasks ran');
    });

    test(
      'counts the runs it announced, and nothing else, on the span',
      () async {
        await baseline.write(_account, seen);
        jobs([ran('2026-09-21T08:00:00+00:00')]);

        await refresh(() => [step()]);

        final span = taskSpan();
        expect(span.attributes['schedules.ran'], 1);
        expect(span.attributes.toString(), isNot(contains('Morning brief')));
      },
    );
  });

  group('Spotlight', () {
    late FakeSpotlightIndex index;
    var lockOn = false;

    setUp(() {
      index = FakeSpotlightIndex();
      lockOn = false;
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'd1', title: 'Trip plan', lastActive: 1780000100),
        ]),
        query: {'profile': 'default'},
      );
    });

    tearDown(() => index.dispose());

    Future<void> run() => runBackgroundRefresh(
      deps: BackgroundRefreshDeps(
        headless: HeadlessDeps(
          tokenStore: tokens,
          prefs: SharedPreferencesAsync(),
          devServerUrl: '',
          adapter: server,
          openSocket: (_) => gateway.connect(),
          snapshotStore: store,
          appLockOn: () async => lockOn,
        ),
        notifications: notifications,
        announced: AnnouncedRequests(),
        notificationsEnabled: () async => notificationsOn,
        appLockOn: () async => lockOn,
        cancelSchedule: () async {},
        appInFront: () async => appOpen,
        steps: () {
          final requests = OpenRequestsStep();
          final snapshot = SnapshotStep(requests);
          return [
            requests,
            snapshot,
            SpotlightRefreshStep(snapshot, index: index),
          ];
        },
        timeout: const Duration(seconds: 5),
        stepTimeout: const Duration(seconds: 3),
      ),
    );

    test('puts the chats of the fresh snapshot in the index', () async {
      await SpotlightSettings().setEnabled(true);

      await run();

      expect(index.calls, ['replace chat']);
      expect(index.items['chat']!.single.title, 'Trip plan');
    });

    test('does nothing after the user turns it off', () async {
      await SpotlightSettings().setEnabled(false);
      await run();

      expect(index.calls, isEmpty);
    });

    test('empties an index that holds chats while App Lock is on', () async {
      await SpotlightSettings().setEnabled(true);
      await SharedPreferencesAsync().setBool('hermes.spotlight.dirty', true);
      index.items['chat'] = const [
        SpotlightItem(
          domain: 'chat',
          id: 'default/d1',
          title: 'Trip plan',
          text: '',
          url: 'hermes://chat?profile=default&id=d1',
        ),
      ];
      lockOn = true;

      await run();

      expect(index.calls, ['deleteAll']);
      expect(index.items, isEmpty);
    });

    test('leaves the index alone while the device is locked', () async {
      await SpotlightSettings().setEnabled(true);
      index.available = false;

      await run();

      expect(index.calls, isEmpty);
    });

    test('leaves the index to the app while it is in front', () async {
      await SpotlightSettings().setEnabled(true);
      appOpen = true;

      await run();

      expect(index.calls, isEmpty);
    });
  });

  group('badge and Siri', () {
    late _FakeBadge badge;
    late List<String> asked;

    setUp(() {
      badge = _FakeBadge();
      asked = [];
      gateway.handlers['approval.pending'] = (_) => {'approvals': []};
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'd1', title: 'Trip plan', lastActive: 1780000100),
        ]),
        query: {'profile': 'default'},
      );
    });

    Future<void> run({
      TargetPlatform platform = TargetPlatform.iOS,
      Duration? snapshotWait,
    }) => refresh(() {
      final requests = OpenRequestsStep();
      final snapshot = SnapshotStep(requests);
      return [
        requests,
        snapshot,
        BadgeRefreshStep(
          snapshot,
          badge: badge,
          settings: NotificationSettings(),
          platform: platform,
          snapshotWait: snapshotWait,
        ),
        ShortcutsRefreshStep(
          snapshot,
          refresh: () async {
            asked.add('refresh');
          },
          platform: platform,
        ),
      ];
    });

    test('shows the number of open requests on the icon', () async {
      sessions = {
        'default': [
          {
            'id': 'rt-d1',
            'session_key': 'd1',
            'title': 'Trip plan',
            'status': 'waiting',
            'message_count': 2,
          },
        ],
      };

      await run();

      expect(badge.counts, [1]);
    });

    test('shows the stored count when its own snapshot was dropped', () async {
      beforeSnapshotWrite = () async {
        final other = SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 11, 12),
          pending: [
            for (final id in ['a', 'b'])
              PendingRequest(
                profile: 'default',
                threadId: id,
                threadTitle: 'Chat',
                kind: PendingKind.approval,
                requestId: id,
                createdAt: DateTime.utc(2026, 10, 11, 11),
              ),
          ],
        ).atRevision(9);
        await storage.save(other.encode());
      };

      await run();

      expect(events.named('surface.snapshot.write_skipped'), isNotEmpty);
      expect(badge.counts, [2]);
      expect(asked, isEmpty);
    });

    test('clears the badge while notifications are off', () async {
      await NotificationSettings().setEnabled(false);
      sessions = {
        'default': [
          {
            'id': 'rt-d1',
            'session_key': 'd1',
            'title': 'Trip plan',
            'status': 'waiting',
            'message_count': 2,
          },
        ],
      };

      await run();

      expect(badge.counts, [0]);
    });

    test('counts a snapshot that never comes as a failed step', () async {
      final snapshot = SnapshotStep(OpenRequestsStep());
      await refresh(
        () => [
          BadgeRefreshStep(
            snapshot,
            badge: badge,
            settings: NotificationSettings(),
            platform: TargetPlatform.iOS,
            snapshotWait: const Duration(milliseconds: 50),
          ),
          ShortcutsRefreshStep(
            snapshot,
            refresh: () async => asked.add('refresh'),
            platform: TargetPlatform.iOS,
            snapshotWait: const Duration(milliseconds: 50),
          ),
        ],
      );

      expect(taskSpan().attributes['steps_failed'], 2);
      expect(badge.counts, isEmpty);
      expect(asked, isEmpty);
    });

    test('the default run updates the badge and asks Siri', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final name in ['app_badge_plus', kShortcutsChannel]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          calls.add('$name ${call.method}');
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(MethodChannel(name), null),
        );
      }

      await refresh(null);

      expect(
        calls,
        containsAll([
          'app_badge_plus updateBadge',
          '$kShortcutsChannel refreshShortcuts',
        ]),
      );
    });

    test('clears the badge when nothing waits', () async {
      await run();

      expect(badge.counts, [0]);
    });

    test('leaves the badge alone where the icon has none', () async {
      await run(platform: TargetPlatform.linux);

      expect(badge.counts, isEmpty);
    });

    test('asks Siri to re-read the chats after a changed snapshot', () async {
      await run();

      expect(asked, ['refresh']);
    });

    test('does not ask again when the run changed nothing', () async {
      await run();
      await run();

      expect(asked, ['refresh']);
    });

    test('asks on iOS only', () async {
      await run(platform: TargetPlatform.android);

      expect(asked, isEmpty);
    });
  });

  group('messages from Hermes', () {
    late AgentMessageRecord record;

    AgentMessagesStep step() => AgentMessagesStep(record: record);

    Map<String, Object?> delivery(
      String id, {
      required double at,
      String? title,
      bool unread = true,
      int messages = 1,
    }) => sessionRow(
      id: id,
      title: title,
      startedAt: at,
      unread: unread,
      messageCount: messages,
      source: 'hermes_app',
    );

    void deliveries(String profile, List<Map<String, Object?>> rows) =>
        server.on(
          'GET',
          '/api/sessions',
          sessionListBody(rows),
          query: {'source': 'hermes_app', 'profile': profile},
        );

    void text(String id, String content) => server.on(
      'GET',
      '/api/sessions/$id/messages',
      messageListBody(id, [
        messageRow(id: 1, role: 'assistant', content: content),
      ]),
    );

    List<Object?> listings() => [
      for (final request in server.requestsTo('GET', '/api/sessions'))
        if (request.queryParameters['source'] == 'hermes_app')
          request.queryParameters['profile'],
    ];

    final seen = {'default': 0.0, 'work': 100.0};

    /// Stores [seen] and lists one new delivery in `work`.
    Future<void> arrangeNew() async {
      await record.write(_account, seen);
      deliveries('work', [
        delivery('hermes-app-new', at: 200, title: 'Message: Report'),
        delivery('hermes-app-old', at: 100),
      ]);
      text('hermes-app-new', 'Daily report ready: 3 builds failed');
    }

    setUp(() {
      record = AgentMessageRecord();
      deliveries('default', []);
      deliveries('work', []);
    });

    test('announces a delivery after the first run, not before', () async {
      deliveries('work', [delivery('hermes-app-old', at: 100)]);
      await refresh(() => [step()]);
      expect(notifications.shown, isEmpty);
      expect(await record.read(_account), seen);

      await arrangeNew();
      await refresh(() => [step()]);

      final shown = notifications.shown.single;
      expect(shown.threadId, 'hermes-app-new');
      expect(shown.profile, 'work');
      expect(shown.title, 'Message: Report (work)');
      expect(shown.body, 'Daily report ready: 3 builds failed');
      expect(shown.isMessage, isTrue);
      expect(await record.read(_account), {'default': 0, 'work': 200});

      await refresh(() => [step()]);
      expect(notifications.shown, hasLength(1));
    });

    test('names no profile when the delivery is in the active one', () async {
      await record.write(_account, seen);
      deliveries('default', [delivery('hermes-app-new', at: 200, title: 'Hi')]);
      text('hermes-app-new', 'Hello');

      await refresh(() => [step()]);

      expect(notifications.shown.single.title, 'Hi');
    });

    test('lists every profile at once', () async {
      await record.write(_account, seen);
      final started = <Object?>[];
      final release = Completer<void>();
      for (final profile in ['default', 'work']) {
        server.onRequest('GET', '/api/sessions', (request) async {
          started.add(request.queryParameters['profile']);
          await release.future;
          return (status: 200, body: sessionListBody([]));
        }, query: {'source': 'hermes_app', 'profile': profile});
      }

      final run = refresh(() => [step()]);
      for (var i = 0; i < 200 && started.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(started, unorderedEquals(['default', 'work']));
      release.complete();
      await run;
    });

    test('saves the record before it posts, so a cut run repeats', () async {
      await arrangeNew();
      final stored = <Map<String, double>?>[];
      final service = _OrderedService(() async {
        stored.add(await record.read(_account));
      });

      await runBackgroundRefresh(
        deps: BackgroundRefreshDeps(
          headless: headless(),
          notifications: service,
          announced: AnnouncedRequests(),
          notificationsEnabled: () async => true,
          appLockOn: () async => false,
          cancelSchedule: () async {},
          appInFront: () async => false,
          steps: () => [step()],
        ),
      );

      expect(stored, [
        {'default': 0, 'work': 200},
      ]);
    });

    test('is not announced again by the app in front', () async {
      await arrangeNew();
      await refresh(() => [step()]);
      expect(notifications.shown, hasLength(1));

      final settings = NotificationSettings();
      await settings.load();
      final finds = AgentMessageFinds();
      final watcher = AgentMessageWatcher(
        chat: HermesChatRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        service: notifications,
        settings: settings,
        finds: finds,
        record: record,
        account: () => _account,
        appLock: () => false,
      );
      addTearDown(() {
        watcher.dispose();
        finds.dispose();
      });
      await watcher.check();

      expect(notifications.shown, hasLength(1));
      expect(finds.profiles, isEmpty);
    });

    test('hides the title and text under App Lock', () async {
      replyPreviewsLocked = true;
      await arrangeNew();

      await refresh(() => [step()]);

      final shown = notifications.shown.single;
      expect(shown.title, kMessageFallbackTitle);
      expect(shown.body, kNewMessageBody);
      expect(
        server.requestsTo('GET', '/api/sessions/hermes-app-new/messages'),
        isEmpty,
      );
    });

    test('says "New message" when the text cannot be read', () async {
      await arrangeNew();
      server.on('GET', '/api/sessions/hermes-app-new/messages', {
        'detail': 'down',
      }, status: 500);

      await refresh(() => [step()]);

      expect(notifications.shown.single.body, kNewMessageBody);
    });

    test('keeps the record of a profile that cannot be listed', () async {
      await arrangeNew();
      server.on(
        'GET',
        '/api/sessions',
        {'detail': 'down'},
        status: 500,
        query: {'source': 'hermes_app', 'profile': 'default'},
      );
      await record.write(_account, {'default': 50, 'work': 100});

      await refresh(() => [step()]);

      expect(notifications.shown, hasLength(1));
      expect(await record.read(_account), {'default': 50, 'work': 200});
      expect(events.named('agent_messages.look_failed'), [
        {'error_type': 'DioException', 'background': true},
      ]);
    });

    test('does nothing while the app is in front', () async {
      appOpen = true;
      await arrangeNew();

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(listings(), isEmpty);
      expect(await record.read(_account), seen);
    });

    test('does nothing while notifications are off', () async {
      notificationsOn = false;
      await arrangeNew();

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(listings(), isEmpty);
      expect(await record.read(_account), seen);
    });

    test('follows the setting', () async {
      await NotificationSettings().setAgentMessages(false);
      await arrangeNew();

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(listings(), isEmpty);
      expect(await record.read(_account), seen);
    });

    for (final (name, arrange) in <(String, void Function())>[
      (
        'the profile list fails',
        () =>
            server.on('GET', '/api/profiles', {'detail': 'down'}, status: 500),
      ),
      (
        'the server lists no profile',
        () => server.on('GET', '/api/profiles', {'profiles': <Object?>[]}),
      ),
    ]) {
      test('writes and posts nothing when $name', () async {
        await arrangeNew();
        arrange();

        await refresh(() => [step()]);

        expect(notifications.shown, isEmpty);
        expect(listings(), isEmpty);
        expect(await record.read(_account), seen);
        expect(events.named('agent_messages.look_failed'), [
          {'error_type': 'UnreadableProfiles', 'background': true},
        ]);
      });
    }

    for (final (name, arrange, expected)
        in <(String, void Function(), Matcher)>[
          (
            'locked',
            () => tokens.unreadable = true,
            isA<HeadlessLocked<void>>(),
          ),
          (
            'server down',
            () => server.on('GET', '/api/status', {
              'detail': 'down',
            }, status: 503),
            isA<HeadlessUnreachable<void>>(),
          ),
          (
            'signed out',
            () => server.on('GET', '/api/status', {
              'auth_required': true,
              'version': '0.9.0',
            }),
            isA<HeadlessSignedOut<void>>(),
          ),
        ]) {
      test('does not run and keeps the record when $name', () async {
        await arrangeNew();
        arrange();

        final outcome = await refresh(() => [step()]);

        expect(outcome, expected);
        expect(notifications.shown, isEmpty);
        expect(await record.read(_account), seen);
      });
    }

    test('does not use the record of another account', () async {
      await arrangeNew();
      await record.write('someone-else', seen);

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await record.read(_account), {'default': 0, 'work': 200});
    });

    test('counts and logs what it announced, and no content', () async {
      await arrangeNew();

      await refresh(() => [step()]);

      final span = taskSpan();
      expect(span.attributes['agent_messages.found'], 1);
      expect(events.named('agent_messages.announced'), [
        {'count': 1, 'summary': false, 'background': true},
      ]);
      final recorded = [
        span.attributes,
        events.named('agent_messages.announced'),
      ].toString();
      for (final secret in ['hermes-app-new', 'Report', 'builds', 'work']) {
        expect(recorded, isNot(contains(secret)));
      }
    });

    test('shares one profile list request with the other steps', () async {
      await arrangeNew();

      await refresh(() => [OpenRequestsStep(), step()]);

      expect(server.requestsTo('GET', '/api/profiles'), hasLength(1));
    });

    test('gives up on a profile list that takes too long', () async {
      await arrangeNew();
      final release = Completer<void>();
      server.onRequest('GET', '/api/profiles', (_) async {
        await release.future;
        return (
          status: 200,
          body: profileListBody([profileRow(name: 'default', isDefault: true)]),
        );
      });

      await refresh(
        () => [
          AgentMessagesStep(
            record: record,
            lookup: const Duration(milliseconds: 100),
          ),
        ],
      );
      release.complete();

      expect(notifications.shown, isEmpty);
      expect(await record.read(_account), seen);
      expect(events.named('agent_messages.look_failed'), [
        {'error_type': 'UnreadableProfiles', 'background': true},
      ]);
      expect(taskSpan().attributes['steps_failed'], 0);
    });

    test('writes and posts nothing when the step has no time left', () async {
      await arrangeNew();

      await runBackgroundRefresh(
        deps: BackgroundRefreshDeps(
          headless: headless(),
          notifications: notifications,
          announced: AnnouncedRequests(),
          notificationsEnabled: () async => true,
          appLockOn: () async => false,
          cancelSchedule: () async {},
          appInFront: () async => false,
          steps: () => [step()],
          timeout: const Duration(seconds: 5),
          stepTimeout: const Duration(seconds: 1),
        ),
      );

      expect(notifications.shown, isEmpty);
      expect(await record.read(_account), seen);
      expect(taskSpan().attributes['steps_failed'], 0);
    });

    test('writes and posts nothing when the app came to the front while '
        'the text was read', () async {
      await arrangeNew();
      server.onRequest('GET', '/api/sessions/hermes-app-new/messages', (
        _,
      ) async {
        appOpen = true;
        return (
          status: 200,
          body: messageListBody('hermes-app-new', [
            messageRow(id: 1, role: 'assistant', content: 'Hi'),
          ]),
        );
      });

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(await record.read(_account), seen);
    });

    test('posts nothing for a record the app in front moved while the text '
        'was read', () async {
      await arrangeNew();
      final held = Completer<void>();
      var reads = 0;
      var started = false;
      server.onRequest('GET', '/api/sessions/hermes-app-new/messages', (
        _,
      ) async {
        // The first read is the step's; the watcher's comes later.
        if (reads++ == 0) {
          started = true;
          await held.future;
        }
        return (
          status: 200,
          body: messageListBody('hermes-app-new', [
            messageRow(id: 1, role: 'assistant', content: 'Hi'),
          ]),
        );
      });

      final run = refresh(() => [step()]);
      for (var i = 0; i < 200 && !started; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final settings = NotificationSettings();
      await settings.load();
      final finds = AgentMessageFinds();
      final watcher = AgentMessageWatcher(
        chat: HermesChatRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        service: notifications,
        settings: settings,
        finds: finds,
        record: record,
        account: () => _account,
        appLock: () => false,
      );
      addTearDown(() {
        watcher.dispose();
        finds.dispose();
      });
      await watcher.check();
      expect(notifications.shown, hasLength(1));

      held.complete();
      await run;

      expect(notifications.shown, hasLength(1));
      expect(await record.read(_account), {'default': 0, 'work': 200});
    });

    test('announces nothing when the record cannot be saved', () async {
      SharedPreferencesAsyncPlatform.instance = _RecordWriteFails({
        kSavedServerUrlKey: _url,
        'hermes.agent_messages.baseline.v1':
            '{"account":"$_account","profiles":{"default":0,"work":100}}',
      });
      record = AgentMessageRecord();
      deliveries('work', [
        delivery('hermes-app-new', at: 200, title: 'Message: Report'),
      ]);
      text('hermes-app-new', 'Hi');

      await refresh(() => [step()]);

      expect(notifications.shown, isEmpty);
      expect(events.named('agent_messages.look_failed'), [
        {'error_type': 'StateError', 'background': true},
      ]);
      expect(events.named('agent_messages.announced'), isEmpty);
    });

    test('folds more than five finds into one summary without reading any '
        'text', () async {
      await record.write(_account, seen);
      deliveries('work', [
        for (var i = 0; i < 6; i++) delivery('hermes-app-$i', at: 200.0 + i),
      ]);

      await refresh(() => [step()]);

      expect(notifications.shown.single.body, '6 new messages');
      expect(
        server.requests.where((r) => r.path.endsWith('/messages')),
        isEmpty,
      );
      expect(server.requestsTo('GET', '/api/profiles/active'), isEmpty);
      expect(events.named('agent_messages.announced'), [
        {'count': 6, 'summary': true, 'background': true},
      ]);
      expect(taskSpan().attributes['agent_messages.found'], 6);
    });

    test('is part of the default run', () async {
      await arrangeNew();

      await refresh(null);

      expect(notifications.shown.map((n) => n.threadId), ['hermes-app-new']);
    });
  });

  test('the default run includes both checks', () async {
    await running.replace([
      RunningReply(profile: 'work', threadId: 'c1', since: DateTime.now()),
    ]);
    sessions = {
      'work': [
        {'id': 'rt-c1', 'session_key': 'c1', 'status': 'idle'},
      ],
    };
    server
      ..on('GET', '/api/sessions/c1', sessionRow(id: 'c1', title: 'Trip plan'))
      ..on(
        'GET',
        '/api/sessions/c1/messages',
        messageListBody('c1', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Done'),
        ]),
      );
    await baseline.write(_account, {'work/job1': DateTime.utc(2026, 9, 20)});
    server.on('GET', '/api/cron/jobs', [
      cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
    ]);

    await refresh(null);

    expect(
      notifications.shown.map((n) => n.body),
      containsAll(['Done', kJobFinishedBody]),
    );
  });
}

/// Calls [onShow] before it records a notification.
class _OrderedService extends FakeNotificationService {
  _OrderedService(this.onShow);

  final Future<void> Function() onShow;

  @override
  Future<void> show(AttentionNotification notification) async {
    await onShow();
    await super.show(notification);
  }
}

/// Fails the save of the agent-message record and no other.
base class _RecordWriteFails extends InMemorySharedPreferencesAsync {
  _RecordWriteFails(super.data) : super.withData();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (key == 'hermes.agent_messages.baseline.v1') {
      throw StateError('disk full');
    }
    return super.setString(key, value, options);
  }
}

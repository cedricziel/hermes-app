import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/live_activities/live_activities.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_live_activity_service.dart';

ChatThread _thread(String id, [String title = 'Groceries']) =>
    ChatThread(id: id, title: title, updatedAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLiveActivityService service;
  late NotificationSettings settings;
  late LiveActivities activities;
  late StreamController<void> signedOut;
  late BreadcrumbTrail trail;
  List<String> crumbs() => [
    for (final c in trail.recent)
      c.attributes.isEmpty
          ? c.name
          : '${c.name} ${c.attributes.values.join(',')}',
  ];
  var now = DateTime(2026, 10, 8, 12);

  Future<void> settle() => pumpEventQueue();

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    service = FakeLiveActivityService();
    settings = NotificationSettings();
    await settings.load();
    signedOut = StreamController<void>.broadcast(sync: true);
    trail = BreadcrumbTrail(capacity: 100);
    activities = LiveActivities(
      service: service,
      settings: settings,
      signedOut: signedOut.stream,
      breadcrumbs: Breadcrumbs.of(trail),
      now: () => now,
    )..didChangeAppLifecycleState(AppLifecycleState.resumed);
    await activities.start();
  });

  tearDown(() async {
    activities.dispose();
    await signedOut.close();
  });

  test('ends what an earlier launch left behind', () {
    expect(service.endAllCalls, 1);
    expect(crumbs(), contains('live_activity.ended orphaned'));
  });

  test('a send shows the chat working', () async {
    activities.begin(_thread('s1'), profile: 'work');
    await settle();

    expect(service.running, hasLength(1));
    final activity = service.running.single;
    expect(activity.title, 'Groceries');
    expect(activity.state, 'working');
    expect(activity.data['label'], 'Working');
    expect(activity.data['threadId'], 's1');
    expect(activity.data['profile'], 'work');
    expect(activity.data['startedAt'], now.millisecondsSinceEpoch.toDouble());
    expect(crumbs(), contains('live_activity.started'));
  });

  test('no activity while the setting is off or iOS refuses', () async {
    await settings.setLiveActivities(false);
    activities.begin(_thread('s1'));
    await settle();
    expect(service.activities, isEmpty);

    await settings.setLiveActivities(true);
    service.refuse = true;
    activities.begin(_thread('s1'));
    await settle();
    expect(service.activities, isEmpty);
    expect(crumbs(), contains('live_activity.unavailable'));
  });

  test('no activity before the setting has loaded', () async {
    final fresh = NotificationSettings();
    final early = LiveActivities(service: service, settings: fresh);
    early.begin(_thread('s1'));
    await settle();
    expect(service.activities, isEmpty);
    early.dispose();
  });

  test('events move the state; streaming does not reach iOS', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    await settle();
    final activity = service.running.single;

    activities.onEvent(thread, const ReplyDelta('a'));
    activities.onEvent(thread, const ReplyDelta('b'));
    await settle();
    expect(activity.updates, 0);

    activities.onEvent(
      thread,
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r',
          command: 'rm -rf build',
          description: '',
          choices: [],
        ),
      ),
    );
    await settle();
    expect(activity.state, 'approval');
    expect(activity.data.values, isNot(contains('rm -rf build')));

    activities.onEvent(thread, const ReplyDelta('c'));
    await settle();
    expect(activity.state, 'working');
  });

  test('a new title is shown', () async {
    final thread = _thread('s1', 'New chat');
    activities.begin(thread);
    await settle();

    thread.title = 'Groceries';
    activities.onEvent(thread, const ThreadTitled('Groceries'));
    await settle();

    expect(service.running.single.title, 'Groceries');
  });

  test('a finished reply stays for 15 minutes', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    await settle();

    activities.onEvent(thread, const ReplyCompleted('Done. Two files.'));
    await settle();

    final activity = service.activities.single;
    expect(activity.state, 'ready');
    expect(activity.data.values, isNot(contains('Done. Two files.')));
    expect(activity.ended, isTrue);
    expect(activity.dismissAt, now.add(const Duration(minutes: 15)));
    expect(crumbs(), contains('live_activity.ended completed'));

    activities.onEvent(thread, const ReplyCompleted('', failed: true));
    await settle();
    expect(activity.state, 'ready');
  });

  test('a failed reply says so', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    await settle();

    activities.onEvent(thread, const ReplyCompleted('', failed: true));
    await settle();

    expect(service.activities.single.state, 'failed');
    expect(crumbs(), contains('live_activity.ended failed'));
  });

  test('a stopped reply goes away at once', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    await settle();

    activities.onEvent(thread, const ReplyCompleted('', stopped: true));
    await settle();

    final activity = service.activities.single;
    expect(activity.ended, isTrue);
    expect(activity.dismissAt, isNull);
    expect(crumbs(), contains('live_activity.ended stopped'));
  });

  test('one activity per chat', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    activities.begin(thread);
    await settle();
    expect(service.activities, hasLength(1));

    activities.onEvent(thread, const ReplyCompleted('ok'));
    await settle();
    now = now.add(const Duration(minutes: 2));
    activities.begin(thread);
    await settle();

    expect(service.activities, hasLength(2));
    expect(service.activities.first.dismissAt, isNull);
    expect(service.running.single.state, 'working');
    expect(
      service.running.single.data['startedAt'],
      now.millisecondsSinceEpoch.toDouble(),
    );
  });

  test('goes stale a minute after an update in the background', () async {
    final thread = _thread('s1');
    activities.begin(thread);
    await settle();
    final activity = service.running.single;
    expect(activity.staleIn, const Duration(hours: 8));

    activities.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    expect(activity.staleIn, const Duration(minutes: 1));

    activities.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(activity.staleIn, const Duration(hours: 8));
  });

  test('deleting the chat ends its activity', () async {
    activities.begin(_thread('s1'), profile: 'work');
    activities.begin(_thread('s2'), profile: 'work');
    await settle();

    activities.endChat('s1', 'work');
    await settle();

    expect(service.running.single.data['threadId'], 's2');
  });

  test('sign-out and switching it off end everything', () async {
    activities.begin(_thread('s1'));
    await settle();
    signedOut.add(null);
    await settle();
    expect(service.running, isEmpty);
    expect(crumbs(), contains('live_activity.ended signed_out'));

    activities.begin(_thread('s2'));
    await settle();
    await settings.setLiveActivities(false);
    await settle();
    expect(service.running, isEmpty);
    expect(crumbs(), contains('live_activity.ended disabled'));
  });

  test('a thread bound later is opened by its server id', () async {
    final thread = _thread('local');
    activities.begin(thread);
    await settle();

    thread.id = 'server-1';
    activities.onEvent(thread, const ThreadBound('server-1'));
    await settle();

    expect(service.running.single.data['threadId'], 'server-1');
  });

  group('taps', () {
    test('open the chat of the activity', () async {
      final targets = <NotificationTarget>[];
      activities.taps.listen(targets.add);

      service.tap(Uri.parse('hermes-activity://open?thread=s1&profile=work'));
      service.tap(Uri.parse('hermes-activity://open?thread=s2&profile='));
      service.tap(Uri.parse('hermes-activity://open'));
      await settle();

      expect(targets.map((t) => (t.threadId, t.profile)), [
        ('s1', 'work'),
        ('s2', null),
      ]);
    });

    test('a tap that started the app is handed over once', () async {
      service.launch = Uri.parse('hermes-activity://open?thread=s1');
      final fresh = LiveActivities(service: service, settings: settings);

      final first = await fresh.takeLaunchTarget();
      expect(first?.threadId, 's1');
      expect(await fresh.takeLaunchTarget(), isNull);
      fresh.dispose();
    });
  });
}

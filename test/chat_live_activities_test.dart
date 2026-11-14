import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/live_activities/live_activities.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_live_activity_service.dart';
import 'support/fake_notification_service.dart';
import 'support/pump_chat.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeLiveActivityService service;
  late NotificationSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    service = FakeLiveActivityService();
    settings = NotificationSettings();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      );
  });

  Future<void> pump(WidgetTester tester, {bool withTransport = true}) async {
    await tester.runAsync(settings.load);
    final activities = LiveActivities(service: service, settings: settings);
    addTearDown(activities.dispose);
    await pumpChatScreen(
      tester,
      server: server,
      transport: withTransport ? transport : null,
      providers: [
        ChangeNotifierProvider<NotificationSettings>.value(value: settings),
        Provider<NotificationService>.value(value: FakeNotificationService()),
        Provider<LiveActivities?>.value(value: activities),
      ],
    );
  }

  Future<FakeSend> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a send shows its chat as a Live Activity', (tester) async {
    await pump(tester);
    await openThread(tester, 'Run failure');

    await send(tester, 'Any news?');
    await settle(tester);

    final activity = service.running.single;
    expect(activity.title, 'Run failure');
    expect(activity.state, 'working');
    expect(activity.data['threadId'], 's1');
  });

  testWidgets('the reply drives the activity to its end', (tester) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');

    turn.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r1',
          command: 'rm -rf build',
          description: 'delete files',
          choices: ['once', 'deny'],
        ),
      ),
    );
    await settle(tester);
    expect(service.running.single.state, 'approval');

    turn.emit(const ReplyCompleted('Nothing new.'));
    await settle(tester);
    final activity = service.activities.single;
    expect(activity.state, 'ready');
    expect(activity.ended, isTrue);
  });

  testWidgets('a turn that breaks shows as failed', (tester) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');

    turn.fail();
    await settle(tester);

    expect(service.activities.single.state, 'failed');
  });

  testWidgets('a turn that settles without a completion is finished', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');

    turn
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('All good.'))
      ..emit(const SessionInfo(running: false));
    await settle(tester);

    expect(service.activities.single.state, 'ready');
  });

  testWidgets('a canned reply without an agent starts none', (tester) async {
    await pump(tester, withTransport: false);

    await tester.enterText(composerField, 'Hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(service.activities, isEmpty);
  });

  testWidgets('a prompt folded into the running turn keeps one activity', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final first = await send(tester, 'Any news?');
    first.emit(const ReplyStarted());
    await settle(tester);

    final second = await send(tester, 'Also check the logs');
    second.emit(const PromptFolded());
    await settle(tester);

    expect(service.activities, hasLength(1));
    expect(service.running.single.state, 'working');
  });

  testWidgets('tapping an activity opens its chat', (tester) async {
    await pump(tester);

    service.tap(Uri.parse('hermes-activity://open?thread=s2&profile='));
    await settle(tester);

    expect(
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId,
      's2',
    );
  });

  testWidgets('an activity that started the app opens its chat', (
    tester,
  ) async {
    service.launch = Uri.parse('hermes-activity://open?thread=s2');

    await pump(tester);

    expect(
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId,
      's2',
    );
  });

  testWidgets('deleting a chat ends its activity', (tester) async {
    server.on('DELETE', '/api/sessions/s1', {'ok': true});
    await tester.runAsync(settings.load);
    final activities = LiveActivities(service: service, settings: settings);
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      liveActivities: activities,
      report: (_) {},
    );
    addTearDown(() {
      attention.dispose();
      activities.dispose();
    });
    await tester.runAsync(chat.loadThreads);
    chat.select('s1');
    chat.submit('Any news?', const []);
    await tester.pump();
    expect(service.running, hasLength(1));

    final thread = chat.threads.firstWhere((t) => t.id == 's1');
    await tester.runAsync(() => chat.housekeeping!.delete(thread));
    await tester.pump();

    expect(service.running, isEmpty);
    chat.dispose();
    await tester.pump(const Duration(minutes: 5));
  });
}

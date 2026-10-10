import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/live_activities/live_activities.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_live_activity_service.dart';

/// Turns that end without the Live Activity hearing a completion, and the
/// turn Hermes runs ahead of a prompt, which is not the prompt's end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeLiveActivityService service;
  late LiveActivities activities;
  late AttentionNotifier attention;
  late ChatController chat;
  var disposedEarly = false;

  const approval = ApprovalRequested(
    ApprovalRequest(
      requestId: 'r1',
      command: 'rm -rf build',
      description: 'delete files',
      choices: ['once', 'deny'],
    ),
  );

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    service = FakeLiveActivityService();
    disposedEarly = false;
    final settings = NotificationSettings();
    await settings.load();
    activities = LiveActivities(service: service, settings: settings);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([]),
        query: {'profile': 'work'},
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      liveActivities: activities,
      report: (_) {},
    );
  });

  tearDown(() {
    if (!disposedEarly) chat.dispose();
    attention.dispose();
    activities.dispose();
  });

  Future<FakeSend> submitIn(String id) async {
    await chat.loadThreads();
    chat.select(id);
    await pumpEventQueue();
    chat.submit('Any news?', const []);
    await pumpEventQueue();
    return transport.sends.last;
  }

  group('a turn that ends in no way the chat reports', () {
    test('a stop the server has nothing left to stop for', () async {
      final turn = await submitIn('s1');
      turn.emit(const ReplyStarted());
      await pumpEventQueue();
      expect(service.running.single.state, 'working');
      transport.stopsRunning = false;

      await chat.stopReply(chat.selectedThread!);
      await pumpEventQueue();

      expect(service.running, isEmpty);
      expect(service.activities.single.dismissAt, isNull);
    });

    test('a folded prompt whose connection breaks', () async {
      final turn = await submitIn('s1');
      turn.emit(const PromptFolded());
      await pumpEventQueue();
      expect(service.running.single.state, 'working');

      turn.fail();
      await pumpEventQueue();

      expect(service.activities.single.state, 'failed');
    });

    test('a turn followed in a profile that goes out of view', () async {
      final turn = await submitIn('s1');
      turn
        ..emit(const ReplyCompleted('Checking first.'))
        ..finish();
      await pumpEventQueue();
      chat.submit('And again', const []);
      await pumpEventQueue();
      final again = transport.sends.last;
      again
        ..emit(const PromptFolded())
        ..finish();
      transport.followUpStreams['s1']!.emit(const ReplyStarted());
      await pumpEventQueue();
      expect(service.running.single.state, 'working');

      await chat.loadThreads('work');
      await pumpEventQueue();

      expect(service.running, isEmpty);
    });

    test('a reply sent here is not ended by leaving its profile', () async {
      final turn = await submitIn('s1');
      await chat.loadThreads('work');
      await pumpEventQueue();
      expect(service.running.single.state, 'working');

      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      expect(service.activities.single.state, 'ready');
    });

    test('a reply of another profile when the chat is closed', () async {
      final turn = await submitIn('s1');
      await chat.loadThreads('work');
      await pumpEventQueue();
      turn.emit(const ReplyDelta('still going'));
      await pumpEventQueue();
      expect(service.running.single.state, 'working');

      disposedEarly = true;
      chat.dispose();
      await pumpEventQueue();

      expect(service.running, isEmpty);
    });

    test('a chat that is closed with its reply running', () async {
      await submitIn('s1');
      expect(service.running, hasLength(1));

      disposedEarly = true;
      chat.dispose();
      await pumpEventQueue();

      expect(service.running, isEmpty);
    });

    test(
      'a finished activity is left to linger when the chat closes',
      () async {
        final turn = await submitIn('s1');
        turn.emit(const ReplyCompleted('Done.'));
        await pumpEventQueue();

        disposedEarly = true;
        chat.dispose();
        await pumpEventQueue();

        expect(service.activities.single.state, 'ready');
        expect(service.activities.single.dismissAt, isNotNull);
      },
    );
  });

  group('the turn Hermes runs ahead of the prompt', () {
    test('ending does not finish the prompt, which waits', () async {
      chat.newThread();
      chat.submit('Plan it', const []);
      final turn = transport.sends.last..emit(const ThreadBound('n1'));
      turn
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
        ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')));
      await pumpEventQueue();

      expect(service.running.single.state, 'working');

      turn.emit(const ReplyCompleted('Planned.'));
      await pumpEventQueue();
      expect(service.activities.single.state, 'ready');
    });

    test('failing does not fail the prompt', () async {
      chat.newThread();
      chat.submit('Plan it', const []);
      final turn = transport.sends.last..emit(const ThreadBound('n1'));
      turn
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(ReplyCompleted('', failed: true)));
      await pumpEventQueue();

      expect(service.running.single.state, 'working');
    });

    test('asking shows the user is needed', () async {
      chat.newThread();
      chat.submit('Plan it', const []);
      transport.sends.last
        ..emit(const ThreadBound('n1'))
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(approval));
      await pumpEventQueue();

      expect(service.running.single.state, 'approval');
    });
  });

  test('a turn chained after a finished reply leaves its activity', () async {
    final turn = await submitIn('s1');
    turn
      ..emit(const ReplyCompleted('Checking first.'))
      ..finish();
    await pumpEventQueue();

    transport.followUpStreams['s1']!.emit(const ReplyStarted());
    await pumpEventQueue();

    expect(service.activities, hasLength(1));
    expect(service.activities.single.state, 'ready');
  });
}

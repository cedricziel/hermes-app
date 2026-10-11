import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The chats a background run is told about when the app leaves while their
/// reply still runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late RunningReplies running;
  late ChatController chat;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    running = RunningReplies();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Trip plan', lastActive: 1780000500),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [messageRow(id: 1, role: 'user', content: 'Hi')]),
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
      runningReplies: running,
      report: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  Future<FakeSend> replyIn(String id) async {
    await chat.loadThreads('work');
    chat.select(id);
    await pumpEventQueue();
    chat.submit('Any news?', const []);
    await pumpEventQueue();
    return transport.sends.last;
  }

  test('remembers the chats whose reply runs when the app leaves', () async {
    await replyIn('s1');

    chat.rememberRunningReplies();
    await pumpEventQueue();

    final remembered = await running.read();
    expect(remembered.map((r) => (r.profile, r.threadId)), [('work', 's1')]);
  });

  test('remembers nothing when no reply runs', () async {
    await chat.loadThreads('work');

    chat.rememberRunningReplies();
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets them when the app returns', () async {
    await replyIn('s1');
    chat.rememberRunningReplies();
    await pumpEventQueue();

    chat.forgetRunningReplies();
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets them when it starts, as a killed app left them', () async {
    await running.replace([
      RunningReply(profile: 'work', threadId: 's9', since: DateTime.now()),
    ]);
    final restarted = ChatController(
      repository: HermesChatRepository(server.client().raw),
      attention: attention,
      runningReplies: running,
      report: (_) {},
    );
    addTearDown(restarted.dispose);
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets a chat whose reply ends after the app left', () async {
    final turn = await replyIn('s1');
    chat.rememberRunningReplies();
    await pumpEventQueue();

    turn.emit(const ReplyCompleted('Nothing new.'));
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('keeps the other chats when one reply ends', () async {
    final first = await replyIn('s1');
    chat.select('s2');
    await pumpEventQueue();
    chat.submit('And here?', const []);
    await pumpEventQueue();
    chat.rememberRunningReplies();
    await pumpEventQueue();

    first.emit(const ReplyCompleted('Nothing new.'));
    await pumpEventQueue();

    expect((await running.read()).map((r) => r.threadId), ['s2']);
  });

  group('on the chat screen', () {
    final mark = RunningReply(
      profile: 'work',
      threadId: 's9',
      since: DateTime.utc(2026, 10, 11),
    );

    testWidgets('leaving the app writes the list', (tester) async {
      final store = RunningReplies();
      await pumpChatScreen(
        tester,
        providers: [Provider<RunningReplies?>.value(value: store)],
      );
      await tester.runAsync(() => store.replace([mark]));

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }

      // The mock chats are not on the server, so none is remembered.
      expect(
        await tester.runAsync(() async {
          await pumpEventQueue();
          return store.read();
        }),
        isEmpty,
      );
    });

    testWidgets('coming back clears it', (tester) async {
      final store = RunningReplies();
      await pumpChatScreen(
        tester,
        providers: [Provider<RunningReplies?>.value(value: store)],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(() => store.replace([mark]));

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }

      expect(
        await tester.runAsync(() async {
          await pumpEventQueue();
          return store.read();
        }),
        isEmpty,
      );
    });
  });
}

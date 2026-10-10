import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/watch/watch_complication.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late List<Map<String, Object>> sent;
  late ChatController chat;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    sent = [];
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
      ..on('DELETE', '/api/sessions/s1', {'ok': true});
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      watchStatus: WatchComplicationStatus(
        send: (payload) async {
          sent.add(payload);
          return 'complication';
        },
      ),
      report: (_) {},
    );
    addTearDown(attention.dispose);
  });

  Future<void> finish(WidgetTester tester) async {
    chat.dispose();
    await tester.pump(const Duration(minutes: 5));
  }

  Future<FakeSend> submit(WidgetTester tester) async {
    await tester.runAsync(chat.loadThreads);
    await tester.runAsync(() async {
      chat.select('s1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    chat.submit('Any news?', const []);
    await tester.pump();
    return transport.sends.single;
  }

  testWidgets('a reply sent here shows on the watch, with its chat', (
    tester,
  ) async {
    await submit(tester);

    expect(sent.single, containsPair('state', 'working'));
    expect(sent.single, containsPair('title', 'Run failure'));
    expect(sent.single, containsPair('threadId', '/s1'));
    await finish(tester);
  });

  testWidgets('the reply drives it to ready, without its text', (tester) async {
    final turn = await submit(tester);

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
    await tester.pump();
    expect(sent.last['state'], 'waiting');

    turn.emit(const ReplyCompleted('Nothing new.'));
    await tester.pump();
    expect(sent.last['state'], 'ready');
    expect(sent.join(), isNot(contains('rm -rf')));
    expect(sent.join(), isNot(contains('Nothing new')));
    await finish(tester);
  });

  testWidgets('a broken turn shows as failed', (tester) async {
    final turn = await submit(tester);

    turn.fail();
    await tester.pump();

    expect(sent.last['state'], 'failed');
    await finish(tester);
  });

  testWidgets('deleting the chat takes it off the watch', (tester) async {
    await submit(tester);

    final thread = chat.threads.firstWhere((t) => t.id == 's1');
    await tester.runAsync(() => chat.housekeeping!.delete(thread));
    await tester.pump();

    expect(sent.last['state'], 'none');
    await finish(tester);
  });
}

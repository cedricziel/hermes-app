import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a turn another client sent leaves its prompt in the transcript',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer();
      // The stored history, as the server holds it. The prompt the phone sent
      // is added while the turn runs, before the reply is complete.
      final stored = <Map<String, Object?>>[
        messageRow(id: 1, role: 'user', content: 'from the mac'),
        messageRow(id: 2, role: 'assistant', content: 'first answer'),
      ];
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'shared', title: 'Chat')]),
        )
        ..on(
          'GET',
          '/api/sessions/shared',
          sessionRow(id: 'shared', title: 'Chat'),
        )
        ..onRequest('GET', '/api/sessions/shared/messages', (_) async {
          return (
            status: 200,
            body: messageListBody('shared', List.of(stored)),
          );
        });
      final transport = FakeChatTransport();
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      final chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      addTearDown(() {
        chat.dispose();
        attention.dispose();
      });

      await chat.loadThreads('default');
      chat.select('shared');
      await pumpEventQueue();
      expect(chat.selectedThread!.messages.map((m) => m.content), [
        'from the mac',
        'first answer',
      ]);

      // An own send opens the follow-up watch of the thread; it ends at once.
      chat.submit('my prompt', const []);
      final send = transport.sends.single;
      send
        ..emit(const ReplyStarted())
        ..emit(const ReplyCompleted('own reply'))
        ..finish();
      await pumpEventQueue();
      expect(chat.selectedThread!.isReplying, isFalse);
      // ignore: avoid_print

      // The server has stored what this client sent, as prompt.submit does.
      stored
        ..add(messageRow(id: 3, role: 'user', content: 'my prompt'))
        ..add(messageRow(id: 4, role: 'assistant', content: 'own reply'));

      // The phone sends its prompt into the same session: the stored history
      // gains it, the gateway streams only what the agent made of it.
      stored
        ..add(messageRow(id: 5, role: 'user', content: 'from the phone'))
        ..add(messageRow(id: 6, role: 'assistant', content: 'phone answer'));
      transport.followUpStreams['shared']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyCompleted('phone answer'));
      await pumpEventQueue(times: 200);
      // ignore: avoid_print

      expect(chat.selectedThread!.messages.map((m) => m.content), [
        'from the mac',
        'first answer',
        'my prompt',
        'own reply',
        'from the phone',
        'phone answer',
      ]);
    },
  );
}

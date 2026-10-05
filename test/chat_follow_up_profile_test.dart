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

  test('an old profile reply cannot claim the current thread pickup', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final server = FakeHermesServer();
    for (final profile in ['default', 'work']) {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'shared', title: profile)]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/shared/messages',
          messageListBody('shared', [
            messageRow(id: 1, role: 'user', content: '$profile prompt'),
          ]),
          query: {'profile': profile},
        );
    }
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
    chat.submit('Old prompt', const []);
    final oldSend = transport.sends.single;

    await chat.loadThreads('work');
    oldSend
      ..emit(const ReplyCompleted('Old reply'))
      ..finish();
    await pumpEventQueue();
    chat.select('shared');
    await pumpEventQueue();
    transport.followUpStreams['shared']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyCompleted('Work reply'));
    await pumpEventQueue();

    expect(chat.selectedThread!.messages.last.content, 'Work reply');
  });
}

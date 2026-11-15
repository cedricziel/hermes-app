import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// A deleted chat is not picked up again by the timer of its lost reply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleting the chat ends the timer of its lost reply', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final transport = FakeChatTransport();
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
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
    addTearDown(attention.dispose);
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
      reconnectRetry: const Duration(milliseconds: 10),
    );
    addTearDown(chat.dispose);
    await chat.loadThreads();
    chat.select('s1');
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    chat.submit('Again', const []);
    final send = transport.sends.single;
    send
      ..emit(const PromptAcknowledged(2))
      ..emit(const ReplyDelta('x'));
    await pumpEventQueue();
    send.fail(const GatewayReplyLost());
    await pumpEventQueue();
    expect(thread.messages.last.reconnecting, isTrue);

    await chat.housekeeping!.delete(thread);
    await pumpEventQueue();
    final calls = transport.followUpCalls;

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(transport.followUpCalls, calls);
  });
}

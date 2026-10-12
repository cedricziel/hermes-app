import 'package:dio/dio.dart';
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
    // The stored history of the shared session, per profile. What a turn
    // streamed is stored there too, as the server does once the turn ends.
    final stored = <String, List<Map<String, Object?>>>{};
    for (final profile in ['default', 'work']) {
      stored[profile] = [
        messageRow(id: 1, role: 'user', content: '$profile prompt'),
      ];
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'shared', title: profile)]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/shared',
          sessionRow(id: 'shared', title: profile),
          query: {'profile': profile},
        )
        ..onRequest('GET', '/api/sessions/shared/messages', (
          RequestOptions r,
        ) async {
          final profile = r.uri.queryParameters['profile'] ?? 'default';
          return (
            status: 200,
            body: messageListBody('shared', List.of(stored[profile]!)),
          );
        });
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
    stored['work']!.add(
      messageRow(
        id: 2,
        role: 'assistant',
        content: 'Work reply',
        timestamp: 1780000100,
      ),
    );
    transport.followUpStreams['shared']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyCompleted('Work reply'));
    await pumpEventQueue(times: 200);

    // The reply shown came from the work profile's stream, and the turn's
    // end re-read the thread, so its stored prompt is in the transcript too.
    expect(chat.selectedThread!.messages.last.content, 'Work reply');
    expect(
      chat.selectedThread!.messages.map((m) => m.content),
      contains('work prompt'),
    );
  });
}

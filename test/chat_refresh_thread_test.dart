import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// A chat open in a conversation window changes there; the main window reads
/// it again when it becomes key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ChatController chat;

  setUp(() async {
    server = FakeHermesServer();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's2', title: 'Other', lastActive: 1780000100),
          sessionRow(id: 's1', title: 'Old title'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      );
    transport = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    await chat.loadThreads();
    chat.select('s1');
    await pumpEventQueue();
  });

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);

  test('reads the title, pin and messages again', () async {
    server
      ..on(
        'GET',
        '/api/sessions/s1',
        sessionRow(
          id: 's1',
          title: 'Renamed',
          pinned: true,
          lastActive: 1780000200,
        ),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Hello there'),
        ]),
      );

    await chat.refreshThread('s1');

    expect(thread('s1').title, 'Renamed');
    expect(thread('s1').pinned, isTrue);
    expect(chat.threads.first.id, 's1');
    expect(thread('s1').messages.map((m) => m.content), ['Hi', 'Hello there']);
  });

  test('a chat with no new activity keeps its messages', () async {
    server.on(
      'GET',
      '/api/sessions/s1',
      sessionRow(id: 's1', title: 'Renamed'),
    );
    final before = server.requestsTo('GET', '/api/sessions/s1/messages').length;

    await chat.refreshThread('s1');

    expect(thread('s1').title, 'Renamed');
    expect(
      server.requestsTo('GET', '/api/sessions/s1/messages'),
      hasLength(before),
    );
  });

  test('a chat that is gone leaves the list', () async {
    server.on('GET', '/api/sessions/s1', {'detail': 'gone'}, status: 404);

    await chat.refreshThread('s1');

    expect(chat.threads.map((t) => t.id), ['s2']);
    expect(chat.selectedId, 's2');
  });

  test('leaves a chat alone while a reply streams into it', () async {
    chat.submit('More', const []);
    final before = server.requests.length;

    await chat.refreshThread('s1');

    expect(server.requests, hasLength(before));
    expect(thread('s1').isReplying, isTrue);
  });

  test(
    'a chat whose messages were never loaded only gets its details',
    () async {
      server.on('GET', '/api/sessions/s2', sessionRow(id: 's2', title: 'New'));

      await chat.refreshThread('s2');

      expect(thread('s2').title, 'New');
      expect(server.requestsTo('GET', '/api/sessions/s2/messages'), isEmpty);
    },
  );
}

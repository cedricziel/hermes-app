import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// A chat's pages arrive while the user sends into it or it is read again:
/// what arrives late must not land in the wrong place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ChatController chat;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's1', title: 'Chat', lastActive: 1780000100),
        sessionRow(id: 's2', title: 'Other'),
      ]),
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
  });

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);

  List<String> contents(String id) => [
    for (final m in thread(id).messages) m.content,
  ];

  test('a prompt sent while the first page loads goes after it', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/sessions/s1/messages', (_) async {
      await gate.future;
      return (
        status: 200,
        body: messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Hello'),
        ]),
      );
    });
    await chat.loadThreads();
    chat.select('s1');

    final sent = chat.submit('More', const []);
    gate.complete();
    expect(await sent, isTrue);
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', '']);
    expect(thread('s1').messages.map((m) => m.id).toSet(), hasLength(4));
    expect(transport.sends.single.text, 'More');
    expect(transport.sends.single.threadId, 's1');
  });

  test('a chat sent into after its first page failed reads it once', () async {
    server.on('GET', '/api/sessions/s1/messages', {
      'detail': 'boom',
    }, status: 500);
    await chat.loadThreads();
    chat.select('s1');
    await pumpEventQueue();

    expect(await chat.submit('More', const []), isTrue);
    transport.sends.single
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await pumpEventQueue();
    expect(contents('s1'), ['More', 'Answer']);

    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 1, role: 'user', content: 'Hi'),
        messageRow(id: 2, role: 'assistant', content: 'Hello'),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Answer'),
      ]),
    );
    chat.select('s2');
    chat.select('s1');
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Answer']);
  });

  test(
    'a turn that failed after the first page failed keeps its prompt',
    () async {
      server.on('GET', '/api/sessions/s1/messages', {
        'detail': 'boom',
      }, status: 500);
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();

      expect(await chat.submit('Continue', const []), isTrue);
      transport.sends.single
        ..emit(const ReplyCompleted('', failed: true, error: 'boom'))
        ..finish();
      await pumpEventQueue();
      expect(thread('s1').messages.last.status, MessageStatus.error);

      // Hermes never stored this prompt; an earlier one has the same words.
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Continue'),
          messageRow(id: 2, role: 'assistant', content: 'Done'),
        ]),
      );
      chat.select('s2');
      chat.select('s1');
      await pumpEventQueue();

      final messages = thread('s1').messages;
      expect(
        [for (final m in messages.take(3)) m.content],
        ['Continue', 'Done', 'Continue'],
      );
      expect(messages, hasLength(4));
      expect(messages.last.status, MessageStatus.error);
    },
  );

  test('a command run while the first page loads goes after it', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/sessions/s1/messages', (_) async {
      await gate.future;
      return (
        status: 200,
        body: messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Hello'),
        ]),
      );
    });
    await chat.loadThreads();
    chat.select('s1');

    final ran = chat.runSlashCommand('/usage');
    await pumpEventQueue();
    gate.complete();
    expect(await ran, isTrue);
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', '/usage', 'Done']);
  });

  test('a first page that arrives mid-reply is read once it ends', () async {
    server.on('GET', '/api/sessions/s1/messages', {
      'detail': 'boom',
    }, status: 500);
    await chat.loadThreads();
    chat.select('s1');
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);

    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 1, role: 'user', content: 'Hi'),
        messageRow(id: 2, role: 'assistant', content: 'Hello'),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Answer'),
      ]),
    );
    chat.select('s2');
    chat.select('s1');
    await pumpEventQueue();
    expect(contents('s1'), ['More', '']);

    transport.sends.single
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Answer']);
  });

  test('a profile switch while the first page loads drops the send', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/sessions/s1/messages', (_) async {
      await gate.future;
      return (status: 200, body: messageListBody('s1', []));
    });
    await chat.loadThreads();
    chat.select('s1');

    final sent = chat.submit('More', const []);
    await chat.loadThreads('work');
    gate.complete();

    expect(await sent, isFalse);
    expect(transport.sends, isEmpty);
  });

  test(
    'an older page read before the chat was read again is dropped',
    () async {
      var total = 130;
      Completer<void>? olderGate;
      server.onRequest('GET', '/api/sessions/s1/messages', (request) async {
        final limit = request.queryParameters['limit'] as int;
        final offset = request.queryParameters['offset'] as int;
        final newest = total - offset;
        final oldest = newest - limit + 1 < 1 ? 1 : newest - limit + 1;
        final body = messageListBody('s1', [
          for (var id = oldest; id <= newest; id++)
            messageRow(id: id, role: 'user', content: 'line $id'),
        ]);
        if (offset > 0) await olderGate?.future;
        return (status: 200, body: body);
      });
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();
      expect(chat.hasOlder('s1'), isTrue);

      olderGate = Completer<void>();
      final older = chat.loadOlder('s1');
      await pumpEventQueue();

      // Thirty messages arrive elsewhere and the chat is read again.
      total = 160;
      server.on(
        'GET',
        '/api/sessions/s1',
        sessionRow(id: 's1', title: 'Chat', lastActive: 1780000500),
      );
      await chat.refreshThread('s1');
      expect(contents('s1').first, 'line 61');

      olderGate.complete();
      await older;

      final ids = [
        for (final m in thread('s1').messages) int.parse(m.id.split('-').last),
      ];
      expect(ids, [for (var id = ids.first; id <= 160; id++) id]);
      expect(chat.hasOlder('s1'), isTrue);
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_queue_keys.dart';
import 'support/fake_queue_transport.dart';

const _scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'stored',
);

/// The chat list is read again for the profile in view while a turn runs in
/// a chat: the turn, its queue and the prompt a queued send put in the
/// transcript must come through, and `prompt.submit` must go out once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DurableQueueStore store;
  late FakeQueueTransport transport;
  late FakeHermesServer server;
  late AttentionNotifier attention;
  late ChatController chat;
  Completer<void>? listGate;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('reload-running-');
    store = DurableQueueStore(directory: directory, keys: FakeQueueKeys());
    transport = FakeQueueTransport();
    listGate = null;
    server = FakeHermesServer()
      ..onRequest('GET', '/api/sessions', (_) async {
        await listGate?.future;
        return (
          status: 200,
          body: sessionListBody([sessionRow(id: 'stored', title: 'Chat')]),
        );
      })
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Hello'),
        ]),
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
      report: (_) {},
      queueStore: () async => store,
      queueScope: (thread, profile) => QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: profile,
        conversationId: thread.id,
      ),
    );
    await chat.loadThreads('work');
    chat.select('stored');
    await pumpEventQueue();
  });

  tearDown(() async {
    if (listGate case final gate? when !gate.isCompleted) gate.complete();
    await pumpEventQueue();
    chat.dispose();
    attention.dispose();
    await directory.delete(recursive: true);
  });

  ChatThread thread() => chat.threads.singleWhere((t) => t.id == 'stored');
  List<String> contents() => [for (final m in thread().messages) m.content];

  Future<void> waitFor(bool Function() done, [String what = '']) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out $what');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('a queued send listed again before the server accepts it keeps its '
      'prompt text, and the prompt goes out once', () async {
    await store.commit(_scope, 'Queued text');
    await chat.loadThreads('work');
    chat.select('stored');
    await waitFor(() => !chat.queueBusy(thread()), 'restore');
    expect(chat.queueNeedsReview(thread()), isTrue);
    final running = thread();
    final gate = transport.acceptanceGate = Completer<void>();

    chat.sendQueued(running);
    await transport.prepared;
    await pumpEventQueue();
    await chat.loadThreads('work');
    await pumpEventQueue();
    expect(identical(thread(), running), isTrue);

    gate.complete();
    await waitFor(() => contents().contains('Queued text'), 'text');
    transport.sends.single
      ..emit(const ReplyCompleted('Done'))
      ..finish();
    await pumpEventQueue();

    expect(contents(), containsAllInOrder(['Hi', 'Hello', 'Queued text']));
    expect(contents().where((c) => c == 'Queued text'), hasLength(1));
    expect(transport.sends, hasLength(1));
  });

  test('a prompt queued behind the running turn still sends once the turn '
      'ends after the list was read again', () async {
    final first = chat.submit('First', const []);
    await pumpEventQueue();
    expect(await first, isTrue);
    final running = thread();
    expect(transport.sends, hasLength(1));
    await chat.submit('Next', const []);
    await waitFor(() => chat.queuedIn(running).isNotEmpty);

    await chat.loadThreads('work');
    await pumpEventQueue();
    expect(identical(thread(), running), isTrue);
    expect(chat.queuedIn(running).single.text, 'Next');
    expect(chat.queueNeedsReview(running), isFalse);

    transport.sends.first
      ..emit(const ReplyCompleted('One'))
      ..finish();
    await waitFor(() => transport.sends.length == 2);
    transport.sends.last
      ..emit(const ReplyCompleted('Two'))
      ..finish();
    await pumpEventQueue();

    expect(transport.sends.map((s) => s.text), ['First', 'Next']);
    expect(chat.queuedIn(running), isEmpty);
  });

  test('a turn that ends while the list is being read stays in the chat, '
      'selected, with its reply', () async {
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    final running = thread();
    send.emit(const ReplyDelta('Par'));
    await pumpEventQueue();

    final gate = listGate = Completer<void>();
    final loading = chat.loadThreads('work');
    await pumpEventQueue();
    send
      ..emit(const ReplyCompleted('Partial'))
      ..finish();
    await sent;
    await pumpEventQueue();
    gate.complete();
    await loading;
    await pumpEventQueue();

    expect(identical(thread(), running), isTrue);
    expect(chat.selectedThread, same(running));
    expect(contents(), ['Hi', 'Hello', 'More', 'Partial']);
    expect(transport.sends, hasLength(1));
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/live_activities/live_activities.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_live_activity_service.dart';

/// A chat sends at once, while its first page is still being read: what the
/// page holds is merged with what was sent, and must neither duplicate it nor
/// land below it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late _OwnedTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;

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
    transport = _OwnedTransport();
    attention = AttentionNotifier(
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

  /// Answers the chat's first page once [gate] completes.
  void gatePage(
    Completer<void> gate,
    List<Map<String, Object?>> Function() rows, {
    String id = 's1',
  }) {
    server.onRequest('GET', '/api/sessions/$id/messages', (_) async {
      await gate.future;
      return (status: 200, body: messageListBody(id, rows()));
    });
  }

  void page(List<Map<String, Object?>> rows, {String id = 's1'}) =>
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, rows));

  void pageFails() => server.on('GET', '/api/sessions/s1/messages', {
    'detail': 'boom',
  }, status: 500);

  /// The stored turn 1-2 every test starts from.
  List<Map<String, Object?>> history() => [
    messageRow(id: 1, role: 'user', content: 'Hi'),
    messageRow(id: 2, role: 'assistant', content: 'Hello'),
  ];

  Future<void> open() async {
    await chat.loadThreads('work');
    chat.select('s1');
  }

  /// Reads the first page again, as selecting the chat after another does.
  Future<void> reread() async {
    chat.select('s2');
    chat.select('s1');
    await pumpEventQueue();
  }

  void ack(FakeSend send, int row) => send.emit(
    PromptAcknowledged(
      row,
      runtimeId: transport.binding.runtimeId,
      connection: transport.binding.connection,
    ),
  );

  test('a prompt sent before the first page arrives is sent at once', () async {
    final gate = Completer<void>();
    gatePage(gate, history);
    await open();

    final sent = chat.submit('More', const []);
    await pumpEventQueue();

    expect(contents('s1'), ['More', '']);
    expect(thread('s1').messages.last.isPending, isTrue);
    expect(transport.sends.single.text, 'More');
    expect(transport.sends.single.threadId, 's1');

    gate.complete();
    expect(await sent, isTrue);
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', '']);
    expect(thread('s1').messages.map((m) => m.id).toSet(), hasLength(4));
    expect(transport.sends, hasLength(1));
  });

  test('the reply keeps streaming into its message when history lands '
      'above it', () async {
    final gate = Completer<void>();
    gatePage(gate, history);
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    final reply = thread('s1').messages.last;
    send.emit(const ReplyDelta('Par'));
    await pumpEventQueue();

    gate.complete();
    await sent;
    await pumpEventQueue();
    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Par']);
    expect(identical(thread('s1').messages.last, reply), isTrue);

    send
      ..emit(const ReplyDelta('tial'))
      ..emit(const ReplyCompleted('Partial'))
      ..finish();
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Partial']);
    expect(identical(thread('s1').messages.last, reply), isTrue);
    expect(reply.isPending, isFalse);
    expect(reply.status, isNot(MessageStatus.error));
  });

  test('a page that already holds the sent prompt shows it once', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Par'),
      ],
    );
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    ack(send, 3);
    send.emit(const ReplyDelta('Partial'));
    await pumpEventQueue();
    expect(thread('s1').messages.first.canonicalRow?.rowId, 3);

    gate.complete();
    await sent;
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Partial']);
    expect(thread('s1').messages.map((m) => m.id).toSet(), hasLength(4));
    send
      ..emit(const ReplyCompleted('Partial answer'))
      ..finish();
    await pumpEventQueue();
    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Partial answer']);
  });

  test('a turn that failed here but was stored and answered shows the stored '
      'answer once', () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    final send = transport.sends.single;
    ack(send, 3);
    await pumpEventQueue();
    send.fail();
    await pumpEventQueue();
    expect(thread('s1').messages.last.status, MessageStatus.error);

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(id: 4, role: 'assistant', content: 'Answer'),
    ]);
    await reread();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Answer']);
    expect(
      thread('s1').messages.where((m) => m.status == MessageStatus.error),
      isEmpty,
    );
  });

  test('a receipt after the page already held the prompt shows it once and '
      'branches from an earlier reply with one undo', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Par'),
      ],
    );
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;

    gate.complete();
    await sent;
    await pumpEventQueue();
    ack(send, 3);
    await pumpEventQueue();

    send
      ..emit(const ReplyCompleted('Partial answer'))
      ..finish();
    await pumpEventQueue();
    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Partial answer']);

    await chat.branch(thread('s1'), fromMessageId: 's1-2');
    expect(transport.branches, hasLength(1));
    expect(transport.branches.single.$3, 1);
  });

  test('a receipt after the page drops the stored copy and keeps the live '
      'reply', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Par'),
      ],
    );
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    final reply = thread('s1').messages.last;
    send.emit(const ReplyDelta('Partial'));
    await pumpEventQueue();

    gate.complete();
    await sent;
    await pumpEventQueue();
    ack(send, 3);
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Partial']);
    expect(identical(thread('s1').messages.last, reply), isTrue);
    expect(thread('s1').messages.map((m) => m.id).toSet(), hasLength(4));
    send.emit(const ReplyDelta(' more'));
    await pumpEventQueue();
    expect(reply.content, 'Partial more');
  });

  test('a receipt after the page puts the held turn where the stored copy '
      'was, above later turns', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Par'),
        messageRow(id: 5, role: 'user', content: 'Elsewhere'),
        messageRow(id: 6, role: 'assistant', content: 'Theirs'),
      ],
    );
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    final reply = thread('s1').messages.last;
    send.emit(const ReplyDelta('Partial'));
    await pumpEventQueue();

    gate.complete();
    await sent;
    await pumpEventQueue();
    ack(send, 3);
    await pumpEventQueue();

    expect(contents('s1'), [
      'Hi',
      'Hello',
      'More',
      'Partial',
      'Elsewhere',
      'Theirs',
    ]);
    expect(identical(thread('s1').messages[3], reply), isTrue);
    send.emit(const ReplyDelta(' more'));
    await pumpEventQueue();
    expect(reply.content, 'Partial more');

    send
      ..emit(const ReplyCompleted('Partial more'))
      ..finish();
    await pumpEventQueue();
    await chat.branch(thread('s1'), fromMessageId: 's1-6');
    expect(transport.branches.single.$3, 0);
  });

  test('a receipt after the chat was stored under a new id still shows the '
      'prompt once', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Par'),
      ],
    );
    page(history(), id: 's1b');
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;

    gate.complete();
    await sent;
    await pumpEventQueue();
    expect(thread('s1').messages.any((m) => m.id == 's1-3'), isTrue);
    send.emit(const SessionInfo(storedSessionId: 's1b'));
    await pumpEventQueue();
    ack(send, 3);
    await pumpEventQueue();

    expect(chat.selectedThread?.id, 's1b');
    expect(
      contents('s1b').where((c) => c == 'More'),
      hasLength(1),
      reason: contents('s1b').toString(),
    );
  });

  test('a failed turn is kept when its stored turn only calls tools', () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    final send = transport.sends.single;
    ack(send, 3);
    await pumpEventQueue();
    send.fail();
    await pumpEventQueue();

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(
        id: 4,
        role: 'assistant',
        toolCalls: [functionCall('terminal', '{"command":"ls"}')],
      ),
    ]);
    await reread();

    expect(
      thread('s1').messages.where(
        (m) => m.role == ChatRole.assistant && m.status == MessageStatus.error,
      ),
      hasLength(1),
    );
    expect(thread('s1').messages.where((m) => m.toolCalls.isNotEmpty), isEmpty);
  });

  test('a failed turn without a receipt is kept after the page', () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    transport.sends.single.fail();
    await pumpEventQueue();

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(id: 4, role: 'assistant', content: 'Answer'),
    ]);
    await reread();

    final messages = thread('s1').messages;
    expect(
      [for (final m in messages.take(4)) m.content],
      ['Hi', 'Hello', 'More', 'Answer'],
    );
    expect(messages, hasLength(6));
    expect(messages[4].content, 'More');
    expect(messages.last.status, MessageStatus.error);
  });

  test('a prompt answered after the first page failed is shown once with its '
      'receipt', () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    final send = transport.sends.single;
    ack(send, 3);
    send
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await pumpEventQueue();
    expect(contents('s1'), ['More', 'Answer']);

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(id: 4, role: 'assistant', content: 'Answer'),
    ]);
    await reread();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Answer']);
  });

  test('a prompt answered after the first page failed is kept after the '
      'page without a receipt', () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    transport.sends.single
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await pumpEventQueue();

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(id: 4, role: 'assistant', content: 'Answer'),
    ]);
    await reread();

    // Hermes may never have taken it: a repeat is shown, not hidden.
    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Answer', 'More', 'Answer']);
  });

  test(
    'a queued prompt that ran while the first page loaded is kept',
    () async {
      final gate = Completer<void>();
      gatePage(gate, history);
      await open();
      final first = chat.submit('First', const []);
      await pumpEventQueue();
      final queued = chat.submit('Second', const []);
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      transport.sends.first
        ..emit(const ReplyCompleted('One'))
        ..finish();
      await pumpEventQueue();
      // The queue waits for the session to settle before it sends.
      transport.followUpStreams['s1']!.emit(const SessionInfo(running: false));
      await pumpEventQueue();
      expect(transport.sends, hasLength(2));
      transport.sends.last
        ..emit(const ReplyCompleted('Two'))
        ..finish();
      await pumpEventQueue();
      expect(contents('s1'), ['First', 'One', 'Second', 'Two']);

      gate.complete();
      await first;
      await queued;
      await pumpEventQueue();

      expect(contents('s1'), ['Hi', 'Hello', 'First', 'One', 'Second', 'Two']);
    },
  );

  test('a command run while the first page loads keeps its lines', () async {
    final gate = Completer<void>();
    gatePage(gate, history);
    await open();

    final ran = chat.runSlashCommand('/usage');
    await pumpEventQueue();
    expect(contents('s1'), ['/usage', 'Done']);
    gate.complete();
    expect(await ran, isTrue);
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', '/usage', 'Done']);
  });

  test('a command that re-reads the chat keeps a reply still streaming and '
      'the lines only this app has', () async {
    page(history());
    await open();
    await pumpEventQueue();
    await chat.runSlashCommand('/usage');
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    ack(send, 3);
    send.emit(const ReplyDelta('Par'));
    await pumpEventQueue();
    final reply = thread('s1').messages.last;
    transport.slashResult = const SlashCommandResult(
      threadId: 's1',
      output: 'Undid',
      prefill: 'draft',
    );

    await chat.runSlashCommand('/undo');
    await pumpEventQueue();

    expect(contents('s1'), [
      'Hi',
      'Hello',
      '/usage',
      'Done',
      'More',
      'Par',
      '/undo',
      'Undid',
    ]);
    expect(identical(thread('s1').messages[5], reply), isTrue);
    send
      ..emit(const ReplyCompleted('Partial'))
      ..finish();
    await sent;
    await pumpEventQueue();
    expect(thread('s1').messages[5].content, 'Partial');
  });

  test('a command that undid a turn sent here removes it, and one older '
      'than the page is not shown twice', () async {
    page(history());
    await open();
    await pumpEventQueue();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    ack(send, 3);
    send
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await sent;
    await pumpEventQueue();
    transport.slashResult = const SlashCommandResult(
      threadId: 's1',
      output: 'Undid',
      prefill: 'More',
    );

    await chat.runSlashCommand('/undo');
    await pumpEventQueue();
    expect(contents('s1'), ['Hi', 'Hello', '/undo', 'Undid']);
  });

  test('a command that re-reads a chat whose page starts after a turn sent '
      'here does not keep that turn out of place', () async {
    page(history());
    await open();
    await pumpEventQueue();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    ack(send, 3);
    send
      ..emit(const ReplyCompleted('Answer'))
      ..finish();
    await sent;
    await pumpEventQueue();
    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 50, role: 'user', content: 'Later'),
        messageRow(id: 51, role: 'assistant', content: 'Reply'),
      ]),
    );
    transport.slashResult = const SlashCommandResult(
      threadId: 's1',
      output: 'Done',
      prefill: 'x',
    );

    await chat.runSlashCommand('/undo');
    await pumpEventQueue();

    expect(contents('s1'), ['Later', 'Reply', '/undo', 'Done']);
  });

  test('a command that undid a turn removes it from the chat', () async {
    page(history());
    await open();
    await pumpEventQueue();
    page([messageRow(id: 1, role: 'user', content: 'Hi')]);
    transport.slashResult = const SlashCommandResult(
      threadId: 's1',
      output: 'Undid',
      prefill: 'Hello',
    );

    await chat.runSlashCommand('/undo');
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', '/undo', 'Undid']);
  });

  test('listing the chats again keeps the turn that is running', () async {
    page(history());
    await open();
    await pumpEventQueue();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    send.emit(const ReplyDelta('Par'));
    await pumpEventQueue();
    final running = thread('s1');

    await chat.loadThreads('work');
    await pumpEventQueue();

    expect(chat.threads.where((t) => t.id == 's1'), hasLength(1));
    expect(identical(thread('s1'), running), isTrue);
    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Par']);
    expect(chat.selectedThread, same(running));
    send
      ..emit(const ReplyCompleted('Partial'))
      ..finish();
    await sent;
    await pumpEventQueue();
    expect(contents('s1').last, 'Partial');
  });

  test('a prompt sent into a chat stays in it when another is opened while '
      'its page loads', () async {
    final gate = Completer<void>();
    gatePage(gate, history);
    page([], id: 's2');
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();

    chat.select('s2');
    await pumpEventQueue();
    gate.complete();
    await sent;
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', '']);
    expect(contents('s2'), isEmpty);
    expect(transport.sends.single.threadId, 's1');
  });

  test('turns from another device go after the matched turn and before later '
      'ones', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Mine'),
        messageRow(id: 5, role: 'user', content: 'Elsewhere'),
        messageRow(id: 6, role: 'assistant', content: 'Theirs'),
      ],
    );
    await open();
    final first = chat.submit('More', const []);
    await pumpEventQueue();
    ack(transport.sends.first, 3);
    transport.sends.first
      ..emit(const ReplyCompleted('Mine'))
      ..finish();
    await pumpEventQueue();
    final second = chat.submit('Later', const []);
    await pumpEventQueue();
    transport.sends.last
      ..emit(const ReplyCompleted('Later answer'))
      ..finish();
    await pumpEventQueue();

    gate.complete();
    await first;
    await second;
    await pumpEventQueue();

    expect(contents('s1'), [
      'Hi',
      'Hello',
      'More',
      'Mine',
      'Elsewhere',
      'Theirs',
      'Later',
      'Later answer',
    ]);
    expect(thread('s1').messages.map((m) => m.id).toSet(), hasLength(8));
  });

  test(
    'a turn streaming in from another device goes below its prompt',
    () async {
      final gate = Completer<void>();
      gatePage(
        gate,
        () => [
          ...history(),
          messageRow(id: 3, role: 'user', content: 'More'),
          messageRow(id: 4, role: 'assistant', content: 'Mine'),
          messageRow(id: 5, role: 'user', content: 'Elsewhere'),
        ],
      );
      await open();
      final sent = chat.submit('More', const []);
      await pumpEventQueue();
      final send = transport.sends.single;
      ack(send, 3);
      send
        ..emit(const ReplyCompleted('Mine'))
        ..finish();
      await pumpEventQueue();
      final follow = transport.followUpStreams['s1']!;
      follow.emit(const SessionInfo(running: false));
      await pumpEventQueue();
      follow
        ..emit(const ReplyStarted())
        ..emit(const ReplyDelta('Theirs'));
      await pumpEventQueue();

      gate.complete();
      await sent;
      await pumpEventQueue();

      expect(contents('s1'), [
        'Hi',
        'Hello',
        'More',
        'Mine',
        'Elsewhere',
        'Theirs',
      ]);
    },
  );

  test('a failed turn is replaced by its stored answer while another '
      "device's reply streams after it", () async {
    pageFails();
    await open();
    await pumpEventQueue();
    expect(await chat.submit('More', const []), isTrue);
    final send = transport.sends.single;
    ack(send, 3);
    await pumpEventQueue();
    send.fail();
    await pumpEventQueue();
    final follow = transport.followUpStreams['s1']!;
    follow
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('Other rep'));
    await pumpEventQueue();
    final streaming = thread('s1').messages.last;

    page([
      ...history(),
      messageRow(id: 3, role: 'user', content: 'More'),
      messageRow(id: 4, role: 'assistant', content: 'Answer'),
      messageRow(id: 5, role: 'user', content: 'Elsewhere'),
    ]);
    await reread();

    expect(contents('s1'), [
      'Hi',
      'Hello',
      'More',
      'Answer',
      'Elsewhere',
      'Other rep',
    ]);
    expect(
      thread('s1').messages.where((m) => m.status == MessageStatus.error),
      isEmpty,
    );
    expect(identical(thread('s1').messages.last, streaming), isTrue);
    follow.emit(const ReplyDelta('ly'));
    await pumpEventQueue();
    expect(streaming.content, 'Other reply');
    expect(identical(thread('s1').messages.last, streaming), isTrue);
  });

  test('a chat stored under a new id while its page loads gets its history '
      'under that id', () async {
    final gate = Completer<void>();
    gatePage(gate, history);
    page(history(), id: 's1b');
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    transport.sends.single.emit(const SessionInfo(storedSessionId: 's1b'));
    await pumpEventQueue();

    gate.complete();
    await sent;
    await pumpEventQueue();

    expect(chat.selectedThread?.id, 's1b');
    expect(contents('s1b'), ['Hi', 'Hello', 'More', '']);
  });

  test('rows the page holds after a matched turn, such as an automatic '
      'continuation, stay after it', () async {
    final gate = Completer<void>();
    gatePage(
      gate,
      () => [
        ...history(),
        messageRow(id: 3, role: 'user', content: 'More'),
        messageRow(id: 4, role: 'assistant', content: 'Mine'),
        {
          ...messageRow(id: 5, role: 'user', content: 'auto'),
          'display_kind': 'auto_continue',
        },
        messageRow(id: 6, role: 'assistant', content: 'Cont'),
      ],
    );
    await open();
    final sent = chat.submit('More', const []);
    await pumpEventQueue();
    final send = transport.sends.single;
    ack(send, 3);
    send
      ..emit(const ReplyCompleted('Mine'))
      ..finish();
    await pumpEventQueue();

    gate.complete();
    await sent;
    await pumpEventQueue();

    expect(contents('s1'), ['Hi', 'Hello', 'More', 'Mine', 'auto', 'Cont']);
  });

  testWidgets('a Live Activity starts on the tap, before the page arrives', (
    tester,
  ) async {
    final service = FakeLiveActivityService();
    final settings = NotificationSettings();
    await tester.runAsync(settings.load);
    final activities = LiveActivities(service: service, settings: settings);
    final gate = Completer<void>();
    gatePage(gate, history);
    final live = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      liveActivities: activities,
      report: (_) {},
    );
    addTearDown(activities.dispose);
    await tester.runAsync(live.loadThreads);
    live.select('s1');
    live.submit('Any news?', const []);
    await tester.pump();

    expect(service.running, hasLength(1));
    await tester.runAsync(() async {
      gate.complete();
      await pumpEventQueue();
    });
    live.dispose();
    await tester.pump(const Duration(minutes: 5));
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

/// A transport that owns every session, so prompt receipts are accepted.
class _OwnedTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  final binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'rt',
    profile: 'work',
  );
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);

  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      profile == binding.profile ? binding : null;

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw UnsupportedError(method);

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}

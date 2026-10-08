import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';

/// A controller with a fake transport, and the calls the tests make on it.
class Rig {
  Rig({HermesChatRepository? repository})
    : transport = FakeChatTransport(),
      _attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      ) {
    chat = ChatController(
      repository: repository,
      transport: transport,
      attention: _attention,
      report: reports.add,
    );
  }

  late final ChatController chat;
  final FakeChatTransport transport;
  final reports = <String>[];
  final AttentionNotifier _attention;

  /// Sends [text] in a new thread whose stored id is [id].
  (ChatThread, FakeSend) start(String text, {String id = 's1'}) {
    chat.newThread();
    chat.submit(text, const []);
    final send = transport.sends.last..emit(ThreadBound(id));
    return (chat.selectedThread!, send);
  }

  /// Ends [send] with a completion, as the server does.
  void complete(FakeSend send, {String text = 'Done.'}) {
    send
      ..emit(ReplyCompleted(text))
      ..finish();
  }

  /// The follow-up stream of thread [id], which the controller listens to once
  /// the reply of its send ended.
  FakeFollowUps followUp([String id = 's1']) => transport.followUpStreams[id]!;

  List<String> get sentTexts => [for (final s in transport.sends) s.text];

  void dispose() {
    chat.dispose();
    _attention.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Queued messages', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    test('Sent only once the session settled: a queued message is not sent on '
        'ReplyCompleted', () async {
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.chat.submit('Two', const []);

      rig.complete(first);
      await pumpEventQueue();

      expect(rig.sentTexts, ['One']);
      expect(rig.chat.queuedIn(thread), hasLength(1));
    });

    test('Sent only once the session settled: sent when the follow-ups report '
        'running false, flagged queued', () async {
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.chat.submit('Two', const []);
      rig.complete(first);
      await pumpEventQueue();

      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(rig.sentTexts, ['One', 'Two']);
      expect(rig.transport.sends.last.queued, isTrue);
      expect(rig.transport.sends.last.threadId, 's1');
      expect(rig.chat.queuedIn(thread), isEmpty);
    });

    test('Sent only once the session settled: running true or unknown does not '
        'send the queued message', () async {
      final (_, first) = rig.start('One');
      await pumpEventQueue();
      rig.chat.submit('Two', const []);
      rig.complete(first);
      await pumpEventQueue();

      rig.followUp()
        ..emit(const SessionInfo(running: true))
        ..emit(const SessionInfo());
      await pumpEventQueue();

      expect(rig.sentTexts, ['One']);
    });

    test(
      'Sent only once the session settled: a direct send is not flagged queued',
      () async {
        final (_, first) = rig.start('One');
        await pumpEventQueue();
        rig.complete(first);
        await pumpEventQueue();
        rig.followUp().emit(const SessionInfo(running: false));
        await pumpEventQueue();

        rig.chat.submit('Two', const []);

        expect(rig.sentTexts, ['One', 'Two']);
        expect(rig.transport.sends.last.queued, isFalse);
      },
    );

    test(
      'Sent only once the session settled: a settle report sends the message '
      'once, and the 2 s fallback does not repeat it',
      () {
        fakeAsync((async) {
          final rig = Rig();
          final (_, first) = rig.start('One');
          async.flushMicrotasks();
          rig.chat.submit('Two', const []);
          rig.complete(first);
          async.flushMicrotasks();

          rig.followUp().emit(const SessionInfo(running: false));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 3));

          expect(rig.sentTexts, ['One', 'Two']);
          rig.dispose();
        });
      },
    );

    test('Sent only once the session settled: after 2 s when no settle report '
        'comes', () {
      fakeAsync((async) {
        final rig = Rig();
        final (_, first) = rig.start('One');
        async.flushMicrotasks();
        rig.chat.submit('Two', const []);
        rig.complete(first);
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1999));
        expect(rig.sentTexts, ['One']);

        async.elapse(const Duration(milliseconds: 1));
        expect(rig.sentTexts, ['One', 'Two']);
        expect(rig.transport.sends.last.queued, isTrue);
        rig.dispose();
      });
    });
  });

  group('Folded into the running turn', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    test(
      'Folded into the running turn: PromptFolded removes the placeholder '
      'without marking it failed, and the running turn is still followed',
      () async {
        final (thread, send) = rig.start('One');
        await pumpEventQueue();

        send
          ..emit(const PromptFolded())
          ..finish();
        await pumpEventQueue();

        expect(thread.messages.map((m) => m.role), [ChatRole.user]);
        expect(thread.messages.single.content, 'One');
        expect(thread.isReplying, isFalse);
        expect(rig.chat.controllerFor(thread).messages, hasLength(1));
        expect(rig.reports, isEmpty);
        expect(rig.transport.followUpStreams['s1'], isNotNull);
      },
    );
  });

  group('Settled without a completion', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    test(
      'Settled without a completion: a completion arriving later lands on the '
      'same reply',
      () async {
        final (thread, send) = rig.start('One');
        await pumpEventQueue();
        send.emit(const SessionInfo(running: false));
        await pumpEventQueue();
        // The reducer settles the reply on that report; set it here so this
        // test does not depend on the reducer.
        final reply = thread.messages.last
          ..status = MessageStatus.sent
          ..settledWithoutCompletion = true;
        send.finish();
        await pumpEventQueue();

        rig.followUp().emit(const ReplyCompleted('final'));
        await pumpEventQueue();

        final replies = [
          for (final m in thread.messages)
            if (m.role == ChatRole.assistant) m,
        ];
        expect(replies, hasLength(1));
        expect(identical(replies.single, reply), isTrue);
        expect(reply.content, 'final');
        expect(thread.isReplying, isFalse);
      },
    );
  });

  group('Missed start of a chained turn', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    test('Missed start of a chained turn: a delta on follow-ups with no reply '
        'open opens one', () async {
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.complete(first);
      await pumpEventQueue();

      rig.followUp().emit(const ReplyDelta('Next'));
      await pumpEventQueue();

      expect(thread.messages, hasLength(3));
      expect(thread.messages.last.role, ChatRole.assistant);
      expect(thread.isReplying, isTrue);
    });

    test('Missed start of a chained turn: a tool start on follow-ups with no '
        'reply open opens one', () async {
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.complete(first);
      await pumpEventQueue();

      rig.followUp().emit(const ToolStarted(name: 'terminal', id: 't1'));
      await pumpEventQueue();

      expect(thread.messages, hasLength(3));
      expect(thread.messages.last.toolCalls, isNotEmpty);
      expect(thread.isReplying, isTrue);
    });
  });

  group('Stop while the interrupt is in flight', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    /// A chained turn is replying on follow-ups, and 'Two' waits behind it.
    Future<ChatThread> replyingWithQueue() async {
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.complete(first);
      await pumpEventQueue();
      rig.followUp().emit(const ReplyDelta('Next'));
      await pumpEventQueue();
      rig.chat.submit('Two', const []);
      return thread;
    }

    test('an idle report before the interrupt answers is the stop: the queue '
        'stays paused', () async {
      final thread = await replyingWithQueue();
      final gate = rig.transport.stopGate = Completer<void>();

      final stopping = rig.chat.stopReply(thread);
      await pumpEventQueue();
      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();
      expect(rig.sentTexts, ['One']);
      expect(rig.chat.queuedIn(thread), isNotEmpty);

      // The user sends by hand while the answer is still held; the answer
      // then belongs to the turn before, not to this reply.
      rig.chat.sendQueued(thread);
      rig.chat.submit('Three', const []);
      final second = rig.transport.sends.last;
      gate.complete();
      await stopping;
      rig.complete(second);
      await pumpEventQueue();
      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(rig.sentTexts, ['One', 'Two', 'Three']);
    });

    test('a completion before the interrupt answers does not leave the mark '
        'for the next reply', () async {
      final thread = await replyingWithQueue();
      final gate = rig.transport.stopGate = Completer<void>();

      final stopping = rig.chat.stopReply(thread);
      await pumpEventQueue();
      rig.followUp().emit(const ReplyCompleted('Next.', stopped: true));
      await pumpEventQueue();

      rig.chat.sendQueued(thread);
      rig.chat.submit('Three', const []);
      final second = rig.transport.sends.last;
      gate.complete();
      await stopping;
      rig.complete(second);
      await pumpEventQueue();
      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(second.text, 'Two');
      expect(rig.sentTexts, ['One', 'Two', 'Three']);
    });

    test('a stop that fails clears the mark: the next settle sends the '
        'queue', () async {
      final thread = await replyingWithQueue();
      rig.transport.answerError = Exception('offline');

      await rig.chat.stopReply(thread);
      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(rig.sentTexts, ['One', 'Two']);
    });

    test('a first stop that fails leaves the mark of the second one in '
        'flight', () async {
      final thread = await replyingWithQueue();
      final first = Completer<bool>();
      final second = Completer<bool>();
      final answers = [first, second];
      rig.transport.onStop = (_) => answers.removeAt(0).future;

      final stopA = rig.chat.stopReply(thread);
      final stopB = rig.chat.stopReply(thread);
      first.completeError(Exception('offline'));
      await stopA;
      rig.followUp().emit(const SessionInfo(running: false));
      await pumpEventQueue();
      second.complete(true);
      await stopB;

      expect(rig.sentTexts, ['One']);
    });
  });

  group('Compression rotates the stored id', () {
    late Rig rig;

    setUp(() {
      rig = Rig();
    });

    tearDown(() => rig.dispose());

    test(
      'Compression rotates the stored id: on the send stream the reply keeps '
      'streaming and the next send resumes the new id',
      () async {
        final (thread, send) = rig.start('One', id: 'stored-1');
        await pumpEventQueue();
        send.emit(const ReplyDelta('Hi'));
        await pumpEventQueue();

        send.emit(
          const SessionInfo(running: true, storedSessionId: 'stored-2'),
        );
        await pumpEventQueue();

        expect(thread.id, 'stored-2');
        expect(rig.chat.selectedId, 'stored-2');
        expect(thread.title, 'One');
        expect(thread.messages, hasLength(2));
        expect(thread.isReplying, isTrue);

        rig.complete(send, text: 'Hi there');
        await pumpEventQueue();
        rig.chat.submit('Two', const []);

        expect(rig.transport.sends.last.threadId, 'stored-2');
      },
    );

    test(
      'Compression rotates the stored id: on follow-ups after the reply, the '
      'next send resumes the new id',
      () async {
        final (thread, first) = rig.start('One', id: 'stored-1');
        await pumpEventQueue();
        rig.complete(first);
        await pumpEventQueue();

        rig.transport.followUpStreams['stored-1']!.emit(
          const SessionInfo(running: false, storedSessionId: 'stored-2'),
        );
        await pumpEventQueue();

        expect(thread.id, 'stored-2');
        expect(thread.messages, hasLength(2));
        rig.chat.submit('Two', const []);
        expect(rig.transport.sends.last.threadId, 'stored-2');
      },
    );

    test('Compression rotates the stored id: the same id as the thread '
        'changes nothing', () async {
      final (thread, send) = rig.start('One');
      await pumpEventQueue();

      send.emit(const SessionInfo(running: true, storedSessionId: 's1'));
      await pumpEventQueue();

      expect(thread.id, 's1');
      expect(rig.chat.selectedId, 's1');
      expect(thread.isReplying, isTrue);
      expect(rig.transport.sends, hasLength(1));
    });
  });

  group('Thread refetch', () {
    late FakeHermesServer server;
    late Rig rig;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 's1', title: 'Old title', lastActive: 1780000100),
          ]),
        )
        ..on(
          'GET',
          '/api/sessions/s1',
          sessionRow(id: 's1', title: 'Old title', lastActive: 1780000100),
        )
        ..on(
          'GET',
          '/api/sessions/s1/messages',
          messageListBody('s1', [
            messageRow(id: 1, role: 'user', content: 'Hi'),
          ]),
        );
      rig = Rig(
        repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
      );
      await rig.chat.loadThreads();
      rig.chat.select('s1');
      await pumpEventQueue();
    });

    tearDown(() => rig.dispose());

    test(
      'ThreadNeedsRefetch on the send stream reads the thread once the reply '
      'is no longer pending',
      () async {
        rig.chat.submit('Plan', const []);
        final send = rig.transport.sends.last..emit(const ThreadNeedsRefetch());
        await pumpEventQueue();
        expect(server.requestsTo('GET', '/api/sessions/s1'), isEmpty);

        rig.complete(send);
        await pumpEventQueue();

        expect(server.requestsTo('GET', '/api/sessions/s1'), hasLength(1));
      },
    );

    test(
      'ThreadNeedsRefetch on follow-ups with no reply open reads the thread at '
      'once',
      () async {
        rig.chat.submit('Plan', const []);
        rig.complete(rig.transport.sends.last);
        await pumpEventQueue();

        rig.followUp().emit(const ThreadNeedsRefetch());
        await pumpEventQueue();

        expect(server.requestsTo('GET', '/api/sessions/s1'), hasLength(1));
      },
    );
  });
}

import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

/// A reply whose turn the server no longer has is settled once, with a notice
/// that says what is true, and the queue follows the rule after any failed
/// reply. `prompt.submit` is never sent twice by any of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late List<String> reports;
  late ChatController chat;
  late ChatThread thread;
  late FakeSend send;

  setUp(() {
    transport = FakeChatTransport();
    reports = [];
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: reports.add,
      reconnectRetry: const Duration(hours: 1),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  /// A prompt answered, with text and one tool call still running.
  Future<void> startTurn() async {
    chat.newThread();
    thread = chat.selectedThread!;
    expect(chat.submit('Run the build', const []), isTrue);
    send = transport.sends.single;
    send
      ..emit(const ThreadBound('s1'))
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Starting the build. '))
      ..emit(const ToolStarted(name: 'terminal', id: 't1', summary: 'make'));
    await pumpEventQueue();
  }

  ChatMessage assistant() =>
      thread.messages.lastWhere((m) => m.role == ChatRole.assistant);

  int assistantCount() =>
      thread.messages.where((m) => m.role == ChatRole.assistant).length;

  Future<void> lose(Object error) async {
    send.fail(error);
    await pumpEventQueue();
  }

  void expectOneSubmit() => expect(transport.sends, hasLength(1));

  /// The one note a settled reply shows, and no error text beside it.
  void expectNote(ChatMessage reply, ReplyLoss loss) {
    final shown = chatMessageToFlyer(reply)
        .whereType<TextMessage>()
        .firstWhere((m) => m.id == reply.id);
    expect(shown.metadata?[kMetaLoss], loss.name);
    expect(shown.metadata?[kMetaError], isNull);
    expect(
      chatMessageToFlyer(reply)
          .whereType<CustomMessage>()
          .any((m) => m.metadata?[kMetaKind] == kKindReconnecting),
      isFalse,
    );
  }

  group('a send that ends because the server no longer has the turn', () {
    for (final (name, error, loss) in <(String, Object, ReplyLoss)>[
      (
        'a session it answers is not found',
        const GatewaySessionGone(4007),
        ReplyLoss.notOnServer,
      ),
      (
        'a session gone after a restart',
        const GatewaySessionGone(4007, restarted: true),
        ReplyLoss.restarted,
      ),
      (
        'a turn found over after a restart with nothing to show',
        const GatewayTurnEnded(restarted: true),
        ReplyLoss.restarted,
      ),
      (
        'a server that could not be made to say',
        const GatewayReplyUnconfirmed(),
        ReplyLoss.unconfirmed,
      ),
      (
        'a refusal read through the step it came at',
        SendFailure(SendStep.reply, GatewaySessionGone(4007)),
        ReplyLoss.notOnServer,
      ),
    ]) {
      test('$name settles the reply once, in its own bubble', () async {
        await startTurn();
        final reply = assistant();
        await lose(error);

        expect(assistantCount(), 1);
        expect(identical(assistant(), reply), isTrue);
        expect(reply.status, MessageStatus.error);
        expect(reply.loss, loss);
        expect(reply.error, isNull);
        expect(reply.reconnecting, isFalse);
        expect(reply.isPending, isFalse);
        // What streamed stays.
        expect(reply.sealedProse.single.text, 'Starting the build. ');
        // The running call is settled by that, not marked failed.
        expect(reply.toolCalls.single.status, ToolCallStatus.cancelled);
        // Stop goes: nothing is replying any more.
        expect(thread.isReplying, isFalse);
        expectNote(reply, loss);
        expectOneSubmit();
      });
    }

    test('a turn found over with nothing to show, and no restart, is a plain '
        'failure still', () async {
      await startTurn();
      await lose(const GatewayTurnEnded());

      expect(assistant().status, MessageStatus.error);
      expect(assistant().loss, isNull);
      expect(assistant().error, kReplyFailedMessage);
      expect(assistant().toolCalls.single.status, ToolCallStatus.error);
      expectOneSubmit();
    });

    test('a reply that waited for a reconnect and then hears the server '
        'restarted settles in the same bubble', () async {
      await startTurn();
      await lose(const GatewayReplyLost());
      final reply = assistant();
      expect(reply.reconnecting, isTrue);

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.fail(
        const GatewaySessionGone(4007, restarted: true),
      );
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(identical(assistant(), reply), isTrue);
      expect(reply.loss, ReplyLoss.restarted);
      expect(reply.reconnecting, isFalse);
      expect(reply.reconnectIdle, isFalse);
      expect(thread.isReplying, isFalse);
      expectNote(reply, ReplyLoss.restarted);
      expectOneSubmit();
    });

    test('a completion that still reaches the reply wins over the note', () {
      final reply = ChatMessage(
        id: 'm1',
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime(2026),
        status: MessageStatus.streaming,
      );
      settleLost(reply, ReplyLoss.unconfirmed);
      expect(reply.loss, ReplyLoss.unconfirmed);

      applyReplyEvent(reply, const ReplyCompleted('Built.'));

      expect(reply.loss, isNull);
      expect(reply.status, MessageStatus.sent);
      expect(reply.content, 'Built.');
    });
  });

  group('the queue after a reply the server lost', () {
    test(
      'is paused: the prompt is kept and nothing is sent by itself',
      () async {
        await startTurn();
        chat.submit('And then deploy', const []);
        await pumpEventQueue();
        expect(chat.queuedIn(thread), hasLength(1));

        await lose(const GatewaySessionGone(4007, restarted: true));
        await pumpEventQueue();

        expectOneSubmit();
        expect(chat.queuedIn(thread).single.text, 'And then deploy');
        expect(chat.queuePaused(thread), isTrue);
      },
    );

    test('is the same as after a failed reply', () async {
      await startTurn();
      chat.submit('And then deploy', const []);
      await pumpEventQueue();
      await lose(StateError('boom'));
      final afterFailure = (
        chat.queuedIn(thread).length,
        chat.queuePaused(thread),
        transport.sends.length,
      );

      // A second chat, ended by a lost turn instead.
      chat.newThread();
      thread = chat.selectedThread!;
      chat.submit('Second', const []);
      send = transport.sends.last;
      send
        ..emit(const ThreadBound('s2'))
        ..emit(const PromptAcknowledged(1))
        ..emit(const ReplyDelta('Working. '));
      await pumpEventQueue();
      chat.submit('And then deploy', const []);
      await pumpEventQueue();
      await lose(const GatewaySessionGone(4007));
      await pumpEventQueue();

      expect(chat.queuedIn(thread).length, afterFailure.$1);
      expect(chat.queuePaused(thread), afterFailure.$2);
      // Two chats, two prompts: the queued ones were never sent.
      expect(transport.sends, hasLength(2));
      expect(transport.sends.map((s) => s.text), ['Run the build', 'Second']);
    });
  });

  group('Stop when the server answers that it has no turn to stop', () {
    test('the interrupt answered 4001 after a restart settles the reply with '
        'the honest note, and Stop goes', () async {
      await startTurn();
      transport.onStop = (_) async =>
          throw const GatewaySessionGone(4001, restarted: true);

      await chat.stopReply(thread);
      await pumpEventQueue();

      final reply = assistant();
      expect(reply.loss, ReplyLoss.restarted);
      expect(reply.isPending, isFalse);
      expect(thread.isReplying, isFalse);
      // Stop never marks success on its own.
      expect(reply.stopped, isFalse);
      expect(reply.status, MessageStatus.error);
      expect(reply.toolCalls.single.status, ToolCallStatus.cancelled);
      expect(reports, isEmpty);
      expectNote(reply, ReplyLoss.restarted);
      expectOneSubmit();
    });

    test(
      '4001 with no restart says the reply is no longer on the server',
      () async {
        await startTurn();
        transport.onStop = (_) async => throw const GatewaySessionGone(4001);

        await chat.stopReply(thread);
        await pumpEventQueue();

        expect(assistant().loss, ReplyLoss.notOnServer);
        expect(thread.isReplying, isFalse);
        expectOneSubmit();
      },
    );

    test(
      'a reply that waits for a reconnect settles too, and its timer goes',
      () async {
        await startTurn();
        await lose(const GatewayReplyLost());
        expect(assistant().reconnecting, isTrue);
        transport.onStop = (_) async => throw const GatewaySessionGone(4007);

        await chat.stopReply(thread);
        await pumpEventQueue();

        expect(assistant().loss, ReplyLoss.notOnServer);
        expect(assistant().reconnecting, isFalse);
        expect(thread.isReplying, isFalse);
        expectOneSubmit();
      },
    );

    test(
      'a queued prompt stays queued and is not sent by the settle',
      () async {
        await startTurn();
        chat.submit('And then deploy', const []);
        await pumpEventQueue();
        transport.onStop = (_) async => throw const GatewaySessionGone(4001);

        await chat.stopReply(thread);
        await pumpEventQueue();

        expectOneSubmit();
        expect(chat.queuedIn(thread), hasLength(1));
        expect(chat.queuePaused(thread), isTrue);
      },
    );

    test(
      'a stop that did not get through settles nothing and is said',
      () async {
        await startTurn();
        transport.onStop = (_) async => throw const GatewayConnectionClosed();

        await chat.stopReply(thread);
        await pumpEventQueue();

        final reply = assistant();
        expect(reply.isPending, isTrue);
        expect(reply.loss, isNull);
        expect(reply.stopped, isFalse);
        expect(reply.status, isNot(MessageStatus.sent));
        expect(reply.toolCalls.single.status, ToolCallStatus.running);
        expect(reports, hasLength(1));
        // The stop is there to be tried again.
        expect(thread.isReplying, isTrue);
        expectOneSubmit();
      },
    );

    test('a stop that timed out does not hold the queue for good', () async {
      await startTurn();
      chat.submit('And then deploy', const []);
      await pumpEventQueue();
      transport.onStop = (_) async => throw const GatewayConnectionClosed();

      await chat.stopReply(thread);
      await pumpEventQueue();

      // The turn is still the server's; the queue goes on with its own end.
      send
        ..emit(const ReplyCompleted('Built.'))
        ..finish();
      await pumpEventQueue();
      expect(assistant().status, MessageStatus.sent);
    });
  });

  group('the continued turn after a restart goes into the same reply', () {
    test('settles the old calls as ended and takes the re-run in', () async {
      await startTurn();
      await lose(const GatewayReplyLost());
      final reply = assistant();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyRebuilt('', continued: true))
        ..emit(const ReplyDelta('Starting again. '))
        ..emit(const ReplyCompleted('Starting again. Done.'));
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(identical(assistant(), reply), isTrue);
      expect(reply.loss, isNull);
      expect(reply.status, MessageStatus.sent);
      expect(reply.content, 'Starting again. Done.');
      expect(reply.toolCalls.single.status, ToolCallStatus.cancelled);
      expect(reply.reconnecting, isFalse);
      expect(thread.isReplying, isFalse);
      expectOneSubmit();
    });

    test('is not settled as lost', () async {
      await startTurn();
      await lose(const GatewayReplyLost());

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyRebuilt('', continued: true));
      await pumpEventQueue();

      expect(assistant().isPending, isTrue);
      expect(assistant().loss, isNull);
      expect(assistant().reconnecting, isFalse);
      expectOneSubmit();
    });
  });
}

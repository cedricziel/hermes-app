import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart' show AgentNotice;
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

/// A reply whose connection drops while the server may still run its turn is
/// not failed: it says so, keeps what it had, and the turn is picked up again
/// into the same bubble. `prompt.submit` is never sent twice by any of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late List<String> reports;
  late ChatController chat;
  late ChatThread thread;
  late FakeSend send;

  ChatController build({Duration retry = const Duration(hours: 1)}) {
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final controller = ChatController(
      transport: transport,
      attention: attention,
      report: reports.add,
      reconnectRetry: retry,
    );
    addTearDown(() {
      controller.dispose();
      attention.dispose();
    });
    return controller;
  }

  /// A prompt sent, answered, with some text and a tool call still running.
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

  Future<void> lose([Object error = const GatewayConnectionClosed()]) async {
    send.fail(error);
    await pumpEventQueue();
  }

  /// The submit count every test ends on: nothing is ever sent again.
  void expectOneSubmit() => expect(transport.sends, hasLength(1));

  setUp(() {
    transport = FakeChatTransport();
    reports = [];
    chat = build();
  });

  group('the connection is lost while the server runs the turn', () {
    test('the reply is not failed and keeps its running tool call', () async {
      await startTurn();
      await lose();

      final reply = assistant();
      expect(reply.reconnecting, isTrue);
      expect(reply.isPending, isTrue);
      expect(reply.error, isNull);
      expect(reply.status, isNot(MessageStatus.error));
      expect(reply.sealedProse.single.text, 'Starting the build. ');
      expect(reply.toolCalls.single.status, ToolCallStatus.running);
      expect(thread.isReplying, isTrue);
      expect(reports, isEmpty);
      expectOneSubmit();
    });

    test('it says so with a note, and not with an error', () async {
      await startTurn();
      await lose();

      final shown = chatMessageToFlyer(assistant());
      final kinds = [
        for (final m in shown.whereType<CustomMessage>())
          m.metadata?[kMetaKind],
      ];
      expect(kinds, contains(kKindReconnecting));
      expect(
        shown.whereType<TextMessage>().any(
          (m) => m.metadata?[kMetaError] != null,
        ),
        isFalse,
      );
      expectOneSubmit();
    });

    test('the queue holds: a message typed now is not sent', () async {
      await startTurn();
      await lose();

      chat.submit('And then deploy', const []);
      await pumpEventQueue();

      expectOneSubmit();
      expect(assistant().reconnecting, isTrue);
    });

    test('Retry and Edit are not offered while the turn runs', () async {
      await startTurn();
      await lose();

      expect(chat.canEditLastPrompt(thread), isFalse);
      expectOneSubmit();
    });

    test('Stop stays available and asks the server', () async {
      await startTurn();
      await lose();

      await chat.stopReply(thread);

      expect(transport.stops, ['s1']);
      expect(assistant().error, isNull);
      expectOneSubmit();
    });

    test('a loss before the server had the prompt still fails', () async {
      chat.newThread();
      thread = chat.selectedThread!;
      chat.submit('Hello', const []);
      send = transport.sends.single;
      send.emit(const ThreadBound('s1'));
      await pumpEventQueue();
      await lose();

      expect(assistant().status, MessageStatus.error);
      expect(assistant().error, kReplyFailedMessage);
      expect(assistant().reconnecting, isFalse);
      expectOneSubmit();
    });
  });

  group('the connection is won back while the server still runs the turn', () {
    test('the same bubble goes on and the notice clears', () async {
      await startTurn();
      await lose();
      final reply = assistant();

      chat.checkConnection();
      await pumpEventQueue();
      final follow = transport.followUpStreams['s1']!;
      follow
        ..emit(const ReplyStarted())
        ..emit(const ReplyRebuilt('Starting the build. Compiling'));
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(identical(assistant(), reply), isTrue);
      expect(reply.reconnecting, isFalse);
      expect(reply.error, isNull);
      expect(reply.content, contains('Compiling'));
      expect(reply.toolCalls.single.status, ToolCallStatus.running);

      follow
        ..emit(const ToolFinished(name: 'terminal', id: 't1'))
        ..emit(const ReplyDelta(' Done.'))
        ..emit(const ReplyCompleted('Starting the build. Done.'));
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(reply.status, MessageStatus.sent);
      expect(reply.toolCalls.single.status, ToolCallStatus.completed);
      expect(thread.isReplying, isFalse);
      expectOneSubmit();
    });

    test('a request the server asks again is not shown twice', () async {
      await startTurn();
      const request = ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: 'Delete the build folder',
        choices: ['once', 'deny'],
        toolName: 'terminal',
      );
      send.emit(const ApprovalRequested(request));
      await pumpEventQueue();
      await lose();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ApprovalRequested(request));
      await pumpEventQueue();

      expect(assistant().inputRequests, hasLength(1));
      expectOneSubmit();
    });

    test('opening the chat picks it up without a second bubble', () async {
      await startTurn();
      await lose();
      final before = transport.followUpCalls;

      chat.select('s1');
      await pumpEventQueue();

      expect(transport.followUpCalls, greaterThan(before));
      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyRebuilt('Starting the build. More'));
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(assistant().reconnecting, isFalse);
      expect(assistant().content, contains('More'));
      expectOneSubmit();
    });

    test('a stop that reached the server picks the turn up at once', () async {
      await startTurn();
      await lose();
      final before = transport.followUpCalls;

      await chat.stopReply(thread);
      await pumpEventQueue();

      expect(transport.followUpCalls, greaterThan(before));
      transport.followUpStreams['s1']!.emit(
        const ReplyCompleted('Starting the build.', stopped: true),
      );
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(assistant().stopped, isTrue);
      expect(assistant().status, MessageStatus.sent);
      expectOneSubmit();
    });

    test(
      'the next try comes by itself while the chat stays in front',
      () async {
        chat = build(retry: const Duration(milliseconds: 20));
        await startTurn();
        await lose();
        final before = transport.followUpCalls;

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(transport.followUpCalls, greaterThan(before));
        expect(assistant().reconnecting, isTrue);
        expectOneSubmit();
      },
    );
  });

  group('the turn ended while the connection was away', () {
    test('the finished reply lands in the same bubble', () async {
      await startTurn();
      await lose();
      final reply = assistant();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!
        ..emit(const ThreadNeedsRefetch())
        ..emit(const ReplyCompleted('The build finished: 0 errors.'));
      await pumpEventQueue();

      expect(assistantCount(), 1);
      expect(identical(assistant(), reply), isTrue);
      expect(reply.content, 'The build finished: 0 errors.');
      expect(reply.reconnecting, isFalse);
      expect(reply.status, MessageStatus.sent);
      expect(reply.toolCalls.single.status, ToolCallStatus.completed);
      expect(thread.isReplying, isFalse);
      expectOneSubmit();
    });
  });

  group('still out of reach', () {
    test('a pick-up that cannot connect leaves the notice up', () async {
      await startTurn();
      await lose();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.fail(const GatewayConnectionClosed());
      await pumpEventQueue();

      final reply = assistant();
      expect(reply.reconnecting, isTrue);
      expect(reply.error, isNull);
      expect(reply.toolCalls.single.status, ToolCallStatus.running);
      expect(reply.reconnectEpisodes, 1);
      expect(assistantCount(), 1);
      expectOneSubmit();
    });
  });

  group('Stop, queue, cap and timers', () {
    test('Retry, Edit and Branch are all off while the turn may run', () async {
      await startTurn();
      await lose();

      expect(chat.canEditLastPrompt(thread), isFalse);
      expect(chat.canBranch(thread), isFalse);
      expectOneSubmit();
    });

    test(
      'another chat accepting its prompt does not make this loss one',
      () async {
        // The transport's acceptance flag belongs to its latest send.
        transport.promptAccepted = true;
        chat.newThread();
        thread = chat.selectedThread!;
        chat.submit('Hello', const []);
        send = transport.sends.single;
        send.emit(const ThreadBound('s1'));
        await pumpEventQueue();
        await lose();

        expect(assistant().status, MessageStatus.error);
        expect(assistant().reconnecting, isFalse);
        expectOneSubmit();
      },
    );

    test(
      'a stop the server has nothing to stop for reads the reply back',
      () async {
        await startTurn();
        await lose();
        transport.stopsRunning = false;
        final before = transport.followUpCalls;

        await chat.stopReply(thread);
        await pumpEventQueue();

        expect(assistant().stopped, isFalse);
        expect(assistant().reconnecting, isTrue);
        expect(transport.followUpCalls, greaterThan(before));
        transport.followUpStreams['s1']!
          ..emit(const ThreadNeedsRefetch())
          ..emit(const ReplyCompleted('Finished while away.'));
        await pumpEventQueue();

        expect(assistantCount(), 1);
        expect(assistant().content, 'Finished while away.');
        expect(assistant().stopped, isFalse);
        expect(assistant().status, MessageStatus.sent);
        expectOneSubmit();
      },
    );

    test(
      'a message queued meanwhile is sent exactly once after the turn',
      () async {
        await startTurn();
        await lose();
        chat.submit('And then deploy', const []);
        await pumpEventQueue();
        expectOneSubmit();

        chat.checkConnection();
        await pumpEventQueue();
        transport.followUpStreams['s1']!
          ..emit(const ReplyStarted())
          ..emit(const ReplyCompleted('Built.'))
          ..emit(const SessionInfo(running: false));
        await pumpEventQueue();

        expect(transport.sends, hasLength(2));
        expect(transport.sends.last.text, 'And then deploy');
      },
    );

    test('after the tries run out the note stops claiming to try', () async {
      chat = build(retry: const Duration(milliseconds: 1));
      await startTurn();
      var calls = transport.followUpCalls;
      await lose();

      // Each try fails to reach the server, until the cap.
      for (var i = 0; i < 200 && !assistant().reconnectIdle; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final follow = transport.followUpStreams['s1'];
        if (transport.followUpCalls > calls && follow != null) {
          calls = transport.followUpCalls;
          follow.fail(const GatewayConnectionClosed());
        }
        await pumpEventQueue();
      }

      expect(assistant().reconnectIdle, isTrue);
      expect(assistant().reconnecting, isTrue);
      expect(assistant().error, isNull);
      final shown = chatMessageToFlyer(assistant()).whereType<CustomMessage>();
      expect(shown.any((m) => m.metadata?[kMetaReconnectIdle] == true), isTrue);
      // Nothing tries by itself any more.
      final stopped = transport.followUpCalls;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(transport.followUpCalls, stopped);

      // The app coming back does, and the note says so again.
      chat.checkConnection();
      await pumpEventQueue();
      expect(transport.followUpCalls, greaterThan(stopped));
      expect(assistant().reconnectIdle, isFalse);
      expectOneSubmit();
    });

    test('a disposed controller tries nothing more', () async {
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      addTearDown(attention.dispose);
      final other = ChatController(
        transport: transport,
        attention: attention,
        report: reports.add,
        reconnectRetry: const Duration(milliseconds: 10),
      );
      other.newThread();
      thread = other.selectedThread!;
      other.submit('Run the build', const []);
      send = transport.sends.single;
      send
        ..emit(const ThreadBound('s1'))
        ..emit(const PromptAcknowledged(1))
        ..emit(const ReplyDelta('x'));
      await pumpEventQueue();
      await lose();
      other.dispose();
      final calls = transport.followUpCalls;

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(transport.followUpCalls, calls);
    });

    test('only the chat in front is tried by the timer', () async {
      chat = build(retry: const Duration(milliseconds: 10));
      await startTurn();
      chat.newThread();
      await lose();
      final calls = transport.followUpCalls;

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(transport.followUpCalls, calls);
      expect(assistant().reconnecting, isTrue);

      // Opening it tries at once.
      chat.select('s1');
      await pumpEventQueue();
      expect(transport.followUpCalls, greaterThan(calls));
    });
  });

  group('Review round two', () {
    test('a typed prompt the server accepted with no row id and no frame '
        'waits when the connection is lost', () async {
      chat.newThread();
      thread = chat.selectedThread!;
      chat.submit('Hello', const []);
      send = transport.sends.single;
      send.emit(const ThreadBound('s1'));
      await pumpEventQueue();
      // The transport reports a reply lost after its prompt was answered.
      await lose(const GatewayReplyLost());

      expect(assistant().reconnecting, isTrue);
      expect(assistant().error, isNull);
      expectOneSubmit();
    });

    test('a lost send keeps its notices: nothing of the turn ended', () async {
      await startTurn();
      send.emit(
        const NoticeShown(AgentNotice(text: 'Heads up'), runtimeId: 'rt-1'),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(thread), hasLength(1));

      await lose();

      expect(chat.noticesIn(thread), hasLength(1));
      expectOneSubmit();
    });

    test('a failed send drops its notices', () async {
      await startTurn();
      send.emit(
        const NoticeShown(AgentNotice(text: 'Heads up'), runtimeId: 'rt-1'),
      );
      await pumpEventQueue();

      await lose(StateError('boom'));

      expect(chat.noticesIn(thread), isEmpty);
    });

    test('a follow-up that is lost again keeps the notices too', () async {
      await startTurn();
      await lose();
      chat.checkConnection();
      await pumpEventQueue();
      final follow = transport.followUpStreams['s1']!;
      follow
        ..emit(const ReplyStarted())
        ..emit(
          const NoticeShown(AgentNotice(text: 'Heads up'), runtimeId: 'rt-1'),
        );
      await pumpEventQueue();
      follow.fail(const GatewayReplyLost());
      await pumpEventQueue();

      expect(assistant().reconnecting, isTrue);
      expect(chat.noticesIn(thread), hasLength(1));
    });

    test('a chat that is not in front says nothing is trying', () async {
      await startTurn();
      chat.newThread();
      await lose();

      expect(assistant().reconnecting, isTrue);
      expect(assistant().reconnectIdle, isTrue);

      chat.select('s1');
      await pumpEventQueue();
      expect(assistant().reconnectIdle, isFalse);
    });

    test('suspending ends the timers', () async {
      final activity = ValueNotifier<bool>(true);
      addTearDown(activity.dispose);
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      addTearDown(attention.dispose);
      final other = ChatController(
        transport: transport,
        attention: attention,
        activity: activity,
        report: reports.add,
        reconnectRetry: const Duration(milliseconds: 10),
      );
      addTearDown(other.dispose);
      other.newThread();
      thread = other.selectedThread!;
      other.submit('Run the build', const []);
      send = transport.sends.single;
      send
        ..emit(const ThreadBound('s1'))
        ..emit(const PromptAcknowledged(1))
        ..emit(const ReplyDelta('x'));
      await pumpEventQueue();
      await lose();
      activity.value = false;
      await pumpEventQueue();
      // Back in front before the timer would have run: it must not run.
      activity.value = true;
      await pumpEventQueue();
      final calls = transport.followUpCalls;

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(transport.followUpCalls, calls);
    });
  });

  group('a real failure still fails the reply', () {
    for (final (name, error) in <(String, Object)>[
      ('an unknown error', StateError('boom')),
      ('a session the server no longer has', const GatewaySessionGone(4007)),
      ('a turn the server ended with nothing', const GatewayTurnEnded()),
      ('an answer from the server', const GatewayRpcException(5000, 'boom')),
    ]) {
      test(name, () async {
        await startTurn();
        await lose(error);

        final reply = assistant();
        expect(reply.status, MessageStatus.error);
        expect(reply.error, kReplyFailedMessage);
        expect(reply.reconnecting, isFalse);
        expect(reply.toolCalls.single.status, ToolCallStatus.error);
        expect(thread.isReplying, isFalse);
        expectOneSubmit();
      });
    }

    test('a pick-up the server says is gone fails the reply', () async {
      await startTurn();
      await lose();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.fail(const GatewaySessionGone(4007));
      await pumpEventQueue();

      expect(assistant().status, MessageStatus.error);
      expect(assistant().reconnecting, isFalse);
      expect(assistantCount(), 1);
      expectOneSubmit();
    });
  });
}

import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_gateway.dart';

class _R implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

/// A turn the server keeps listing as running is not failed for being quiet,
/// and a settled reply is handed only its own turn: no flip between states, no
/// repeated failure signal, no other prompt's answer in the wrong bubble.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a long silent tool the server lists as running never flips the reply '
      'and never fails it; the result lands in the same bubble and the queue '
      'is released by the usual rule', () {
    fakeAsync((async) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true
        ..activeSessions = {'stored-1': 'working'};
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        random: _R(),
      );
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      final chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
        reconnectRetry: const Duration(seconds: 15),
      );
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'Starting. '});
        g.event('tool.start', sid, {'tool_id': 't1', 'name': 'terminal'});
      };
      chat.newThread();
      final thread = chat.selectedThread!;
      final states = <String>[];
      String? last;
      chat.addListener(() {
        final replies = thread.messages
            .where((m) => m.role == ChatRole.assistant)
            .toList();
        if (replies.isEmpty) return;
        final state =
            '${replies.length}:${replies.last.status.name}:'
            '${replies.last.loss?.name}';
        if (state != last) states.add('${async.elapsed.inSeconds}s $state');
        last = state;
      });
      chat.submit('hi', const []);
      async.elapse(const Duration(minutes: 1));
      chat.submit('And then deploy', const []);
      async.elapse(const Duration(hours: 3));

      // One state change at most (thinking to streaming), never an error.
      expect(states.where((s) => s.contains('error')), isEmpty);
      expect(states.length, lessThanOrEqualTo(2), reason: states.join('\n'));
      final reply = thread.messages.lastWhere(
        (m) => m.role == ChatRole.assistant,
      );
      expect(reply.isPending, isTrue);
      expect(thread.isReplying, isTrue);
      expect(
        gateway.methods.where((m) => m == 'session.resume'),
        isEmpty,
        reason: 'nothing is picked up again: nothing was lost',
      );
      expect(gateway.methods.where((m) => m == 'prompt.submit'), hasLength(1));

      gateway
        ..event('tool.complete', 'rt-1', {'tool_id': 't1', 'name': 'terminal'})
        ..event('message.complete', 'rt-1', {
          'text': 'Done.',
          'status': 'complete',
        })
        ..event('session.info', 'rt-1', {'running': false});
      async.elapse(const Duration(seconds: 10));

      // The first bubble is the turn's; the second is the queued prompt's.
      final replies = thread.messages
          .where((m) => m.role == ChatRole.assistant)
          .toList();
      expect(replies, hasLength(2));
      expect(identical(replies.first, reply), isTrue);
      expect(reply.status, MessageStatus.sent);
      expect(reply.content, 'Done.');
      // The reply never failed, so the queued prompt goes by the usual rule.
      expect(gateway.methods.where((m) => m == 'prompt.submit'), hasLength(2));
      chat.dispose();
      attention.dispose();
      transport.close();
    });
  });

  group('a settled reply is handed its own turn only', () {
    late FakeChatTransport transport;
    late ChatController chat;
    late AttentionNotifier attention;

    ChatController build(Duration window) {
      transport = FakeChatTransport();
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      return chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
        reconnectRetry: const Duration(hours: 1),
        lostAdoptWindow: window,
      );
    }

    tearDown(() {
      chat.dispose();
      attention.dispose();
    });

    Future<ChatThread> settleRestarted() async {
      chat.newThread();
      final thread = chat.selectedThread!;
      chat.submit('Run the build', const []);
      transport.sends.single
        ..emit(const ThreadBound('s1'))
        ..emit(const PromptAcknowledged(1))
        ..emit(const ReplyDelta('Starting the build. '));
      await pumpEventQueue();
      transport.sends.single.fail(const GatewayTurnEnded(restarted: true));
      await pumpEventQueue();
      return thread;
    }

    test('another prompt that runs on the session much later gets a bubble of '
        'its own, and the notice stays', () async {
      build(const Duration(milliseconds: 20));
      final thread = await settleRestarted();
      final lost = thread.messages.lastWhere(
        (m) => m.role == ChatRole.assistant,
      );
      expect(lost.loss, ReplyLoss.restarted);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyDelta('Answer to the other prompt.'))
        ..emit(const ReplyCompleted('Answer to the other prompt.'))
        ..emit(const SessionInfo(running: false));
      await pumpEventQueue();

      final replies = thread.messages
          .where((m) => m.role == ChatRole.assistant)
          .toList();
      expect(replies, hasLength(2));
      expect(lost.loss, ReplyLoss.restarted);
      expect(lost.status, MessageStatus.error);
      expect(lost.content, 'Starting the build. ');
      expect(replies.last.content, 'Answer to the other prompt.');
      expect(transport.sends, hasLength(1));
    });

    test(
      'a completion that comes much later does not fill the notice',
      () async {
        build(const Duration(milliseconds: 20));
        final thread = await settleRestarted();
        final lost = thread.messages.lastWhere(
          (m) => m.role == ChatRole.assistant,
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        transport.followUpStreams['s1']!.emit(const ReplyCompleted('Other.'));
        await pumpEventQueue();

        expect(lost.status, MessageStatus.error);
        expect(lost.loss, ReplyLoss.restarted);
        expect(lost.content, 'Starting the build. ');
      },
    );

    test(
      'only the first turn of the pick-up is the settled reply\'s own',
      () async {
        build(const Duration(hours: 1));
        final thread = await settleRestarted();
        final lost = thread.messages.lastWhere(
          (m) => m.role == ChatRole.assistant,
        );

        transport.followUpStreams['s1']!
          ..emit(const ReplyStarted())
          ..emit(const ReplyDelta('More. '))
          ..emit(const ReplyCompleted('Starting the build. More.'))
          ..emit(const SessionInfo(running: false))
          ..emit(const ReplyStarted())
          ..emit(const ReplyDelta('Another prompt.'))
          ..emit(const ReplyCompleted('Another prompt.'));
        await pumpEventQueue();

        final replies = thread.messages
            .where((m) => m.role == ChatRole.assistant)
            .toList();
        expect(replies, hasLength(2));
        expect(identical(replies.first, lost), isTrue);
        expect(lost.content, 'Starting the build. More.');
        expect(replies.last.content, 'Another prompt.');
        expect(transport.sends, hasLength(1));
      },
    );
  });
}

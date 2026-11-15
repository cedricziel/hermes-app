import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_gateway.dart';

/// The real controller on the real transport against a scripted server: the
/// socket drops at each point of a reply, and the server is in each of the
/// states the recordings of a real Hermes show afterwards. The reply must end
/// in its own bubble, finished or with a clear notice, never in a second
/// bubble and never with Stop left on, and `prompt.submit` is sent once.

/// Where the socket drops under the reply.
enum Drop {
  /// After the prompt was sent, before its answer reached the app.
  beforeAck,

  /// While text streams.
  midStream,

  /// While a tool call runs.
  duringTool,

  /// While text streams, and the server stays out of reach for longer than the
  /// reconnect window, so the reply waits and is picked up again.
  duringResume,
}

/// What the server is like once the app can reach it again.
enum Server {
  /// The turn still runs and finishes later.
  running,

  /// The turn finished while the app was away.
  finished,

  /// It finished and its runtime session was reaped: the stored id resumes on
  /// a new runtime session that holds the reply.
  reaped,

  /// It restarted, and re-runs the interrupted turn by itself.
  restartedWithAutoContinue,

  /// It restarted and brought nothing back.
  restartedWithout,

  /// It answers that the session is not there.
  gone,
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

/// What a cell ended in.
class _Ended {
  _Ended(this.reply, this.assistants, this.replying, this.submits);

  final ChatMessage reply;
  final int assistants;
  final bool replying;
  final int submits;
}

_Ended _run(Drop drop, Server server) {
  late _Ended ended;
  fakeAsync((async) {
    final gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true;
    final transport = HermesGatewayTransport(
      connect: gateway.connect,
      random: _FixedRandom(),
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

    void away(FakeGateway g) {
      switch (server) {
        case Server.running:
          g.resumeResult = {'session_id': 'rt-1', 'running': true};
        case Server.finished || Server.reaped:
          g.event('tool.complete', 'rt-1', {'tool_id': 't1', 'name': 'bash'});
          g.event('message.complete', 'rt-1', {
            'text': 'Finished.',
            'status': 'complete',
          });
          g.event('session.info', 'rt-1', {'running': false});
          g.resumeResult = {
            'session_id': server == Server.finished ? 'rt-1' : 'rt-9',
            'running': false,
            'messages': [
              {'role': 'user', 'text': 'hi'},
              {'role': 'assistant', 'text': 'Finished.'},
            ],
          };
        case Server.restartedWithAutoContinue:
          g.epoch = 'epoch-2';
          g.resumeResult = {
            'session_id': 'rt-9',
            'running': false,
            'auto_continue': {'attempt': 1},
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          };
        case Server.restartedWithout:
          g.epoch = 'epoch-2';
          g.resumeResult = {
            'session_id': 'rt-9',
            'running': false,
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          };
        case Server.gone:
          g.resumeResult = null;
      }
    }

    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'Starting. '});
      if (drop == Drop.duringTool) {
        g.event('tool.start', sid, {
          'tool_id': 't1',
          'name': 'bash',
          'context': 'make',
        });
      } else {
        g.event('tool.start', sid, {
          'tool_id': 't1',
          'name': 'bash',
          'context': 'make',
        });
        g.event('tool.complete', sid, {'tool_id': 't1', 'name': 'bash'});
        g.event('message.delta', sid, {'text': 'Building. '});
      }
      if (drop == Drop.beforeAck) return;
      g.drop();
      away(g);
    };
    if (drop == Drop.beforeAck) {
      gateway.beforeSubmitAnswer = (g) => g.drop();
    }
    if (drop == Drop.duringResume) {
      gateway.silent.add('session.resume');
    }

    chat.newThread();
    final thread = chat.selectedThread!;
    chat.submit('hi', const []);

    if (drop == Drop.duringResume) {
      // Out of reach past the reconnect window: the reply waits and the chat in
      // front picks it up again every 15 s.
      async.elapse(const Duration(seconds: 90));
      expect(
        thread.messages.last.reconnecting,
        isTrue,
        reason: 'waits for the server instead of failing',
      );
      gateway.silent.remove('session.resume');
    }
    async.elapse(const Duration(seconds: 40));

    // What the server does after the app is back.
    switch (server) {
      case Server.running:
        gateway.event('tool.complete', 'rt-1', {
          'tool_id': 't1',
          'name': 'bash',
        });
        gateway.event('message.complete', 'rt-1', {
          'text': 'Finished.',
          'status': 'complete',
        });
        gateway.event('session.info', 'rt-1', {'running': false});
      case Server.restartedWithAutoContinue:
        gateway.event('message.delta', 'rt-9', {'text': 'Again. '});
        gateway.event('message.complete', 'rt-9', {
          'text': 'Finished.',
          'status': 'complete',
        });
        gateway.event('session.info', 'rt-9', {'running': false});
      default:
        break;
    }
    async.elapse(const Duration(seconds: 40));

    ended = _Ended(
      thread.messages.lastWhere((m) => m.role == ChatRole.assistant),
      thread.messages.where((m) => m.role == ChatRole.assistant).length,
      thread.isReplying,
      gateway.methods.where((m) => m == 'prompt.submit').length,
    );
    chat.dispose();
    attention.dispose();
    transport.close();
  });
  return ended;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a dropped socket under a reply, by where it drops and what the '
      'server is like after', () {
    for (final drop in [Drop.midStream, Drop.duringTool, Drop.duringResume]) {
      for (final server in Server.values) {
        test('${drop.name}, server ${server.name}', () {
          final ended = _run(drop, server);
          final reply = ended.reply;

          // The same bubble, never a second one, and nothing resent.
          expect(ended.assistants, 1);
          expect(ended.submits, 1);
          // Stop is gone: the reply is over one way or the other.
          expect(ended.replying, isFalse);
          expect(reply.isPending, isFalse);
          expect(reply.reconnecting, isFalse);
          expect(
            reply.toolCalls.every((c) => c.status != ToolCallStatus.running),
            isTrue,
          );

          switch (server) {
            case Server.running ||
                Server.finished ||
                Server.reaped ||
                Server.restartedWithAutoContinue:
              expect(reply.status, MessageStatus.sent);
              expect(reply.loss, isNull);
              expect(reply.error, isNull);
              expect(reply.content, contains('Finished.'));
            case Server.restartedWithout:
              expect(reply.status, MessageStatus.error);
              expect(reply.loss, ReplyLoss.restarted);
              expect(reply.error, isNull);
            case Server.gone:
              expect(reply.status, MessageStatus.error);
              expect(reply.loss, ReplyLoss.notOnServer);
              expect(reply.error, isNull);
          }
        });
      }
    }

    test(
      'beforeAck, the prompt is never resent and the reply ends clearly',
      () {
        final ended = _run(Drop.beforeAck, Server.running);

        expect(ended.assistants, 1);
        expect(ended.submits, 1);
        expect(ended.replying, isFalse);
        expect(ended.reply.isPending, isFalse);
        expect(ended.reply.status, MessageStatus.error);
        expect(ended.reply.error, kReplyFailedMessage);
      },
    );
  });
}

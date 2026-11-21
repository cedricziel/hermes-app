import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/reply_diagnostics.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/recorded_events.dart';

/// A reply settled because the server no longer has its turn (or cannot say)
/// is counted once, as failed, with a fixed cause, whichever path settled it.
/// A turn that then goes on and fills the settled bubble is not a second end
/// and never a `completed` of a reply already counted: it shows as a late
/// event, and R keeps the failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late RecordedEvents events;
  late ChatController chat;
  late ChatThread thread;
  late FakeSend send;

  setUp(() {
    transport = FakeChatTransport();
    events = RecordedEvents();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      events: events.call,
      reconnectRetry: const Duration(hours: 1),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  Future<void> startTurn() async {
    chat.newThread();
    thread = chat.selectedThread!;
    chat.submit('Run the build', const []);
    send = transport.sends.single;
    send
      ..emit(const ThreadBound('s1'))
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Starting. '))
      ..emit(const ToolStarted(name: 'terminal', id: 't1', summary: 'make'));
    await pumpEventQueue();
  }

  Future<void> lose(Object error) async {
    send.fail(error);
    await pumpEventQueue();
  }

  List<Map<String, Object>> ended() => events.named('chat.reply.ended');

  List<String> outcomes() => [for (final e in ended()) '${e['outcome']}'];

  group('the send ends with the server having no turn', () {
    for (final (name, error, cause) in <(String, Object, String)>[
      ('not found', const GatewaySessionGone(4007), 'session_gone'),
      (
        'restarted',
        const GatewaySessionGone(4007, restarted: true),
        'server_restarted',
      ),
      (
        'over after a restart',
        const GatewayTurnEnded(restarted: true),
        'server_restarted',
      ),
      ('over, no restart', const GatewayTurnEnded(), 'turn_ended'),
      ('unconfirmed', const GatewayReplyUnconfirmed(), 'unconfirmed'),
      (
        'unconfirmed under a send failure',
        SendFailure(SendStep.reply, GatewayReplyUnconfirmed()),
        'unconfirmed',
      ),
    ]) {
      test('$name is one failed end with cause $cause', () async {
        await startTurn();
        await lose(error);

        expect(ended(), hasLength(1));
        expect(ended().single['outcome'], 'failed');
        expect(ended().single['cause'], cause);
        expect(kReplyEndCauses, contains(cause));
      });
    }
  });

  test('a held reply that hears the server restarted ends once', () async {
    await startTurn();
    await lose(const GatewayReplyLost());
    chat.checkConnection();
    await pumpEventQueue();
    transport.followUpStreams['s1']!.fail(
      const GatewaySessionGone(4007, restarted: true),
    );
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'failed']);
    expect(ended().last['cause'], 'server_restarted');
  });

  test('a stop answered 4001 on a running reply ends it once', () async {
    await startTurn();
    transport.onStop = (_) async =>
        throw const GatewaySessionGone(4001, restarted: true);
    await chat.stopReply(thread);
    await pumpEventQueue();

    expect(outcomes(), ['failed']);
    expect(ended().single['cause'], 'server_restarted');
  });

  test('a stop answered 4001 on a held reply ends it once', () async {
    await startTurn();
    await lose(const GatewayReplyLost());
    transport.onStop = (_) async => throw const GatewaySessionGone(4001);
    await chat.stopReply(thread);
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'failed']);
    expect(ended().last['cause'], 'session_gone');
  });

  test('a turn that goes on after a settle is not a second end', () async {
    await startTurn();
    await lose(const GatewayReplyUnconfirmed());
    expect(outcomes(), ['failed']);

    transport.followUpStreams['s1']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('More. '))
      ..emit(const ReplyCompleted('Starting. More. Done.'))
      ..emit(const SessionInfo(running: false));
    await pumpEventQueue();

    expect(outcomes(), ['failed']);
    expect(
      events.named('chat.reply.late_event').map((e) => e['kind']),
      containsAll(['delta', 'completed']),
    );
    expect(transport.sends, hasLength(1));
  });

  test('a held reply settled, then continued, stays one failed end', () async {
    await startTurn();
    await lose(const GatewayReplyLost());
    chat.checkConnection();
    await pumpEventQueue();
    transport.followUpStreams['s1']!.fail(const GatewayReplyUnconfirmed());
    await pumpEventQueue();
    expect(outcomes(), ['lost_connection', 'failed']);

    transport.followUpStreams['s1']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyCompleted('Done.'));
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'failed']);
  });

  test('Stop 4001 on a held reply with a queue records the pause', () async {
    await startTurn();
    chat.submit('queued', const []);
    await pumpEventQueue();
    await lose(const GatewayReplyLost());
    transport.onStop = (_) async => throw const GatewaySessionGone(4001);
    await chat.stopReply(thread);
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'failed']);
    expect(events.named('chat.queue.state'), [
      {'state': 'held', 'count': '1'},
      {'state': 'paused', 'count': '1'},
    ]);
  });

  test('a held reply that fails with no error logs a server error', () async {
    await startTurn();
    await lose(const GatewayReplyLost());
    chat.checkConnection();
    await pumpEventQueue();
    transport.followUpStreams['s1']!
      ..emit(const ReplyStarted())
      ..emit(const ReplyCompleted('', failed: true));
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'failed']);
    expect(ended().last['cause'], 'server_error');
  });

  test('an idle report that ends a stopped held reply is a stop', () async {
    await startTurn();
    await lose(const GatewayReplyLost());
    await chat.stopReply(thread);
    await pumpEventQueue();
    transport.followUpStreams['s1']!
      ..emit(const ReplyStarted())
      ..emit(const SessionInfo(running: false));
    await pumpEventQueue();

    expect(outcomes(), ['lost_connection', 'stopped']);
  });

  test('an idle report that ends a stopped running reply is a stop', () async {
    await startTurn();
    await chat.stopReply(thread);
    await pumpEventQueue();
    send
      ..emit(const SessionInfo(running: false))
      ..finish();
    await pumpEventQueue();

    expect(outcomes(), ['stopped']);
  });
}

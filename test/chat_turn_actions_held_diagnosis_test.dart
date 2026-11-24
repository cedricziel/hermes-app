import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/reply_diagnostics.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/recorded_events.dart';

/// A reply held as "the server may still run the turn" is one failed end with a
/// fixed outcome and cause, and releasing the hold (the server listing the
/// session as idle) is not another end and logs nothing of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late RecordedEvents events;
  late ChatController chat;
  late ChatThread thread;

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

  Future<void> heldTurn() async {
    chat.newThread();
    thread = chat.selectedThread!;
    await chat.submit('Run the build', const []);
    final send = transport.sends.single;
    send
      ..emit(const ThreadBound('s1'))
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Starting. '));
    await pumpEventQueue();
    transport.active['s1'] = 'working';
    send.fail(const GatewayTurnEnded());
    await pumpEventQueue();
    expect(chat.turnActionsHeld(thread), isTrue);
  }

  test('a held reply is one failed end with a fixed cause, and releasing the '
      'hold logs no second end and nothing else', () async {
    await heldTurn();
    final ended = events.named('chat.reply.ended');
    expect(ended, hasLength(1));
    expect(ended.single['outcome'], 'failed');
    expect(ended.single['cause'], 'turn_ended');
    expect(kReplyEndCauses, contains(ended.single['cause']));
    for (final value in ended.single.values) {
      expect('$value', isNot(contains('Run the build')));
      expect('$value', isNot(contains('s1')));
    }

    final logged = events.namesStartingWith('').length;
    transport.active.clear();
    await chat.refreshActive();

    expect(chat.turnActionsHeld(thread), isFalse);
    expect(events.named('chat.reply.ended'), hasLength(1));
    expect(events.namesStartingWith('').length, logged);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/voice/calls/call_agent.dart';

import '../../support/fake_chat_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late ChatController chat;
  late ChatCallAgent agent;
  var contextLost = 0;
  setUp(() {
    transport = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    chat.newThread();
    contextLost = 0;
    agent = ChatCallAgent(chat, onContextLost: () => contextLost++);
    addTearDown(() {
      agent.dispose();
      chat.dispose();
      attention.dispose();
    });
  });
  test(
    'speaks prose incrementally and keeps reasoning and MEDIA paths out',
    () async {
      final spoken = <String>[];
      final done = agent.reply(
        'Hello',
        onText: spoken.add,
        onAttention: (_) {},
      );
      await pumpEventQueue();
      final send = transport.sends.single;
      send
        ..emit(const ReasoningUpdated('Private deliberation.'))
        ..emit(const ReplyDelta('Hello.'));
      await pumpEventQueue();
      expect(spoken.join(), 'Hello.');
      send.emit(
        const ReplyDelta(' Welcome &amp; enjoy!\nMEDIA:/tmp/voice.ogg'),
      );
      await pumpEventQueue();
      send.emit(
        const ReplyCompleted(
          'Hello. Welcome &amp; enjoy!\nMEDIA:/tmp/voice.ogg',
        ),
      );
      await done;
      expect(spoken.join(), contains('Welcome & enjoy!'));
      expect(spoken.join(), isNot(contains('MEDIA:')));
      expect(spoken.join(), isNot(contains('Private')));
      expect(chat.selectedThread!.messages.first.content, 'Hello');
    },
  );
  test('a busy chat is not queued or interrupted by a new call', () async {
    chat.submit('Unrelated work', const []);
    await expectLater(
      agent.reply('Voice', onText: (_) {}, onAttention: (_) {}),
      throwsStateError,
    );
    await agent.interrupt();
    expect(transport.sends.length, 1);
    expect(chat.selectedThread!.isReplying, isTrue);
    expect(chat.queuedIn(chat.selectedThread!), isEmpty);
  });
  test('changing chat ends the captured context', () {
    chat.newThread();
    expect(contextLost, greaterThan(0));
    expect(agent.valid, isFalse);
  });
  test('interrupting an owned turn waits for its stopped event', () async {
    final reply = agent.reply('Hello', onText: (_) {}, onAttention: (_) {});
    final failed = expectLater(reply, throwsStateError);
    await pumpEventQueue();
    final stopping = agent.interrupt();
    await pumpEventQueue();
    expect(transport.stops, isNotEmpty);
    transport.sends.single.emit(const ReplyCompleted('', stopped: true));
    await stopping;
    await failed;
    expect(chat.selectedThread!.isReplying, isFalse);
  });
  test(
    'approval pauses the call and is never answered automatically',
    () async {
      final waiting = <bool>[];
      final reply = agent.reply(
        'Check the server',
        onText: (_) {},
        onAttention: waiting.add,
      );
      final interrupted = expectLater(reply, throwsStateError);
      await pumpEventQueue();
      transport.sends.single.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'call-approval',
            command: 'restart service',
            description: 'Restart the service',
            choices: ['once', 'deny'],
          ),
        ),
      );
      await pumpEventQueue();
      expect(waiting.last, isTrue);
      expect(chat.selectedThread!.messages.last.awaitingInput, isTrue);
      transport.stopsRunning = false;
      await agent.interrupt();
      await interrupted;
    },
  );
}

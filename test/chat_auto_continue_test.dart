import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

/// The turn Hermes runs on its own after a resume that reports
/// `auto_continue` streams into a reply of its own, above the prompt's reply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late ChatController chat;

  setUp(() {
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  /// A prompt sent in a stored thread, and the stream of its send.
  (ChatThread, FakeSend) sendPrompt() {
    chat.newThread();
    chat.submit('Plan it', const []);
    final send = transport.sends.last..emit(const ThreadBound('s1'));
    return (chat.selectedThread!, send);
  }

  List<ChatMessage> replies(ChatThread thread) => [
    for (final m in thread.messages)
      if (m.role == ChatRole.assistant) m,
  ];

  const approval = ApprovalRequest(
    requestId: 'srq-1',
    command: 'rm -rf build',
    description: 'delete files',
    choices: ['once', 'deny'],
    toolName: 'terminal',
  );

  test('Auto-continue after resume: the turn streams into a reply above the '
      'prompt\'s, which keeps waiting', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();

    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed ')))
      ..emit(const UnsolicitedEvent(ReplyDelta('work')));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.content, 'resumed work');
    expect(auto.status, MessageStatus.streaming);
    expect(prompt.content, isEmpty);
    expect(prompt.status, MessageStatus.thinking);
    // The user's message, the turn, then the prompt's reply.
    expect(thread.messages.map((m) => m.role), [
      ChatRole.user,
      ChatRole.assistant,
      ChatRole.assistant,
    ]);
    expect(thread.messages[1], same(auto));
    expect(thread.messages[2], same(prompt));
    final shown = chat.controllerFor(thread).messages;
    expect(shown.map((m) => m.id), [
      for (final m in thread.messages)
        ...chatMessageToFlyer(m).map((f) => f.id),
    ]);
    expect((shown[1] as TextMessage).text, 'resumed work');
  });

  test('Auto-continue after resume: the prompt\'s reply fills once its turn '
      'begins, and the turn above is left alone', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('mine'));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.content, 'resumed work');
    expect(auto.status, MessageStatus.sent);
    expect(prompt.content, 'mine');
    expect(prompt.status, MessageStatus.streaming);

    send
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();

    expect(auto.content, 'resumed work');
    expect(prompt.content, 'mine');
    expect(prompt.status, MessageStatus.sent);
    expect(thread.isReplying, isFalse);
  });

  test('Auto-continue after resume: the turn\'s approval is answerable on its '
      'reply and withdrawn there when the turn ends', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ApprovalRequested(approval)));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.inputRequests.map((r) => r.requestId), ['srq-1']);
    expect(auto.awaitingInput, isTrue);
    expect(prompt.inputRequests, isEmpty);

    await chat.answerApproval(thread, 'srq-1', 'once');
    expect(transport.approvalAnswers, [('srq-1', 'once')]);

    send
      ..emit(const UnsolicitedEvent(ReplyCompleted('')))
      ..emit(const UnsolicitedEvent(InputRequestsCancelled(['srq-1'])));
    await pumpEventQueue();

    expect(auto.awaitingInput, isFalse);
    expect(auto.isPending, isFalse);
    expect(prompt.isPending, isTrue);
  });

  test('Auto-continue after resume: a reply is opened by an approval that '
      'comes before any text', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();

    send.emit(const UnsolicitedEvent(ApprovalRequested(approval)));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.inputRequests, hasLength(1));
    expect(prompt.inputRequests, isEmpty);
  });

  test('Auto-continue after resume: a send that gives up fails the turn it '
      'was showing as well', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed')))
      ..emit(const ThreadNeedsRefetch())
      ..fail();
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.status, MessageStatus.error);
    expect(prompt.status, MessageStatus.error);
    expect(thread.isReplying, isFalse);
  });

  test('Auto-continue after resume: a send that ends with the turn still open '
      'settles it', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed')))
      ..emit(const SessionInfo(running: false))
      ..finish();
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.isPending, isFalse);
    expect(auto.content, 'resumed');
    expect(prompt.isPending, isFalse);
    expect(thread.isReplying, isFalse);
  });

  test('Auto-continue after resume: the turn is shown once when the follow-ups '
      'start', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();

    expect(replies(thread), hasLength(2));
    expect(transport.followUpStreams['s1'], isNotNull);
  });
}

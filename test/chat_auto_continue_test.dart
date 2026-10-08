import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

/// The turn Hermes runs on its own after a resume that reports
/// `auto_continue` streams into a reply of its own, in front of the prompt it
/// ran ahead of, where the server stores it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late FakeNotificationService service;
  late AttentionNotifier attention;
  late ChatController chat;
  late List<String> reports;
  String? prefilled;

  ChatController buildChat({HermesChatRepository? repository}) {
    return ChatController(
      repository: repository,
      transport: transport,
      attention: attention,
      report: reports.add,
      onPrefill: (text) => prefilled = text,
    );
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    service = FakeNotificationService();
    reports = [];
    attention = AttentionNotifier(
      service: service,
      settings: null,
      onOpen: (_) {},
    );
    chat = buildChat();
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  /// A prompt sent in a stored thread, and the stream of its send.
  (ChatThread, FakeSend) sendPrompt({String text = 'Plan it'}) {
    chat.newThread();
    chat.submit(text, const []);
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

  test('Auto-continue after resume: the turn streams into a reply in front of '
      'the prompt, which keeps waiting', () async {
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
    // The turn, the user's message, then the prompt's reply: the server runs
    // the turn first and stores them so.
    expect(thread.messages.map((m) => m.role), [
      ChatRole.assistant,
      ChatRole.user,
      ChatRole.assistant,
    ]);
    expect(thread.messages[0], same(auto));
    expect(thread.messages[2], same(prompt));
    final shown = chat.controllerFor(thread).messages;
    expect(shown.map((m) => m.id), [
      for (final m in thread.messages)
        ...chatMessageToFlyer(m).map((f) => f.id),
    ]);
    expect((shown[0] as TextMessage).text, 'resumed work');
  });

  test('Auto-continue after resume: the order stays after the prompt\'s reply '
      'streams and ends', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('mine'))
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();

    expect(thread.messages.map((m) => m.content), [
      'resumed work',
      'Plan it',
      'mine',
    ]);
    expect(
      chat.controllerFor(thread).messages.map((m) => (m as TextMessage).text),
      ['resumed work', 'Plan it', 'mine'],
    );
  });

  test('Auto-continue after resume: a read of the thread keeps the order the '
      'live view had', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Plan', lastActive: 1)]),
      )
      ..on(
        'GET',
        '/api/sessions/s1',
        sessionRow(id: 's1', title: 'Plan', lastActive: 1780000200),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'assistant', content: 'resumed work'),
          messageRow(id: 2, role: 'user', content: 'Plan it'),
          messageRow(id: 3, role: 'assistant', content: 'mine, as stored'),
        ]),
      );
    chat.dispose();
    chat = buildChat(
      repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
    );
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyStarted())
      ..emit(const ReplyDelta('mine'))
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();
    final live = thread.messages.map((m) => (m.role, m.content)).toList();

    await chat.refreshThread('s1');

    expect(live.map((m) => m.$2), ['resumed work', 'Plan it', 'mine']);
    expect(thread.messages.map((m) => (m.role, m.content)), [
      (ChatRole.assistant, 'resumed work'),
      (ChatRole.user, 'Plan it'),
      (ChatRole.assistant, 'mine, as stored'),
    ]);
  });

  test('Auto-continue after resume: editing the prompt leaves the turn that '
      'ran ahead of it', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();
    await chat.editLastPrompt(thread);

    expect(transport.undos, [('s1', false)]);
    expect(prefilled, 'Plan it');
    expect(thread.messages.map((m) => m.content), ['resumed work']);
    expect(
      chat.controllerFor(thread).messages.map((m) => (m as TextMessage).text),
      ['resumed work'],
    );
  });

  test('Auto-continue after resume: trying the prompt again leaves the turn '
      'that ran ahead of it', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const ReplyCompleted('mine'))
      ..finish();
    await pumpEventQueue();

    await chat.retry(thread);

    expect(transport.undos, [('s1', true)]);
    expect(transport.sends.last.text, 'Plan it');
    expect(thread.messages.map((m) => m.role), [
      ChatRole.assistant,
      ChatRole.user,
      ChatRole.assistant,
    ]);
    expect(thread.messages.first.content, 'resumed work');
  });

  test('Auto-continue after resume: the prompt\'s reply fills once its turn '
      'begins, and the turn in front is left alone', () async {
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

  test('Auto-continue after resume: an idle report before the turn began does '
      'not close a reply that only holds an approval', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ApprovalRequested(approval)))
      ..emit(const UnsolicitedEvent(SessionInfo(running: false)));
    await pumpEventQueue();

    final [auto, _] = replies(thread);
    expect(auto.isPending, isTrue);
    expect(auto.awaitingInput, isTrue);
    await chat.answerApproval(thread, 'srq-1', 'once');
    expect(transport.approvalAnswers, [('srq-1', 'once')]);

    // Once the turn has begun, the idle report is its end.
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(SessionInfo(running: false)));
    await pumpEventQueue();

    expect(auto.isPending, isFalse);
  });

  test('Auto-continue after resume: a completion that comes after the turn '
      'settled on an idle report lands on its reply', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed')))
      ..emit(const UnsolicitedEvent(SessionInfo(running: false)));
    await pumpEventQueue();
    final [auto, prompt] = replies(thread);
    expect(auto.isPending, isFalse);
    expect(auto.settledWithoutCompletion, isTrue);

    send.emit(const UnsolicitedEvent(ReplyCompleted('resumed work')));
    await pumpEventQueue();

    expect(auto.content, 'resumed work');
    expect(auto.settledWithoutCompletion, isFalse);
    expect(replies(thread), hasLength(2));
    expect(prompt.isPending, isTrue);
  });

  test('Auto-continue after resume: a failure before any frame of the turn is '
      'shown on a reply of its own', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();

    send
      ..emit(const UnsolicitedEvent(ReplyErrored('provider down')))
      ..emit(const UnsolicitedEvent(ReplyCompleted('', failed: true)));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.status, MessageStatus.error);
    expect(prompt.isPending, isTrue);
    expect(reports, isEmpty);
  });

  test('Auto-continue after resume: a stray failure after the turn ended is '
      'reported', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyErrored('late failure')));
    await pumpEventQueue();

    expect(reports, ['late failure']);
    expect(replies(thread), hasLength(2));
  });

  test('Auto-continue after resume: a snapshot of the turn before any of its '
      'frames opens its reply', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();

    send.emit(const UnsolicitedEvent(ReplyRebuilt('so far: resumed')));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.content, 'so far: resumed');
    expect(auto.status, MessageStatus.streaming);
    expect(prompt.content, isEmpty);
  });

  test('Auto-continue after resume: a snapshot after the turn ended opens no '
      'second reply for it', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
      ..emit(const UnsolicitedEvent(ReplyRebuilt('so far: mine')));
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.content, 'resumed work');
    expect(prompt.content, isEmpty);
  });

  test('Auto-continue after resume: a send that gives up fails the turn it '
      'was showing as well, with one notification', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    chat.newThread();
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
    expect(service.shown, hasLength(1));
  });

  test('Auto-continue after resume: a turn that fails after the prompt\'s '
      'reply settled is announced as failed', () async {
    final (thread, send) = sendPrompt();
    await pumpEventQueue();
    chat.newThread();
    send
      ..emit(const UnsolicitedEvent(ReplyStarted()))
      ..emit(const UnsolicitedEvent(ReplyDelta('resumed')))
      ..emit(const SessionInfo(running: false))
      ..fail();
    await pumpEventQueue();

    final [auto, prompt] = replies(thread);
    expect(auto.status, MessageStatus.error);
    expect(prompt.isPending, isFalse);
    expect(service.shown.map((n) => n.body), contains(kReplyFailedBody));
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

  group('the turn belongs to the send', () {
    test('Auto-continue after resume: its end does not send a queued prompt, '
        'while the prompt\'s own reply is pending', () async {
      final (thread, send) = sendPrompt();
      await pumpEventQueue();
      chat.submit('Then this', const []);
      send
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
        ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
        ..emit(const UnsolicitedEvent(SessionInfo(running: false)));
      await pumpEventQueue();

      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread), hasLength(1));
      expect(thread.isReplying, isTrue);
    });

    test('Auto-continue after resume: its end leaves a stop in flight '
        'alone', () async {
      final (thread, send) = sendPrompt();
      await pumpEventQueue();
      chat.submit('Then this', const []);
      transport.stopGate = Completer<void>();
      final stopping = chat.stopReply(thread);
      await pumpEventQueue();

      send
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
        ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')))
        ..emit(const UnsolicitedEvent(SessionInfo(running: false)));
      await pumpEventQueue();
      transport.stopGate!.complete();
      await stopping;

      // The stop still paused the queue: the prompt's reply ends, and the
      // queued prompt waits for the user.
      send
        ..emit(const ReplyCompleted('', stopped: true))
        ..finish();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread), hasLength(1));
      expect(chat.queuePaused(thread), isTrue);
    });
  });
}

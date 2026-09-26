import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late List<String> reports;
  late ChatController chat;

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
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  test('a sent prompt streams its reply into the thread', () async {
    chat.newThread();
    final thread = chat.selectedThread!;
    var changes = 0;
    chat.addListener(() => changes++);

    expect(chat.submit('Hello', const []), isTrue);
    final send = transport.sends.single;
    expect(send.text, 'Hello');
    expect(send.threadId, isNull);
    expect(thread.title, 'Hello');
    expect(thread.isReplying, isTrue);

    send
      ..emit(const ThreadBound('s1'))
      ..emit(const ReplyDelta('Hi '))
      ..emit(const ReplyDelta('there'))
      ..emit(const ReplyCompleted('Hi there'));
    await pumpEventQueue();

    expect(thread.id, 's1');
    expect(thread.remote, isTrue);
    expect(chat.selectedId, 's1');
    expect(thread.messages.map((m) => (m.role, m.content)), [
      (ChatRole.user, 'Hello'),
      (ChatRole.assistant, 'Hi there'),
    ]);
    expect(thread.isReplying, isFalse);
    expect(changes, greaterThan(0));

    // A later send continues the bound session.
    chat.submit('Again', const []);
    expect(transport.sends.last.threadId, 's1');
  });

  test('a reply stays in its thread after the user switches away', () async {
    chat.newThread();
    final first = chat.selectedThread!;
    chat.submit('Question', const []);
    final send = transport.sends.single;

    chat.newThread();
    final second = chat.selectedThread!;
    expect(second, isNot(same(first)));

    send
      ..emit(const ThreadBound('s1'))
      ..emit(const ReplyDelta('Answer'))
      ..emit(const ReplyCompleted('Answer'));
    await pumpEventQueue();

    expect(first.id, 's1');
    expect(first.messages.last.content, 'Answer');
    expect(second.messages, isEmpty);
    expect(chat.selectedThread, same(second));
  });

  test('an answered approval is recorded on its reply', () async {
    chat.newThread();
    final thread = chat.selectedThread!;
    chat.submit('Run it', const []);
    transport.sends.single.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r1',
          command: 'rm -rf build',
          description: 'Clean the build',
          choices: ['once', 'deny'],
        ),
      ),
    );
    await pumpEventQueue();

    await chat.answerApproval(thread, 'r1', 'once');

    expect(transport.approvalAnswers, [('r1', 'once')]);
    final request =
        thread.messages.last.inputRequests.single as ApprovalRequest;
    expect(request.choice, 'once');
  });
}

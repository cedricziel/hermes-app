import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
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

  test('slash command output is shown without a normal prompt send', () async {
    chat.newThread();
    transport.slashResult = const SlashCommandResult(
      threadId: 's-command',
      output: 'Available commands',
    );
    expect(await chat.runSlashCommand('/help'), isTrue);
    expect(transport.slashRuns, ['/help']);
    expect(transport.sends, isEmpty);
    expect(chat.selectedThread!.messages.map((m) => m.content), [
      '/help',
      'Available commands',
    ]);
    expect(chat.selectedThread!.remote, isTrue);
  });

  test('a command waits for the first prompt to bind its session', () async {
    chat.newThread();
    expect(chat.submit('First prompt', const []), isTrue);
    expect(await chat.runSlashCommand('/help'), isFalse);
    expect(transport.slashRuns, isEmpty);
    expect(reports.single, contains('Wait for this chat to open'));
  });

  test('a skill command submits its expanded prompt', () async {
    chat.newThread();
    transport.slashResult = const SlashCommandResult(
      threadId: 's-skill',
      prompt: 'Expanded skill prompt',
      display: '/review',
    );
    expect(await chat.runSlashCommand('/review'), isTrue);
    expect(transport.sends.single.text, 'Expanded skill prompt');
    expect(transport.sends.single.threadId, 's-skill');
    expect(
      chat.selectedThread!.messages
          .where((m) => m.role == ChatRole.user)
          .last
          .content,
      '/review',
    );
    expect(chat.lastPromptText(chat.selectedThread!), 'Expanded skill prompt');
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

  test('an answered vault request is recorded on its reply', () async {
    chat.newThread();
    final thread = chat.selectedThread!;
    chat.submit('Save it', const []);
    transport.sends.single.emit(
      VaultRequested(
        const VaultRequest(
          requestId: 'srq-1',
          kind: VaultKind.saveLogin,
          origin: 'https://www.example.com',
          site: 'www.example.com',
        ),
      ),
    );
    await pumpEventQueue();

    await chat.answerVaultRequest(
      thread,
      'srq-1',
      VaultKind.saveLogin,
      identifier: 'ada@example.com',
      password: 's3cret',
    );

    expect(transport.vaultAnswers.single.identifier, 'ada@example.com');
    final request = thread.messages.last.inputRequests.single as VaultRequest;
    expect(request.status, InputRequestStatus.answered);
    expect(request.identifier, 'ada@example.com');
  });

  test('a skipped vault request records a decline', () async {
    chat.newThread();
    final thread = chat.selectedThread!;
    chat.submit('Save it', const []);
    transport.sends.single.emit(
      VaultRequested(
        const VaultRequest(
          requestId: 'srq-1',
          kind: VaultKind.code,
          site: 'example.com',
        ),
      ),
    );
    await pumpEventQueue();

    await chat.answerVaultRequest(thread, 'srq-1', VaultKind.code);

    expect(transport.vaultAnswers.single.code, isEmpty);
    final request = thread.messages.last.inputRequests.single as VaultRequest;
    expect(request.status, InputRequestStatus.answered);
    expect(request.provided, isFalse);
  });
}

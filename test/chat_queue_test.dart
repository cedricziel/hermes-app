import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/share/shared_item.dart';

import 'support/attachment_fixtures.dart';
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

  /// Sends [text] in a new thread and returns the thread with its send.
  (ChatThread, FakeSend) start(String text) {
    chat.newThread();
    chat.submit(text, const []);
    final send = transport.sends.last..emit(const ThreadBound('s1'));
    return (chat.selectedThread!, send);
  }

  Future<void> complete(FakeSend send, {bool stopped = false}) async {
    send
      ..emit(ReplyCompleted('Done.', stopped: stopped))
      ..finish();
    await pumpEventQueue();
  }

  List<String> queuedTexts(ChatThread thread) => [
    for (final prompt in chat.queuedIn(thread)) prompt.text,
  ];

  test('a prompt sent while the thread replies is queued', () async {
    final (thread, _) = start('One');
    await pumpEventQueue();

    expect(chat.submit('Two', const []), isTrue);

    expect(transport.sends, hasLength(1));
    expect(queuedTexts(thread), ['Two']);
    expect(thread.messages.where((m) => m.content == 'Two'), isEmpty);
    expect(chat.queuePaused(thread), isFalse);
    expect(reports, isEmpty);
  });

  test('queued prompts go out one per completed reply', () async {
    final (thread, first) = start('One');
    await pumpEventQueue();
    chat
      ..submit('Two', const [])
      ..submit('Three', const []);

    await complete(first);

    expect(transport.sends.map((s) => s.text), ['One', 'Two']);
    expect(transport.sends.last.threadId, 's1');
    expect(queuedTexts(thread), ['Three']);
    expect(thread.isReplying, isTrue);

    await complete(transport.sends.last);

    expect(transport.sends.map((s) => s.text), ['One', 'Two', 'Three']);
    expect(chat.queuedIn(thread), isEmpty);
  });

  test(
    'a prompt queued during a turn Hermes chains is sent after it',
    () async {
      final (thread, first) = start('One');
      await complete(first);
      final follow = transport.followUpStreams['s1']!
        ..emit(const ReplyStarted());
      await pumpEventQueue();

      chat.submit('Two', const []);
      expect(transport.sends, hasLength(1));

      follow.emit(const ReplyCompleted('Carried on.'));
      await pumpEventQueue();

      expect(transport.sends.map((s) => s.text), ['One', 'Two']);
      expect(chat.queuedIn(thread), isEmpty);
    },
  );

  test('a stopped reply pauses the queue until sent by hand', () async {
    final (thread, first) = start('One');
    await pumpEventQueue();
    chat.submit('Two', const []);

    await complete(first, stopped: true);

    expect(transport.sends, hasLength(1));
    expect(chat.queuePaused(thread), isTrue);

    chat.sendQueued(thread);

    expect(transport.sends.map((s) => s.text), ['One', 'Two']);
    expect(chat.queuedIn(thread), isEmpty);
    expect(chat.queuePaused(thread), isFalse);
  });

  test('a failed reply pauses the queue', () async {
    final (thread, first) = start('One');
    await pumpEventQueue();
    chat.submit('Two', const []);

    first.fail();
    await pumpEventQueue();

    expect(transport.sends, hasLength(1));
    expect(chat.queuePaused(thread), isTrue);
  });

  test('a prompt sent on a paused queue joins its end', () async {
    final (thread, first) = start('One');
    await pumpEventQueue();
    chat.submit('Two', const []);
    await complete(first, stopped: true);

    expect(chat.submit('Three', const []), isTrue);

    expect(transport.sends.map((s) => s.text), ['One', 'Two']);
    expect(queuedTexts(thread), ['Three']);
  });

  test('a removed prompt is never sent', () async {
    final (thread, first) = start('One');
    await pumpEventQueue();
    chat.submit('Two', const []);

    chat.removeQueued(thread, chat.queuedIn(thread).single);
    await complete(first);

    expect(transport.sends, hasLength(1));
    expect(chat.queuedIn(thread), isEmpty);
  });

  test('a queued prompt keeps its attachments', () async {
    final file = writeTemp(tempDir('chat_queue'), 'report.pdf', [1, 2, 3]);
    final report = SharedFile(path: file.path, name: 'report.pdf');
    final (_, first) = start('One');
    await pumpEventQueue();
    chat.submit('Read this', [report]);

    await complete(first);

    expect(transport.sends.last.attachments.single.name, 'report.pdf');
  });

  test('an unreadable attachment is refused when queued', () async {
    const missing = SharedFile(path: '/nonexistent/x.pdf', name: 'x.pdf');
    final (thread, _) = start('One');
    await pumpEventQueue();

    expect(chat.submit('Read this', [missing]), isFalse);

    expect(chat.queuedIn(thread), isEmpty);
    expect(reports, hasLength(1));
  });

  test('another thread sends at once while one replies', () async {
    final (first, _) = start('One');
    await pumpEventQueue();
    chat.newThread();

    chat.submit('Elsewhere', const []);

    expect(transport.sends.map((s) => s.text), ['One', 'Elsewhere']);
    expect(chat.queuedIn(first), isEmpty);
    expect(chat.queuedIn(chat.selectedThread!), isEmpty);
  });
}

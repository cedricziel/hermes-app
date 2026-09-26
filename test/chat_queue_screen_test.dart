import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(id: 2, role: 'user', content: 'Draft the notes.'),
        ]),
      );
  });

  /// The cards in the transcript hold selectable text, so the composer field
  /// is found through its own widget.
  final composerField = find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(EditableText),
  );

  Future<void> pump(WidgetTester tester, {ShareController? share}) =>
      pumpChatScreen(
        tester,
        server: server,
        transport: transport,
        providers: [
          if (share != null)
            ChangeNotifierProvider<ShareController>.value(value: share),
        ],
      );

  late SharedFile report;

  setUp(() {
    final file = writeTemp(tempDir('chat_one_turn'), 'report.pdf', [1, 2, 3]);
    report = SharedFile(path: file.path, name: 'report.pdf');
  });

  Future<FakeSend> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(composerField).controller.text;

  testWidgets('a prompt sent while the reply streams is queued', (
    tester,
  ) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(const ReplyDelta('Working'));
    await tester.pump();
    expect(find.text('Queue a message…'), findsOneWidget);

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(composerText(tester), isEmpty);
    expect(find.text('Queued, sent when Hermes is done'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the queued prompt is sent when the reply completes', (
    tester,
  ) async {
    await pump(tester);
    final first = await send(tester, 'One');
    await send(tester, 'Two');

    first
      ..emit(const ReplyCompleted('Done.'))
      ..finish();
    await tester.pump();
    await tester.pump();

    expect(transport.sends.map((s) => s.text), ['One', 'Two']);
    expect(find.text('Queued, sent when Hermes is done'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a queued prompt can be removed', (tester) async {
    await pump(tester);
    await send(tester, 'One');
    await send(tester, 'Two');

    await tester.tap(find.byTooltip('Remove from queue'));
    await tester.pump();

    expect(find.text('Two'), findsNothing);
    expect(find.text('Queued, sent when Hermes is done'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a stopped reply pauses the queue until Send now', (
    tester,
  ) async {
    await pump(tester);
    final first = await send(tester, 'One');
    await send(tester, 'Two');

    first
      ..emit(const ReplyCompleted('', stopped: true))
      ..finish();
    await tester.pump();
    await tester.pump();

    expect(transport.sends, hasLength(1));
    expect(find.text('Queue paused'), findsOneWidget);

    await tester.tap(find.text('Send now'));
    await tester.pump();

    expect(transport.sends.map((s) => s.text), ['One', 'Two']);
    expect(find.text('Queue paused'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a queued prompt takes its attachments along', (tester) async {
    final inbox = FakeShareInbox();
    final share = ShareController(inbox);
    await share.start();
    await pump(tester, share: share);
    final first = await send(tester, 'One');
    inbox.emit([report]);
    await tester.pump();
    expect(find.byTooltip('Remove report.pdf'), findsOneWidget);

    await send(tester, 'Two');

    expect(find.byTooltip('Remove report.pdf'), findsNothing);
    first
      ..emit(const ReplyCompleted('Done.'))
      ..finish();
    await tester.pump();
    await tester.pump();
    expect(transport.sends.last.attachments.single.name, 'report.pdf');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an accepted prompt still empties the composer', (tester) async {
    await pump(tester);

    await send(tester, 'One');

    expect(tester.widget<EditableText>(composerField).controller.text, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an accepted prompt also clears its attachments', (tester) async {
    final inbox = FakeShareInbox();
    final share = ShareController(inbox);
    await share.start();
    await pump(tester, share: share);
    inbox.emit([report]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Remove report.pdf'), findsOneWidget);

    await send(tester, 'One');

    expect(transport.sends, hasLength(1));
    expect(find.byTooltip('Remove report.pdf'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a prompt sent while a request is pending is queued', (
    tester,
  ) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: 'list',
          choices: ['once', 'deny'],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(find.text('Queued, sent when Hermes is done'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sending works again once the reply completed', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(const ReplyCompleted('Done.'));
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a broken stream frees the thread again', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.fail();
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('another thread can be written to meanwhile', (tester) async {
    await pump(tester);
    await send(tester, 'One');
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Release notes'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    expect(transport.sends.last.threadId, 's2');
    await tester.pump(const Duration(seconds: 5));
  });
}

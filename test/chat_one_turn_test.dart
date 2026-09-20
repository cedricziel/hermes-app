import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart';

const _blockedMessage =
    'Hermes is still replying. Wait for it to finish, or answer its request.';

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
    of: find.byType(Composer),
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

  testWidgets('a second prompt is not sent while the reply is streaming', (
    tester,
  ) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(const ReplyDelta('Working'));
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(find.text(_blockedMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a refused prompt stays in the composer', (tester) async {
    await pump(tester);
    await send(tester, 'One');

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(tester.widget<EditableText>(composerField).controller.text, 'Two');
    expect(find.text(_blockedMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an accepted prompt still empties the composer', (tester) async {
    await pump(tester);

    await send(tester, 'One');

    expect(tester.widget<EditableText>(composerField).controller.text, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a refused prompt keeps its attachments', (tester) async {
    final inbox = FakeShareInbox();
    final share = ShareController(inbox);
    await share.start();
    await pump(tester, share: share);
    await send(tester, 'One');
    inbox.emit([report]);
    await tester.pump();
    expect(find.byTooltip('Remove report.pdf'), findsOneWidget);

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(find.byTooltip('Remove report.pdf'), findsOneWidget);
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

  testWidgets('a pending request also blocks sending', (tester) async {
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
    expect(find.text(_blockedMessage), findsOneWidget);
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

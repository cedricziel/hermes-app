import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_share_inbox.dart';
import 'support/fake_hermes_server.dart';

import 'support/pump_chat.dart';

void main() {
  testWidgets('phone opens Chats before showing a conversation', (
    tester,
  ) async {
    await pumpChatScreen(tester, size: const Size(400, 800));

    expect(find.text('Chats'), findsWidgets);
    expect(find.byType(ThreadSidebar), findsOneWidget);
    expect(composerField, findsNothing);
    expect(find.byTooltip('New message'), findsOneWidget);
  });

  testWidgets('Back returns to Chats and reopening keeps the draft', (
    tester,
  ) async {
    await pumpChatScreen(tester, size: const Size(400, 800));
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await tester.pumpAndSettle();
    await tester.enterText(composerField, 'Keep this draft');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsWidgets);
    expect(composerField, findsNothing);
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Keep this draft',
    );
  });

  testWidgets('resize retains selected detail and its unsent draft', (
    tester,
  ) async {
    await pumpChatScreen(tester, size: const Size(400, 800));
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await tester.pumpAndSettle();
    await tester.enterText(composerField, 'Resize draft');
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(ThreadSidebar), findsOneWidget);
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Resize draft',
    );
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Resize draft',
    );
  });
  testWidgets('shared text opens detail without sending', (tester) async {
    final inbox = FakeShareInbox();
    final share = ShareController(inbox);
    addTearDown(share.dispose);
    await share.start();
    await pumpChatScreen(
      tester,
      size: const Size(400, 800),
      providers: [ChangeNotifierProvider<ShareController>.value(value: share)],
    );
    inbox.emit([const SharedText('Shared draft')]);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Shared draft',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsWidgets);
  });

  testWidgets('Back keeps an in-flight reply attached to its conversation', (
    tester,
  ) async {
    final transport = FakeChatTransport();
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'running', title: 'Running chat')]),
      )
      ..on(
        'GET',
        '/api/sessions/running/messages',
        messageListBody('running', []),
      );
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      size: const Size(400, 800),
    );
    await openThread(tester, 'Running chat');
    await tester.enterText(composerField, 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(transport.sends, hasLength(1));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(composerField, findsNothing);
    transport.sends.single
      ..emit(const ReplyCompleted('Reply while away'))
      ..finish();
    await tester.pumpAndSettle();
    await openThread(tester, 'Running chat');
    expect(
      find.textContaining('Reply while away', findRichText: true),
      findsOneWidget,
    );
    expect(transport.sends, hasLength(1));
  });

  testWidgets('returning to another chat restores only that chat draft', (
    tester,
  ) async {
    await pumpChatScreen(tester, size: const Size(400, 800));
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await tester.pumpAndSettle();
    await tester.enterText(composerField, 'Only for the first chat');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('thread-t2')));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(composerField).controller.text, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thread-t1')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Only for the first chat',
    );
  });
}

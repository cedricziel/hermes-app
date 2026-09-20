import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/mock_chat_data.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_share_inbox.dart';

Widget _wrap(Widget child, {ShareController? share}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<ShareController>(
        create: (_) => share ?? ShareController(FakeShareInbox()),
      ),
    ],
    child: MaterialApp(theme: buildHermesLightTheme(), home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('wide layout shows the thread rail and the first thread', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final threads = buildMockThreads();
    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    // The sidebar lists every mock thread, and the first one is open by
    // default with its own messages visible in the transcript (its title
    // also repeats in the top bar, hence findsWidgets rather than one).
    for (final thread in threads) {
      expect(find.text(thread.title), findsWidgets);
    }
    expect(find.byType(Chat), findsOneWidget);
    expect(
      find.textContaining(
        threads.first.messages.first.content,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('New chat'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.textContaining(
          threads.first.messages.first.content,
          findRichText: true,
        ),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the demo chat has no Plugins entry', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Plugins'), findsNothing);
  });

  testWidgets('a tool call from the mock data renders as a ToolCallCard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    final card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
    expect(card.call.name, 'search_logs');
    expect(find.text('search_logs'), findsOneWidget);
  });

  testWidgets('switching threads shows that thread\'s messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final threads = buildMockThreads();
    final first = threads[0].messages.first.content;
    final second = threads[1].messages.first.content;

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining(first, findRichText: true), findsOneWidget);
    expect(find.textContaining(second, findRichText: true), findsNothing);

    await tester.tap(find.text(threads[1].title));
    await tester.pumpAndSettle();

    expect(find.textContaining(second, findRichText: true), findsOneWidget);
    expect(find.textContaining(first, findRichText: true), findsNothing);
    expect(find.byType(ToolCallCard), findsNothing);

    await tester.tap(find.text(threads[0].title));
    await tester.pumpAndSettle();
    expect(find.textContaining(first, findRichText: true), findsOneWidget);
  });

  testWidgets('starter prompt sends a message and gets a reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    // Start a new, empty thread so the welcome view with starter prompts
    // is showing.
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(find.text(kStarterPrompts.first), findsOneWidget);

    await tester.tap(find.text(kStarterPrompts.first));
    await tester.pump();

    // The user's turn appears immediately, with a thinking placeholder for
    // the reply, while the welcome view (and its starter prompts) is gone.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ThinkingIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Chat),
        matching: find.textContaining(
          kStarterPrompts.first,
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('placeholder reply', findRichText: true),
      findsNothing,
    );

    // The canned reply replaces the placeholder once the simulated
    // round-trip resolves.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byType(ThinkingIndicator), findsNothing);
    expect(
      find.textContaining('placeholder reply', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a reply lands in its own thread after switching away', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final threads = buildMockThreads();
    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kStarterPrompts.first));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(threads[1].title));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('placeholder reply', findRichText: true),
      findsNothing,
    );
    expect(find.byType(ThinkingIndicator), findsNothing);

    await tester.tap(find.text(kStarterPrompts.first));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('placeholder reply', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ThinkingIndicator), findsNothing);
  });

  testWidgets('replies stay beside their prompt across consecutive sends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();

    Future<void> send(String text) async {
      await tester.enterText(find.byType(EditableText), text);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
    }

    await send('FIRSTQ');
    await tester.pump(const Duration(milliseconds: 1000));
    await send('SECONDQ');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // The thread title (sidebar, top bar) repeats the first prompt, so only
    // look inside the transcript.
    double top(Finder finder) {
      final inChat = find.descendant(of: find.byType(Chat), matching: finder);
      expect(inChat, findsOneWidget);
      return tester.getTopLeft(inChat).dy;
    }

    final ordered = [
      top(find.text('FIRSTQ', findRichText: true)),
      top(find.textContaining('standing in for "FIRSTQ"', findRichText: true)),
      top(find.text('SECONDQ', findRichText: true)),
      top(find.textContaining('standing in for "SECONDQ"', findRichText: true)),
    ];
    expect(ordered, orderedEquals([...ordered]..sort()));
    expect(find.byType(ThinkingIndicator), findsNothing);
  });

  testWidgets('typing enables the composer and sending clears it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ChatScreen()));
    await tester.pumpAndSettle();

    final sendButtonFinder = find.byIcon(Icons.arrow_upward);
    expect(sendButtonFinder, findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Hello Hermes');
    await tester.pump();

    await tester.tap(sendButtonFinder);
    await tester.pump();
    expect(
      find.textContaining('Hello Hermes', findRichText: true),
      findsOneWidget,
    );

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, isEmpty);

    // Let the pending mock-reply timer fire so it doesn't leak past the
    // end of the test.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  });

  group('shared content', () {
    void useWideView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('text shared before the chat opens prefills the composer', (
      tester,
    ) async {
      useWideView(tester);
      final inbox = FakeShareInbox([
        const SharedText('Look at this'),
        const SharedText('https://example.com'),
      ]);
      final share = ShareController(inbox);
      await share.start();

      await tester.pumpWidget(_wrap(const ChatScreen(), share: share));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, 'Look at this\nhttps://example.com');
      expect(share.hasPending, isFalse);
    });

    testWidgets('text shared while chat is open is appended to a draft', (
      tester,
    ) async {
      useWideView(tester);
      final inbox = FakeShareInbox();
      final share = ShareController(inbox);
      await share.start();

      await tester.pumpWidget(_wrap(const ChatScreen(), share: share));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Summarise:');

      inbox.emit([const SharedText('https://example.com')]);
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, 'Summarise:\nhttps://example.com');
    });

    testWidgets(
      'shared files show as removable chips and only their names are sent',
      (tester) async {
        useWideView(tester);
        final inbox = FakeShareInbox([
          const SharedFile(path: '/tmp/a/report.pdf', name: 'report.pdf'),
          const SharedFile(
            path: '/tmp/a/photo.png',
            name: 'photo.png',
            isImage: true,
          ),
        ]);
        final share = ShareController(inbox);
        await share.start();

        await tester.pumpWidget(_wrap(const ChatScreen(), share: share));
        await tester.pumpAndSettle();

        expect(find.text('report.pdf'), findsOneWidget);
        expect(find.text('photo.png'), findsOneWidget);

        await tester.tap(find.byTooltip('Remove photo.png'));
        await tester.pump();
        expect(find.text('photo.png'), findsNothing);

        // Attachments alone are enough to send.
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();
        expect(
          find.textContaining(
            'Files (names only, contents not sent): report.pdf',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Remove report.pdf'), findsNothing);

        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();
      },
    );
  });
}

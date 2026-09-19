import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/mock_chat_data.dart';
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
    expect(find.text(threads.first.messages.first.content), findsOneWidget);
    expect(find.text('New chat'), findsOneWidget);
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(kStarterPrompts.first), findsWidgets);

    // The canned reply lands once the simulated round-trip resolves.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.textContaining('placeholder reply'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField), 'Hello Hermes');
    await tester.pump();

    await tester.tap(sendButtonFinder);
    await tester.pump();
    expect(find.text('Hello Hermes'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

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

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Look at this\nhttps://example.com');
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
      await tester.enterText(find.byType(TextField), 'Summarise:');

      inbox.emit([const SharedText('https://example.com')]);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Summarise:\nhttps://example.com');
    });

    testWidgets('shared files show as removable chips and are named on send', (
      tester,
    ) async {
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
      expect(find.textContaining('Attached: report.pdf'), findsOneWidget);
      expect(find.byTooltip('Remove report.pdf'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
    });
  });
}

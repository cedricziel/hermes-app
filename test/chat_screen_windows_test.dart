import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The main window's side of conversation windows on macOS.
void main() {
  late FakeHermesServer server;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Trip plan', lastActive: 1780000100),
          sessionRow(id: 's2', title: 'Groceries'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      );
  });

  /// The registry is built inside the test's fake-async zone, so the events
  /// it forwards run when the test pumps.
  Future<void> pump(WidgetTester tester) {
    host = FakeConversationWindowHost();
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
      headers: ({rejected}) async => const {},
    );
    addTearDown(() {
      windows.dispose();
      host.dispose();
    });
    return pumpChatScreen(
      tester,
      server: server,
      platform: TargetPlatform.macOS,
      providers: [
        ChangeNotifierProvider<ConversationWindows?>.value(value: windows),
      ],
    );
  }

  Finder row(String title) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(title),
  );

  testWidgets('double-clicking a thread opens it in a window', (tester) async {
    await pump(tester);

    await tester.tap(row('Trip plan'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row('Trip plan'));
    await tester.pumpAndSettle();

    expect(host.created.values.single.threadId, 's1');
    expect(host.created.values.single.title, 'Trip plan');
  });

  testWidgets('the thread menu opens the chat in a window', (tester) async {
    await pump(tester);

    await tester.tap(row('Trip plan'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open in New Window'));
    await tester.pumpAndSettle();

    expect(host.created.values.single.threadId, 's1');
  });

  testWidgets('a single click only selects the thread', (tester) async {
    await pump(tester);

    await tester.tap(row('Trip plan'));
    await tester.pumpAndSettle();
    await tester.tap(row('Groceries'));
    await tester.pumpAndSettle();

    expect(host.created, isEmpty);
  });

  testWidgets('option-command-O opens the open thread in a window', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Trip plan');
    await tester.tap(composerField);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(host.created.values.single.threadId, 's1');
  });

  testWidgets('the main window reads a chat open in a window again when it '
      'becomes key', (tester) async {
    await pump(tester);
    await openThread(tester, 'Trip plan');
    await windows.open('s1', profile: null, title: 'Trip plan');
    server
      ..on(
        'GET',
        '/api/sessions/s1',
        sessionRow(id: 's1', title: 'Porto', lastActive: 1780000200),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hi'),
          messageRow(id: 2, role: 'assistant', content: 'Sent from a window'),
        ]),
      );

    host.focusMain();
    await tester.pumpAndSettle();

    expect(row('Porto'), findsOneWidget);
    expect(find.textContaining('Sent from a window'), findsOneWidget);
  });
}

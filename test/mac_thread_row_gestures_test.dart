import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/drag_out/mac_drag_out_source.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_conversation_window_host.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

const _channel = MethodChannel('test/drag_out_rows');

/// The Mac sidebar rows with the real [MacDragOutSource] on a mocked channel:
/// click, double-click, right-click and Archive still do their thing, and a
/// drag starts a native drag without doing any of them.
void main() {
  late FakeHermesServer server;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late MacDragOutSource source;
  late List<MethodCall> started;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    started = [];
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
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hello from the trip'),
        ]),
      )
      ..on(
        'PATCH',
        '/api/sessions/s1',
        sessionPatchBody(flags: {'archived': true}),
      );
  });

  Future<void> pump(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      started.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
    source = MacDragOutSource(channel: _channel);
    addTearDown(source.dispose);
    host = FakeConversationWindowHost();
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      ownerKey: () => 'test-owner',
      connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
      headers: ({rejected}) async => const {},
    );
    addTearDown(() {
      windows.dispose();
      host.dispose();
    });
    return pumpChatScreen(
      tester,
      transport: FakeChatTransport(),
      server: server,
      platform: TargetPlatform.macOS,
      providers: [
        ChangeNotifierProvider<ConversationWindows?>.value(value: windows),
        Provider<DragOutSource?>.value(value: source),
      ],
    );
  }

  Finder row(String title) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(title),
  );

  Finder archive(String title) => find.descendant(
    of: find.ancestor(of: row(title), matching: find.byType(Row)).first,
    matching: find.byTooltip('Archive'),
  );

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(target));
    await tester.pumpAndSettle();
    return mouse;
  }

  Future<void> dragFrom(
    WidgetTester tester,
    Offset from, {
    double by = 20,
  }) async {
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(Offset(by, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  int messageReads() =>
      server.requestsTo('GET', '/api/sessions/s1/messages').length;

  group('gestures that must keep working', () {
    testWidgets('a click opens the chat', (tester) async {
      await pump(tester);

      await tester.tap(row('Trip plan'));
      await tester.pumpAndSettle();

      expect(messageReads(), 1);
      expect(find.text('Hello from the trip'), findsWidgets);
      expect(started, isEmpty);
    });

    testWidgets('a double-click opens a window', (tester) async {
      await pump(tester);

      await tester.tap(row('Trip plan'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(row('Trip plan'));
      await tester.pumpAndSettle();

      expect(host.created.values.single.threadId, 's1');
      expect(started, isEmpty);
    });

    testWidgets('a right-click opens the thread menu', (tester) async {
      await pump(tester);

      await tester.tap(row('Trip plan'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Open in New Window'), findsOneWidget);
      expect(find.text('Copy Transcript'), findsOneWidget);
      expect(started, isEmpty);
    });

    testWidgets('the Archive button archives', (tester) async {
      await pump(tester);
      await hover(tester, row('Trip plan'));

      await tester.tap(archive('Trip plan'));
      await tester.pumpAndSettle();

      expect(jsonBody(server.requestsTo('PATCH', '/api/sessions/s1').single), {
        'archived': true,
      });
      expect(started, isEmpty);
    });
  });

  group('a drag', () {
    testWidgets('on a row starts a thread drag and does nothing else', (
      tester,
    ) async {
      await pump(tester);

      await dragFrom(tester, tester.getCenter(row('Trip plan')));

      expect(started.single.method, 'startDrag');
      expect(started.single.arguments, containsPair('type', 'file'));
      expect(started.single.arguments, containsPair('name', 'Trip plan.md'));
      expect(messageReads(), 0, reason: 'the chat was not opened');
      expect(host.created, isEmpty);
      expect(server.requestsTo('PATCH', '/api/sessions/s1'), isEmpty);
    });

    testWidgets('let go near where it began does not click the row', (
      tester,
    ) async {
      await pump(tester);

      await dragFrom(tester, tester.getCenter(row('Trip plan')), by: 8);

      expect(started, hasLength(1));
      expect(messageReads(), 0);
    });

    testWidgets('from the Archive button does not archive', (tester) async {
      await pump(tester);
      await hover(tester, row('Trip plan'));

      await dragFrom(tester, tester.getCenter(archive('Trip plan')), by: 8);

      expect(started, hasLength(1));
      expect(server.requestsTo('PATCH', '/api/sessions/s1'), isEmpty);
    });
  });
}

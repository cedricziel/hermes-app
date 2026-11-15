import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Runs [body], then unmounts the screen and lets the list's pending timers
/// run out.
void streamTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }
    });

/// What the reader opened in a streaming reply stays open as more tool calls
/// start, through the real chat screen.
void main() {
  late FakeChatTransport transport;
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/profiles', profileListBody([profileRow(name: 'work')]))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored', title: 'Synthetic')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      );
  });

  Future<FakeSend> start(WidgetTester tester, {required Size size}) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      size: size,
    );
    await openThread(tester, 'Synthetic');
    await tester.enterText(composerField, 'go');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final send = transport.sends.single;
    send.emit(const ReplyStarted());
    await tester.pump(const Duration(milliseconds: 50));
    return send;
  }

  Future<void> emit(WidgetTester tester, FakeSend send, ChatEvent e) async {
    send.emit(e);
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tool(
    WidgetTester tester,
    FakeSend send,
    int n, {
    bool finish = true,
  }) async {
    await emit(
      tester,
      send,
      ToolStarted(id: 't$n', name: 'tool$n', summary: 's$n', args: {'a': 'b'}),
    );
    if (finish) {
      await emit(
        tester,
        send,
        ToolFinished(id: 't$n', name: 'tool$n', result: 'RESULT-$n body'),
      );
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder result(int n) => find.textContaining('RESULT-$n');

  for (final (label, size) in [
    ('desktop', const Size(1400, 900)),
    ('phone', const Size(390, 844)),
  ]) {
    group(label, () {
      streamTest('a lone call the reader opened stays open when a second '
          'starts, inside the opened group', (tester) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tap(tester, find.byType(ToolCallCard));
        expect(result(1), findsOneWidget);

        await tool(tester, send, 2, finish: false);

        expect(find.byType(ToolCallGroup), findsOneWidget);
        expect(find.text('Running tool2…'), findsOneWidget);
        expect(find.byType(ToolCallCard), findsNWidgets(2));
        expect(result(1), findsOneWidget);
        // The card the reader was reading is still on screen, and so is what
        // it shows: reachable by a tap and inside the viewport.
        final card = find.byType(ToolCallCard).first;
        final rect = tester.getRect(card);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(result(1).hitTestable(), findsOneWidget);
        final shown = tester.getRect(result(1));
        expect(shown.top, greaterThanOrEqualTo(0));
        expect(shown.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      });

      streamTest('an open group and an open inner card stay open when a '
          'third call starts', (tester) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tool(tester, send, 2);
        await tap(tester, find.text('Used 2 tools'));
        await tap(tester, find.byType(ToolCallCard).first);
        expect(result(1), findsOneWidget);

        await tool(tester, send, 3, finish: false);

        expect(find.byType(ToolCallCard), findsNWidgets(3));
        expect(result(1), findsOneWidget);
        await emit(
          tester,
          send,
          const ToolFinished(id: 't3', name: 'tool3', result: 'RESULT-3'),
        );
        expect(result(1), findsOneWidget);
      });

      streamTest('a card opened in a group survives the reply completing', (
        tester,
      ) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tool(tester, send, 2);
        await tap(tester, find.text('Used 2 tools'));
        await tap(tester, find.byType(ToolCallCard).first);

        await emit(tester, send, const ReplyDelta('answer'));
        send.finish();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 2));

        expect(result(1), findsOneWidget);
      });

      streamTest('a group the reader closed stays closed when another call '
          'starts', (tester) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tool(tester, send, 2);
        await tap(tester, find.text('Used 2 tools'));
        await tap(tester, find.text('Used 2 tools'));
        expect(find.byType(ToolCallCard), findsNothing);

        await tool(tester, send, 3, finish: false);

        expect(find.text('Running tool3…'), findsOneWidget);
        expect(find.byType(ToolCallCard), findsNothing);
      });

      streamTest('a card the reader closed again stays closed when a second '
          'call starts', (tester) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tap(tester, find.byType(ToolCallCard));
        await tap(tester, find.byType(ToolCallCard));
        expect(result(1), findsNothing);

        await tool(tester, send, 2, finish: false);

        expect(find.byType(ToolCallGroup), findsOneWidget);
        expect(find.byType(ToolCallCard), findsNothing);
      });

      streamTest('a card opened in a group is open again after the group is '
          'folded and opened', (tester) async {
        final send = await start(tester, size: size);
        await tool(tester, send, 1);
        await tool(tester, send, 2);
        await tap(tester, find.text('Used 2 tools'));
        await tap(tester, find.byType(ToolCallCard).first);
        await tap(tester, find.text('Used 2 tools'));
        expect(result(1), findsNothing);

        await tap(tester, find.text('Used 2 tools'));

        expect(result(1), findsOneWidget);
      });
    });
  }
}

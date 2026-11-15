import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show ChatAnimatedList;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/following_chat_list.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

void streamTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }
    });

/// What the reader opened among the tool calls stays open when the list is
/// built anew (the blank-list recovery) and when its row scrolls out of the
/// list and back, through the real chat screen.
void main() {
  late FakeChatTransport transport;
  late FakeHermesServer server;
  var size = const Size(390, 844);

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
        sessionListBody([
          sessionRow(id: 'stored', title: 'Synthetic'),
          sessionRow(id: 'other', title: 'Elsewhere'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', [
          for (var i = 0; i < 40; i++)
            messageRow(
              id: i + 1,
              role: i.isEven ? 'user' : 'assistant',
              content: 'History line $i. ${'More words. ' * 60}',
            ),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/other/messages',
        messageListBody('other', [
          messageRow(id: 1, role: 'user', content: 'Hello there'),
          messageRow(id: 2, role: 'assistant', content: 'Hi'),
        ]),
      );
  });

  Future<FakeSend> start(WidgetTester tester) async {
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
    String id, {
    String? n,
  }) async {
    n ??= id;
    await emit(
      tester,
      send,
      ToolStarted(id: id, name: 'tool$n', summary: 's$n', args: {'a': 'b'}),
    );
    await emit(
      tester,
      send,
      ToolFinished(id: id, name: 'tool$n', result: 'RESULT-$n body'),
    );
  }

  Finder result(String n) => find.textContaining('RESULT-$n');

  /// Scrolls the chat list, not a card's own scroll area, until [f] is in
  /// the part of the viewport above the composer.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    final list = find
        .descendant(
          of: find.byType(ChatAnimatedList),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 16; i++) {
      final r = tester.getRect(f);
      if (r.top >= 0 && r.bottom <= size.height - 140) return;
      await tester.drag(
        list,
        Offset(0, r.bottom > size.height - 140 ? -250 : 250),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The text is on screen: in the viewport, above the composer, and
  /// reachable by a tap.
  Future<void> expectVisible(WidgetTester tester, Finder f) async {
    expect(f, findsOneWidget);
    await reveal(tester, f);
    expect(f.hitTestable(), findsOneWidget);
    final rect = tester.getRect(f);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(size.height - 140));
  }

  /// Back to the end of the thread, where the list follows again.
  Future<void> toBottom(WidgetTester tester) async {
    final list = find
        .descendant(
          of: find.byType(ChatAnimatedList),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 8; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// The blank-list recovery: the list mounts anew under a fresh key.
  Future<void> remountList(WidgetTester tester) async {
    (tester.state(find.byType(FollowingChatList)) as dynamic).recoverForTest();
    await frames(tester, 40);
    await toBottom(tester);
  }

  /// A row of the list, which is built anew when the list is.
  Element rowElement(WidgetTester tester) =>
      tester.element(find.byType(ChatAnimatedList));

  Future<void> tapCard(WidgetTester tester, Finder card) async {
    await reveal(tester, card);
    await tester.tap(card);
    await frames(tester, 25);
  }

  for (final (label, viewSize) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1400, 900)),
  ]) {
    group(label, () {
      setUp(() => size = viewSize);

      streamTest(
        'opening the last card of a streaming reply over a long history '
        'does not remount the list',
        (tester) async {
          final send = await start(tester);
          await tool(tester, send, 't1');
          await tool(tester, send, 't2');
          await tool(tester, send, 't3');
          await tapCard(tester, find.text('Used 3 tools'));
          final row = rowElement(tester);

          await tapCard(tester, find.byType(ToolCallCard).last);
          await frames(tester, 40);

          expect(identical(rowElement(tester), row), isTrue);
          await expectVisible(tester, result('t3'));
        },
      );

      streamTest('an opened card is open after the list is built anew', (
        tester,
      ) async {
        final send = await start(tester);
        await tool(tester, send, 't1');
        await tool(tester, send, 't2');
        await tool(tester, send, 't3');
        await tapCard(tester, find.text('Used 3 tools'));
        await tapCard(tester, find.byType(ToolCallCard).last);
        await tester.pump(const Duration(seconds: 1));
        final row = rowElement(tester);
        await expectVisible(tester, result('t3'));

        await remountList(tester);

        expect(
          identical(rowElement(tester), row),
          isFalse,
          reason: 'the list was remounted by the watchdog',
        );
        await expectVisible(tester, result('t3'));
        expect(find.byType(ToolCallCard), findsNWidgets(3));
      });

      streamTest('a card opened with ids out of order stays open on its own '
          'after a remount', (tester) async {
        final send = await start(tester);
        await tool(tester, send, 't9', n: '9');
        await tool(tester, send, 't2', n: '2');
        await tool(tester, send, 't5', n: '5');
        await tapCard(tester, find.text('Used 3 tools'));
        await tapCard(tester, find.byType(ToolCallCard).at(1));
        await tester.pump(const Duration(seconds: 1));
        await expectVisible(tester, result('2'));

        await remountList(tester);

        await expectVisible(tester, result('2'));
        expect(result('9'), findsNothing);
        expect(result('5'), findsNothing);
      });

      streamTest(
        'an opened group and card are open after scrolling the row far '
        'out of view and back',
        (tester) async {
          final send = await start(tester);
          await tool(tester, send, 't1');
          await tool(tester, send, 't2');
          await tapCard(tester, find.text('Used 2 tools'));
          await tapCard(tester, find.byType(ToolCallCard).first);
          expect(result('t1'), findsOneWidget);

          final list = find
              .descendant(
                of: find.byType(ChatAnimatedList),
                matching: find.byType(Scrollable),
              )
              .first;
          for (
            var i = 0;
            i < 80 &&
                find
                    .byType(ToolCallCard, skipOffstage: false)
                    .evaluate()
                    .isNotEmpty;
            i++
          ) {
            await tester.drag(list, const Offset(0, 700));
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(
            find.byType(ToolCallCard, skipOffstage: false),
            findsNothing,
            reason: 'row left the list',
          );

          for (var i = 0; i < 90; i++) {
            await tester.drag(list, const Offset(0, -700));
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(ToolCallCard), findsNWidgets(2));
          expect(result('t1'), findsOneWidget);
        },
      );

      streamTest('what was opened stays open when the chat list is read again '
          'for the same profile', (tester) async {
        server.on(
          'GET',
          '/api/sessions/stored/messages',
          messageListBody('stored', [
            messageRow(id: 1, role: 'user', content: 'List the files'),
            messageRow(
              id: 2,
              role: 'assistant',
              toolCalls: [functionCall('terminal', '{"command":"ls"}')],
            ),
            messageRow(
              id: 3,
              role: 'tool',
              toolName: 'terminal',
              toolCallId: 'call_terminal',
              content: 'RESULT-h body',
            ),
            messageRow(id: 4, role: 'assistant', content: 'Here they are.'),
          ]),
        );
        await pumpChatScreen(
          tester,
          server: server,
          withProfiles: true,
          transport: transport,
          size: size,
        );
        await openThread(tester, 'Synthetic');
        await tapCard(tester, find.byType(ToolCallCard));
        expect(result('h'), findsOneWidget);

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        await expectVisible(tester, result('h'));
      });

      if (label == 'desktop') {
        streamTest('what was opened is dropped when another chat opens', (
          tester,
        ) async {
          final send = await start(tester);
          await tool(tester, send, 't1');
          await tapCard(tester, find.byType(ToolCallCard));
          expect(result('t1'), findsOneWidget);
          send.finish();
          await tester.pump(const Duration(seconds: 1));

          await openThread(tester, 'Elsewhere');
          expect(find.byType(ToolCallCard), findsNothing);
          await openThread(tester, 'Synthetic');
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(ToolCallCard), findsOneWidget);
          expect(result('t1'), findsNothing);
        });
      }
    });
  }
}

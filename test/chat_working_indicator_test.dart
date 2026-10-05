import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/widgets/working_dot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A turn running in a thread this client never streamed — started on the TUI
/// or another device — and the working mark in the thread list. A spinner
/// never settles, so nothing here may pumpAndSettle while one is on screen.
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
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      );
  });

  testWidgets('opening a thread mid-turn shows the replying indicator', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');

    // The turn was picked up mid-stream: its first event is a delta, with no
    // ReplyStarted before it.
    final follow = transport.followUpStreams['s1']!;
    expect(follow.hasListener, isTrue);
    follow.emit(const ReplyDelta('Still digging.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Still digging.', findRichText: true), findsOneWidget);
    expect(find.text('Hermes is replying…'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    follow.emit(const ReplyCompleted('It was the retry loop.'));
    await tester.pump();

    expect(
      find.text('It was the retry loop.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Stop'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a thread mid-turn elsewhere carries the working mark', (
    tester,
  ) async {
    transport.active['s1'] = 'working';
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      settle: false,
    );
    for (var i = 0; i < 10 && find.byType(WorkingDot).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(WorkingDot), findsOneWidget);

    // When the turn ends elsewhere, the mark goes from the list. Tapping the
    // row asks again; a spinner is still on screen, so no pumpAndSettle.
    transport.active.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Run failure'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WorkingDot), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('reopening a thread can pick up a later turn', (tester) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    transport.followUpStreams['s1']!.finish();
    await tester.pump();

    await openThread(tester, 'Run failure');

    expect(transport.followUpCalls, 2);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('MacThreadRow shows the working mark when busy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MacThreadRow(
            title: 'Run failure',
            selected: false,
            busy: true,
            onTap: () {},
            menuItems: (_) =>
                macThreadMenuItems(pinned: false, manageable: false),
            onAction: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(WorkingDot), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Working',
      ),
      findsOneWidget,
    );
  });
}

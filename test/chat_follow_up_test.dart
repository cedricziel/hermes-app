import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Turns Hermes chains after a reply, with no prompt from the user: the screen
/// keeps listening once the reply it sent ended.
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

  final composerField = find.descendant(
    of: find.byType(Composer),
    matching: find.byType(EditableText),
  );

  Future<FakeSend> sendAndFinish(
    WidgetTester tester,
    String reply, {
    bool failed = false,
  }) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    await tester.enterText(composerField, 'Plan it');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final turn = transport.sends.last;
    turn.emit(ReplyCompleted(reply, failed: failed));
    await tester.pump();
    turn.finish();
    await tester.pump();
    return turn;
  }

  testWidgets('a turn chained after the reply shows up as a new reply', (
    tester,
  ) async {
    await sendAndFinish(tester, 'Checking first.');
    final follow = transport.followUpStreams['s1']!;

    follow.emit(const ReplyStarted());
    follow.emit(const ReplyDelta('Now the board'));
    await tester.pump();

    expect(find.text('Checking first.'), findsOneWidget);
    expect(find.text('Now the board'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    follow.emit(const ReplyCompleted('Now the board is planned.'));
    await tester.pump();

    expect(find.text('Now the board is planned.'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('every chained turn gets its own reply', (tester) async {
    await sendAndFinish(tester, 'One.');
    final follow = transport.followUpStreams['s1']!;

    for (final text in ['Two.', 'Three.']) {
      follow.emit(const ReplyStarted());
      follow.emit(ReplyCompleted(text));
      await tester.pump();
    }

    expect(find.text('One.'), findsOneWidget);
    expect(find.text('Two.'), findsOneWidget);
    expect(find.text('Three.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a title between turns does not touch the last reply', (
    tester,
  ) async {
    await sendAndFinish(tester, 'Done.');
    final follow = transport.followUpStreams['s1']!;

    follow.emit(const ThreadTitled('Board planning'));
    await tester.pump();

    expect(find.text('Board planning'), findsWidgets);
    expect(find.text('Done.'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a connection lost mid-turn fails that reply only', (
    tester,
  ) async {
    await sendAndFinish(tester, 'One.');
    final follow = transport.followUpStreams['s1']!;

    follow.emit(const ReplyStarted());
    follow.fail();
    await tester.pump();

    expect(find.text('One.'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a reply that completed as failed is not followed', (
    tester,
  ) async {
    await sendAndFinish(tester, '', failed: true);

    expect(transport.followUpStreams, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed reply is not followed', (tester) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    await tester.enterText(composerField, 'Plan it');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    transport.sends.last.fail();
    await tester.pump();

    expect(transport.followUpStreams, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });
}

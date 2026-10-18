import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Hermes reads a reply back once its turn is over and may save memories or
/// skills; reports stay bound to that reply and appear in the inspector.
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
    of: find.byType(ChatComposer),
    matching: find.byType(EditableText),
  );

  Future<void> sendAndFinish(WidgetTester tester, String reply) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    await tester.enterText(composerField, 'Plan it');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final turn = transport.sends.last;
    turn.emit(ReplyCompleted(reply));
    await tester.pump();
    turn.finish();
    await tester.pump();
  }

  testWidgets('background review appears only in the inspector', (
    tester,
  ) async {
    await sendAndFinish(tester, 'The disk was full.');
    transport.followUpStreams['s1']!.emit(
      const ReviewSummarized(['Memory updated', "Skill 'disk-check' patched"]),
    );
    await tester.pump();
    expect(find.textContaining('Memory updated'), findsNothing);
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Memory & review'));
    await tester.pumpAndSettle();
    expect(find.text('Memory updated'), findsOneWidget);
    expect(find.text("Skill 'disk-check' patched"), findsOneWidget);
    expect(find.text('The disk was full.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a review that arrives during the next turn stays with the '
      'reply it read', (tester) async {
    await sendAndFinish(tester, 'The disk was full.');
    final follow = transport.followUpStreams['s1']!;
    follow.emit(const ReplyStarted());
    follow.emit(const ReplyDelta('Now cleaning up'));
    await tester.pump();

    follow.emit(const ReviewSummarized(['Memory updated']));
    await tester.pump();

    expect(find.text('Memory updated'), findsNothing);
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final panel = tester.widget<BoundActivityPanel>(
      find.byType(BoundActivityPanel),
    );
    final messages = panel.thread!.messages;
    expect(
      messages.firstWhere((m) => m.content == 'The disk was full.').reviewNotes,
      ['Memory updated'],
    );
    expect(messages.last.reviewNotes, isEmpty);
    await tester.tap(find.text('Memory & review'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Memory updated'), findsOneWidget);

    follow.emit(const ReplyCompleted('Now cleaning up the disk.'));
    await tester.pump(const Duration(seconds: 5));
  });
}

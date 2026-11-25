import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';
import 'support/tooltip_finder.dart';

/// What the person sees: the transcript marks a reply that Retry replaced, and
/// no other.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
        ]),
      );
  });

  final marker = find.descendant(
    of: find.byType(Chat),
    matching: find.text('Regenerated'),
  );

  Future<void> answer(WidgetTester tester, String prompt, String text) async {
    await tester.enterText(composerField, prompt);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    transport.sends.last
      ..emit(const PromptAcknowledged(1))
      ..emit(ReplyDelta(text))
      ..emit(ReplyCompleted(text))
      ..finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('only the reply Retry produced shows Regenerated', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    await answer(tester, 'And again', 'First try');
    expect(find.textContaining('First try', findRichText: true), findsWidgets);
    expect(marker, findsNothing);

    await tester.tap(find.tooltip('Try again'));
    await tester.pump();
    await tester.pump();
    transport.sends.last
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Second try'))
      ..emit(const ReplyCompleted('Second try'))
      ..finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Second try', findRichText: true), findsWidgets);
    expect(marker, findsOneWidget);
  });
}

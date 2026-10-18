import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';

import 'support/fake_chat_transport.dart';
import 'support/pump_chat.dart';

void main() {
  Future<FakeSend> start(WidgetTester tester) async {
    final transport = FakeChatTransport();
    await pumpChatScreen(tester, transport: transport);
    await tester.enterText(composerField, 'Check the logs');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    return transport.sends.single;
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('a waiting-only block stays honest and open after completion', (
    tester,
  ) async {
    final send = await start(tester);
    await tester.tap(find.byType(ReasoningBlock));
    await flush(tester);
    send.emit(const ReplyDelta('Here is'));
    await flush(tester);
    expect(find.text('No reasoning text was provided.'), findsOneWidget);
    send
      ..emit(const ReplyCompleted('Here is the answer.'))
      ..finish();
    await tester.pumpAndSettle();
    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.text('No reasoning text was provided.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an opened thinking block streams and remains after the answer', (
    tester,
  ) async {
    final send = await start(tester);
    await tester.tap(find.byType(ReasoningBlock));
    await flush(tester);
    expect(find.text('Waiting for reasoning…'), findsOneWidget);
    send.emit(const ReasoningUpdated('First, check'));
    await flush(tester);
    expect(find.text('First, check'), findsOneWidget);
    send.emit(const ReasoningUpdated(' the retry loop.'));
    await flush(tester);
    expect(find.text('First, check the retry loop.'), findsOneWidget);
    send.emit(const ReplyDelta('The retry'));
    await flush(tester);
    expect(
      tester.widget<ReasoningBlock>(find.byType(ReasoningBlock)).active,
      isFalse,
    );
    expect(find.text('First, check the retry loop.'), findsOneWidget);
    send
      ..emit(const ReplyCompleted('The retry loop caused it.'))
      ..finish();
    await tester.pumpAndSettle();
    expect(find.text('First, check the retry loop.'), findsOneWidget);
    expect(find.text('Reasoning'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('starting a tool preserves the expanded reasoning before it', (
    tester,
  ) async {
    final send = await start(tester);
    send.emit(const ReasoningUpdated('Inspect the log file.'));
    await flush(tester);
    await tester.tap(find.byType(ReasoningBlock));
    await flush(tester);
    send.emit(const ToolPreparing('read_file'));
    await flush(tester);
    expect(find.text('Inspect the log file.'), findsOneWidget);
    send.emit(
      const ToolStarted(name: 'read_file', summary: 'Read logs', id: 'read-1'),
    );
    await flush(tester);
    expect(find.text('Inspect the log file.'), findsOneWidget);
    send.emit(const ReasoningUpdated('Now compare the timestamps.'));
    await flush(tester);
    expect(find.byType(ReasoningBlock), findsNWidgets(2));
    expect(find.text('Inspect the log file.'), findsOneWidget);
    expect(find.text('Now compare the timestamps.'), findsNothing);
    await tester.tap(find.byType(ReasoningBlock).last);
    await flush(tester);
    expect(find.text('Now compare the timestamps.'), findsOneWidget);
    send
      ..emit(const ReplyCompleted('Found it.'))
      ..finish();
    await tester.pumpAndSettle();
    expect(find.text('Inspect the log file.'), findsOneWidget);
    expect(find.text('Now compare the timestamps.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(WidgetTester tester, List<ToolCall> calls) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: ToolCallGroup(calls: calls)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a single call renders as a bare ToolCallCard', (tester) async {
    await _pump(tester, const [ToolCall(name: 'terminal', summary: 'ls')]);

    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(find.textContaining('Ran'), findsNothing);
  });

  testWidgets('several finished calls collapse behind a count, closed', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'read_file', summary: 'a.dart'),
      ToolCall(name: 'write_file', summary: 'b.dart'),
    ]);

    expect(find.text('Ran 3 commands'), findsOneWidget);
    expect(find.byType(ToolCallCard), findsNothing);

    await tester.tap(find.text('Ran 3 commands'));
    await tester.pump();

    expect(find.byType(ToolCallCard), findsNWidgets(3));

    await tester.tap(find.text('Ran 3 commands'));
    await tester.pump();

    expect(find.byType(ToolCallCard), findsNothing);
  });

  testWidgets('a call still running names it, while others show a count', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'git_show', summary: '', status: ToolCallStatus.running),
    ]);

    expect(find.text('Running git_show…'), findsOneWidget);
    expect(find.text('Ran 2 commands'), findsNothing);
  });

  testWidgets('a failed call in a finished group is not mistaken for '
      'success', (tester) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'web_search', summary: '', status: ToolCallStatus.error),
    ]);

    await tester.tap(find.text('Ran 2 commands'));
    await tester.pump();

    final failed = tester.widget<ToolCallCard>(
      find.byWidgetPredicate(
        (w) => w is ToolCallCard && w.call.name == 'web_search',
      ),
    );
    expect(failed.call.status, ToolCallStatus.error);
  });
}

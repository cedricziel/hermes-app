import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(WidgetTester tester, ToolCall call) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 320, child: ToolCallCard(call: call)),
      ),
    ),
  ),
);

void main() {
  testWidgets('tapping opens the input and result, and again closes them', (
    tester,
  ) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: '{"command":"ls -la"}',
        result: 'total 0',
      ),
    );

    expect(find.text('Result'), findsNothing);

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.byType(JsonView), findsOneWidget);
    final viewer = find.byType(JsonView);
    expect(
      find.descendant(of: viewer, matching: find.textContaining('command')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: viewer, matching: find.textContaining('ls -la')),
      findsOneWidget,
    );
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('total 0'), findsOneWidget);

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Result'), findsNothing);
  });

  testWidgets('input that is not JSON is shown as it is', (tester) async {
    await _pump(tester, const ToolCall(name: 'terminal', summary: 'ls -la'));

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('ls -la'), findsWidgets);
    expect(find.byType(JsonView), findsNothing);
    expect(find.text('Result'), findsNothing);
  });

  testWidgets('a call with nothing to show does not expand', (tester) async {
    await _pump(tester, const ToolCall(name: 'kanban_show', summary: ''));

    await tester.tap(find.text('kanban_show'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });
}

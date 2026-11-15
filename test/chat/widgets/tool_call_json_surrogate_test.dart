import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _open(WidgetTester tester, String result) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: ToolCallCard(
              call: ToolCall(name: 'custom', summary: '', result: result),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('custom'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('an escaped lone surrogate in a value and a key paints', (
    tester,
  ) async {
    await _open(tester, r'{"k\ud800":"v\ud800","list":["\udc00"]}');
    expect(find.byType(JsonView), findsOneWidget);
  });

  testWidgets('keys that clean to the same text stay as flat text', (
    tester,
  ) async {
    await _open(tester, r'{"\ud800":1,"\ud801":2}');
    expect(find.byType(JsonView), findsNothing);
    expect(find.textContaining('ud801', findRichText: true), findsOneWidget);
  });

  testWidgets('a 50,000-deep input paints as flat text', (tester) async {
    const depth = 50000;
    await _open(tester, '${'[' * depth}"\\ud800"${']' * depth}');
    expect(find.byType(JsonView), findsNothing);
  });

  testWidgets('well-formed JSON is still a tree', (tester) async {
    await _open(tester, '{"a":1.0,"b":["\u{1F600}"]}');
    expect(find.byType(JsonView), findsOneWidget);
  });
}

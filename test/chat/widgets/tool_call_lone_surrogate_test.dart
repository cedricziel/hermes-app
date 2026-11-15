import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_arguments_view.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

Future<void> _open(WidgetTester tester, ToolCall call) async {
  await _pump(tester, ToolCallCard(call: call));
  await tester.tap(find.text(call.name));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a generic call paints lone surrogates in args and result', (
    tester,
  ) async {
    await _open(
      tester,
      const ToolCall(
        name: 'custom',
        summary: 'sum\ud800',
        args: {'k\ud800': 'v\ud800', 'n': 1},
        result: 'plain \ud800 result',
      ),
    );
    expect(find.textContaining('�', findRichText: true), findsWidgets);
  });

  testWidgets('a JSON result with an escaped lone surrogate paints', (
    tester,
  ) async {
    await _open(
      tester,
      const ToolCall(
        name: 'custom',
        summary: 's',
        result: r'{"a":"x\ud800","b":[1.0,"\udc00"]}',
      ),
    );
  });

  testWidgets('a terminal call paints a lone surrogate', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: 's',
        args: {'command': 'echo \ud800'},
        result: 'out\ud800',
        resultData: {'output': 'out\ud800', 'error': 'bad\ud800'},
      ),
    );
    expect(find.textContaining('out�', findRichText: true), findsOneWidget);
  });

  testWidgets('a diff paints a lone surrogate', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'patch',
        summary: 's',
        diff: '-old\ud800\n+new\ud800',
      ),
    );
  });

  testWidgets('ToolArgumentsView paints a lone surrogate', (tester) async {
    await _pump(
      tester,
      const ToolArgumentsView(
        arguments: {
          'command': 'ls \ud800',
          'nested': {'a': '\udc00'},
        },
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ls �', findRichText: true), findsOneWidget);
  });

  testWidgets('emoji in args and result are unchanged', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: 's',
        args: {'command': 'echo \u{1F600}'},
        result: 'hi \u{1F600}',
        resultData: {'output': 'hi \u{1F600}'},
      ),
    );
    expect(
      find.textContaining('hi \u{1F600}', findRichText: true),
      findsOneWidget,
    );
  });
}

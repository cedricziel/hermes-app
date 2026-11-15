import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/src/theme/hermes_code_colors.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

/// The leaf spans of the code text of the [index]th block on screen.
List<TextSpan> _runs(WidgetTester tester, {int index = 0}) {
  final block = find.byType(HermesCodeBlock).at(index);
  final text = tester.widget<Text>(
    find.descendant(
      of: block,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.textSpan?.style?.fontFamily != null),
      ),
    ),
  );
  return [...(text.textSpan! as TextSpan).children!.cast<TextSpan>()];
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

HermesCodeBlock _block({required bool highlight}) => HermesCodeBlock(
  name: 'python',
  codes: 'def f(x):\n    return x + 1  # one\n',
  style: const CodeBlockStyle(),
  highlightCode: highlight,
);

void main() {
  testWidgets('a block told not to colour is one plain run', (tester) async {
    await _pump(tester, _block(highlight: false));
    final runs = _runs(tester);
    expect(runs, hasLength(1));
    expect(runs.single.text, 'def f(x):\n    return x + 1  # one\n');
    expect(runs.single.style, isNull);
  });

  testWidgets('a block told to colour is coloured by the palette', (
    tester,
  ) async {
    await _pump(tester, _block(highlight: true));
    final runs = _runs(tester);
    expect(runs.length, greaterThan(1));
    expect(
      runs.firstWhere((r) => r.text == 'def').style?.color,
      HermesCodeColors.light.keyword,
    );
  });

  testWidgets('a document past its colouring budget shows later blocks plain', (
    tester,
  ) async {
    final text = List.generate(
      40,
      (i) => '```js\nconst v$i = ${'1 + ' * 80}1;\n```',
    ).join('\n\n');
    await _pump(tester, BoundedMarkdown(text));
    final count = find.byType(HermesCodeBlock).evaluate().length;
    expect(count, 40);
    expect(_runs(tester, index: 0).length, greaterThan(1));
    final last = _runs(tester, index: count - 1);
    expect(last, hasLength(1));
    expect(last.single.style, isNull);
  });
}

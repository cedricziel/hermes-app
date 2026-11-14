import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/code_highlight.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';

import 'widgets/files_widget_harness.dart';

int _leafSpans(WidgetTester tester) {
  final selectable = tester.widget<SelectableText>(
    find.descendant(
      of: find.byType(CodePreview),
      matching: find.byType(SelectableText),
    ),
  );
  var count = 0;
  selectable.textSpan!.visitChildren((span) {
    if (span is TextSpan && span.text != null) count++;
    return true;
  });
  return count;
}

int _keywordFences(WidgetTester tester) {
  var count = 0;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'def') count++;
      return true;
    });
  }
  return count;
}

void main() {
  group('capRuns', () {
    test('merges adjacent runs of one token', () {
      expect(
        capRuns([
          ('a', CodeToken.keyword),
          ('b', CodeToken.keyword),
          ('c', null),
        ]),
        [('ab', CodeToken.keyword), ('c', null)],
      );
    });

    test('leaves a few runs alone', () {
      final runs = <CodeRun>[('a', CodeToken.keyword), ('b', null)];
      expect(capRuns(runs), runs);
    });

    test('turns the rest into one plain run past the cap, text unchanged', () {
      final runs = <CodeRun>[
        for (var i = 0; i < 50; i++)
          ('$i;', i.isEven ? CodeToken.number : null),
      ];
      final capped = capRuns(runs, max: 10);
      expect(capped, hasLength(10));
      expect(capped.last.$2, isNull);
      expect(capped.map((r) => r.$1).join(), runs.map((r) => r.$1).join());
    });
  });

  test('a dense file comes out of highlightCode with at most the cap', () {
    final dense = '1+1;\n' * 4000;
    final runs = highlightCode(dense, 'typescript');
    expect(runs.length, lessThanOrEqualTo(kCodeHighlightMaxRuns));
    expect(runs.length, greaterThan(100), reason: 'still coloured at the top');
    expect(runs.map((r) => r.$1).join(), dense);
  });

  testWidgets('a dense small file builds a bounded number of spans', (
    tester,
  ) async {
    final dense = '1+1;\n' * 400;
    expect(isInlineSafe(dense), isTrue);
    await pumpFiles(tester, CodePreview(text: dense, language: 'typescript'));
    expect(_leafSpans(tester), lessThanOrEqualTo(kCodeHighlightMaxRuns));
    expect(_leafSpans(tester), greaterThan(100));
  });

  testWidgets('a dense file from the worker builds a bounded frame', (
    tester,
  ) async {
    final dense = '1+1;\n' * 20000;
    await pumpFiles(tester, CodePreview(text: dense, language: 'typescript'));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && CodeHighlightWorker.alive > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    final clock = Stopwatch()..start();
    await tester.pump();
    expect(_leafSpans(tester), lessThanOrEqualTo(kCodeHighlightMaxRuns));
    expect(clock.elapsedMilliseconds, lessThan(3000));
  });

  testWidgets('Markdown fences colour the same after Source and back', (
    tester,
  ) async {
    final fences = List.generate(
      6,
      (i) => '```python\ndef f$i(): pass\n```',
    ).join('\n\n');
    Future<void> show(bool source) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(text: fences, showSource: source),
        ),
      ),
    );
    await show(false);
    final first = _keywordFences(tester);
    expect(first, 6);
    for (var i = 0; i < 3; i++) {
      await show(true);
      await show(false);
      expect(_keywordFences(tester), first, reason: 'toggle ${i + 1}');
    }
  });
}

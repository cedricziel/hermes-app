import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:hermes_app/src/theme/hermes_code_colors.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

const _mixed = '''
# Title

Some **bold** prose with `inline code` and a [link](https://example.com).

- item one
- item two with a block:

  ```python
  def f(x):
      return x + 1  # comment
  ```

> quoted text
>
> ```js
> const q = 1;
> ```

1. first
2. second

| a | b |
|---|---|
| 1 | 2 |

```dart
void main() {
  print('hello');
}
```

```
no language here
```

Done.
''';

/// What a document shows: every code block's name, code and size, every run's
/// text, and the colour and weight of every run outside a code block. A code
/// block is `CodeField` in a plain `GptMarkdown` and [HermesCodeBlock] in a
/// `BoundedMarkdown`, which colours it by the app's code palette rather than
/// the package's and merges runs of one colour, so only the joined text of a
/// code block is kept.
String _digest(WidgetTester tester) {
  final out = StringBuffer();
  final blocks = find.byWidgetPredicate(
    (w) => w is CodeField || w is HermesCodeBlock,
  );
  for (final block in tester.widgetList(blocks)) {
    out.writeln(
      block is CodeField
          ? 'field ${block.name}|${block.codes}'
          : 'field ${(block as HermesCodeBlock).name}|${block.codes}',
    );
  }
  for (final rect in tester.elementList(blocks)) {
    out.writeln('size ${(rect.renderObject! as RenderBox).size}');
  }
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text != null) {
        out.writeln(
          'run ${span.text}|${span.style?.color}|${span.style?.fontWeight}',
        );
      }
      span.children?.forEach(visit);
    }
  }

  final inside = tester
      .widgetList<RichText>(
        find.descendant(of: blocks, matching: find.byType(RichText)),
      )
      .toSet();
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    if (inside.contains(rich)) {
      out.writeln(
        'code ${rich.text.toPlainText(includeSemanticsLabels: false)}',
      );
    } else {
      visit(rich.text);
    }
  }
  return out.toString();
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function(String) build,
  String text, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: build(text))),
      ),
    ),
  );
}

String _block(int chars, [String c = 'a']) =>
    List.filled(chars ~/ 100, c * 99).join('\n');

void main() {
  group('CodeHighlightBudget', () {
    test('admits an ordinary block', () {
      expect(CodeHighlightBudget().admit('final a = 1;\nfinal b = 2;'), isTrue);
    });

    test('refuses a line over the line limit, at the limit it admits', () {
      expect(CodeHighlightBudget().admit('a' * kHighlightMaxLine), isTrue);
      expect(
        CodeHighlightBudget().admit('a' * (kHighlightMaxLine + 1)),
        isFalse,
      );
      expect(
        CodeHighlightBudget().admit('${'a' * kHighlightMaxLine}\r\nb'),
        isTrue,
      );
    });

    test('refuses a block over the block limit', () {
      final lines = List.filled(kHighlightMaxBlock ~/ 10 + 1, 'a' * 9);
      expect(CodeHighlightBudget().admit(lines.join('\n')), isFalse);
      final fits = List.filled(kHighlightMaxBlock ~/ 10 - 1, 'a' * 9);
      expect(CodeHighlightBudget().admit(fits.join('\n')), isTrue);
    });

    test('shares one budget over the blocks of a document', () {
      final budget = CodeHighlightBudget();
      var granted = 0;
      for (var i = 0; i < 100; i++) {
        if (budget.admit('block $i ${'x' * 400}')) granted++;
      }
      expect(granted, kHighlightMaxDocument ~/ 410);
      expect(budget.used, lessThanOrEqualTo(kHighlightMaxDocument));
    });

    test('charges every copy of an identical block', () {
      final budget = CodeHighlightBudget();
      final same = _block(7600);
      var granted = 0;
      for (var i = 0; i < 50; i++) {
        if (budget.admit(same)) granted++;
      }
      expect(granted, 1);
      expect(budget.used, same.length);
    });

    test('charges blocks whose bodies are prefixes of each other', () {
      final budget = CodeHighlightBudget();
      final long = _block(6000);
      final short = long.substring(0, 3000);
      expect(budget.admit(long), isTrue);
      expect(budget.admit(short), isTrue);
      expect(budget.admit(long), isFalse);
      expect(budget.used, long.length + short.length);
    });

    test('the same pass again gives the same answers', () {
      final budget = CodeHighlightBudget();
      final first = _block(6000);
      final second = _block(6000, 'b');
      for (var pass = 0; pass < 3; pass++) {
        budget.begin();
        expect(budget.admit(first), isTrue);
        expect(budget.admit(second), isFalse);
      }
      expect(budget.used, first.length);
    });

    test('a streamed block replaces its shorter self in the budget', () {
      final budget = CodeHighlightBudget();
      var code = '';
      for (var i = 0; i < 300; i++) {
        code += 'line $i\n';
        budget.begin();
        budget.admit(code);
      }
      expect(budget.used, code.length);
      expect(budget.admit('another block'), isTrue);
    });

    test('a streamed block that outgrows a limit stays plain', () {
      final budget = CodeHighlightBudget();
      expect(budget.admit('a' * 400), isTrue);
      budget.begin();
      expect(budget.admit('a' * 600), isFalse);
      expect(budget.used, 0);
    });

    test('clear forgets the decisions', () {
      final budget = CodeHighlightBudget()..admit(_block(6000));
      budget.clear();
      expect(budget.used, 0);
      expect(budget.admit(_block(6000, 'b')), isTrue);
    });
  });

  group('BoundedMarkdown colours code by the shared palette', () {
    for (final (name, theme, palette) in [
      ('light', buildHermesLightTheme(), HermesCodeColors.light),
      ('dark', buildHermesDarkTheme(), HermesCodeColors.dark),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: BoundedMarkdown(
                '```json\n{"a": [1, "s", true]}\n```\n\n```python\ndef f(): pass\n```',
              ),
            ),
          ),
        );
        final styles = <String, TextStyle?>{};
        for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
          rich.text.visitChildren((span) {
            if (span is TextSpan && span.text != null) {
              styles[span.text!] = span.style;
            }
            return true;
          });
        }
        expect(styles['"a"']?.color, palette.key);
        expect(styles['"s"']?.color, palette.string);
        expect(styles['1']?.color, palette.number);
        expect(styles['true']?.color, palette.number);
        expect(styles['true']?.fontWeight, FontWeight.w600);
        expect(styles['def']?.color, palette.keyword);
      });
    }
  });

  group('BoundedMarkdown renders like GptMarkdown', () {
    for (final scale in [1.0, 1.6]) {
      testWidgets('a mixed message at text scale $scale', (tester) async {
        await _pump(tester, (t) => GptMarkdown(t), _mixed, scale: scale);
        final plain = _digest(tester);
        await _pump(tester, (t) => BoundedMarkdown(t), _mixed, scale: scale);
        expect(plain, contains('field python'));
        expect(plain, contains('field js'));
        expect(_digest(tester), plain);
      });
    }

    testWidgets('a fence whose info has a backtick is not a fence', (
      tester,
    ) async {
      const text = '```a`b\n\nprose\n\n```js\nconst a = 1;\n```\n';
      await _pump(tester, (t) => GptMarkdown(t), text);
      final plain = _digest(tester);
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      expect(_digest(tester), plain);
    });
  });

  group('BoundedMarkdown keeps a block over its limits plain', () {
    bool highlighted(WidgetTester tester) => tester
        .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
        .any((f) => f.highlightCode);

    testWidgets('a block within its limits is coloured', (tester) async {
      await _pump(tester, (t) => BoundedMarkdown(t), _mixed);
      expect(highlighted(tester), isTrue);
    });

    final long = 'a${' ' * 3000}b';
    final forms = {
      'plain fence': '```js\n$long\n```',
      'blockquote': '> ```js\n> $long\n> ```',
      'list item': '- ```js\n  $long\n  ```',
      'list, 4 spaces': '1. a\n\n    ```js\n    $long\n    ```',
      'tab': '1. a\n\n\t```js\n\t$long\n\t```',
      'CRLF': '```js\r\n$long\r\n```\r\n',
      'pre code': '<pre><code class="language-js">$long</code></pre>',
      'backtick info after a real fence': '```a`b\n\n```js\n$long\n```',
      'still streaming': '```js\n$long',
    };
    for (final form in forms.entries) {
      testWidgets(form.key, (tester) async {
        await _pump(tester, (t) => BoundedMarkdown(t), form.value);
        expect(
          find.byType(HermesCodeBlock),
          findsWidgets,
          reason: 'a code block',
        );
        expect(highlighted(tester), isFalse);
        for (final f in tester.widgetList<HermesCodeBlock>(
          find.byType(HermesCodeBlock),
        )) {
          debugPrint(
            '${form.key}: ${f.name} ${f.codes.length} ${f.highlightCode}',
          );
        }
      });
    }

    testWidgets('only the blocks past the document budget', (tester) async {
      final text = List.generate(
        40,
        (i) => '```js\nconst v$i = ${'1 + ' * 80}1;\n```',
      ).join('\n\n');
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      final fields = tester
          .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
          .toList();
      expect(fields.length, 40);
      final on = fields.where((f) => f.highlightCode).length;
      expect(on, greaterThan(0));
      expect(on, lessThan(40));
      expect(fields.first.highlightCode, isTrue);
      expect(fields.last.highlightCode, isFalse);
    });

    int coloured(WidgetTester tester) => tester
        .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
        .where((f) => f.highlightCode)
        .length;

    testWidgets('50 identical blocks are charged one by one', (tester) async {
      final body = List.filled(19, '1+' * 200).join('\n');
      final text = List.filled(50, '```js\n$body\n```').join('\n\n');
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      expect(tester.widgetList(find.byType(HermesCodeBlock)), hasLength(50));
      expect(coloured(tester), 1);
    });

    testWidgets('blocks with prefix-related bodies are charged each', (
      tester,
    ) async {
      final long = List.generate(60, (i) => 'x$i = $i;' * 12).join('\n');
      final short = long.split('\n').take(30).join('\n');
      final text = [
        for (final body in [long, short, long, short, long])
          '```js\n$body\n```',
      ].join('\n\n');
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      final fields = tester
          .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
          .toList();
      expect(fields.map((f) => f.codes.length).toSet().length, 2);
      final charged = fields
          .where((f) => f.highlightCode)
          .fold<int>(0, (sum, f) => sum + f.codes.length);
      expect(charged, lessThanOrEqualTo(kHighlightMaxDocument));
      expect(fields.where((f) => !f.highlightCode), isNotEmpty);
    });

    testWidgets('a relayout keeps the decisions', (tester) async {
      final text = List.generate(
        30,
        (i) => '```js\nconst v$i = ${'1 + ' * 80}1;\n```',
      ).join('\n\n');
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      final before = coloured(tester);
      expect(before, inInclusiveRange(1, 29));
      tester.view.physicalSize = const Size(700, 1400);
      await tester.pump();
      expect(coloured(tester), before);
    });

    testWidgets('a reply that streams in does not use the budget up', (
      tester,
    ) async {
      var text = '';
      late StateSetter set;
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return BoundedMarkdown(text);
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 400; i++) {
        set(
          () =>
              text = '```js\n${List.generate(i + 1, (j) => 'x$j').join('\n')}',
        );
        await tester.pump();
      }
      final field = tester.widget<HermesCodeBlock>(
        find.byType(HermesCodeBlock),
      );
      expect(field.codes.length, lessThan(kHighlightMaxBlock));
      expect(field.highlightCode, isTrue);
    });
  });
}

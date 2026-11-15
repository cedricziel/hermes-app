import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

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

/// What a document shows: every code block's name, code and the colour of
/// every run in it, every other run's text and style, and the size of each
/// block.
String _digest(WidgetTester tester) {
  final out = StringBuffer();
  for (final field in tester.widgetList<CodeField>(find.byType(CodeField))) {
    out.writeln('field ${field.name}|${field.codes}');
  }
  for (final rect in tester.elementList(find.byType(CodeField))) {
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

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(rich.text);
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

    test('answers the same for a block asked about again', () {
      final budget = CodeHighlightBudget();
      final first = _block(6000);
      final second = _block(6000, 'b');
      expect(budget.admit(first), isTrue);
      expect(budget.admit(second), isFalse);
      expect(budget.admit(first), isTrue);
      expect(budget.admit(second), isFalse);
      expect(budget.used, first.length);
    });

    test('a streamed block replaces its shorter self in the budget', () {
      final budget = CodeHighlightBudget();
      var code = '';
      for (var i = 0; i < 300; i++) {
        code += 'line $i\n';
        budget.admit(code);
      }
      expect(budget.used, code.length);
      expect(budget.admit('another block'), isTrue);
    });

    test('a streamed block that outgrows a limit stays plain', () {
      final budget = CodeHighlightBudget();
      expect(budget.admit('a' * 400), isTrue);
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
        .widgetList<CodeField>(find.byType(CodeField))
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
        expect(find.byType(CodeField), findsWidgets, reason: 'a code block');
        expect(highlighted(tester), isFalse);
        for (final f in tester.widgetList<CodeField>(find.byType(CodeField))) {
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
          .widgetList<CodeField>(find.byType(CodeField))
          .toList();
      expect(fields.length, 40);
      final on = fields.where((f) => f.highlightCode).length;
      expect(on, greaterThan(0));
      expect(on, lessThan(40));
      expect(fields.first.highlightCode, isTrue);
      expect(fields.last.highlightCode, isFalse);
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
      final field = tester.widget<CodeField>(find.byType(CodeField));
      expect(field.codes.length, lessThan(kHighlightMaxBlock));
      expect(field.highlightCode, isTrue);
    });
  });
}

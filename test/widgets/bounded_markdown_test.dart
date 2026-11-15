import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart' as mui;

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

    int coloured(WidgetTester tester) => tester
        .widgetList<CodeField>(find.byType(CodeField))
        .where((f) => f.highlightCode)
        .length;

    testWidgets('50 identical blocks are charged one by one', (tester) async {
      final body = List.filled(19, '1+' * 200).join('\n');
      final text = List.filled(50, '```js\n$body\n```').join('\n\n');
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      expect(tester.widgetList(find.byType(CodeField)), hasLength(50));
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
          .widgetList<CodeField>(find.byType(CodeField))
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
      final field = tester.widget<CodeField>(find.byType(CodeField));
      expect(field.codes.length, lessThan(kHighlightMaxBlock));
      expect(field.highlightCode, isTrue);
    });
  });

  group('BoundedMarkdown caps the code fields of a document', () {
    String fences(int n, {String lang = 'js', String body = 'a\nb\nc'}) =>
        List.generate(n, (i) => '```$lang\n$body\n```').join('\n\n');

    int fields(WidgetTester t) => t.widgetList(find.byType(CodeField)).length;
    int plains(WidgetTester t) =>
        t.widgetList(find.byType(PlainCodeBlock)).length;

    testWidgets('a document at the cap keeps every block a code field', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount),
      );
      expect(fields(tester), kCodeFieldMaxCount);
      expect(plains(tester), 0);
      expect(
        tester
            .widgetList<CodeField>(find.byType(CodeField))
            .every((f) => f.highlightCode),
        isTrue,
      );
    });

    testWidgets('the blocks at the cap render like GptMarkdown', (
      tester,
    ) async {
      final text = fences(kCodeFieldMaxCount);
      await _pump(tester, (t) => GptMarkdown(t), text);
      final plain = _digest(tester);
      await _pump(tester, (t) => BoundedMarkdown(t), text);
      expect(_digest(tester), plain);
    });

    testWidgets('blocks past the cap are plain blocks, the rest are fields', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount + 7, body: 'const a = 1;'),
      );
      expect(fields(tester), kCodeFieldMaxCount);
      expect(plains(tester), 7);
      // Order: every field comes before every plain block.
      final lastField = tester.getTopLeft(find.byType(CodeField).last).dy;
      final firstPlain = tester
          .getTopLeft(find.byType(PlainCodeBlock).first)
          .dy;
      expect(firstPlain, greaterThan(lastField));
    });

    testWidgets('a plain block has the size and look of a code field', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount + 1, lang: 'dart', body: 'a\nb\nc'),
      );
      final field = find.byType(CodeField).first;
      final plain = find.byType(PlainCodeBlock);
      expect(tester.getSize(plain), tester.getSize(field));
      BoxDecoration panel(Finder f) =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(of: f, matching: find.byType(DecoratedBox))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(panel(plain), panel(field));
      expect(
        find.descendant(
          of: plain,
          matching: find.textContaining('dart', findRichText: true),
        ),
        findsOneWidget,
      );
      final code = tester.widget<Text>(
        find.descendant(of: plain, matching: find.text('a\nb\nc')),
      );
      expect(code.style?.fontFamily, endsWith('JetBrainsMono'));
    });

    testWidgets('a block with no language is labelled Code, like a field', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount + 1, lang: ''),
      );
      expect(
        find.descendant(
          of: find.byType(PlainCodeBlock),
          matching: find.textContaining('Code', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(PlainCodeBlock)),
        tester.getSize(find.byType(CodeField).first),
      );
    });

    testWidgets('a plain block is never coloured and has no copy button', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount + 3, body: 'const a = 1; // x'),
      );
      final plain = find.byType(PlainCodeBlock);
      expect(plain, findsNWidgets(3));
      expect(
        find.descendant(
          of: plain,
          matching: find.byIcon(Icons.content_copy_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: plain, matching: find.byType(Tooltip)),
        findsNothing,
      );
      for (final text in tester.widgetList<Text>(
        find.descendant(of: plain, matching: find.text('const a = 1; // x')),
      )) {
        expect(text.textSpan, isNull, reason: 'one run, no colour spans');
      }
      expect(
        find.byIcon(Icons.content_copy_rounded),
        findsNWidgets(kCodeFieldMaxCount),
      );
    });

    testWidgets('bidi and control characters in a plain block are shown', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        fences(kCodeFieldMaxCount + 1, body: 'a\u202Eb\u001Bc'),
      );
      expect(
        find.descendant(
          of: find.byType(PlainCodeBlock),
          matching: find.text('a<U+202E>b<U+001B>c'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty fences past the cap are plain blocks too', (
      tester,
    ) async {
      await _pump(
        tester,
        (t) => BoundedMarkdown(t),
        List.filled(kCodeFieldMaxCount + 5, '```\n```').join('\n\n'),
      );
      expect(fields(tester), kCodeFieldMaxCount);
      expect(plains(tester), 5);
    });

    testWidgets('a reply streamed fence by fence keeps the cap', (
      tester,
    ) async {
      late StateSetter set;
      var text = '';
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
      for (var i = 0; i < kCodeFieldMaxCount + 6; i++) {
        // The fence is open for one frame, then closed.
        set(() => text += '${i == 0 ? '' : '\n\n'}```js\nconst a = $i;');
        await tester.pump();
        set(() => text += '\n```');
        await tester.pump();
      }
      expect(fields(tester), kCodeFieldMaxCount);
      expect(plains(tester), 6);
    });

    testWidgets('a reply that grows past the cap, and back, is counted anew', (
      tester,
    ) async {
      late StateSetter set;
      var text = fences(kCodeFieldMaxCount - 1);
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
      expect((fields(tester), plains(tester)), (kCodeFieldMaxCount - 1, 0));
      set(() => text = fences(kCodeFieldMaxCount + 2));
      await tester.pump();
      expect((fields(tester), plains(tester)), (kCodeFieldMaxCount, 2));
      set(() => text = fences(3));
      await tester.pump();
      expect((fields(tester), plains(tester)), (3, 0));
    });
  });

  group('BoundedMarkdown places blocks the same however it is asked', () {
    late StateSetter set;
    Widget Function(Widget) wrap = (w) => w;

    Future<void> host(WidgetTester tester, String Function() text) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => wrap = (w) => w);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return wrap(BoundedMarkdown(text()));
                },
              ),
            ),
          ),
        ),
      );
    }

    int fields(WidgetTester t) => t.widgetList(find.byType(CodeField)).length;
    int plains(WidgetTester t) =>
        t.widgetList(find.byType(PlainCodeBlock)).length;
    int coloured(WidgetTester t) => t
        .widgetList<CodeField>(find.byType(CodeField))
        .where((f) => f.highlightCode)
        .length;
    String fences(int n, [String tag = 'a']) =>
        List.generate(n, (i) => '```js\nconst $tag = $i;\n```').join('\n\n');

    Future<void> stream(WidgetTester tester, String Function(int) more) async {
      for (var i = 0; i < 60; i++) {
        set(() => _text += more(i));
        await tester.pump();
      }
    }

    testWidgets('prose streaming after a fence in a list item', (tester) async {
      _text = '1. Run this:\n   ```sh\n   ls\n   ```\n   Then';
      await host(tester, () => _text);
      await stream(tester, (i) => ' word$i');
      expect((fields(tester), plains(tester)), (1, 0));
    });

    testWidgets('prose streaming after a fence with no blank line', (
      tester,
    ) async {
      _text = '```js\nconst a = 1;\n```\nThen';
      await host(tester, () => _text);
      await stream(tester, (i) => ' word$i');
      expect((fields(tester), plains(tester)), (1, 0));
    });

    testWidgets('a second adjacent fence streaming', (tester) async {
      _text = '```js\nconst a = 1;\n```\n```js\n';
      await host(tester, () => _text);
      await stream(tester, (i) => 'x$i\n');
      expect((fields(tester), plains(tester)), (2, 0));
    });

    testWidgets('a change the wrapper does not see, within the cap', (
      tester,
    ) async {
      _text = fences(40);
      var dir = TextDirection.ltr;
      wrap = (w) => Directionality(textDirection: dir, child: w);
      await host(tester, () => _text);
      for (var k = 0; k < 2; k++) {
        set(
          () => dir = dir == TextDirection.ltr
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        await tester.pump();
      }
      expect((fields(tester), plains(tester)), (40, 0));
    });

    testWidgets('over the cap, the same change keeps the first 50 fields', (
      tester,
    ) async {
      // One widget instance: a change above it rebuilds the renderer, not the
      // wrapper, so the blocks are asked about again with no build in between.
      final markdown = BoundedMarkdown(fences(80));
      var dark = false;
      wrap = (w) => mui.Theme(
        data: dark ? mui.ThemeData.dark() : mui.ThemeData.light(),
        child: markdown,
      );
      await host(tester, () => _text);
      for (var k = 0; k < 3; k++) {
        set(() => dark = !dark);
        await tester.pump();
        expect((fields(tester), plains(tester)), (50, 30));
      }
    });

    testWidgets('a block keeps its colour while prose streams after it', (
      tester,
    ) async {
      final big = '```js\n${List.filled(40, '// ${'a' * 90}').join('\n')}\n```';
      _text = '$big\nThen';
      await host(tester, () => _text);
      expect(coloured(tester), 1);
      for (var i = 0; i < 4; i++) {
        set(() => _text += ' w');
        await tester.pump();
      }
      expect(coloured(tester), 1);
    });

    testWidgets('a tail edit of a 100-fence reply keeps the cap', (
      tester,
    ) async {
      _text = '${fences(100)}\n\nend \$x';
      await host(tester, () => _text);
      expect(fields(tester), kCodeFieldMaxCount);
      set(() => _text = '${fences(100)}\n\nend');
      await tester.pump();
      expect(fields(tester), kCodeFieldMaxCount);
      set(() => _text = '${fences(100)}\n\n```js\nnew\n```');
      await tester.pump();
      expect((fields(tester), plains(tester)), (50, 51));
    });

    testWidgets('replacements that keep earlier segments keep the cap', (
      tester,
    ) async {
      _text = fences(50);
      await host(tester, () => _text);
      for (var k = 0; k < 3; k++) {
        set(() => _text = '${fences(50 * (k + 1))}\n\n${fences(50, 'r$k')}x');
        await tester.pump();
        set(() => _text = '${fences(50 * (k + 1))}\n\n${fences(50, 'r$k')}');
        await tester.pump();
        expect(fields(tester), kCodeFieldMaxCount);
      }
    });

    testWidgets('the label of a plain block is read without its icon glyph', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _text = fences(kCodeFieldMaxCount + 1).replaceAll('js', 'dart');
      await host(tester, () => _text);
      final label = tester
          .getSemantics(
            find.descendant(
              of: find.byType(PlainCodeBlock),
              matching: find.textContaining('dart', findRichText: true),
            ),
          )
          .label;
      expect(label.trim(), 'dart');
      expect(label.codeUnits.every((u) => u < 0xE000 || u > 0xF8FF), isTrue);
      semantics.dispose();
    });

    test('the fence bound does not undercount the forms a block can take', () {
      expect(codeFenceBound('no code'), 0);
      expect(codeFenceBound('```js\nx\n```'), 1);
      expect(codeFenceBound('```js\nx'), 1);
      expect(codeFenceBound('```a\n```\n```b\nx'), 2);
      expect(codeFenceBound('~~~\nx\n~~~'), 1);
      expect(codeFenceBound('<pre><code>x</code></pre>'), 1);
      expect(codeFenceBound('<pre><code>x</code></pre><pre>y</pre>'), 2);
      expect(codeFenceBound('> ```js\n> x\n> ```\n- ```\n  ```'), 2);
    });
  });
}

String _text = '';

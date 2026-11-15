import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/code_highlight.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/files/widgets/safe_path_text.dart';
import 'package:hermes_app/src/theme/hermes_code_colors.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'files_widget_harness.dart';

const _python = 'def hello():\n    return "hi"  # 42\n';

/// The leaf spans of the first rich text under [CodePreview], as
/// (text, colour, italic).
List<(String, Color?, bool)> _spans(WidgetTester tester) {
  final selectable = tester.widget<SelectableText>(
    find.descendant(
      of: find.byType(CodePreview),
      matching: find.byType(SelectableText),
    ),
  );
  final out = <(String, Color?, bool)>[];
  selectable.textSpan!.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      out.add((
        span.text!,
        span.style?.color,
        span.style?.fontStyle == FontStyle.italic,
      ));
    }
    return true;
  });
  return out;
}

void main() {
  group('CodePreview', () {
    for (final brightness in Brightness.values) {
      testWidgets('colours by the server language, ${brightness.name}', (
        tester,
      ) async {
        await pumpFiles(
          tester,
          const CodePreview(text: _python, language: 'python'),
          brightness: brightness,
        );
        final palette = brightness == Brightness.dark
            ? HermesCodeColors.dark
            : HermesCodeColors.light;
        final spans = _spans(tester);
        expect(spans.map((s) => s.$1).join(), _python);
        Color? colourOf(String text) =>
            spans.firstWhere((s) => s.$1.contains(text)).$2;
        expect(colourOf('def'), palette.keyword);
        expect(colourOf('"hi"'), palette.string);
        expect(colourOf('hello'), palette.function);
        final comment = spans.firstWhere((s) => s.$1.contains('# 42'));
        expect(comment.$2, palette.comment);
        expect(comment.$3, isTrue, reason: 'comments are italic too');
      });
    }

    testWidgets('JSON keys are blue, literals purple and semibold', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const CodePreview(text: '{"a": true, "b": "x"}', language: 'json'),
      );
      final palette = HermesCodeColors.light;
      final spans = _spans(tester);
      Color? colourOf(String text) =>
          spans.firstWhere((s) => s.$1.contains(text)).$2;
      expect(colourOf('"a"'), palette.key);
      expect(colourOf('"x"'), palette.string);
      expect(colourOf('true'), palette.number);
      expect(colourOf('{'), palette.comment, reason: 'punctuation is muted');
    });

    testWidgets('an unknown language is plain monospace', (tester) async {
      await pumpFiles(
        tester,
        const CodePreview(text: _python, language: 'text'),
      );
      final spans = _spans(tester);
      expect(spans, hasLength(1));
      expect(spans.single.$1, _python);
    });

    testWidgets('no language is plain monospace', (tester) async {
      await pumpFiles(tester, const CodePreview(text: _python));
      expect(_spans(tester), hasLength(1));
    });

    testWidgets('above the cap nothing is coloured and no worker starts', (
      tester,
    ) async {
      final big = 'x = 1\n' * (kCodeHighlightMaxChars ~/ 6 + 1);
      await pumpFiles(tester, CodePreview(text: big, language: 'python'));
      expect(_spans(tester), hasLength(1));
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('text and plaintext start no worker and no highlighter', (
      tester,
    ) async {
      final long = 'x = 1\n' * 600;
      await pumpFiles(tester, CodePreview(text: long, language: 'plaintext'));
      expect(_spans(tester), hasLength(1));
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('a larger file shows plain at once, coloured from a worker', (
      tester,
    ) async {
      final long = 'x = 1\n' * 600;
      expect(isInlineSafe(long), isFalse);
      await pumpFiles(tester, CodePreview(text: long, language: 'python'));
      expect(_spans(tester), hasLength(1), reason: 'plain until ready');
      await tester.runAsync(
        () => _settle(() => CodeHighlightWorker.alive == 0),
      );
      await tester.pump();
      final spans = _spans(tester);
      expect(spans.length, greaterThan(1));
      expect(spans.map((s) => s.$1).join(), long);
    });

    testWidgets('a crafted slow file never runs on the UI isolate', (
      tester,
    ) async {
      final crafted = 'a${' ' * 20000}';
      final clock = Stopwatch()..start();
      await pumpFiles(
        tester,
        CodePreview(text: crafted, language: 'typescript'),
      );
      expect(clock.elapsedMilliseconds, lessThan(1500));
      expect(_spans(tester), hasLength(1));
      expect(CodeHighlightWorker.alive, 1, reason: 'one worker, off-thread');
      // Closing the preview kills the worker; nothing arrives late.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => _settle(() => CodeHighlightWorker.alive == 0),
      );
      expect(CodeHighlightWorker.alive, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new text kills the old worker', (tester) async {
      final crafted = 'a${' ' * 20000}';
      await pumpFiles(
        tester,
        CodePreview(text: crafted, language: 'typescript'),
      );
      expect(CodeHighlightWorker.alive, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: const Scaffold(
            body: CodePreview(text: 'x = 1', language: 'python'),
          ),
        ),
      );
      await tester.runAsync(
        () => _settle(() => CodeHighlightWorker.alive == 0),
      );
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('a new file replaces the colours of the old one', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const CodePreview(text: _python, language: 'python'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: const Scaffold(body: CodePreview(text: 'plain words')),
        ),
      );
      expect(_spans(tester).single.$1, 'plain words');
    });

    testWidgets('control and bidi characters are shown, not obeyed', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const CodePreview(text: 'a\u202Eb\u001B[2Jc\r\nd\te', language: 'text'),
      );
      expect(_spans(tester).single.$1, 'a<U+202E>b<U+001B>[2Jc\nd\te');
    });

    testWidgets('truncated code keeps its note', (tester) async {
      await pumpFiles(
        tester,
        const CodePreview(
          text: _python,
          language: 'python',
          truncation: FileTruncation(shownBytes: 524288, totalBytes: 3355443),
        ),
      );
      expect(find.text('Download full file'), findsOneWidget);
    });
  });

  group('Markdown polish', () {
    testWidgets('a fenced block is coloured by the name after the fence', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(text: '# T\n\n```python\ndef f(): pass\n```\n'),
      );
      final palette = HermesCodeColors.light;
      final colours = <Color?>[];
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && (span.text ?? '').contains('def')) {
            colours.add(span.style?.color);
          }
          return true;
        });
      }
      expect(colours, contains(palette.keyword));
    });

    testWidgets('many fences share one budget and start no worker', (
      tester,
    ) async {
      final fences = List.generate(
        26,
        (i) => '```python\ndef f$i(): pass\n```',
      ).join('\n\n');
      await pumpFiles(tester, MarkdownPreview(text: fences));
      var coloured = 0;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'def') coloured++;
          return true;
        });
      }
      expect(coloured, greaterThan(0));
      expect(coloured, lessThanOrEqualTo(8));
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('a fence with a crafted slow body stays plain', (tester) async {
      final text = '```javascript\na${' ' * 20000}\n```';
      final clock = Stopwatch()..start();
      await pumpFiles(tester, MarkdownPreview(text: text));
      expect(clock.elapsedMilliseconds, lessThan(1500));
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('bidi controls in rendered Markdown are shown', (tester) async {
      await pumpFiles(tester, const MarkdownPreview(text: 'safe \u202E text'));
      expect(find.textContaining('<U+202E>', findRichText: true), findsWidgets);
    });

    testWidgets('bidi controls in Markdown source are shown', (tester) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(text: 'safe \u202E text', showSource: true),
      );
      expect(find.textContaining('<U+202E>'), findsOneWidget);
    });

    testWidgets('bidi controls in plain text are shown', (tester) async {
      await pumpFiles(tester, const TextPreview(text: 'a\u2066b'));
      expect(find.textContaining('<U+2066>'), findsOneWidget);
    });
  });

  group('character references in Markdown', () {
    const unsafe = '\u202E\u202C\u200E\u200F\u200B\uFEFF';

    String rendered(WidgetTester tester) {
      final out = StringBuffer();
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        out.write(rich.text.toPlainText());
      }
      return out.toString();
    }

    testWidgets('that decode to bidi or invisible characters are shown', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(
          text:
              'safe &#x202E;abc&#x202C; &#8238; &lrm;&rlm; '
              '&#x200B; &#xFEFF; &ZeroWidthSpace;',
        ),
      );
      final text = rendered(tester);
      for (final char in unsafe.split('')) {
        expect(
          text.contains(char),
          isFalse,
          reason: 'U+${char.codeUnitAt(0).toRadixString(16)}',
        );
      }
      for (final name in ['202E', '202C', '200E', '200F', '200B', 'FEFF']) {
        expect(text, contains('<U+$name>'));
      }
    });

    testWidgets('that decode to ordinary characters still render', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(text: 'a &amp; b &lt; c &copy; d &#65;'),
      );
      expect(rendered(tester), contains('a & b < c \u00A9 d A'));
    });

    for (final (name, source) in [
      ('a relative link', '&#x202E[;](rel) x'),
      ('an anchor link', '&#x202E[;](#a) x'),
      ('an image', '&lrm![;](https://e.com/i.png) x'),
      ('a reference image', '&rlm![;][r] y\n\n[r]: https://e.com/i.png'),
      ('a reference without a semicolon', '&lrm x'),
      ('a hex reference without a semicolon', '&#x202E x'),
      ('a padded hex reference', '&#x000202E; x'),
    ]) {
      testWidgets('a reference joined by $name shows no raw character', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpFiles(tester, MarkdownPreview(text: source));
        final text = rendered(tester);
        for (final char in unsafe.split('')) {
          expect(text.contains(char), isFalse, reason: source);
        }
        final labels = StringBuffer();
        void walk(SemanticsNode node) {
          labels.write(node.label);
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(tester.getSemantics(find.byType(MarkdownPreview)));
        for (final char in unsafe.split('')) {
          expect(labels.toString().contains(char), isFalse, reason: source);
        }
        handle.dispose();
      });
    }

    test('safeMarkdownText leaves ordinary references and text alone', () {
      const text = 'a &amp; b &#65; &copy; & lone &x; &#xZZ;';
      expect(identical(safeMarkdownText(text), text), isTrue);
    });

    test('safeMarkdownText names the unsafe ones', () {
      expect(safeMarkdownText('x&#x202E;y&lrm;z'), 'x<U+202E>y<U+200E>z');
    });
  });

  group('safeContentText', () {
    test('keeps line feeds and tabs, folds CRLF', () {
      expect(safeContentText('a\nb\tc\r\nd'), 'a\nb\tc\nd');
    });

    test('draws a lone carriage return and the other controls', () {
      expect(safeContentText('a\rb'), 'a<U+000D>b');
      expect(safeContentText('\u0000\u007F\u0085'), '<U+0000><U+007F><U+0085>');
    });

    test('draws every bidi control', () {
      expect(
        safeContentText(
          '\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069',
        ),
        '<U+202A><U+202B><U+202C><U+202D><U+202E>'
        '<U+2066><U+2067><U+2068><U+2069>',
      );
      expect(safeContentText('\u200E\u200F\u061C'), '<U+200E><U+200F><U+061C>');
    });

    test('leaves ordinary text, emoji and joiners alone', () {
      const text = 'héllo 日本 👩‍💻 ی‌ا\n';
      expect(identical(safeContentText(text), text), isTrue);
    });

    test('safePathText still escapes line breaks in a name', () {
      expect(safePathText('a\nb'), 'a<U+000A>b');
    });
  });

  group('code palette', () {
    test('both themes register the palette themselves', () {
      expect(
        buildHermesLightTheme().extension<HermesCodeColors>(),
        HermesCodeColors.light,
      );
      expect(
        buildHermesDarkTheme().extension<HermesCodeColors>(),
        HermesCodeColors.dark,
      );
    });

    testWidgets('the theme carries the palette of its brightness', (
      tester,
    ) async {
      late BuildContext context;
      await pumpFiles(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(context.codeColors.keyword, HermesCodeColors.dark.keyword);
    });
  });
}

Future<void> _settle(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

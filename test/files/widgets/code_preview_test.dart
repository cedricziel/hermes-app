import 'dart:math' as math;

import 'package:flutter/material.dart';
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

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
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
    test(
      'every colour is at least 5.2:1 on the page and the raised surface',
      () {
        for (final (palette, theme) in [
          (HermesCodeColors.light, buildHermesLightTheme()),
          (HermesCodeColors.dark, buildHermesDarkTheme()),
        ]) {
          final scheme = theme.colorScheme;
          for (final background in [
            scheme.surface,
            scheme.surfaceContainerHighest,
          ]) {
            for (final colour in [
              palette.keyword,
              palette.string,
              palette.comment,
              palette.number,
              palette.function,
              palette.typeName,
            ]) {
              expect(
                _contrast(colour, background),
                greaterThanOrEqualTo(5.2),
                reason: '$colour on $background',
              );
            }
          }
        }
      },
    );

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

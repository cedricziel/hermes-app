import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

/// Canary for the private behaviour of `gpt_markdown` that
/// [CodeHighlightBudget] relies on (see `bounded_markdown.dart`). It fails
/// loudly when a package upgrade changes one of:
///
/// 1. source normalisation: the renderer trims the text and turns CRLF and CR
///    into LF before it splits and parses it;
/// 2. the parse: the fences `BoundedMarkdown` reads from its own parse of each
///    segment (lists, quotes, alerts, footnotes included) are the code blocks
///    the renderer asks its `codeBuilder` about, in the same order;
/// 3. the per-segment cache: a delta asks only about the blocks of the tail
///    segment, and an edit asks only about the segments that changed (by index
///    and text);
/// 4. the tail held back while streaming: an unfinished inline construct at the
///    end does not change which fences are asked about, and the renderer builds
///    that tail again on its own once the stream goes quiet;
/// 5. the definitions: when a link or footnote definition arrives or changes,
///    only the segments that looked it up are built again;
/// 6. the inherited values the renderer drops everything it kept for: a change
///    of the text scale or of screen reader navigation while a reply arrives
///    (and of the theme); any other change of `MediaQuery` leaves it alone. The
///    list is mirrored in `_BoundedMarkdownState.build`;
/// 7. the parse of forms that are easy to get wrong: `<pre><code>`, tildes and
///    longer fences, nested lists and quotes.
///
/// When it fails, read the new behaviour in the package and change
/// `_DocumentFences` and `_placeOf`, not this test.

const _f = '```';

Widget _app(Widget markdown) => MaterialApp(
  theme: buildHermesLightTheme(),
  builder: (context, child) => AppThemeScopes(child: child!),
  home: Scaffold(
    body: SingleChildScrollView(child: AppMarkdownTheme(child: markdown)),
  ),
);

/// A raw [GptMarkdown] that records the code it is asked to build.
Widget _raw(String text, List<String> asked) => _app(
  GptMarkdown(
    text,
    codeBuilder: (context, name, code, closed) {
      asked.add(code);
      return const SizedBox(height: 4);
    },
  ),
);

/// Fenced code in every place a block can be nested in.
String _mixed({String eol = '\n'}) => [
  'Intro paragraph.',
  '',
  '${_f}js',
  'plain();',
  _f,
  '',
  '- item one',
  '',
  '  ${_f}js',
  '  inList();',
  '  $_f',
  '',
  '1. numbered',
  '',
  '   ${_f}py',
  '   inNumbered()',
  '   $_f',
  '',
  '> quoted',
  '>',
  '> ${_f}js',
  '> inQuote();',
  '> $_f',
  '',
  '> [!NOTE]',
  '> ${_f}js',
  '> inAlert();',
  '> $_f',
  '',
  'Text with a note[^1] and another[^two].',
  '',
  '[^1]: first note',
  '',
  '    ${_f}js',
  '    inFootnote();',
  '    $_f',
  '',
  '[^two]: second note',
  '',
  '    ${_f}js',
  '    inSecondFootnote();',
  '    $_f',
  '',
  'Last paragraph.',
].join(eol);

/// Forms of a fence besides the backtick fence of a list, quote or footnote.
String get _forms => [
  '<pre><code class="language-js">',
  'inHtml();',
  '</code></pre>',
  '',
  '~~~python title="x"',
  'inTildes()',
  '~~~',
  '',
  '````js {1,3}',
  'before();',
  _f,
  'inner fence',
  _f,
  'after();',
  '````',
  '',
  '- level one',
  '  - level two',
  '',
  '    ${_f}js',
  '    inLevelTwo();',
  '    $_f',
  '',
  '    1. level three',
  '',
  '       ${_f}js',
  '       inLevelThree();',
  '       $_f',
  '',
  '> outer',
  '> > inner',
  '> >',
  '> > ${_f}js',
  '> > inNestedQuote();',
  '> > $_f',
  '',
  '> - quoted item',
  '>',
  '>   ${_f}js',
  '>   inQuotedItem();',
  '>   $_f',
].join('\n');

/// What a raw renderer asks about at each of [steps], shown one after the other.
Future<List<List<String>>> _askedAt(
  WidgetTester tester,
  List<String> steps,
) async {
  final asked = <String>[];
  final out = <List<String>>[];
  for (final step in steps) {
    asked.clear();
    await tester.pumpWidget(_raw(step, asked));
    out.add(List.of(asked));
  }
  return out;
}

void main() {
  group(
    'the fences BoundedMarkdown reads are those the renderer asks about',
    () {
      final variants = {
        'plain': _mixed(),
        'CRLF': _mixed(eol: '\r\n'),
        'padded with blank lines': '\n\n  \n${_mixed()}\n\n\n',
        'CR only': _mixed(eol: '\r'),
        'an open link held back at the end': '${_mixed()}\n\nA [dangling link',
        'an open fence at the end': '${_mixed()}\n\n${_f}js\nopen();',
        'html pre and code': _forms,
      };
      for (final MapEntry(:key, :value) in variants.entries) {
        testWidgets(key, (tester) async {
          final asked = <String>[];
          await tester.pumpWidget(_raw(value, asked));
          expect(
            asked,
            isNotEmpty,
            reason: 'the renderer asks about no code block',
          );
          expect(
            boundedMarkdownFences(value),
            asked,
            reason: 'the document parse and the renderer disagree',
          );
        });
      }
    },
  );

  testWidgets('a delta asks only about the blocks of the tail', (tester) async {
    String fence(int i) => '$_f\nblock$i();\n$_f\n\nParagraph $i.\n\n';
    var text = [for (var i = 0; i < 6; i++) fence(i)].join();
    final asked = <String>[];
    await tester.pumpWidget(_raw(text, asked));
    expect(asked.length, 6);
    asked.clear();

    // Words arrive in the last paragraph: nothing before it is built again.
    for (final word in ['one ', 'two ', 'three ']) {
      text += word;
      await tester.pumpWidget(_raw(text, asked));
    }
    expect(asked, isEmpty, reason: 'a finished block was built again');

    // A new fence streams in: only it is asked about.
    for (final piece in ['\n\n$_f\nfres', 'h();\n', _f]) {
      text += piece;
      await tester.pumpWidget(_raw(text, asked));
    }
    expect(asked, isNotEmpty);
    expect(
      asked.where((c) => c.startsWith('block')),
      isEmpty,
      reason: 'a finished block was built again',
    );
  });

  testWidgets('an edit builds again only the segments that changed', (
    tester,
  ) async {
    String fence(int i) => '$_f\nblock$i();\n$_f\n\nParagraph $i.\n\n';
    final rest = [for (var i = 1; i < 5; i++) fence(i)].join();
    final asked = <String>[];
    await tester.pumpWidget(_raw('${fence(0)}$rest', asked));
    asked.clear();
    await tester.pumpWidget(
      _raw('$_f\nedited();\n$_f\n\nParagraph 0.\n\n$rest', asked),
    );
    expect(asked, ['edited();'], reason: 'segments are kept by index and text');
  });

  group('the blocks built again when a definition changes', () {
    String doc([String tail = '']) => [
      'Intro.',
      '',
      '- see [ref] here',
      '',
      '  ${_f}js',
      '  withLink();',
      '  $_f',
      '',
      'Between.',
      '',
      '${_f}js',
      'plain();',
      _f,
      '',
      'End.$tail',
    ].join('\n');
    final footnotes = [
      'Intro.',
      '',
      '[^n]: note',
      '',
      '    ${_f}js',
      '    inNote();',
      '    $_f',
      '',
      'Middle.',
      '',
      '${_f}js',
      'plain();',
      _f,
      '',
      'End',
    ].join('\n');
    final scenarios = {
      'a link definition arrives, then changes': [
        doc(),
        doc('\n\n[ref]: https://example.com/a'),
        doc('\n\n[ref]: https://example.com/b'),
      ],
      'a footnote is referenced after its definition': [
        footnotes,
        '$footnotes[^n]',
        '$footnotes[^n] and more',
      ],
    };
    for (final MapEntry(:key, :value) in scenarios.entries) {
      testWidgets(key, (tester) async {
        final asked = await _askedAt(tester, value);
        expect(
          boundedMarkdownExpectedQuestions(value),
          asked,
          reason: 'the segments that are built again are not the ones expected',
        );
      });
    }

    testWidgets('only the segments that looked the definition up', (
      tester,
    ) async {
      final asked = await _askedAt(tester, [
        doc(),
        doc('\n\n[ref]: https://example.com/a'),
      ]);
      expect(asked.last, ['withLink();']);
      final note = await _askedAt(tester, [footnotes, '$footnotes[^n]']);
      expect(note.last, ['inNote();']);
    });
  });

  group('what makes the renderer drop everything it kept', () {
    // Each change is made while a reply arrives, the only time the renderer
    // reads the screen reader setting.
    final changes = <String, MediaQueryData Function(MediaQueryData)>{
      'text scale': (d) => d.copyWith(textScaler: const TextScaler.linear(2)),
      'screen reader navigation': (d) => d.copyWith(accessibleNavigation: true),
      'disabled animations': (d) => d.copyWith(disableAnimations: true),
      'bold text': (d) => d.copyWith(boldText: true),
      'window size': (d) => d.copyWith(size: const Size(500, 500)),
      'high contrast': (d) => d.copyWith(highContrast: true),
      'padding': (d) => d.copyWith(padding: const EdgeInsets.all(5)),
    };
    // What `_BoundedMarkdownState.build` depends on from `MediaQuery`.
    const dropped = {'text scale', 'screen reader navigation'};
    for (final MapEntry(:key, :value) in changes.entries) {
      testWidgets(key, (tester) async {
        final asked = <String>[];
        Widget app(String text, MediaQueryData Function(MediaQueryData) f) =>
            MaterialApp(
              theme: buildHermesLightTheme(),
              builder: (context, child) => MediaQuery(
                data: f(MediaQuery.of(context)),
                child: AppThemeScopes(child: child!),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AppMarkdownTheme(
                    child: GptMarkdown(
                      text,
                      codeBuilder: (context, name, code, closed) {
                        asked.add(code);
                        return const SizedBox(height: 4);
                      },
                    ),
                  ),
                ),
              ),
            );
        final text =
            'Intro.\n\n${_f}js\na();\n$_f\n\n${_f}js\nb();\n$_f\n\nEnd';
        await tester.pumpWidget(app(text, (d) => d));
        await tester.pumpWidget(app('$text more', (d) => d));
        asked.clear();
        await tester.pumpWidget(app('$text more', value));
        expect(
          asked,
          dropped.contains(key) ? ['a();', 'b();'] : isEmpty,
          reason:
              'the renderer reads another value of MediaQuery than '
              'BoundedMarkdown depends on',
        );
      });
    }
  });

  testWidgets('the renderer builds its tail again once the stream is quiet', (
    tester,
  ) async {
    // The last fence is open and ends in two backticks: the renderer holds
    // that line back and builds the block again on its own, with no build of
    // ours in between.
    String block(String c) => '${_f}js\n${c * 20}\n$_f\n\n';
    final text = '${block('a')}${block('b')}${_f}js\nlast();\n``';
    final asked = <String>[];
    await tester.pumpWidget(_raw(text, asked));
    await tester.pumpWidget(_raw(text, asked));
    asked.clear();
    await tester.pump(const Duration(seconds: 3));
    expect(asked, [boundedMarkdownFences(text).last]);
  });
}

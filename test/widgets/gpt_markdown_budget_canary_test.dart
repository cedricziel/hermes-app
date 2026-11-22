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
///    end does not change which fences are asked about.
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
}

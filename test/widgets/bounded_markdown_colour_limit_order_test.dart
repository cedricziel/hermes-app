/// The colouring limit of `BoundedMarkdown` does not depend on the order in
/// which the package draws its code blocks. `GptMarkdown` draws arbitrary
/// subsets of its segments again: a segment that changed, the end of a held
/// reply when its 1.5 s timer runs out, a dependency change. A block's
/// decision must come from the text, in document order, so each case here
/// compares the colours after such a redraw with the colours of a document
/// nobody streamed (see `bounded_markdown_colour_limit_test.dart`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/widgets/bounded_markdown.dart';

import '../support/markdown_colour_harness.dart';

/// A closed fence of [first] characters, a paragraph, then an open fence whose
/// code starts with the same text and goes on for [more] characters. The last
/// line is a lone backtick, so the renderer holds the stream's end for 1.5 s.
String _repeatedThenTail(int first, int more) {
  final a = exactCode(first);
  return 'Intro\n\n${fenced(a)}\n\nMiddle.\n\n'
      '${fence}js\n$a\n${exactCode(more)}\n`';
}

void main() {
  testWidgets('C1: a held tail that does not fit is plain after the hold, '
      'streamed', (tester) async {
    // 4000 + 7003 characters: the tail does not fit after the closed block.
    final document = _repeatedThenTail(4000, 3000);
    await streamDocument(
      tester,
      document,
      chunk: 400,
      steps: [Step(document.length, hold: const Duration(milliseconds: 3000))],
    );
    expect(drawnColours(tester), [true, false]);
    expect(drawnColours(tester), await freshColours(tester, document));
  });

  testWidgets('C1: a held tail that does not fit is plain after the hold, '
      'static mount', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final document = _repeatedThenTail(4000, 3000);
    await tester.pumpWidget(markdownApp(document, const Env()));
    for (var k = 0; k < 8; k++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        colouredChars(tester),
        lessThanOrEqualTo(kDocumentLimit),
        reason: 'after ${(k + 1) * 500} ms of a static mount',
      );
    }
    expect(drawnColours(tester), [true, false]);
  });

  testWidgets('C2: a held tail that fits is coloured after the hold and a '
      'theme redraw', (tester) async {
    // 3000 + 6002 characters: both blocks fit, 9002 of the 10 000.
    final document = _repeatedThenTail(3000, 2999);
    await streamDocument(
      tester,
      document,
      chunk: 400,
      expectOverflow: false,
      steps: [Step(document.length, hold: const Duration(milliseconds: 3000))],
    );
    final streamed = drawnColours(tester);
    final fresh = await freshColours(tester, document);
    expect(fresh, [true, true], reason: 'a fresh judgement in order');
    expect(streamed, fresh, reason: 'settled after the hold');
  });

  testWidgets('C2: the same document stays coloured through a theme redraw', (
    tester,
  ) async {
    final document = _repeatedThenTail(3000, 2999);
    await streamDocument(
      tester,
      document,
      chunk: 400,
      expectOverflow: false,
      steps: [Step(document.length, hold: const Duration(milliseconds: 3000))],
    );
    // A redraw that changes only a dependency: the theme.
    await tester.pumpWidget(markdownApp(document, const Env(dark: true)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(drawnColours(tester), [true, true], reason: 'after a theme redraw');
  });

  testWidgets('C3: without AppMarkdownTheme, streaming 7000 then 5000 '
      'characters stays within the document limit', (tester) async {
    final document =
        'Intro\n\n${fenced(exactCode(7000))}\n\nMiddle.\n\n'
        '${fenced(exactCode(5000))}\n';
    await streamDocument(
      tester,
      document,
      chunk: 400,
      initialEnv: const Env(appMarkdownTheme: false),
    );
    expect(drawnColours(tester), [true, false]);
  });

  testWidgets('a block the scan did not read is never coloured', (
    tester,
  ) async {
    // The renderer parses with the package's own parser, so no document of
    // ours makes it hand over a block the scan lacks. The plan is replaced by
    // the plan of another text: every block the renderer hands over is then
    // unknown to it, and unknown means plain, however small the block is.
    final document =
        'Intro\n\n${fenced('const a = 1;')}\n\n${fenced('b();')}\n';
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(markdownApp(document, const Env()));
    expect(drawnColours(tester), [true, true], reason: 'the control');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      markdownApp(
        document,
        const Env(),
        planFor: (_) => CodeColourPlan.scan(fenced('const other = 2;')),
      ),
    );
    expect(codeBlocks(tester), hasLength(2));
    expect(drawnColours(tester), [false, false]);
  });
}

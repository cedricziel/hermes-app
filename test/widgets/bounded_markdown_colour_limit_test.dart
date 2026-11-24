/// A reply that streams into `BoundedMarkdown` never has more than 10 000
/// characters of code coloured at once, after any pump, for every fence form
/// the renderer accepts. The cap keeps the highlighter from blocking the UI
/// isolate (docs/architecture/chat.md). These cases stream documents of block
/// fences in chunks. Its siblings hold fences inside lists, quotes, alerts and
/// html (`_containers_test.dart`), footnotes, reference links and the largest
/// documents (`_references_test.dart`), and changes made while a reply streams
/// (`_events_test.dart`). None compares the settled colours with a fresh
/// mount.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/markdown_colour_harness.dart';

/// One document per fence form, built when a case runs.
final _documents = <String, String Function()>{
  'plain distinct fences': distinctFences,
  'identical fences': identicalFences,
  'tildes, info strings and 4-backtick fences': tildesInfoStringsAndLongFences,
  'unclosed fence at the end': unclosedAtEnd,
  'lines of 495 to 502 characters around the 500 limit': longLines,
  'block growing past 8000 characters': growingBlock,
  'emoji and ZWJ sequences': emojiFences,
  'lone surrogates': loneSurrogates,
  'CRLF line ends': () => windowsLineEnds(distinctFences()),
};

void main() {
  defineStreamCases(_documents);

  test('exactCode returns exactly the length asked for', () {
    for (final length in [for (var n = 1; n <= 400; n++) n, 2000, 8000, 8001]) {
      final code = exactCode(length);
      expect(code.length, length, reason: 'length $length');
      expect(code.endsWith('\n'), isFalse, reason: 'length $length');
      expect(
        code.split('\n').every((l) => l.length <= 78),
        isTrue,
        reason: 'length $length',
      );
    }
  });

  // The limits at their exact boundaries. Each document stays under the
  // document limit once its blocks are counted, so none of them needs to
  // overflow.
  testWidgets('a fitting block of exactly 8000 characters is coloured', (
    tester,
  ) async {
    final document = 'Intro\n\n${fenced(exactCode(kBlockLimit))}\n';
    await streamDocument(tester, document, expectOverflow: false);
    expect(
      codeBlocks(tester).single.highlightCode,
      isTrue,
      reason: 'a block of 8000 characters fits the block limit',
    );
  });

  testWidgets('a block pumped at exactly 8001 characters is plain', (
    tester,
  ) async {
    final document = 'Intro\n\n${fenced(exactCode(kBlockLimit + 1))}\n';
    // Pumps at the length where the block holds 8001 characters of code (the
    // opening line is 'Intro\n\n```js\n').
    final at = 'Intro\n\n${fence}js\n'.length + kBlockLimit + 1;
    await streamDocument(
      tester,
      document,
      steps: [Step(at)],
      expectOverflow: false,
    );
    expect(codeBlocks(tester).single.highlightCode, isFalse);
  });

  testWidgets('fitting blocks summing to exactly 10000 are all coloured', (
    tester,
  ) async {
    await streamDocument(
      tester,
      blocksSummingToTheDocumentLimit(),
      expectOverflow: false,
    );
    expect(
      codeBlocks(tester).every((b) => b.highlightCode),
      isTrue,
      reason: 'five blocks of 2000 characters fill the document limit exactly',
    );
  });

  testWidgets('lone surrogates in a static mount', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String block(String c, int n) => List.filled(n ~/ 100, c * 99).join('\n');
    final lone = '${block('a', 1000)}\nx\uD800y';
    final repaired = '${block('a', 1000)}\nx�y';
    final other = block('b', 1000);
    final big = block('c', 4000);
    final document = [
      fenced(lone),
      fenced(other),
      fenced(repaired),
      fenced(big),
      fenced(big),
    ].join('\n\n');
    await tester.pumpWidget(markdownApp(document, const Env()));
    expect(colouredChars(tester), lessThanOrEqualTo(kDocumentLimit));
    expect(colourableChars(tester), greaterThan(kDocumentLimit));
  });

  testWidgets('a held tail block is judged after the closed block before it', (
    tester,
  ) async {
    // The stream ends on a lone backtick, so the renderer holds that line and
    // releases it after 1.5 s: it then draws only the open block again, with
    // the 7000-character block before it still cached.
    final document =
        'Intro\n\n${fenced(exactCode(7000))}\n\nMiddle paragraph.\n\n'
        '${fence}js\n${exactCode(5000)}\n`';
    await streamDocument(
      tester,
      document,
      chunk: 400,
      steps: [Step(document.length, hold: const Duration(milliseconds: 3000))],
    );
    List<bool> drawn() => [for (final b in codeBlocks(tester)) b.highlightCode];
    final settled = drawn();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(markdownApp(document, const Env()));
    expect(settled, drawn(), reason: 'the streamed look is the fresh one');
    expect(settled, [true, false]);
  });
}

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
  'lines of 495 to 502 characters': longLines,
  'block growing past 8000 characters': growingBlock,
  'emoji and ZWJ sequences': emojiFences,
  'lone surrogates': loneSurrogates,
  'CRLF line ends': () => windowsLineEnds(distinctFences()),
};

void main() {
  defineStreamCases(_documents);

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
    expect(codeChars(tester), greaterThan(kDocumentLimit));
  });
}

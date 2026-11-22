/// The colouring limit of `BoundedMarkdown` (see
/// `bounded_markdown_colour_limit_test.dart`) for documents whose fences move
/// when a later line arrives: footnotes, reference links, and the largest
/// mixed document, plus streaming one character at a time.
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/markdown_colour_harness.dart';

final _documents = <String, String Function()>{
  'footnotes referenced before their definitions': footnotesReferencedFirst,
  'footnotes defined first, distinct': footnotesDefinedFirst,
  'footnotes defined first, identical': () => footnotesDefinedFirst(same: true),
  'footnotes referenced one by one, distinct': footnotesReferencedOneByOne,
  'footnotes referenced one by one, identical': () =>
      footnotesReferencedOneByOne(same: true),
  'footnotes referencing each other': footnotesReferencingEachOther,
  'footnotes shifting later fences, distinct': footnotesShifting,
  'footnotes shifting later fences, identical': () =>
      footnotesShifting(same: true),
  'reference links, definitions last, distinct': referenceLinksDefinedLast,
  'reference links, definitions last, identical': () =>
      referenceLinksDefinedLast(same: true),
  'reference links, definitions first': referenceLinksDefinedFirst,
  'reference links, definitions interleaved': referenceLinksInterleaved,
};

void main() {
  defineStreamCases(_documents);

  // The mixed document is over 100 000 characters: chunks of 61 would take
  // minutes, so it streams in chunks of 400 and, around the limit, of 7.
  testWidgets(
    'the large mixed document, chunks of 400 and 7 around the limit',
    (tester) async {
      final document = mixedDocument();
      expect(document.length, greaterThan(100000));
      await streamDocument(
        tester,
        document,
        chunk: 400,
        fineChunk: 7,
        finePumps: 150,
      );
    },
  );

  // Under the limit on purpose: it checks only that one-character chunks of
  // footnotes, lists and alerts render, not the colouring limit.
  testWidgets('a small document streams in one-character chunks', (
    tester,
  ) async {
    final small = [
      for (var i = 0; i < 2; i++)
        'P $i [^s$i].\n\n- li\n\n${indent('  ', fenced(codeBody(4, i)))}\n\n'
            '> [!TIP]\n${indent('> ', fenced(codeBody(3, i + 40)))}\n\n',
      for (var i = 0; i < 2; i++)
        '[^s$i]: n\n\n${indent('    ', fenced(codeBody(2)))}\n\n',
    ].join();
    await streamDocument(tester, small, chunk: 1, expectOverflow: false);
  });

  testWidgets('one character at a time where the limit is reached', (
    tester,
  ) async {
    await streamDocument(
      tester,
      identicalFences(),
      chunk: 400,
      fineChunk: 1,
      fineFrom: 9000,
      finePumps: 300,
    );
  });
}

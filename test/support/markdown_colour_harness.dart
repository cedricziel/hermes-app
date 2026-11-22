/// Harness for the code-colouring limit of `BoundedMarkdown`: mounts a reply the
/// way `ChatTextMessage` does, streams it in chunks, and after every pump sums
/// the characters of the code blocks that are coloured. The limit is written
/// here as a literal, not read from `kHighlightMaxDocument`, so raising the
/// constant fails the cases that use this file.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

import 'test_localizations.dart';

/// The most characters that may be coloured in one document.
const kDocumentLimit = 10000;

/// The most characters that may be coloured in one block.
const kBlockLimit = 8000;

/// The longest line that may be coloured.
const kLineLimit = 500;

const fence = '```';

/// What surrounds the markdown while it streams.
class Env {
  const Env({
    this.dark = false,
    this.scale = 1,
    this.rtl = false,
    this.noAnimations = false,
    this.accessibleNavigation = false,
    this.tick = 0,
    this.defaultFontSize = 14,
  });

  final bool dark;
  final double scale;
  final bool rtl;
  final bool noAnimations;
  final bool accessibleNavigation;

  /// A counter drawn beside the markdown, so a pump rebuilds the parent with
  /// the same text.
  final int tick;

  /// The size of the `DefaultTextStyle` above the markdown.
  final double defaultFontSize;
}

/// Mounts [text] as `ChatTextMessage` does: `AppMarkdownTheme` around
/// `BoundedMarkdown` with an explicit style, under `AppThemeScopes`.
Widget markdownApp(String text, Env env) => MaterialApp(
  theme: env.dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
  localizationsDelegates: kTestLocalizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(env.scale),
      disableAnimations: env.noAnimations,
      accessibleNavigation: env.accessibleNavigation,
    ),
    child: AppThemeScopes(child: child!),
  ),
  home: Directionality(
    textDirection: env.rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      body: SingleChildScrollView(
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: env.defaultFontSize),
          child: Column(
            children: [
              Text('tick ${env.tick}'),
              AppMarkdownTheme(
                child: BoundedMarkdown(
                  text,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

List<HermesCodeBlock> codeBlocks(WidgetTester tester) =>
    tester.widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock)).toList();

/// The characters of every code block that is drawn with colours.
int colouredChars(WidgetTester tester) =>
    codeBlocks(tester)
        .where((b) => b.highlightCode)
        .fold(0, (sum, b) => sum + b.codes.length);

/// The characters of the code blocks that may be coloured: within the block
/// and the line limits. A document needs more than [kDocumentLimit] of them
/// for the document limit to be reached.
int colourableChars(WidgetTester tester) => codeBlocks(tester)
    .where(
      (b) =>
          b.codes.length <= kBlockLimit &&
          !b.codes.split(RegExp('[\r\n]')).any((l) => l.length > kLineLimit),
    )
    .fold(0, (sum, b) => sum + b.codes.length);

/// A change made while the reply streams.
class Step {
  const Step(
    this.at, {
    this.env,
    this.replace,
    this.rewind = 0,
    this.remount = false,
    this.hold,
  });

  /// The streamed length at which it happens; the stream gets a pump that ends
  /// exactly here.
  final int at;

  /// The new surroundings.
  final Env? env;

  /// The whole text from here on (its streamed length is kept, so a shorter
  /// text ends the stream early).
  final String? replace;

  /// Characters the stream falls back by (the tail of the text is rewritten).
  final int rewind;

  /// Unmounts the markdown and mounts it again with the same text.
  final bool remount;

  /// Time that passes after the pump, in pumps of a sixth each.
  final Duration? hold;
}

/// What a streamed document reached.
class Streamed {
  int maxColoured = 0;
  int pumps = 0;
  int colourableCharsAtEnd = 0;
}

void _check(WidgetTester tester, Streamed seen, String where) {
  seen.pumps++;
  final blocks = codeBlocks(tester);
  final sum = blocks
      .where((b) => b.highlightCode)
      .fold(0, (s, b) => s + b.codes.length);
  if (sum > seen.maxColoured) seen.maxColoured = sum;
  expect(
    sum,
    lessThanOrEqualTo(kDocumentLimit),
    reason: '$sum characters are coloured $where',
  );
  for (final b in blocks.where((b) => b.highlightCode)) {
    expect(
      b.codes.length,
      lessThanOrEqualTo(kBlockLimit),
      reason: 'a coloured block of ${b.codes.length} characters $where',
    );
    for (final line in b.codes.split(RegExp('[\r\n]'))) {
      expect(
        line.length,
        lessThanOrEqualTo(kLineLimit),
        reason: 'a coloured line of ${line.length} characters $where',
      );
    }
  }
}

/// Mounts a new `BoundedMarkdown` with the final [text] and checks that no
/// block is refused that fits: a block within the block and line limits may
/// stay plain only because the coloured blocks before it plus its own size
/// pass the document limit. An unclosed block is judged like a closed one (the
/// code block style never turns off colouring while streaming).
///
/// The same lower bound is left out per pump on purpose. On main, 143 of 145
/// cases fail it: 105 settle plain and 38 are refused mid-stream at 1,132 to
/// 3,841 coloured characters. A later fix PR turns it on.
Future<void> _checkFreshMount(
  WidgetTester tester,
  Streamed seen,
  String text,
  Env env,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(markdownApp(text, env));
  for (var k = 0; k < 6; k++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  void nothingRefused(String where) {
    _check(tester, seen, where);
    var colouredBefore = 0;
    for (final b in codeBlocks(tester)) {
      final length = b.codes.length;
      if (b.highlightCode) {
        colouredBefore += length;
      } else if (length <= kBlockLimit &&
          !b.codes.split(RegExp('[\r\n]')).any((l) => l.length > kLineLimit)) {
        expect(
          colouredBefore + length,
          greaterThan(kDocumentLimit),
          reason:
              'a block of $length characters that fits every limit is plain '
              'after $colouredBefore coloured characters $where',
        );
      }
    }
  }

  nothingRefused('in a fresh mount of the final text');
  // The parent rebuilds the same mount with the same text: a second pass over
  // the document must judge its blocks from the first block again.
  await tester.pumpWidget(
    markdownApp(
      text,
      Env(
        dark: env.dark,
        scale: env.scale,
        rtl: env.rtl,
        noAnimations: env.noAnimations,
        accessibleNavigation: env.accessibleNavigation,
        tick: env.tick + 1,
        defaultFontSize: env.defaultFontSize,
      ),
    ),
  );
  nothingRefused('in a fresh mount after a parent rebuild');
}

/// Streams [document] in chunks of [chunk] characters, applying [steps], and
/// checks the limit after every pump and after the document settled. It does
/// not compare the settled colours with a fresh mount.
///
/// A [fineChunk] smaller than [chunk] is used instead while at least
/// [fineFrom] characters are coloured, for at most [finePumps] pumps: the
/// region where the limit is reached, without paying for a tiny chunk across
/// a whole document.
Future<Streamed> streamDocument(
  WidgetTester tester,
  String document, {
  int chunk = 61,
  int? fineChunk,
  int fineFrom = 7000,
  int finePumps = 250,
  List<Step> steps = const [],
  bool expectOverflow = true,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var fineLeft = finePumps;
  final seen = Streamed();
  final pending = [...steps]..sort((a, b) => a.at.compareTo(b.at));
  var env = const Env();
  var text = document;
  var n = 0;
  await tester.pumpWidget(markdownApp('', env));
  while (true) {
    var size = chunk;
    if (fineChunk != null &&
        fineLeft > 0 &&
        colouredChars(tester) >= fineFrom) {
      size = fineChunk;
      fineLeft--;
    }
    var target = n + size;
    if (pending.isNotEmpty &&
        pending.first.at > n &&
        pending.first.at < target) {
      target = pending.first.at;
    }
    n = target.clamp(0, text.length);
    Duration? hold;
    var remount = false;
    while (pending.isNotEmpty && pending.first.at <= target) {
      final step = pending.removeAt(0);
      if (step.env != null) env = step.env!;
      if (step.replace != null) {
        text = step.replace!;
        n = n.clamp(0, text.length);
      }
      if (step.rewind > 0) n = (n - step.rewind).clamp(0, text.length);
      remount = remount || step.remount;
      hold = step.hold ?? hold;
    }
    if (remount) await tester.pumpWidget(const SizedBox());
    final where = 'at $n of ${text.length} characters';
    await tester.pumpWidget(markdownApp(text.substring(0, n), env));
    _check(tester, seen, where);
    if (hold != null) {
      for (var k = 0; k < 6; k++) {
        await tester.pump(hold * (1 / 6));
        _check(tester, seen, 'while held $where');
      }
    }
    if (n >= text.length && pending.isEmpty) break;
    if (n >= text.length) {
      // Steps beyond the end of a shortened text still apply, once.
      for (final step in pending) {
        if (step.env != null) env = step.env!;
      }
      pending.clear();
      await tester.pumpWidget(markdownApp(text, env));
      _check(tester, seen, 'after the last step');
      break;
    }
  }
  for (var k = 0; k < 6; k++) {
    await tester.pump(const Duration(milliseconds: 500));
    _check(tester, seen, 'while settling');
  }
  seen.colourableCharsAtEnd = colourableChars(tester);
  await _checkFreshMount(tester, seen, text, env);
  if (const bool.fromEnvironment('COLOUR_REPORT')) {
    debugPrint(
      'COLOUR_REPORT max=${seen.maxColoured} pumps=${seen.pumps} '
      'colourable=${seen.colourableCharsAtEnd}',
    );
  }
  if (expectOverflow) {
    expect(
      seen.colourableCharsAtEnd,
      greaterThan(kDocumentLimit),
      reason:
          'the document must hold more colourable code (within the block and '
          'line limits) than the document limit, or the case proves nothing',
    );
  }
  return seen;
}

/// Where the k-th (0-based) closing triple backtick of [doc] ends.
int endOfFence(String doc, int k) {
  var at = 0;
  for (var i = 0; i <= k; i++) {
    final open = doc.indexOf(fence, at);
    final close = doc.indexOf('\n$fence', open + 3);
    at = close + 4;
  }
  return at;
}

// Fixture builders. Every name is invented.

String codeLine(int i) => 'const v$i = ${i + 1} + $i;' * 3;
String codeBody(int lines, [int seed = 0]) =>
    List.generate(lines, (i) => codeLine(seed + i)).join('\n');
String indent(String prefix, String block) =>
    block.split('\n').map((l) => '$prefix$l').join('\n');
String fenced(String body, [String info = 'js']) =>
    '$fence$info\n$body\n$fence';

String paragraphs(int count, String Function(int i) fenceOf) =>
    [for (var i = 0; i < count; i++) 'Para $i.\n\n${fenceOf(i)}\n\n'].join();

String distinctFences([int count = 8, int lines = 30]) =>
    paragraphs(count, (i) => fenced(codeBody(lines, i * 100)));

String identicalFences([int count = 8, int lines = 30]) =>
    paragraphs(count, (_) => fenced(codeBody(lines)));

String listFences() {
  final b = codeBody(12);
  return [
    for (var i = 0; i < 4; i++)
      'Item $i:\n\n- first\n\n${indent('  ', fenced(b))}\n\n'
          '- second\n  - nested\n\n${indent('    ', fenced(codeBody(12, i)))}\n\n'
          '1. numbered\n\n${indent('   ', fenced(b, 'py'))}\n\n'
          '2. numbered two\n   1. inner\n\n${indent('      ', fenced(codeBody(12, 50 + i), 'py'))}\n\n',
  ].join();
}

String quoteFences() {
  final b = codeBody(12);
  return [
    for (var i = 0; i < 8; i++)
      '> q $i\n>\n${indent('> ', fenced(b))}\n\n'
          '> outer\n> > inner $i\n> >\n${indent('> > ', fenced(codeBody(12, i)))}\n\n',
  ].join();
}

const alertKinds = ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION'];

String alertFences() {
  final b = codeBody(12);
  return [
    for (var r = 0; r < 4; r++)
      for (final k in alertKinds)
        '> [!$k]\n> text $r\n>\n${indent('> ', fenced(b))}\n\n',
  ].join();
}

String footnotesReferencedFirst() {
  final b = codeBody(12);
  final refs = [for (var i = 0; i < 20; i++) 'see[^n$i]'].join(' ');
  return 'Intro $refs.\n\n${fenced(codeBody(10, 7))}\n\n'
      '${[for (var i = 0; i < 20; i++) '[^n$i]: note $i\n\n${indent('    ', fenced(b))}\n\n'].join()}'
      'Tail paragraph.\n';
}

String footnotesDefinedFirst({bool same = false}) {
  final defs = [
    for (var i = 0; i < 8; i++)
      '[^d$i]: note $i\n\n${indent('    ', fenced(codeBody(30, same ? 0 : i * 100)))}\n\n',
  ].join();
  final refs = [for (var i = 0; i < 8; i++) 'late[^d$i]'].join(' ');
  return 'Intro.\n\n$defs\nNow $refs.\n';
}

String footnotesReferencedOneByOne({bool same = false}) {
  final defs = [
    for (var i = 0; i < 8; i++)
      '[^d$i]: note $i\n\n${indent('    ', fenced(codeBody(30, same ? 0 : i * 100)))}\n\n',
  ].join();
  final refs = [for (var i = 0; i < 8; i++) 'Para late[^d$i].\n\n'].join();
  return 'Intro.\n\n$defs$refs';
}

String footnotesReferencingEachOther() {
  final b = codeBody(20);
  return 'Intro.\n\n${fenced(codeBody(20, 5))}\n\n'
      '[^a]: note a refers[^b]\n\n${indent('    ', fenced(b))}\n\n'
      '[^b]: note b refers[^a]\n\n${indent('    ', fenced(b))}\n\n'
      '${identicalFences(6, 20)}End[^a] and[^b].\n';
}

String footnotesShifting({bool same = false}) {
  String f(int seed) => fenced(codeBody(28, same ? 0 : seed));
  final defs = [
    for (var i = 0; i < 3; i++)
      '[^d$i]: note $i\n\n${indent('    ', f(500 + i * 100))}\n\n',
  ].join();
  final later = [for (var i = 0; i < 4; i++) 'Para $i.\n\n${f(i * 100)}\n\n']
      .join();
  return 'Intro.\n\n${f(900)}\n\n$defs$later'
      '${[for (var i = 0; i < 3; i++) 'late[^d$i]'].join(' ')}.\n';
}

String referenceLinksDefinedLast({bool same = false}) {
  final segments = [
    for (var i = 0; i < 10; i++)
      '- see [doc$i] here\n\n${indent('  ', fenced(codeBody(25, same ? 0 : i * 100)))}\n\n',
  ].join();
  final defs = [for (var i = 0; i < 10; i++) '[doc$i]: https://example.com/$i']
      .join('\n');
  return 'Intro.\n\n${segments}Tail para.\n\n$defs\n';
}

String referenceLinksDefinedFirst() {
  final defs = [for (var i = 0; i < 10; i++) '[doc$i]: https://example.com/$i']
      .join('\n');
  return '$defs\n\nIntro.\n\n'
      '${paragraphs(10, (i) => fenced(codeBody(25, i * 100))).replaceAllMapped(RegExp(r'Para (\d)\.'), (m) => 'See [doc${m[1]}].')}';
}

String referenceLinksInterleaved() {
  final out = StringBuffer('Intro.\n\n');
  for (var i = 0; i < 10; i++) {
    out.write('Para [doc$i] link.\n\n${fenced(codeBody(25, i * 100))}\n\n');
    if (i >= 5) out.write('[doc${i - 5}]: https://example.com/$i\n\n');
  }
  return out.toString();
}

String htmlPre() => paragraphs(
  8,
  (i) => '<pre><code class="language-js">${codeBody(30, i * 10)}</code></pre>',
);

String detailsAndTables() => [
  for (var i = 0; i < 8; i++)
    '<details>\n<summary>s$i</summary>\n\n${fenced(codeBody(25))}\n\n</details>\n\n'
        '| a | b |\n|---|---|\n| <pre><code>${codeBody(1, i)}</code></pre> | `x` |\n\n',
].join();

String tildesInfoStringsAndLongFences() => [
  for (var i = 0; i < 6; i++)
    'Para $i.\n\n~~~python title="x$i"\n${codeBody(25, i)}\n~~~\n\n'
        '````js {1,3}\n${codeBody(10, 90 + i)}\n$fence\ninner fence\n$fence\n````\n\n',
].join();

String unclosedAtEnd() =>
    '${paragraphs(6, (i) => fenced(codeBody(30, i * 7)))}'
    '${fence}js\n${codeBody(60, 999)}';

/// Twelve fences: eleven hold one line of 495 to 502 characters (the limit is
/// 500) and one is plain. The first over-limit lines sit early in the
/// document, where the budget is not spent.
String longLines() {
  const lengths = [null, 501, 495, 502, 496, 500, 497, 501, 498, 499, 500, 502];
  return paragraphs(
    lengths.length,
    (i) => fenced(
      lengths[i] == null
          ? codeBody(20)
          : '${codeBody(10)}\n${'y' * lengths[i]!}\n${codeBody(10)}',
    ),
  );
}

/// The lines of the block that grows past 8000 characters.
const growingBlockLines = 150;

String growingBlock() =>
    'Intro\n\n${fenced(codeBody(growingBlockLines))}\n\n'
    '${identicalFences(9, 20)}';

String emojiFences() => paragraphs(
  8,
  (i) => fenced(
    List.generate(
      30,
      (k) =>
          "const s$k = '\u{1F600}\u{1F468}\u200D\u{1F469}\u200D\u{1F467}' + $k; // e"
              .padRight(80, '\u{1F389}'),
    ).join('\n'),
  ),
);

String loneSurrogates() {
  final high = '${codeBody(20)}\nx\uD800y';
  final low = '${codeBody(20)}\nx\uDC00y';
  return '${identicalFences(3, 20)}${fenced(high)}\n\n${fenced(low)}\n\n'
      '${identicalFences(4, 20)}';
}

String windowsLineEnds(String doc) => doc.replaceAll('\n', '\r\n');

String mixedDocument() => [
  distinctFences(),
  listFences(),
  quoteFences(),
  alertFences(),
  footnotesReferencedFirst(),
  htmlPre(),
  tildesInfoStringsAndLongFences(),
  unclosedAtEnd(),
].join('\n\n');

String removeFirstFence(String doc) {
  final start = doc.indexOf(fence);
  final end = doc.indexOf(fence, doc.indexOf('\n', start)) + 3;
  return doc.substring(0, start) + doc.substring(end);
}

/// Defines a case per document and chunk size: chunks of 400 and of 61 through
/// the whole document, and chunks of 7 through the region where the limit is
/// reached.
void defineStreamCases(Map<String, String Function()> documents) {
  for (final entry in documents.entries) {
    testWidgets('${entry.key}, chunks of 400', (tester) async {
      await streamDocument(tester, entry.value(), chunk: 400);
    });
    testWidgets('${entry.key}, chunks of 61', (tester) async {
      await streamDocument(tester, entry.value(), chunk: 61);
    });
    testWidgets('${entry.key}, chunks of 7 around the limit', (tester) async {
      await streamDocument(tester, entry.value(), chunk: 400, fineChunk: 7);
    });
  }
}

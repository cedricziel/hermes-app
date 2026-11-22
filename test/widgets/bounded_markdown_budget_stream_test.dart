import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

/// The 10,000 character code budget of a document, held at every pump while a
/// reply streams in small chunks (`GptMarkdown` keeps its finished segments and
/// asks only about the tail), and by the settled result, which must equal the
/// same text mounted whole.

const _f = '```';

List<HermesCodeBlock> _blocks(WidgetTester t) =>
    t.widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock)).toList();

List<bool> _coloured(WidgetTester t) => [
  for (final b in _blocks(t)) b.highlightCode,
];

int _chars(WidgetTester t) =>
    _blocks(t)
        .where((b) => b.highlightCode)
        .fold(0, (sum, b) => sum + b.codes.length);

class _Env {
  const _Env({
    this.dark = false,
    this.scale = 1,
    this.nav = false,
    this.dim = false,
    this.fontSize,
  });
  final bool dark;
  final double scale;

  /// `MediaQuery.accessibleNavigation`, which the renderer reads while a reply
  /// arrives.
  final bool nav;

  /// `MediaQuery.platformBrightness`, which the app's theme scopes follow.
  final bool dim;

  /// The `style` parameter of the widget itself.
  final double? fontSize;
}

Widget _app(String text, [_Env env = const _Env()]) => MaterialApp(
  theme: env.dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
  builder: (c, child) => MediaQuery(
    data: MediaQuery.of(c).copyWith(
      textScaler: TextScaler.linear(env.scale),
      accessibleNavigation: env.nav,
      platformBrightness: env.dim ? Brightness.dark : Brightness.light,
    ),
    child: AppThemeScopes(child: child!),
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AppMarkdownTheme(
        child: BoundedMarkdown(
          text,
          style: env.fontSize == null
              ? null
              : TextStyle(fontSize: env.fontSize),
        ),
      ),
    ),
  ),
);

String _line(int i) => 'const v$i = $i + 1;' * 5;
String _body(int lines, [int seed = 0]) =>
    List.generate(lines, (i) => _line(seed + i)).join('\n');
String _indent(String p, String body) =>
    body.split('\n').map((l) => '$p$l').join('\n');

/// What a renderer that keeps nothing colours: every block in order, greedily.
List<bool> _greedy(List<HermesCodeBlock> blocks) {
  var used = 0;
  return [
    for (final b in blocks)
      if (b.codes.length <= kHighlightMaxBlock &&
          used + b.codes.length <= kHighlightMaxDocument)
        (used += b.codes.length) > 0
      else
        false,
  ];
}

/// Streams [doc] in [chunk] characters per pump, asserting the limit after
/// every one, then compares the settled result with a fresh mount. [midway]
/// changes the environment once half of the text is in.
Future<void> _stream(
  WidgetTester tester,
  String doc,
  int chunk, {
  _Env? midway,
  bool expectCut = true,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var env = const _Env();
  await tester.pumpWidget(_app('', env));
  for (var i = chunk; ; i += chunk) {
    final n = doc.length < i ? doc.length : i;
    if (midway != null && i >= doc.length ~/ 2 && env != midway) env = midway;
    await tester.pumpWidget(_app(doc.substring(0, n), env));
    expect(
      _chars(tester),
      lessThanOrEqualTo(kHighlightMaxDocument),
      reason: 'after $n of ${doc.length} characters',
    );
    if (n == doc.length) break;
  }
  await tester.pump(const Duration(seconds: 3));
  expect(_chars(tester), lessThanOrEqualTo(kHighlightMaxDocument));
  final settled = _coloured(tester);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(_app(doc, env));
  final whole = _coloured(tester);
  expect(_chars(tester), lessThanOrEqualTo(kHighlightMaxDocument));
  expect(whole, _greedy(_blocks(tester)), reason: 'a fresh mount is greedy');
  if (expectCut) {
    expect(whole.contains(false), isTrue, reason: 'the document is over');
  }
  expect(settled, whole, reason: 'settled equals a fresh mount');
}

String get _identical {
  final body = _body(30);
  return [for (var f = 0; f < 8; f++) 'Para $f.\n\n${_f}js\n$body\n$_f\n\n']
      .join();
}

String get _lists {
  final small = _body(12);
  return [
    for (var f = 0; f < 6; f++)
      'Item $f:\n\n- first\n\n  ${_f}js\n${_indent('  ', small)}\n  $_f\n\n'
          '- second\n\n  ${_f}js\n${_indent('  ', small)}\n  $_f\n\n'
          '> q $f\n>\n> ${_f}js\n${_indent('> ', small)}\n> $_f\n\n',
  ].join();
}

String get _alerts {
  final small = _body(12);
  return [
    for (var f = 0; f < 11; f++)
      '> [!NOTE]\n> ${_f}js\n${_indent('> ', small)}\n> $_f\n\n',
  ].join();
}

String get _footnotes {
  final small = _body(12);
  return [
    for (var f = 0; f < 11; f++)
      'Text[^$f].\n\n[^$f]: note\n\n    ${_f}js\n${_indent('    ', small)}\n    $_f\n\n',
  ].join();
}

String get _distinct => [
  for (var f = 0; f < 8; f++)
    'Para $f.\n\n${_f}js\n${_body(30, f * 100)}\n$_f\n\n',
].join();

/// Reference links whose definitions arrive after the segments that use them:
/// the renderer builds those segments, and their fences, again.
String _refLinks({required bool same}) {
  final segments = [
    for (var i = 0; i < 10; i++)
      '- see [doc$i] here\n\n  ${_f}js\n'
          '${_indent('  ', _body(25, same ? 0 : i * 100))}\n  $_f\n\n',
  ].join();
  final defs = [for (var i = 0; i < 10; i++) '[doc$i]: https://example.com/$i']
      .join('\n');
  return 'Intro.\n\n${segments}Tail para.\n\n$defs\n';
}

/// Footnote definitions that come before the text that references them: their
/// fences exist only once the references arrive, at the end.
String _footnotesFirst({required bool same}) {
  final defs = [
    for (var i = 0; i < 8; i++)
      '[^d$i]: note $i\n\n    ${_f}js\n'
          '${_indent('    ', _body(30, same ? 0 : i * 100))}\n    $_f\n\n',
  ].join();
  final refs = [for (var i = 0; i < 8; i++) 'late[^d$i]'].join(' ');
  return 'Intro.\n\n$defs\nNow $refs.\n';
}

/// Footnote definitions followed by fences of their own: the references arrive
/// last, and the fences the footnotes show move every block after them.
String _footnotesBeforeFences({required bool same}) {
  String fence(int seed) => '${_f}js\n${_body(20, same ? 0 : seed)}\n$_f';
  final defs = [
    for (var i = 0; i < 3; i++)
      '[^d$i]: note $i\n\n${_indent('    ', fence(500 + i * 100))}\n\n',
  ].join();
  final later = [
    for (var i = 0; i < 4; i++) 'Para $i.\n\n${fence(i * 100)}\n\n',
  ].join();
  final refs = [for (var i = 0; i < 3; i++) 'late[^d$i]'].join(' ');
  return 'Intro.\n\n${fence(900)}\n\n$defs$later$refs.\n';
}

String get _mixed =>
    [_distinct.substring(0, 3000), _lists, _alerts, _footnotes].join('\n\n');

void main() {
  for (final chunk in [61, 400]) {
    for (final same in [true, false]) {
      final kind = same ? 'identical' : 'distinct';
      testWidgets('reference links defined last, $kind, $chunk a pump', (
        t,
      ) async {
        await _stream(t, _refLinks(same: same), chunk);
      });
      testWidgets('footnotes shown before other fences, $kind, $chunk a pump', (
        t,
      ) async {
        await _stream(t, _footnotesBeforeFences(same: same), chunk);
      });
      testWidgets('footnotes defined first, $kind, $chunk a pump', (t) async {
        await _stream(t, _footnotesFirst(same: same), chunk);
      });
    }
  }

  // The renderer drops what it kept when what it reads from `MediaQuery`
  // changes, which `BoundedMarkdown` must see too.
  for (final MapEntry(:key, :value) in {
    'identical fences': _identical,
    'distinct fences': _distinct,
    'mixed fences': _mixed,
  }.entries) {
    testWidgets('screen reader navigation turned on mid-stream, $key', (
      t,
    ) async {
      await _stream(t, value, 61, midway: const _Env(nav: true));
    });
    testWidgets('the text style changed mid-stream, $key', (t) async {
      await _stream(t, value, 61, midway: const _Env(fontSize: 19));
    });
  }

  for (final chunk in [7, 61]) {
    testWidgets('identical fences, $chunk characters a pump', (t) async {
      await _stream(t, _identical, chunk);
    });
    testWidgets('identical fences in lists and quotes, $chunk a pump', (
      t,
    ) async {
      await _stream(t, _lists, chunk);
    });
    testWidgets('alert fences, $chunk characters a pump', (t) async {
      await _stream(t, _alerts, chunk);
    });
    testWidgets('footnote fences, $chunk characters a pump', (t) async {
      await _stream(t, _footnotes, chunk);
    });
  }

  testWidgets('a static reply with alert fences matches a full mount', (
    t,
  ) async {
    await t.pumpWidget(_app(_alerts));
    final blocks = _blocks(t);
    expect(blocks.length, 11);
    // Each alert fence is charged once, as on a renderer that keeps nothing.
    expect(
      _coloured(t).where((c) => c).length,
      kHighlightMaxDocument ~/ blocks.first.codes.length,
    );
    expect(_coloured(t), _greedy(blocks));
  });

  testWidgets('the platform brightness changed in the middle of a stream', (
    t,
  ) async {
    await _stream(t, _lists, 61, midway: const _Env(dim: true));
  });

  testWidgets('a theme change in the middle of a stream', (t) async {
    await _stream(t, _identical, 61, midway: const _Env(dark: true));
  });

  testWidgets('a text scale change in the middle of a stream', (t) async {
    await _stream(t, _lists, 61, midway: const _Env(scale: 1.5));
  });

  testWidgets('the renderer rebuilding on its own keeps its decisions', (
    t,
  ) async {
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Three fences of 3,000 characters, then a last one that is still open and
    // ends in two backticks, the closing fence arriving: the renderer holds
    // that line back and builds the block again 1.5 s later, with no build of
    // ours (the text did not change since an unrelated rebuild of the parent).
    String big(int s) {
      final lines = List.generate(30, (i) => '${'x' * 98}${(s + i) % 10}');
      return '${_f}js\n${lines.join('\n')}\n$_f\n\n';
    }

    final head = [for (var i = 0; i < 3; i++) big(i)].join();
    final last = List.filled(8, 'y' * 99).join('\n');
    final doc = '$head${_f}js\n$last\n``';
    for (var n = 0; n <= doc.length; n += 61) {
      await t.pumpWidget(_app(doc.substring(0, n)));
    }
    await t.pumpWidget(_app(doc));
    await t.pumpWidget(_app(doc));
    for (var s = 0; s < 6; s++) {
      await t.pump(const Duration(milliseconds: 500));
      expect(_chars(t), lessThanOrEqualTo(kHighlightMaxDocument));
    }
    final settled = _coloured(t);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(doc));
    expect(settled, _coloured(t));
    expect(settled.last, isTrue, reason: 'the small last block fits');
  });

  testWidgets('an edit that is not an append builds every block again', (
    t,
  ) async {
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    String fence(int seed, int lines) =>
        '${_f}js\n${_body(lines, seed)}\n$_f\n\n';
    final rest = [for (var i = 1; i < 9; i++) fence(i * 100, 10)].join();
    final before = '${fence(0, 10)}$rest';
    // The first fence grows; the others are unchanged text at the same places.
    final after = '${fence(0, 50)}$rest';
    await t.pumpWidget(_app(before));
    expect(_chars(t), lessThanOrEqualTo(kHighlightMaxDocument));
    await t.pumpWidget(_app(after));
    await t.pump(const Duration(seconds: 3));
    expect(_chars(t), lessThanOrEqualTo(kHighlightMaxDocument));
    final edited = _coloured(t);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(after));
    expect(edited, _coloured(t));
  });
}

/// Source-scan guards for how tests are written (`test.*` rules). Known old
/// violations sit in `baseline/test.yaml` (shrink-only, see `ratchet.dart`);
/// legitimate sites are in a rule's allowlist, each with its reason. The
/// `architecture-guards` skill says how to add a rule and prove it fails.
library;

import 'package:flutter_test/flutter_test.dart';

import 'ratchet.dart';
import 'source_scan.dart';

const _delegatesAllow = {
  'test/support/test_localizations.dart': 'the shared constant itself',
  'test/github_release_store_test.dart':
      'builds the app delegates without the material_ui bridge on purpose, to '
      'prove the bridge is what provides those localizations',
  'widgetbook/main.dart':
      'the catalog app entry point, shipped code that cannot import test/; it '
      'adds the bridge delegates itself',
};

final _delegatesPattern = RegExp(
  r'\bAppLocalizations\s*\.\s*localizationsDelegates\b',
);

List<Hit> _delegateHits() => [
  for (final root in const ['test', 'widgetbook', 'benchmark'])
    ...scanPattern(
      root,
      _delegatesPattern,
      view: (f) => f.code,
      allow: _delegatesAllow.keys,
    ),
];

/// A geometry case is one in a test file that checks a focus ring's shape
/// (`expectRingHugs`, `expectInsideClip` or `expectInsideRow`).
final _geometryFile = RegExp(
  r'\b(?:expectRingHugs|expectInsideClip|expectInsideRow)\s*\(',
);

/// Reaching focus by hand: a call of the `_focus` helper (which calls
/// `requestFocus` on the first node in the control's subtree) or of
/// `requestFocus` itself.
final _byRequest = RegExp(r'\b_focus\s*\(|\.\s*requestFocus\s*\(');

/// The helpers that reach focus by `requestFocus` on purpose. Their
/// definitions and their calls are not counted.
const _focusByRequestAllow = {
  '_focus':
      'the helper itself: its call sites are the violations, and it is the '
      'only place that may call requestFocus on a found node',
  '_focusInk':
      'gives the row\'s own ink well primary focus, the node one level above '
      'the row\'s content, so that a button inside the row that draws its own '
      'ring (the thread row\'s More button) is not the focused control; a Tab '
      'would land on that button or on the next row, never on the ink well '
      'alone',
};

final _helperDefinition = RegExp(
  r'^(?:Future<void>|void) (' + _focusByRequestAllow.keys.join('|') + r')\s*\(',
  multiLine: true,
);

/// [file]'s code with the allowed helpers' definitions and calls blanked, so
/// only a case that reaches focus by hand is left.
String _withoutAllowedHelpers(SourceFile file) {
  final chars = file.code.split('');
  void blank(int from, int to) {
    for (var i = from; i < to && i < chars.length; i++) {
      if (chars[i] != '\n') chars[i] = ' ';
    }
  }

  final code = file.code;
  for (final m in _helperDefinition.allMatches(code)) {
    final end = code.indexOf('\n}\n', m.start);
    blank(m.start, end < 0 ? code.length : end + 2);
  }
  for (final name in _focusByRequestAllow.keys.where((n) => n != '_focus')) {
    for (final m in RegExp('\\b$name\\s*\\(').allMatches(code)) {
      blank(m.start, m.end);
    }
  }
  return chars.join();
}

/// The hits of the `test.geometry-focus-by-key` rule in [file].
List<Hit> geometryFocusHits(SourceFile file) {
  if (!_geometryFile.hasMatch(file.code)) return const [];
  final body = _withoutAllowedHelpers(file);
  return [
    for (final m in _byRequest.allMatches(body))
      Hit(file.path, file.lineOf(m.start), file.lineText(file.lineOf(m.start))),
  ];
}

List<Hit> _geometryFocusHits() => [
  for (final file in dartFiles('test')) ...geometryFocusHits(file),
];

void main() {
  List<Hit>? hits;
  List<Hit> run() => hits ??= _delegateHits();
  List<Hit>? focusHits;
  List<Hit> runFocus() => focusHits ??= _geometryFocusHits();
  ratchetTests([
    Rule(
      id: 'test.localization-delegates',
      message:
          'use kTestLocalizationsDelegates (test/support/test_localizations.dart): '
          'it adds the material_ui and cupertino_ui delegates to the app '
          'delegates, so a non-English locale finds MaterialLocalizations.',
      scan: () => countByPath(run()),
      locate: (path) => hitLines(run(), path),
    ),
    Rule(
      id: 'test.geometry-focus-by-key',
      message:
          'reach focus in a focus ring geometry case with tabTo(tester, '
          'finder) (test/support/tab_to.dart), not requestFocus or _focus: a '
          'node focused by hand can be one no Tab reaches, and then the case '
          'passes while the real control shows no ring. A helper that must '
          'focus a node by hand goes on _focusByRequestAllow with its reason.',
      scan: () => countByPath(runFocus()),
      locate: (path) => hitLines(runFocus(), path),
    ),
  ], namespace: 'test');

  group('test.geometry-focus-by-key reads a geometry case', () {
    SourceFile file(String body) => SourceFile(
      'test/x_ring_test.dart',
      'void main() {\n  testWidgets(\'a\', (tester) async {\n$body\n'
          '    expectRingHugs(band, rect);\n  });\n}\n',
    );

    test('a requestFocus case is a violation', () {
      expect(geometryFocusHits(file('    node.requestFocus();')), hasLength(1));
      expect(
        geometryFocusHits(file('    await _focus(tester, find.text(\'A\'));')),
        hasLength(1),
      );
    });

    test('a tabTo case is not', () {
      expect(
        geometryFocusHits(file('    await tabTo(tester, find.text(\'A\'));')),
        isEmpty,
      );
    });

    test('the allowed helpers are not', () {
      const helpers =
          'Future<void> _focus(WidgetTester tester, Finder f) async {\n'
          '  node.requestFocus();\n}\n\n'
          'Future<void> _focusInk(WidgetTester tester, Finder f) async {\n'
          '  Focus.of(c).requestFocus();\n}\n';
      final source = SourceFile(
        'test/x_ring_test.dart',
        '$helpers\nvoid main() {\n  testWidgets(\'a\', (t) async {\n'
            '    await _focusInk(tester, ink);\n    expectInsideClip(r);\n'
            '  });\n}\n',
      );
      expect(geometryFocusHits(source), isEmpty);
    });

    test('a file that checks no ring geometry is not read', () {
      final source = SourceFile(
        'test/x_test.dart',
        'void main() {\n  node.requestFocus();\n}\n',
      );
      expect(geometryFocusHits(source), isEmpty);
    });
  });
}

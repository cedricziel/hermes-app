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

/// Reaching focus by hand: a call of the `_focus` or `_focusInk` helper (each
/// calls `requestFocus` on a node it finds) or of `requestFocus` itself.
final _byRequest = RegExp(r'\b_focus(?:Ink)?\s*\(|\.\s*requestFocus\s*\(');

/// The helpers whose definitions reach focus by `requestFocus`: a definition
/// is not counted, every call of one is. Why each exists:
///
/// - `_focus` focuses the first node in a control's subtree, or the nearest
///   one above it.
/// - `_focusInk` gives a row's own ink well primary focus, the node one level
///   above the row's content, so that a button inside the row that draws its
///   own ring (the thread row's More button) is not the focused control; a
///   Tab would land on that button or on the next row, never on the ink well
///   alone. Its calls are baselined like any other, and move to `tabTo` once
///   a case can name the ink well.
const _focusByRequestHelpers = ['_focus', '_focusInk'];

final _helperDefinition = RegExp(
  r'^(?:Future<void>|void) (' + _focusByRequestHelpers.join('|') + r')\s*\(',
  multiLine: true,
);

/// [file]'s code with the helpers' definitions blanked, so that only a case
/// that reaches focus by hand is left.
String _withoutHelperDefinitions(SourceFile file) {
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
  return chars.join();
}

/// The hits of the `test.geometry-focus-by-tab` rule in [file].
List<Hit> geometryFocusHits(SourceFile file) {
  if (!_geometryFile.hasMatch(file.code)) return const [];
  final body = _withoutHelperDefinitions(file);
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
      id: 'test.geometry-focus-by-tab',
      message:
          'reach focus in a focus ring geometry case with tabTo(tester, '
          'finder) (test/support/tab_to.dart), not requestFocus or _focus: a '
          'node focused by hand can be one no Tab reaches, and then the case '
          'passes while the real control shows no ring. A helper whose '
          'definition must focus a node by hand goes on _focusByRequestHelpers '
          'with its reason.',
      scan: () => countByPath(runFocus()),
      locate: (path) => hitLines(runFocus(), path),
    ),
  ], namespace: 'test');

  group('test.geometry-focus-by-tab reads a geometry case', () {
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

    test('a _focusInk call is a violation, its definition is not', () {
      const helpers =
          'Future<void> _focus(WidgetTester tester, Finder f) async {\n'
          '  node.requestFocus();\n}\n\n'
          'Future<void> _focusInk(WidgetTester tester, Finder f) async {\n'
          '  Focus.of(c).requestFocus();\n}\n';
      final definitionsOnly = SourceFile(
        'test/x_ring_test.dart',
        '$helpers\nvoid main() {\n  testWidgets(\'a\', (t) async {\n'
            '    expectInsideClip(r);\n  });\n}\n',
      );
      expect(geometryFocusHits(definitionsOnly), isEmpty);
      final withCall = SourceFile(
        'test/x_ring_test.dart',
        '$helpers\nvoid main() {\n  testWidgets(\'a\', (t) async {\n'
            '    await _focusInk(tester, ink);\n    expectInsideClip(r);\n'
            '  });\n}\n',
      );
      expect(geometryFocusHits(withCall), hasLength(1));
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

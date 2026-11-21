/// Source-scan guards for how tests are written (`test.*` rules). Known old
/// violations sit in `baseline/test.yaml` (shrink-only, see `ratchet.dart`);
/// legitimate sites are in a rule's allowlist, each with its reason. The
/// `architecture-guards` skill says how to add a rule and prove it fails.
library;

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
  for (final root in const ['test', 'widgetbook'])
    ...scanPattern(
      root,
      _delegatesPattern,
      view: (f) => f.code,
      allow: _delegatesAllow.keys,
    ),
];

void main() {
  List<Hit>? hits;
  List<Hit> run() => hits ??= _delegateHits();
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
  ], namespace: 'test');
}

/// The colouring limit of `BoundedMarkdown` (see
/// `bounded_markdown_colour_limit_test.dart`) while something changes in the
/// middle of a stream: an edit, a rewind, a remount, the theme, text scale,
/// text direction, the default text style, accessibility flags, parent
/// rebuilds and held frames. The limit is checked after every pump.
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/markdown_colour_harness.dart';

typedef _Steps = List<Step> Function(String document);

/// Steps at fractions of the streamed document.
int _at(String doc, double fraction) => (doc.length * fraction).round();

final _documents = <String, String Function()>{
  'identical fences': identicalFences,
  'distinct fences': distinctFences,
  'mixed': () => mixedDocument().substring(0, 28000),
};

final _midStream = <String, _Steps>{
  'a non-append edit at the start': (doc) => [
    Step(_at(doc, 0.5), replace: 'Changed first. ${doc.substring(10)}'),
  ],
  'an edit that removes a fence': (doc) => [
    Step(_at(doc, 0.6), replace: removeFirstFence(doc)),
  ],
  'a tail rewind': (doc) => [Step(_at(doc, 0.5), rewind: 400)],
  'a remount': (doc) => [Step(_at(doc, 0.5), remount: true)],
  'a theme switch': (doc) => [Step(_at(doc, 0.5), env: const Env(dark: true))],
  '3x text scale': (doc) => [Step(_at(doc, 0.5), env: const Env(scale: 3))],
  'a scale and theme change': (doc) => [
    Step(_at(doc, 0.4), env: const Env(scale: 3, dark: true)),
  ],
  'an RTL direction change': (doc) => [
    Step(_at(doc, 0.5), env: const Env(rtl: true)),
  ],
  'a DefaultTextStyle change': (doc) => [
    Step(_at(doc, 0.5), env: const Env(defaultFontSize: 18)),
  ],
  'accessibleNavigation': (doc) => [
    Step(_at(doc, 0.5), env: const Env(accessibleNavigation: true)),
  ],
  'disableAnimations': (doc) => [
    Step(_at(doc, 0.5), env: const Env(noAnimations: true)),
  ],
  'disableAnimations and back': (doc) => [
    Step(_at(doc, 0.3), env: const Env(noAnimations: true)),
    Step(_at(doc, 0.6), env: const Env()),
  ],
  'parent rebuilds with unchanged text': (doc) => [
    for (var i = 1; i < 10; i++) Step(_at(doc, i / 10), env: Env(tick: i)),
  ],
  'held frames': (doc) => [
    for (var i = 1; i < 6; i++)
      Step(_at(doc, i / 6), hold: const Duration(seconds: 2)),
  ],
};

void main() {
  for (final doc in _documents.entries) {
    for (final event in _midStream.entries) {
      testWidgets('${doc.key}: ${event.key}', (tester) async {
        final document = doc.value();
        await streamDocument(
          tester,
          document,
          steps: event.value(document),
          chunk: doc.key == 'identical fences' ? 61 : 400,
          width: 400,
        );
      });
    }
  }

  // A change that lands on the pump where a duplicate fence closes: the
  // fence's own block is judged again with the new surroundings.
  final identical = identicalFences();
  final surroundings = <String, Env>{
    'RTL direction': const Env(rtl: true),
    'DefaultTextStyle': const Env(defaultFontSize: 18),
    'dark theme': const Env(dark: true),
    'accessibleNavigation': const Env(accessibleNavigation: true),
    'parent rebuild': const Env(tick: 1),
  };
  for (final k in [4, 5]) {
    for (final delta in [0, -1]) {
      for (final change in surroundings.entries) {
        testWidgets('${change.key} at the pump where duplicate fence $k closes'
            '${delta == 0 ? '' : ' ($delta)'}', (tester) async {
          await streamDocument(
            tester,
            identical,
            steps: [Step(endOfFence(identical, k) + delta, env: change.value)],
          );
        });
      }
    }
  }

  testWidgets('a block grown past 8000 characters, then edited back', (
    tester,
  ) async {
    final document = growingBlock();
    final shrunk = document.replaceFirst(
      codeBody(growingBlockLines),
      codeBody(60),
    );
    await streamDocument(
      tester,
      document,
      steps: [Step(_at(document, 0.8), replace: shrunk)],
    );
  });
}

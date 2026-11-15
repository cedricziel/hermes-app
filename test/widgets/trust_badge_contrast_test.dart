import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/widgets/skill_badges.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

Future<void> _pump(WidgetTester tester, Widget child, {required bool dark}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
        home: Scaffold(
          body: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
          ),
        ),
      ),
    );

/// The label colour a badge really paints, against the box behind it.
void _expectReadable(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  final fill = (box.decoration as BoxDecoration).color!;
  final ink = tester
      .renderObject<RenderParagraph>(find.text(label))
      .text
      .style!
      .color!;
  expect(
    _contrast(ink, fill),
    greaterThanOrEqualTo(4.5),
    reason: '$label: $ink on $fill',
  );
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    for (final (level, label) in [
      ('builtin', 'Official'),
      ('trusted', 'Trusted'),
      ('community', 'Community'),
    ]) {
      testWidgets('TrustBadge $level is readable in $mode', (tester) async {
        await _pump(tester, TrustBadge(level), dark: dark);
        _expectReadable(tester, label);
      });
    }

    for (final source in SkillSource.values) {
      testWidgets('SourceBadge ${source.name} is readable in $mode', (
        tester,
      ) async {
        await _pump(tester, SourceBadge(source), dark: dark);
        _expectReadable(tester, skillSourceLabel(source));
      });
    }
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposal_parts.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/widgets/skill_badges.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';

/// Pins what the text badges and the status chip look and measure like, so
/// the shared badge stays behaviour-neutral.
Future<void> _pump(WidgetTester tester, Widget child, {bool dark = false}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
      home: Scaffold(
        body: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      ),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester, String text) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

TextStyle _style(WidgetTester tester, String text) {
  final t = tester.widget<Text>(find.text(text));
  return DefaultTextStyle.of(tester.element(find.text(text))).style
      .merge(t.style);
}

void main() {
  group('text badges', () {
    for (final dark in [false, true]) {
      final theme = dark ? buildHermesDarkTheme() : buildHermesLightTheme();
      final scheme = theme.colorScheme;

      testWidgets('TrustBadge dark=$dark', (tester) async {
        await _pump(
          tester,
          const Column(
            children: [
              TrustBadge('builtin'),
              TrustBadge('trusted'),
              TrustBadge('x'),
            ],
          ),
          dark: dark,
        );
        for (final (text, color) in [
          ('Official', scheme.primary),
          ('Trusted', dark ? HermesColors.zinc700 : HermesColors.zinc200),
          ('Community', scheme.surfaceContainerHighest),
        ]) {
          final d = _decoration(tester, text);
          expect(d.color, color, reason: text);
          expect(d.borderRadius, BorderRadius.circular(6));
          expect(
            _style(tester, text).fontSize,
            Theme.of(tester.element(find.text(text)))
                .textTheme
                .labelSmall!
                .fontSize,
          );
        }
        final size = tester.getSize(find.byType(TrustBadge).first);
        final text = tester.getSize(find.text('Official'));
        expect(size.width, text.width + 14);
        expect(size.height, text.height + 2);
      });

      testWidgets('SourceBadge dark=$dark', (tester) async {
        await _pump(tester, const SourceBadge(SkillSource.hub), dark: dark);
        final d = _decoration(tester, 'Hub');
        expect(d.color, scheme.surfaceContainerHighest);
        expect(d.borderRadius, BorderRadius.circular(6));
        final size = tester.getSize(find.byType(SourceBadge));
        final text = tester.getSize(find.text('Hub'));
        expect(size, Size(text.width + 14, text.height + 2));
      });

      testWidgets('ProposalBadge dark=$dark', (tester) async {
        await _pump(tester, const SizedBox(), dark: dark);
        final hermes = tester.element(find.byType(SizedBox).first).hermesColors;
        final colors = {
          ProposalAction.add: hermes.success,
          ProposalAction.remove: scheme.error,
          ProposalAction.replace: hermes.warning,
          ProposalAction.skill: scheme.primary,
          ProposalAction.change: hermes.subtleText,
        };
        for (final MapEntry(key: action, value: color) in colors.entries) {
          await _pump(
            tester,
            UnconstrainedBox(child: ProposalBadge(action)),
            dark: dark,
          );
          final d = _decoration(tester, action.label);
          expect(d.color, color.withValues(alpha: 0.12), reason: '$action');
          expect(d.borderRadius, BorderRadius.circular(6));
          final style = _style(tester, action.label);
          expect(style.color, color);
          expect(style.fontSize, 12);
          expect(style.fontWeight, FontWeight.w600);
          final size = tester.getSize(find.byType(ProposalBadge));
          expect(size.width, greaterThanOrEqualTo(64));
          expect(
            size.height,
            tester.getSize(find.text(action.label)).height + 4,
          );
        }
      });
    }

    testWidgets('badges are not tappable and read as their words', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrustBadge('trusted'),
            SourceBadge(SkillSource.agent),
            ProposalBadge(ProposalAction.add),
          ],
        ),
      );
      for (final word in ['Trusted', 'Agent', 'Add']) {
        expect(find.bySemanticsLabel(word), findsOneWidget);
      }
      expect(find.byType(InkWell), findsNothing);
      handle.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets('StatusChip dark=$dark', (tester) async {
        await _pump(tester, const StatusChip(ToolsStatus.ready), dark: dark);
        final color = tester
            .element(find.byType(StatusChip))
            .hermesColors
            .success;
        final d = _decoration(tester, 'Ready');
        expect(d.color, color.withValues(alpha: 0.12));
        expect(d.borderRadius, BorderRadius.circular(6));
        final style = _style(tester, 'Ready');
        expect(style.color, color);
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w600);
        expect(tester.widget<Icon>(find.byType(Icon)).color, color);
        final size = tester.getSize(find.byType(StatusChip));
        final text = tester.getSize(find.text('Ready'));
        // 8 + icon 14 + 4 gap + text + 8 wide.
        expect(size.width, text.width + 34);
        // 3 + the row (the taller of the icon with its 1px top and the text) + 3.
        expect(size.height, max(text.height, 15.0) + 6);
        expect(find.byType(InkWell), findsNothing);
      });
    }
  });
}

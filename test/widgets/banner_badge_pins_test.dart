import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_chat_banner.dart';
import 'package:hermes_app/src/memory/memory_proposals.dart';
import 'package:hermes_app/src/memory/widgets/memory_proposal_parts.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/widgets/skill_badges.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';

/// Pins what the bot chat banner and the small text badges read and measure
/// like, so moving them onto the shared widgets stays behaviour-neutral.
const _bot = BotModeBot(
  serverId: 'server',
  name: 'research',
  revision: 0,
  displayName: 'Research Specialist',
);

BotChatContext _ctx({bool protocol = true}) => BotChatContext(
  bot: _bot,
  rootId: 'root',
  storedId: 'tip',
  peers: const [_bot],
  protocolEnabled: protocol,
);

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
  group('BotChatBanner', () {
    testWidgets('reads title, handle and the unavailable note', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, BotChatBanner(context: _ctx(protocol: false)));
      expect(
        find.bySemanticsLabel(RegExp('Research Specialist')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('@research')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Teammate messaging is unavailable')),
        findsOneWidget,
      );
      expect(find.text('Research Specialist'), findsOneWidget);
      expect(find.textContaining('@research · Bot Chat'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('omits the note when messaging is available', (tester) async {
      await _pump(tester, BotChatBanner(context: _ctx()));
      expect(find.textContaining('Teammate messaging'), findsNothing);
    });

    testWidgets('is not a live region and has no tap target', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, BotChatBanner(context: _ctx()));
      final live = tester.semantics.simulatedAccessibilityTraversal().where(
        (n) => n.flagsCollection.isLiveRegion,
      );
      expect(live, isEmpty);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
      handle.dispose();
    });

    testWidgets('keeps its column width on a wide screen', (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, BotChatBanner(context: _ctx()));
      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('Research Specialist'),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect(box.width, 640);
    });
  });

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
          ('Official', scheme.primaryContainer),
          ('Trusted', scheme.secondaryContainer),
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

    testWidgets('StatusChip keeps tint, radius, text style and padding', (
      tester,
    ) async {
      await _pump(tester, const StatusChip(ToolsStatus.ready));
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
      final size = tester.getSize(find.byType(StatusChip));
      final text = tester.getSize(find.text('Ready'));
      // 8 + icon 14 + 4 gap + text + 8 wide; 3 + row + 3 tall.
      expect(size.width, text.width + 34);
      expect(size.height, greaterThanOrEqualTo(text.height + 6));
      expect(find.byType(InkWell), findsNothing);
    });
  });
}

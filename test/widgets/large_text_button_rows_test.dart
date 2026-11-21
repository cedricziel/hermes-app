import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import '../support/test_localizations.dart';

const _phone = Size(390, 844);
const _small = Size(320, 640);
const _desktop = Size(700, 844);

/// One row with a bordered button at its end.
class _Case {
  const _Case(this.name, this.platform, this.row, this.title, this.label);

  final String name;
  final TargetPlatform platform;
  final Widget Function() row;

  /// Finds the text the button shares its row with.
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) label;
}

Widget _slack() => MessagingPlatformRow(
  platform: const HermesMessagingPlatform(id: 'slack', name: 'Slack'),
  onSetUp: () {},
  onToggle: (_) {},
);

final _macUpdates = _Case(
  'Check for Updates on a Mac',
  TargetPlatform.macOS,
  () => SkillUpdatesSection(onPressed: () {}),
  (_) => 'Hub skills',
  (l10n) => l10n.skillsCheckForUpdatesMac,
);
final _macSetUp = _Case(
  'Set Up… on a Mac',
  TargetPlatform.macOS,
  _slack,
  (_) => 'Slack',
  (l10n) => l10n.messagingSetUpMac,
);
final _materialSetUp = _Case(
  'Set up on Material',
  TargetPlatform.android,
  _slack,
  (_) => 'Slack',
  (l10n) => l10n.messagingSetUp,
);

Future<void> _pump(
  WidgetTester tester,
  _Case c, {
  required double scale,
  required Size size,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme(platform: c.platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: GroupedListView(
          children: [
            GroupedSection(children: [c.row()]),
          ],
        ),
      ),
    ),
  );
  // The German strings load a frame later.
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester, Finder from) =>
    AppLocalizations.of(tester.element(from));

Finder _button(WidgetTester tester, _Case c) {
  final l10n = _l10n(tester, find.byType(Scaffold));
  return find.widgetWithText(OutlinedButton, c.label(l10n));
}

/// The button is on screen, tappable and not under another widget.
void _expectReachable(WidgetTester tester, Finder button, Size size) {
  expect(button, findsOneWidget);
  expect(button.hitTestable(), findsOneWidget);
  final rect = tester.getRect(button);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
}

void main() {
  // Each fails without the fix: the button overflows the row at that size.
  for (final (c, scale, size) in [
    (_macUpdates, 2.0, _phone),
    (_macUpdates, 3.0, _phone),
    (_macSetUp, 3.0, _small),
    (_materialSetUp, 3.0, _phone),
  ]) {
    testWidgets(
      '${c.name} stays on screen at ${scale}x text, ${size.width} pt',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, c, scale: scale, size: size);
        expect(tester.takeException(), isNull);
        final button = _button(tester, c);
        _expectReachable(tester, button, size);
        if (c.platform == TargetPlatform.android) {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        } else {
          // Mac pointer targets are at least 28 pt.
          expect(tester.getSize(button).height, greaterThanOrEqualTo(28));
        }
        // On a wide window it neither overflows nor leaves the screen.
        await _pump(tester, c, scale: scale, size: _desktop);
        expect(tester.takeException(), isNull);
        _expectReachable(tester, _button(tester, c), _desktop);
        semantics.dispose();
      },
    );
  }

  group('the layout is unchanged where the button fits beside the label', () {
    for (final (c, cases) in [
      (_macUpdates, [(1.0, _phone), (1.5, _desktop)]),
      (_macSetUp, [(1.0, _phone), (1.5, _desktop)]),
      (_materialSetUp, [(1.0, _phone), (3.0, _desktop)]),
    ]) {
      testWidgets(c.name, (tester) async {
        for (final (scale, size) in cases) {
          await _pump(tester, c, scale: scale, size: size);
          expect(tester.takeException(), isNull);
          final l10n = _l10n(tester, find.byType(Scaffold));
          final label = tester.getRect(find.text(c.title(l10n)));
          final button = tester.getRect(_button(tester, c));
          expect(button.left, greaterThan(label.right));
          expect(button.center.dy, closeTo(label.center.dy, 1));
        }
      });
    }
  });

  testWidgets('the German labels fit beside the row title at 1x', (
    tester,
  ) async {
    for (final c in [_macUpdates, _macSetUp, _materialSetUp]) {
      await _pump(
        tester,
        c,
        scale: 1,
        size: _phone,
        locale: const Locale('de'),
      );
      expect(tester.takeException(), isNull, reason: c.name);
      final l10n = _l10n(tester, find.byType(Scaffold));
      expect(l10n.localeName, 'de');
      final label = tester.getRect(find.text(c.title(l10n)));
      final button = tester.getRect(_button(tester, c));
      expect(button.left, greaterThan(label.right), reason: c.name);
      expect(button.center.dy, closeTo(label.center.dy, 1), reason: c.name);
    }
  });

  group('the Mac button is its own control at every text size', () {
    for (final scale in [1.0, 3.0]) {
      testWidgets('${scale}x', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, _macUpdates, scale: scale, size: _phone);
        final label = _l10n(
          tester,
          find.byType(Scaffold),
        ).skillsCheckForUpdatesMac;
        final button = tester.getSemantics(find.text(label));
        expect(button.flagsCollection.isButton, isTrue);
        expect(button.label, label);
        // The row's own node reads "Hub skills" and nothing of the button.
        final row = tester.getSemantics(find.text('Hub skills'));
        expect(row.label, 'Hub skills');
        semantics.dispose();
      });
    }
  });

  testWidgets('the Mac button keeps the theme label style at 1x', (
    tester,
  ) async {
    await _pump(tester, _macUpdates, scale: 1, size: _phone);
    final label = _l10n(tester, find.byType(Scaffold)).skillsCheckForUpdatesMac;
    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    final expected = theme.textTheme.labelLarge!;
    final drawn = tester
        .renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(OutlinedButton),
            matching: find.text(label),
          ),
        )
        .text
        .style!;
    expect(drawn.fontSize, 12);
    expect(drawn.fontFamily, expected.fontFamily);
    expect(drawn.fontWeight, expected.fontWeight);
    expect(drawn.letterSpacing, expected.letterSpacing);
    expect(drawn.height, expected.height);
  });

  // Near the width where the button stops fitting, the title is never squeezed
  // below a quarter of the row (or its own width): the button's own padding
  // and border count in the decision.
  for (final (c, scale, from, to) in [
    (_macUpdates, 1.5, 440.0, 520.0),
    (_materialSetUp, 2.0, 300.0, 480.0),
  ]) {
    testWidgets('${c.name} stacks before it squeezes the title', (
      tester,
    ) async {
      await _pump(tester, c, scale: scale, size: _desktop);
      final natural = tester
          .getSize(find.text(c.title(_l10n(tester, find.byType(Scaffold)))))
          .width;
      for (var w = from; w <= to; w += 1) {
        await _pump(tester, c, scale: scale, size: Size(w, 900));
        expect(tester.takeException(), isNull, reason: '$w');
        final title = find.text(c.title(_l10n(tester, find.byType(Scaffold))));
        final row = tester.getSize(find.byType(GroupedRow)).width;
        final beside =
            tester.getRect(_button(tester, c)).top <
            tester.getRect(title).bottom;
        if (!beside) continue;
        expect(
          tester.getSize(title).width,
          greaterThanOrEqualTo(natural < row / 4 ? natural : row / 4 - 0.5),
          reason: 'row $row',
        );
      }
    });
  }
}

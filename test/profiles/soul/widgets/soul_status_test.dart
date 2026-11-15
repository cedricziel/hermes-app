import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_status_line.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import 'soul_widget_host.dart';

void main() {
  group('SoulStatusLine', () {
    testWidgets('Saved has a check icon and the words', (tester) async {
      await pumpSoul(tester, const SoulStatusLine(kind: SoulStatusKind.saved));
      expect(find.text('Saved. New chats use it.'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        AppIcons.checkCircle.apple,
      );
    });

    testWidgets('the earlier text has a warning icon and the sentence', (
      tester,
    ) async {
      await pumpSoul(
        tester,
        const SoulStatusLine(kind: SoulStatusKind.earlierText),
        platform: TargetPlatform.android,
      );
      expect(
        find.text(
          'The server still has the earlier text. Your text is still here.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        AppIcons.warning.material,
      );
    });

    testWidgets('saving shows a spinner and the word', (tester) async {
      await pumpSoul(tester, const SoulStatusLine(kind: SoulStatusKind.saving));
      expect(find.text('Saving'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is one polite live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSoul(tester, const SoulStatusLine(kind: SoulStatusKind.saved));
      final node = tester.getSemantics(
        find.bySemanticsLabel('Saved. New chats use it.'),
      );
      expect(node, isNotNull);
      handle.dispose();
    });
  });

  group('SoulStatusBanner', () {
    const offered = {
      SoulBannerKind.lostAnswer: 'Check',
      SoulBannerKind.checkFailed: 'Check again',
      SoulBannerKind.saveCheckFailed: 'Try again',
      SoulBannerKind.readFailed: 'Try again',
      SoulBannerKind.offline: 'Try again',
    };

    for (final MapEntry(key: kind, value: label) in offered.entries) {
      testWidgets('$kind offers $label and calls back once', (tester) async {
        var calls = 0;
        await pumpSoul(
          tester,
          SoulStatusBanner(kind: kind, onAction: () => calls++),
        );
        await tester.tap(find.text(label));
        expect(calls, 1);
      });
    }

    testWidgets('the save error has no action', (tester) async {
      await pumpSoul(
        tester,
        SoulStatusBanner(kind: SoulBannerKind.saveFailed, onAction: () {}),
      );
      expect(find.byType(TextButton), findsNothing);
      expect(find.text("Couldn't save"), findsOneWidget);
      expect(
        find.text(
          'Hermes reported a problem. Nothing was changed on the server.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('checking swaps the action for a spinner and "Checking…"', (
      tester,
    ) async {
      await pumpSoul(
        tester,
        SoulStatusBanner(kind: SoulBannerKind.checking, onAction: () {}),
      );
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text("Couldn't confirm the save"), findsOneWidget);
    });

    testWidgets('the lost answer carries a question-mark icon', (tester) async {
      await pumpSoul(
        tester,
        SoulStatusBanner(kind: SoulBannerKind.lostAnswer, onAction: () {}),
        platform: TargetPlatform.android,
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        AppIcons.questionCircleFilled.material,
      );
    });

    for (final MapEntry(key: platform, value: minimum) in soulTargets.entries) {
      testWidgets('the action is at least $minimum on $platform', (
        tester,
      ) async {
        await pumpSoul(
          tester,
          SoulStatusBanner(kind: SoulBannerKind.lostAnswer, onAction: () {}),
          platform: platform,
        );
        final size = tester.getSize(find.byType(TextButton));
        expect(size.height, greaterThanOrEqualTo(minimum));
      });
    }

    testWidgets('in German the action stacks under the text', (tester) async {
      await pumpSoul(
        tester,
        SoulStatusBanner(kind: SoulBannerKind.lostAnswer, onAction: () {}),
        locale: const Locale('de'),
      );
      expect(find.text('Prüfen'), findsOneWidget);
      final text = tester.getTopLeft(
        find.text('Die Speicherung konnte nicht bestätigt werden'),
      );
      final action = tester.getTopLeft(find.text('Prüfen'));
      expect(action.dy, greaterThan(text.dy));
      expect(find.byType(AppBanner), findsOneWidget);
    });
  });
}

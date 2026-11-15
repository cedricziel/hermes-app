import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_editor.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_save_actions.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_status_line.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';

import 'soul_widget_host.dart';

SoulSaveActions _buttons({
  bool dirty = true,
  bool busy = false,
  VoidCallback? onSave,
  VoidCallback? onRevert,
}) => SoulSaveActions(
  dirty: dirty,
  busy: busy,
  onSave: onSave ?? () {},
  onRevert: onRevert ?? () {},
);

void main() {
  group('enabled rules', () {
    test('Save needs a difference and nothing running', () {
      expect(soulCanSave(dirty: true, busy: false), isTrue);
      expect(soulCanSave(dirty: false, busy: false), isFalse);
      expect(soulCanSave(dirty: true, busy: true), isFalse);
      expect(soulCanSave(dirty: false, busy: true), isFalse);
    });

    testWidgets('clean: both are drawn and disabled', (tester) async {
      await pumpSoul(tester, _buttons(dirty: false));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Revert'), findsOneWidget);
    });

    testWidgets('dirty: both fire once', (tester) async {
      var saves = 0, reverts = 0;
      await pumpSoul(
        tester,
        _buttons(onSave: () => saves++, onRevert: () => reverts++),
      );
      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Revert'));
      expect((saves, reverts), (1, 1));
    });

    testWidgets('busy: Save shows a spinner instead of its label, both are '
        'disabled', (tester) async {
      await pumpSoul(tester, _buttons(busy: true));
      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('the bar action follows the same rule', (tester) async {
      late SettingsFormAction clean, dirty, busy;
      await pumpSoul(
        tester,
        Builder(
          builder: (context) {
            clean = SoulSaveActions.barAction(
              context,
              dirty: false,
              busy: false,
              onSave: () {},
            );
            dirty = SoulSaveActions.barAction(
              context,
              dirty: true,
              busy: false,
              onSave: () {},
            );
            busy = SoulSaveActions.barAction(
              context,
              dirty: true,
              busy: true,
              onSave: () {},
            );
            return const SizedBox();
          },
        ),
      );
      expect(clean.onPressed, isNull);
      expect(dirty.onPressed, isNotNull);
      expect(busy.busy, isTrue);
      expect(busy.label, 'Save');
    });

    testWidgets('the Revert row is disabled while clean and while busy', (
      tester,
    ) async {
      Future<void> pump(bool dirty, bool busy) => pumpSoul(
        tester,
        SoulSaveActions.revertRow(dirty: dirty, busy: busy, onRevert: () {}),
      );
      VoidCallback? press() =>
          tester.widget<TextButton>(find.byType(TextButton)).onPressed;
      await pump(false, false);
      expect(press(), isNull);
      await pump(true, true);
      expect(press(), isNull);
      await pump(true, false);
      expect(press(), isNotNull);
    });
  });

  group('minimum targets', () {
    for (final MapEntry(key: platform, value: minimum) in soulTargets.entries) {
      testWidgets('buttons are at least $minimum on $platform', (tester) async {
        await pumpSoul(tester, _buttons(), platform: platform);
        for (final finder in [
          find.byType(FilledButton),
          find.byType(OutlinedButton),
        ]) {
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(minimum));
        }
      });

      testWidgets('the Revert row is at least $minimum on $platform', (
        tester,
      ) async {
        await pumpSoul(
          tester,
          SoulSaveActions.revertRow(dirty: true, busy: false, onRevert: () {}),
          platform: platform,
        );
        final size = tester.getSize(find.byType(TextButton));
        expect(size.height, greaterThanOrEqualTo(minimum));
        expect(size.width, greaterThanOrEqualTo(minimum));
      });
    }

    testWidgets('at the largest text the buttons stay in reach', (
      tester,
    ) async {
      await pumpSoul(
        tester,
        _buttons(),
        textScaler: const TextScaler.linear(3),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Revert lines up with the text of the lines above it', () {
    for (final scale in [1.0, 3.0]) {
      for (final locale in [const Locale('en'), const Locale('de')]) {
        testWidgets('at text scale $scale ($locale)', (tester) async {
          final controller = SoulTextController();
          addTearDown(controller.dispose);
          await pumpSoul(
            tester,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoulEditor(controller: controller, profile: 'work'),
                const SoulStatusLine(kind: SoulStatusKind.saved),
                SoulSaveActions.revertRow(
                  dirty: true,
                  busy: false,
                  onRevert: () {},
                ),
              ],
            ),
            locale: locale,
            textScaler: TextScaler.linear(scale),
          );
          double left(Finder f) => tester.getTopLeft(f).dx;
          final revert = find.text(
            locale.languageCode == 'de' ? 'Zurücksetzen' : 'Revert',
          );
          final status = find.text(
            locale.languageCode == 'de'
                ? 'Gespeichert. Neue Chats verwenden sie.'
                : 'Saved. New chats use it.',
          );
          final note = find.text(
            locale.languageCode == 'de'
                ? 'Hermes verwendet seine Standardpersönlichkeit, solange das hier leer ist.'
                : 'Hermes uses its default personality while this is empty.',
          );
          expect(left(status), closeTo(left(note), 0.5));
          expect(left(revert), closeTo(left(status), 0.5));
        });
      }
    }
  });
}

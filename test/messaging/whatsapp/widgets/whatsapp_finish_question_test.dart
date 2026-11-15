import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_finish_question.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import 'whatsapp_widget_host.dart';

Future<void> _ask(
  WidgetTester tester,
  List<bool> answers, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  TextScaler? textScaler,
}) async {
  await pumpWa(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async => answers.add(await askFinishWhatsApp(context)),
        child: const Text('ask'),
      ),
    ),
    platform: platform,
    locale: locale,
    textScaler: textScaler,
  );
  await tester.tap(find.text('ask'));
  await tester.pumpAndSettle();
}

List<AppDialogAction> _actions(WidgetTester tester) =>
    tester.widgetList<AppDialogAction>(find.byType(AppDialogAction)).toList();

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group('on $platform', () {
      testWidgets('Cancel is first and the default, Save and restart is '
          'plain', (tester) async {
        await _ask(tester, [], platform: platform);
        expect(find.text('Save and restart?'), findsOneWidget);
        expect(
          find.text(
            'Save the WhatsApp setup and ask the messaging gateway to restart? '
            'Conversations on messaging channels will be interrupted.',
          ),
          findsOneWidget,
        );
        final actions = _actions(tester);
        expect(actions.length, 2);
        expect((actions[0].child as Text).data, 'Cancel');
        expect(actions[0].isDefault, isTrue);
        expect((actions[1].child as Text).data, 'Save and restart');
        expect(actions[1].isDefault, isFalse);
        expect(actions[1].isDestructive, isFalse);
        // Cancel is on top: the Apple alert stacks its buttons.
        expect(
          tester.getTopLeft(find.text('Cancel')).dy,
          lessThan(tester.getTopLeft(find.text('Save and restart')).dy),
        );
      });

      testWidgets('answers true only for Save and restart', (tester) async {
        final answers = <bool>[];
        await _ask(tester, answers, platform: platform);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save and restart'));
        await tester.pumpAndSettle();
        expect(answers, [false, true]);
      });
    });
  }

  group('on Android', () {
    testWidgets('two text buttons, Cancel first, nothing filled', (
      tester,
    ) async {
      final answers = <bool>[];
      await _ask(tester, answers, platform: TargetPlatform.android);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(CupertinoDialogActionProbe), findsNothing);
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Save and restart')).dx),
      );
      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(
        buttons.where(
          (b) =>
              b.child is Text && (b.child as Text).data == 'Save and restart',
        ),
        hasLength(1),
      );
      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('Escape-style dismissal answers false', (tester) async {
      final answers = <bool>[];
      await _ask(tester, answers, platform: TargetPlatform.android);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('German at the largest text on $platform: no overflow, the '
        'long label is there', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _ask(
        tester,
        [],
        platform: platform,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(3),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Speichern und neu starten'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
    });
  }
}

/// No Cupertino action exists on Android; named so the check reads.
typedef CupertinoDialogActionProbe = CupertinoDialogAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_questions.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import 'soul_widget_host.dart';

Future<void> _ask(
  WidgetTester tester,
  Future<bool> Function(BuildContext) ask,
  List<bool> answers, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    soulHost(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => answers.add(await ask(context)),
          child: const Text('ask'),
        ),
      ),
      platform: platform,
      locale: locale,
    ),
  );
  await tester.tap(find.text('ask'));
  await tester.pumpAndSettle();
}

List<AppDialogAction> _actions(WidgetTester tester) =>
    tester.widgetList<AppDialogAction>(find.byType(AppDialogAction)).toList();

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group('on $platform', () {
      testWidgets(
        'Save question: Cancel first and the default, Replace plain',
        (tester) async {
          final answers = <bool>[];
          await _ask(
            tester,
            (c) => askReplaceSoul(c, profile: 'work'),
            answers,
            platform: platform,
          );
          expect(find.text('Replace the personality of work?'), findsOneWidget);
          expect(
            find.text(
              'New chats use it. Chats already running usually keep the old one; Bot Chats may pick it up.',
            ),
            findsOneWidget,
          );
          final actions = _actions(tester);
          expect(actions.length, 2);
          expect(actions[0].isDefault, isTrue);
          expect(actions[1].isDefault, isFalse);
          expect(actions[1].isDestructive, isFalse);
          expect((actions[0].child as Text).data, 'Cancel');
          expect((actions[1].child as Text).data, 'Replace');
        },
      );

      testWidgets('Discard question: Keep editing is the default, Discard is '
          'plain', (tester) async {
        await _ask(
          tester,
          (c) => askDiscardSoul(c, profile: 'work'),
          [],
          platform: platform,
        );
        expect(find.text('Discard changes?'), findsOneWidget);
        expect(
          find.text(
            "Your edits to the personality of work haven't been saved.",
          ),
          findsOneWidget,
        );
        final actions = _actions(tester);
        expect(actions[0].isDefault, isTrue);
        expect((actions[0].child as Text).data, 'Keep editing');
        expect(actions[1].isDefault, isFalse);
        expect(actions[1].isDestructive, isFalse);
        expect((actions[1].child as Text).data, 'Discard');
      });
    });
  }

  group('on Android', () {
    testWidgets('two text buttons, Cancel first, no filled default', (
      tester,
    ) async {
      await _ask(
        tester,
        (c) => askReplaceSoul(c, profile: 'work'),
        [],
        platform: TargetPlatform.android,
      );
      expect(find.byType(FilledButton), findsNothing);
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      // The opener behind the dialog is a TextButton too.
      final labels = [
        for (final b in buttons)
          if (b.child is Text) (b.child as Text).data,
      ];
      expect(labels.indexOf('Cancel'), lessThan(labels.indexOf('Replace')));
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Replace')).dx),
      );
    });

    testWidgets('Discard: Keep editing first, no filled default', (
      tester,
    ) async {
      await _ask(
        tester,
        (c) => askDiscardSoul(c, profile: 'work'),
        [],
        platform: TargetPlatform.android,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(
        tester.getTopLeft(find.text('Keep editing')).dx,
        lessThan(tester.getTopLeft(find.text('Discard')).dx),
      );
    });
  });

  testWidgets('empty text says Hermes will use its default personality', (
    tester,
  ) async {
    await _ask(
      tester,
      (c) => askReplaceSoul(c, profile: 'work', empty: true),
      [],
    );
    expect(
      find.text(
        'Hermes will use its default personality. Chats already running usually keep the old one; Bot Chats may pick it up.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('after a check found the earlier text the question adds the '
      'pending-save line', (tester) async {
    await _ask(
      tester,
      (c) => askReplaceSoul(c, profile: 'work', pendingSaveNote: true),
      [],
    );
    expect(
      find.textContaining(
        'An earlier save may still be pending on the server.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Bot Chats may pick it up.'), findsOneWidget);
  });

  testWidgets('a 64-character profile name wraps in the title', (tester) async {
    final name = '${'a' * 8}-${'b' * 55}';
    expect(name.length, 64);
    await _ask(tester, (c) => askReplaceSoul(c, profile: name), []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(name), findsOneWidget);
  });

  testWidgets('German wording', (tester) async {
    await _ask(
      tester,
      (c) => askDiscardSoul(c, profile: 'work'),
      [],
      locale: const Locale('de'),
    );
    expect(find.text('Änderungen verwerfen?'), findsOneWidget);
    expect(find.text('Weiterbearbeiten'), findsOneWidget);
    expect(find.text('Verwerfen'), findsOneWidget);
  });

  group('answers', () {
    testWidgets('Replace answers true, Cancel answers false', (tester) async {
      final answers = <bool>[];
      await _ask(tester, (c) => askReplaceSoul(c, profile: 'work'), answers);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answers, [true, false]);
    });

    testWidgets('Discard answers true, Keep editing answers false', (
      tester,
    ) async {
      final answers = <bool>[];
      await _ask(tester, (c) => askDiscardSoul(c, profile: 'work'), answers);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(answers, [true, false]);
    });
  });
}

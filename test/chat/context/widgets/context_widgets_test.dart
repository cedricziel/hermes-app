import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/compress_confirmation.dart';
import 'package:hermes_app/src/chat/context/widgets/compress_outcome_note.dart';
import 'package:hermes_app/src/chat/context/widgets/context_format.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view
    ..physicalSize = const Size(390, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

ContextFigures _figures(int percent, {int? used, bool? estimated = false}) =>
    ContextFigures(
      used: used ?? 2000 * percent,
      max: 200000,
      percent: percent,
      estimated: estimated,
      source: ContextSource.providerUsage,
    );

Widget _row(ContextFigures f) =>
    ContextRow(figures: f, level: contextLevelOf(f), onOpen: () {});

void main() {
  group('level wording', () {
    for (final (percent, word) in [
      (79, null),
      (80, 'Nearly full'),
      (94, 'Nearly full'),
      (95, 'Nearly full'),
      (99, 'Nearly full'),
      (100, 'Full'),
    ]) {
      testWidgets('$percent% says ${word ?? 'nothing'}', (tester) async {
        await _pump(tester, _row(_figures(percent)));
        expect(
          find.text('Nearly full'),
          word == 'Nearly full' ? findsOne : findsNothing,
        );
        expect(find.text('Full'), word == 'Full' ? findsOne : findsNothing);
      });
    }

    testWidgets('more used than the window says Full with the real counts', (
      tester,
    ) async {
      await _pump(tester, _row(_figures(100, used: 212000)));
      expect(find.text('Full'), findsOne);
      expect(find.text('212k of 200k tokens'), findsOne);
    });

    test('95 and over is critical, 80 to 94 nearly full', () {
      expect(contextLevelOf(_figures(94)), ContextLevel.nearlyFull);
      expect(contextLevelOf(_figures(95)), ContextLevel.critical);
      expect(contextLevelOf(_figures(79)), ContextLevel.normal);
      expect(contextLevelOf(_figures(99, used: 250000)), ContextLevel.full);
    });
  });

  testWidgets('the percentage stays whole at three times the text', (
    tester,
  ) async {
    await _pump(tester, _row(_figures(100, used: 212000)), scale: 3);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.text('100%'));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
    // It moved under the label.
    expect(
      rect.top,
      greaterThan(tester.getRect(find.text('Context')).bottom - 1),
    );
  });

  testWidgets('the row carries the bar label, estimated and state', (
    tester,
  ) async {
    await _pump(tester, _row(_figures(82, estimated: true)));
    expect(
      find.bySemanticsLabel(
        RegExp(r'Context, 82 percent used, estimated\. Nearly full'),
      ),
      findsOne,
    );
    await _pump(tester, _row(_figures(62)));
    expect(
      find.bySemanticsLabel(RegExp(r'^Context, 62 percent used\.')),
      findsOne,
    );
  });

  testWidgets('App Lock shows only the percentage', (tester) async {
    final f = _figures(82);
    await _pump(
      tester,
      ContextRow(figures: f, level: contextLevelOf(f), locked: true),
    );
    expect(find.text('82%'), findsOne);
    expect(find.text('Nearly full'), findsNothing);
    expect(find.textContaining('tokens'), findsNothing);
  });

  group('compress confirmation', () {
    Widget sheet({
      String focus = '',
      bool replyStarted = false,
      ValueChanged<String?>? onConfirm,
    }) => SizedBox(
      width: 390,
      height: 760,
      child: CompressConfirmation(
        initialFocus: focus,
        advancedInitiallyOpen: true,
        replyStarted: replyStarted,
        onConfirm: onConfirm ?? (_) {},
        onCancel: () {},
      ),
    );

    for (final focus in ['--preview the schema', 'Here 3', 'up to here']) {
      testWidgets('refuses "$focus"', (tester) async {
        await _pump(tester, sheet(focus: focus));
        expect(
          find.textContaining('Write a topic, like “the database schema”.'),
          findsOne,
        );
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
      });
    }

    testWidgets('hands an acceptable focus over, trimmed', (tester) async {
      String? got = 'unset';
      await _pump(
        tester,
        sheet(focus: ' the schema ', onConfirm: (f) => got = f),
      );
      await tester.tap(find.text('Compress'));
      expect(got, 'the schema');
    });

    testWidgets('a reply started disables Compress and says why', (
      tester,
    ) async {
      await _pump(tester, sheet(replyStarted: true));
      expect(find.text('Wait for the reply to finish.'), findsOne);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('Android has two text buttons, Cancel first', (tester) async {
      await _pump(tester, sheet(), platform: TargetPlatform.android);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Compress')).dx),
      );
    });

    testWidgets('the buttons stack full width at the largest text', (
      tester,
    ) async {
      await _pump(tester, sheet(), scale: 3);
      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final compress = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Compress'),
      );
      expect(compress.top, greaterThan(cancel.bottom - 1));
      expect(compress.left, cancel.left);
      expect(compress.width, cancel.width);
    });
  });

  group('compress outcomes', () {
    testWidgets('the note counts what the server reported', (tester) async {
      await _pump(
        tester,
        const CompressOutcomeNote(
          outcome: CompressOutcome(
            CompressOutcomeKind.compressed,
            beforeMessages: 42,
            afterMessages: 9,
            beforeTokens: 120000,
            afterTokens: 30000,
            fallbackUsed: true,
          ),
        ),
      );
      expect(find.textContaining('Conversation compressed'), findsOne);
      expect(
        find.textContaining('42 → 9 messages · about 120k → 30k tokens'),
        findsOne,
      );
      expect(find.textContaining('dropped them'), findsOne);
    });

    testWidgets('unsupported draws nothing', (tester) async {
      await _pump(
        tester,
        const CompressOutcomeNote(
          outcome: CompressOutcome(CompressOutcomeKind.unsupported),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the transcript line holds counts only', (tester) async {
      late AppLocalizations l10n;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            l10n = context.l10n;
            return const SizedBox();
          },
        ),
      );
      expect(
        transcriptLineForCompress(
          l10n,
          const CompressOutcome(
            CompressOutcomeKind.compressed,
            beforeMessages: 42,
            afterMessages: 9,
            beforeTokens: 120000,
            afterTokens: 30000,
            fallbackUsed: true,
          ),
        ),
        'Conversation compressed · 42 → 9 messages',
      );
      expect(
        transcriptLineForCompress(
          l10n,
          const CompressOutcome(CompressOutcomeKind.failed),
        ),
        isNull,
      );
    });
  });
}

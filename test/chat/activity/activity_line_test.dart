import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line_model.dart';
import 'package:hermes_app/src/chat/activity/widgets/mac_toolbar_subtitle.dart';
import 'package:hermes_app/src/chat/activity/widgets/working_indicator.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  bool still = false,
  double width = 390,
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildHermesLightTheme(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: still,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

ActivityLineModel _model({
  String sentence = 'Recalled 5 memories',
  bool counters = true,
  bool busy = true,
}) => ActivityLineModel(
  sentence: sentence,
  busy: busy,
  counters: counters
      ? const [
          ActivityLineCounter(
            kind: ActivityCounterKind.plan,
            text: '2/5',
            compactText: '2/5',
            label: 'plan 2 of 5',
          ),
          ActivityLineCounter(
            kind: ActivityCounterKind.processes,
            text: '1 running',
            compactText: '1',
            label: '1 process running',
          ),
        ]
      : const [],
);

Size _lineSize(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('activity-line')));

void main() {
  testWidgets('is one button named after the sentence and the counters', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await _pump(tester, ActivityLine(model: _model(), onOpen: () => opened++));

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Hermes is working')),
    );
    expect(
      node.label,
      'Hermes is working: Recalled 5 memories, plan 2 of 5, 1 process '
      'running. Opens activity.',
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isLiveRegion, isFalse);
    await tester.tap(find.byType(ActivityLine));
    expect(opened, 1);
    handle.dispose();
  });

  testWidgets('the name leaves counters out when none is known', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ActivityLine(model: _model(counters: false), onOpen: () {}),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Hermes is working')))
          .label,
      'Hermes is working: Recalled 5 memories. Opens activity.',
    );
    handle.dispose();
  });

  testWidgets(
    'the name drops a closing ellipsis or full stop of the sentence',
    (tester) async {
      final handle = tester.ensureSemantics();
      for (final (sentence, spoken) in [
        ('Restoring the chat…', 'Restoring the chat'),
        ('Restoring the chat...', 'Restoring the chat'),
        ('Waiting for the build.', 'Waiting for the build'),
        ('Version 1.2', 'Version 1.2'),
      ]) {
        await _pump(
          tester,
          ActivityLine(
            model: _model(sentence: sentence, counters: false),
            onOpen: () {},
          ),
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(RegExp('^Hermes is working')))
              .label,
          'Hermes is working: $spoken. Opens activity.',
        );
        // The drawn sentence is untouched.
        expect(find.text(sentence), findsOneWidget);
      }
      handle.dispose();
    },
  );

  testWidgets('a line that is folding away takes no taps and is not spoken', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await _pump(tester, ActivityLine(model: _model(), onOpen: () => opened++));
    await _pump(tester, ActivityLine(model: null, onOpen: () => opened++));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const Key('activity-line')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Hermes is working')), findsNothing);
    await tester.tap(
      find.byKey(const Key('activity-line')),
      warnIfMissed: false,
    );
    expect(opened, 0);
    await tester.pump(const Duration(milliseconds: 300));
    handle.dispose();
  });

  group('counters make room for the sentence', () {
    // The test font is wide: this sentence needs more than the words of the
    // chips leave at 390 pt, and less than their numbers do.
    final long = _model(sentence: 'Checking it');

    testWidgets('keep their words while the sentence fits', (tester) async {
      await _pump(
        tester,
        ActivityLine(
          model: _model(sentence: 'Hi'),
          onOpen: () {},
        ),
      );
      expect(find.text('1 running'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('go compact, icon and number, when it does not', (
      tester,
    ) async {
      await _pump(tester, ActivityLine(model: long, onOpen: () {}));
      expect(find.text('1 running'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.byKey(const Key('activity-chip-processes')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fall back to the one that changed last', (tester) async {
      await _pump(tester, ActivityLine(model: long, onOpen: () {}), width: 250);
      expect(find.byKey(const Key('activity-chip-plan')), findsOneWidget);
      expect(find.byKey(const Key('activity-chip-processes')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keep the full meaning in the name', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, ActivityLine(model: long, onOpen: () {}));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Hermes is working')))
            .label,
        contains('plan 2 of 5, 1 process running'),
      );
      handle.dispose();
    });

    for (final width in [280.0, 320.0, 360.0]) {
      testWidgets('long German counters do not overflow at $width pt', (
        tester,
      ) async {
        await _pump(
          tester,
          ActivityLine(
            model: ActivityLineModel(
              sentence:
                  'Prüft die Quartalszahlen und schreibt die Zusammenfassung',
              counters: const [
                ActivityLineCounter(
                  kind: ActivityCounterKind.processes,
                  text: '12 laufen',
                  compactText: '12',
                  label: '12 Prozesse laufen',
                ),
                ActivityLineCounter(
                  kind: ActivityCounterKind.plan,
                  text: '12/15',
                  compactText: '12/15',
                  label: 'Plan 12 von 15',
                ),
              ],
            ),
            onOpen: () {},
          ),
          width: width,
          locale: const Locale('de'),
        );
        expect(tester.takeException(), isNull);
        final sentence = tester.getSize(
          find.byKey(const Key('activity-line-sentence')),
        );
        expect(sentence.width, greaterThan(100));
      });
    }
  });

  testWidgets('the sentence may use two lines from text scale 2', (
    tester,
  ) async {
    Text sentence() =>
        tester.widget<Text>(find.byKey(const Key('activity-line-sentence')));
    await _pump(
      tester,
      ActivityLine(model: _model(), onOpen: () {}),
      scale: 1.5,
    );
    expect(sentence().maxLines, 1);
    final oneLine = _lineSize(tester).height;
    await _pump(tester, ActivityLine(model: _model(), onOpen: () {}), scale: 2);
    expect(sentence().maxLines, 2);
    expect(_lineSize(tester).height, greaterThan(oneLine));
    final constant = _lineSize(tester).height;
    await _pump(
      tester,
      ActivityLine(
        model: _model(sentence: 'word ' * 30),
        onOpen: () {},
      ),
      scale: 2,
    );
    expect(_lineSize(tester).height, constant);
    expect(tester.takeException(), isNull);
  });

  testWidgets('is a 44 pt target on Apple and 48 dp on Material', (
    tester,
  ) async {
    for (final (platform, height) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.windows, 48.0),
    ]) {
      await _pump(
        tester,
        ActivityLine(model: _model(), onOpen: () {}),
        platform: platform,
      );
      await tester.pump(const Duration(seconds: 1)); // the theme animates
      // The hairline is part of the box, so the line is the height itself.
      expect(_lineSize(tester).height, height, reason: '$platform');
    }
  });

  testWidgets('keeps its height while the sentence and counters change', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await _pump(
        tester,
        ActivityLine(model: _model(counters: false), onOpen: () {}),
        scale: scale,
      );
      final bare = _lineSize(tester).height;
      await _pump(
        tester,
        ActivityLine(
          model: _model(sentence: 'A ' * 60),
          onOpen: () {},
        ),
        scale: scale,
      );
      expect(_lineSize(tester).height, bare, reason: 'scale $scale');
    }
  });

  testWidgets('has two rows from text scale 1.5, sentence over the chips', (
    tester,
  ) async {
    await _pump(tester, ActivityLine(model: _model(), onOpen: () {}));
    final oneRow = _lineSize(tester).height;
    final sentenceOne = tester.getTopLeft(
      find.byKey(const Key('activity-line-sentence')),
    );
    final chipOne = tester.getTopLeft(
      find.byKey(const Key('activity-chip-plan')),
    );
    expect(chipOne.dy, closeTo(sentenceOne.dy, 12));

    await _pump(
      tester,
      ActivityLine(model: _model(), onOpen: () {}),
      scale: 1.5,
    );
    expect(_lineSize(tester).height, greaterThan(oneRow));
    expect(
      tester.getTopLeft(find.byKey(const Key('activity-chip-plan'))).dy,
      greaterThan(
        tester
                .getBottomLeft(find.byKey(const Key('activity-line-sentence')))
                .dy -
            1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows both counters at the largest text size without overflow', (
    tester,
  ) async {
    await _pump(tester, ActivityLine(model: _model(), onOpen: () {}), scale: 3);
    expect(find.byKey(const Key('activity-chip-plan')), findsOneWidget);
    expect(find.byKey(const Key('activity-chip-processes')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('truncates a 90 character sentence at its end on one line', (
    tester,
  ) async {
    await _pump(
      tester,
      ActivityLine(
        model: _model(sentence: 'word ' * 18),
        onOpen: () {},
      ),
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('activity-line-sentence')),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folds in and out with a size transition', (tester) async {
    Future<void> show(ActivityLineModel? model) =>
        _pump(tester, ActivityLine(model: model, onOpen: () {}));

    await show(null);
    expect(find.byKey(const Key('activity-line')), findsNothing);

    await show(_model());
    await tester.pump(const Duration(milliseconds: 90));
    final halfway = tester.getSize(find.byType(ActivityLine)).height;
    await tester.pump(const Duration(milliseconds: 200));
    expect(halfway, lessThan(tester.getSize(find.byType(ActivityLine)).height));

    await show(null);
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byKey(const Key('activity-line')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('activity-line')), findsNothing);
  });

  testWidgets('has no size transition and a still indicator when asked to', (
    tester,
  ) async {
    await _pump(tester, ActivityLine(model: null, onOpen: () {}), still: true);
    await _pump(
      tester,
      ActivityLine(model: _model(), onOpen: () {}),
      still: true,
    );
    expect(find.byKey(const Key('activity-line')), findsOneWidget);
    expect(_lineSize(tester).height, 48);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNotNull,
    );

    await _pump(tester, ActivityLine(model: null, onOpen: () {}), still: true);
    expect(find.byKey(const Key('activity-line')), findsNothing);
  });

  testWidgets('the model builds sentences and counters from a summary', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        },
      ),
      locale: const Locale('de'),
    );
    final summary = WorkingSummary.compute(
      sentences: const [
        WorkingSentence(WorkingSentenceKind.processes, at: 1, count: 2),
      ],
      planOpen: true,
      counters: [
        WorkingCounter.plan(done: 2, total: 5, at: 2),
        WorkingCounter.references(done: 3, total: 5, at: 1),
      ],
    )!;
    final model = ActivityLineModel.fromSummary(l10n, summary);
    expect(model.sentence, '2 Prozesse laufen');
    expect(model.counters.map((c) => c.text), ['2/5', '3/5']);
    expect(model.counters.first.label, 'Plan 2 von 5');
    expect(model.counters.last.label, '3 von 5 Modellen haben geantwortet');
  });

  group('MacToolbarSubtitle', () {
    Widget subtitle({String? status, bool busy = false}) => MacToolbarSubtitle(
      profile: 'default',
      model: 'hermes-4',
      status: status,
      busy: busy,
    );

    testWidgets('idle shows profile and model only', (tester) async {
      await _pump(tester, subtitle(), platform: TargetPlatform.macOS);
      expect(find.text('default · hermes-4'), findsOneWidget);
      expect(find.byType(WorkingIndicator), findsNothing);
    });

    testWidgets('working appends the spinner and the status', (tester) async {
      await _pump(
        tester,
        subtitle(status: 'Running 2 processes', busy: true),
        platform: TargetPlatform.macOS,
      );
      expect(find.text('default · hermes-4 · '), findsOneWidget);
      expect(find.text('Running 2 processes'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('working-indicator'))),
        const Size(12, 12),
      );
    });

    testWidgets('the status is cut before profile and model', (tester) async {
      await _pump(
        tester,
        subtitle(status: 'Ship the weekly digest by Friday', busy: true),
        platform: TargetPlatform.macOS,
        width: 400,
      );
      final lead = tester.getSize(find.byKey(const Key('mac-subtitle-lead')));
      final status = tester.getSize(
        find.byKey(const Key('mac-subtitle-status')),
      );
      expect(status.width, lessThan(200));
      expect(lead.width + status.width, lessThanOrEqualTo(400));
      // The lead is as wide as its text: nothing of it was cut.
      await _pump(
        tester,
        subtitle(status: 'x', busy: true),
        platform: TargetPlatform.macOS,
        width: 400,
      );
      expect(
        tester.getSize(find.byKey(const Key('mac-subtitle-lead'))).width,
        lead.width,
      );
    });

    for (final width in [0.0, 10.0, 60.0, 110.0]) {
      testWidgets('does not overflow or dangle at $width px', (tester) async {
        await _pump(
          tester,
          subtitle(status: 'Ship the weekly digest', busy: true),
          platform: TargetPlatform.macOS,
          width: width,
        );
        expect(tester.takeException(), isNull);
        final statusShown = find
            .byKey(const Key('mac-subtitle-status'))
            .evaluate()
            .isNotEmpty;
        // A spinner or a trailing separator only appears with a status.
        expect(
          find.byKey(const Key('working-indicator')).evaluate().isNotEmpty,
          statusShown,
        );
        if (!statusShown) {
          final lead = find.byKey(const Key('mac-subtitle-lead'));
          if (lead.evaluate().isNotEmpty) {
            expect(tester.widget<Text>(lead).data, isNot(endsWith(' · ')));
          }
        }
      });
    }
  });
}

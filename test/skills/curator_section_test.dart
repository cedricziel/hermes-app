import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/skills/widgets/curator_section.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

final _now = DateTime.utc(2026, 11, 15, 12);
final _ran = DateTime.utc(2026, 11, 12, 9, 12);

CuratorStatusView _status({
  bool? enabled,
  bool? paused = false,
  int? hours = 168,
  CuratorLastRunView lastRun = CuratorLastRunView.at,
}) => CuratorStatusView(
  enabled: enabled,
  paused: paused,
  intervalHours: hours,
  lastRun: lastRun,
  lastRunAt: lastRun == CuratorLastRunView.at ? _ran : null,
  staleAfterDays: 14,
  archiveAfterDays: 30,
);

CuratorSectionModel _model({
  CuratorStatusView? status,
  CuratorPauseView pause = CuratorPauseView.idle,
  CuratorRunView run = CuratorRunView.idle,
  List<String> lines = const [],
  bool blanked = false,
  bool? hasOutput,
}) => CuratorSectionModel(
  status: status ?? _status(),
  pause: pause,
  paused: status?.paused ?? false,
  run: run,
  outputLines: lines,
  hasOutput: hasOutput ?? lines.isNotEmpty,
  outputBlanked: blanked,
  now: _now,
);

class _Calls {
  var runs = 0;
  var checks = 0;
  CuratorSectionCallbacks get callbacks => CuratorSectionCallbacks(
    onTryAgain: () {},
    onPausedChanged: (_) {},
    onRunNow: () => runs++,
    onCheckStatus: () => checks++,
  );
}

Widget _host(
  CuratorSectionModel model,
  _Calls calls, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  bool open = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildHermesLightTheme(platform: platform),
  home: Scaffold(
    body: SingleChildScrollView(
      child: CuratorSection(
        model: model,
        callbacks: calls.callbacks,
        outputInitiallyOpen: open,
      ),
    ),
  ),
);

void main() {
  late _Calls calls;
  setUp(() => calls = _Calls());

  Future<void> pump(
    WidgetTester tester,
    CuratorSectionModel model, {
    TargetPlatform platform = TargetPlatform.iOS,
    bool open = false,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(model, calls, platform: platform, open: open),
    );
  }

  group('interval wording', () {
    for (final (hours, text) in [
      (1, 'Every hour'),
      (24, 'Every day'),
      (48, 'Every 2 days'),
      (168, 'Every 7 days'),
      (12, 'Every 12 hours'),
      (36, 'Every 36 hours'),
    ]) {
      testWidgets('$hours hours reads "$text"', (tester) async {
        await pump(tester, _model(status: _status(hours: hours)));
        expect(find.text(text), findsOneWidget);
      });
    }
  });

  testWidgets('shows the last pass relative, then the exact time on tap', (
    tester,
  ) async {
    await pump(tester, _model());
    expect(find.text('Last pass or first check'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.textContaining('Hermes also sets this time'), findsOneWidget);
    expect(find.textContaining('Nov 12, 2026'), findsNothing);
    await tester.tap(find.text('Last pass or first check'));
    await tester.pump();
    expect(find.textContaining('Nov 12, 2026,'), findsOneWidget);
    await tester.tap(find.text('Last pass or first check'));
    await tester.pump();
    expect(find.textContaining('Nov 12, 2026,'), findsNothing);
  });

  testWidgets('the last pass label carries both times', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _model());
    expect(
      find.bySemanticsLabel(
        RegExp(r'Last ran 3 days ago, .*November 12, 2026'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('never run says so and names the interval', (tester) async {
    await pump(
      tester,
      _model(status: _status(lastRun: CuratorLastRunView.never)),
    );
    expect(find.text("Hasn't run yet"), findsOneWidget);
    expect(
      find.text('The first scheduled pass waits one interval (7 days).'),
      findsOneWidget,
    );
  });

  testWidgets('unknown fields read Unknown and the pause switch is absent', (
    tester,
  ) async {
    await pump(tester, _model(status: const CuratorStatusView()));
    expect(find.text('Unknown'), findsNWidgets(4));
    expect(find.byType(Switch), findsNothing);
    expect(find.text("Couldn't read the pause setting."), findsOneWidget);
  });

  testWidgets('off in config has no pause or Run now row', (tester) async {
    await pump(tester, _model(status: _status(enabled: false)));
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Run now'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  group('targets', () {
    for (final (platform, min) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      testWidgets('rows and buttons are $min tall on $platform', (
        tester,
      ) async {
        await pump(
          tester,
          _model(run: CuratorRunView.elsewhere),
          platform: platform,
        );
        final row = find.ancestor(
          of: find.text('Run now'),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(row.first).height, greaterThanOrEqualTo(min));
        final button = find.ancestor(
          of: find.text('Check status'),
          matching: find.byType(OutlinedButton),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(min));
      });
    }
  });

  testWidgets('the pause switch is named, and says it is saving', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _model());
    expect(find.bySemanticsLabel('Pause scheduled passes'), findsOneWidget);
    await pump(tester, _model(pause: CuratorPauseView.saving));
    expect(
      find.bySemanticsLabel('Pause scheduled passes, Saving…'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    handle.dispose();
  });

  testWidgets('a running pass is named "Run now, running"', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _model(run: CuratorRunView.following));
    expect(find.bySemanticsLabel('Run now, running'), findsOneWidget);
    handle.dispose();
  });

  group('output', () {
    testWidgets('is not selectable and names its line count', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        _model(run: CuratorRunView.finished, lines: ['a', 'b', 'c']),
        open: true,
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('a\nb\nc'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Show output, 3 lines')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('blank mode holds one muted line and no output', (
      tester,
    ) async {
      await pump(
        tester,
        _model(run: CuratorRunView.finished, hasOutput: true, blanked: true),
        open: true,
      );
      expect(
        find.text('Hidden while the app is locked or away'),
        findsOneWidget,
      );
      expect(find.textContaining('curator:'), findsNothing);
    });

    testWidgets('no output says so instead of a tile', (tester) async {
      await pump(tester, _model(run: CuratorRunView.finished));
      expect(find.text('Hermes printed no output.'), findsOneWidget);
      expect(find.text('Show output'), findsNothing);
    });

    testWidgets('keeps the last 30 lines and counts the earlier ones', (
      tester,
    ) async {
      await pump(
        tester,
        _model(
          run: CuratorRunView.finished,
          lines: [for (var i = 1; i <= 35; i++) 'line $i'],
        ),
        open: true,
      );
      expect(find.textContaining('5 earlier lines not shown'), findsOneWidget);
      expect(find.textContaining('line 5\n'), findsNothing);
      expect(find.textContaining('line 6\n'), findsOneWidget);
    });
  });

  group('when Run now is enabled', () {
    const enabled = {
      CuratorRunView.idle,
      CuratorRunView.finished,
      CuratorRunView.failed,
      CuratorRunView.notStarted,
      CuratorRunView.checkedNothing,
    };
    for (final run in CuratorRunView.values) {
      testWidgets('${run.name}: ${enabled.contains(run)}', (tester) async {
        await pump(tester, _model(run: run));
        expect(
          CuratorSection.canRunNow(_model(run: run)),
          enabled.contains(run),
        );
        final ended =
            run == CuratorRunView.finished || run == CuratorRunView.failed;
        final working =
            run == CuratorRunView.starting || run == CuratorRunView.following;
        await tester.tap(
          find.text(
            working
                ? 'Running on the server…'
                : ended
                ? 'Run again'
                : 'Run now',
          ),
          warnIfMissed: false,
        );
        expect(calls.runs, enabled.contains(run) ? 1 : 0);
      });
    }

    testWidgets('a check in flight disables it', (tester) async {
      expect(
        CuratorSection.canRunNow(const CuratorSectionModel(checking: true)),
        isFalse,
      );
    });
  });

  testWidgets('no filled button, and Run now is never red', (tester) async {
    await pump(tester, _model(run: CuratorRunView.notStarted));
    expect(find.byType(FilledButton), findsNothing);
    final context = tester.element(find.byType(CuratorSection));
    final text = tester.widget<Text>(find.text('Run now'));
    expect(text.style!.color, context.hermesColors.link);
    expect(text.style!.color, isNot(Theme.of(context).colorScheme.error));
  });

  testWidgets('German builds without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        _model(run: CuratorRunView.elsewhere),
        calls,
        locale: const Locale('de'),
      ),
    );
    expect(find.text('Zeitplan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

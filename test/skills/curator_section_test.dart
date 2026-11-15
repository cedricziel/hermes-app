import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/skills/widgets/curator_section.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/output_lines_tile.dart';
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

// The controller's rules, which the widget must obey and not repeat.
const _canRun = {
  CuratorRunView.idle,
  CuratorRunView.finished,
  CuratorRunView.failed,
  CuratorRunView.notStarted,
  CuratorRunView.checkedNothing,
};
const _canCheck = {
  CuratorRunView.lostAnswer,
  CuratorRunView.progressLost,
  CuratorRunView.stillRunning,
  CuratorRunView.stopped,
  CuratorRunView.unconfirmed,
  CuratorRunView.elsewhere,
  CuratorRunView.unchecked,
};

CuratorSectionModel _model({
  CuratorStatusView? status,
  CuratorPauseView pause = CuratorPauseView.idle,
  CuratorRunView run = CuratorRunView.idle,
  List<String> lines = const [],
  bool blanked = false,
  bool? hasOutput,
  bool dropped = false,
  bool checkFailed = false,
  bool checking = false,
  String? pauseDetail,
  CuratorLoadView load = CuratorLoadView.loaded,
  CuratorNotStartedView? notStarted,
  String? failureLine,
  bool? paused,
}) => CuratorSectionModel(
  load: load,
  status: status ?? _status(),
  notStarted: notStarted,
  pauseDetail: pauseDetail,
  failureLine: failureLine,
  checkFailed: checkFailed,
  checking: checking,
  outputDropped: dropped,
  canRunNow: !checking && _canRun.contains(run),
  canCheck: !checking && _canCheck.contains(run),
  pause: pause,
  paused: paused ?? status?.paused ?? false,
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
  double scale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
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
    double scale = 1,
    Size size = const Size(800, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(model, calls, platform: platform, open: open, scale: scale),
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
    expect(find.textContaining('12 Nov 2026'), findsNothing);
    await tester.tap(find.text('Last pass or first check'));
    await tester.pump();
    expect(find.textContaining('12 Nov 2026, 09:12'), findsOneWidget);
    await tester.tap(find.text('Last pass or first check'));
    await tester.pump();
    expect(find.textContaining('12 Nov 2026, 09:12'), findsNothing);
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

  group('Run now follows the model', () {
    for (final run in CuratorRunView.values) {
      for (final can in [true, false]) {
        testWidgets('${run.name} with canRunNow $can', (tester) async {
          final model = CuratorSectionModel(
            status: _status(),
            run: run,
            canRunNow: can,
          );
          await pump(tester, model);
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
          expect(calls.runs, can && !working ? 1 : 0);
        });
      }
    }

    testWidgets('Check status follows canCheck', (tester) async {
      await pump(
        tester,
        const CuratorSectionModel(
          status: CuratorStatusView(enabled: true),
          run: CuratorRunView.lostAnswer,
          canCheck: false,
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Check status'),
      );
      expect(button.onPressed, isNull);
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

  group('wording', () {
    const lost =
        "We couldn't tell if it started. Nothing was sent again. "
        'It may be running on the server.';

    testWidgets('a lost start never says Can\'t reach Hermes', (tester) async {
      await pump(tester, _model(run: CuratorRunView.lostAnswer));
      expect(find.text(lost), findsOneWidget);
      expect(find.textContaining("Can't reach Hermes"), findsNothing);
      expect(find.text('Check status'), findsOneWidget);
    });

    testWidgets('a Check status without an answer adds its own line', (
      tester,
    ) async {
      await pump(
        tester,
        _model(run: CuratorRunView.lostAnswer, checkFailed: true),
      );
      expect(find.textContaining(lost), findsOneWidget);
      expect(find.textContaining("Couldn't confirm."), findsOneWidget);
    });

    testWidgets('the pause failures have their own words', (tester) async {
      for (final (pause, text) in [
        (CuratorPauseView.lost, "Couldn't confirm whether this changed."),
        (CuratorPauseView.failed, "Couldn't change it"),
        (CuratorPauseView.offline, "Can't reach Hermes"),
        (CuratorPauseView.profileGone, 'This profile no longer exists'),
      ]) {
        await pump(tester, _model(pause: pause));
        expect(find.text(text), findsOneWidget, reason: pause.name);
      }
    });

    testWidgets('finished and failed have their own headlines', (tester) async {
      await pump(tester, _model(run: CuratorRunView.finished));
      expect(find.text('The pass finished'), findsOneWidget);
      expect(find.textContaining('Failed'), findsNothing);
      await pump(
        tester,
        _model(run: CuratorRunView.failed, failureLine: 'curator: disabled'),
      );
      expect(find.text('Failed: curator: disabled'), findsOneWidget);
      expect(find.text('The pass finished'), findsNothing);
    });

    testWidgets('off in config says so in a line of its own', (tester) async {
      await pump(tester, _model(status: _status(enabled: false)));
      expect(
        find.text(
          "Turned off in the server's config. Change it there to use the curator.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('checked with nothing running names the last pass', (
      tester,
    ) async {
      await pump(tester, _model(run: CuratorRunView.checkedNothing));
      expect(
        find.text(
          'No pass is running now. Last pass or first check 3 days ago.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a started-at line has the date', (tester) async {
      await pump(
        tester,
        CuratorSectionModel(
          status: _status(),
          run: CuratorRunView.unconfirmed,
          startedAt: _ran,
        ),
      );
      expect(find.text('A pass started on 12 Nov 2026 at 09:12'), findsOne);
    });

    testWidgets('checking shows a visible state', (tester) async {
      await pump(
        tester,
        _model(run: CuratorRunView.lostAnswer, checking: true),
      );
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Check status'), findsNothing);
    });
  });

  group('load errors', () {
    testWidgets('a lost status read can be tried again', (tester) async {
      await pump(tester, _model(load: CuratorLoadView.lost));
      expect(find.text("Couldn't confirm the curator's state"), findsOne);
      await tester.tap(find.text('Try again'));
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('profile gone has no Try again', (tester) async {
      await pump(tester, _model(load: CuratorLoadView.profileGone));
      expect(find.text('This profile no longer exists'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('Try again is a standard-density button on a Mac', (
      tester,
    ) async {
      await pump(
        tester,
        _model(load: CuratorLoadView.failed),
        platform: TargetPlatform.macOS,
      );
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.style!.visualDensity, VisualDensity.standard);
    });

    testWidgets('profile gone as a not-started run has no Try again', (
      tester,
    ) async {
      await pump(
        tester,
        _model(
          run: CuratorRunView.notStarted,
          notStarted: CuratorNotStartedView.profileGone,
        ),
      );
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('output', () {
    testWidgets('real lines are not drawn or read while blanked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        _model(
          run: CuratorRunView.finished,
          lines: ['archived secret-skill'],
          blanked: true,
        ),
        open: true,
      );
      expect(find.textContaining('secret-skill'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('secret-skill')), findsNothing);
      expect(find.bySemanticsLabel('Show output'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('lines dropped by App Lock say so, not "no output"', (
      tester,
    ) async {
      await pump(tester, _model(run: CuratorRunView.finished, dropped: true));
      expect(find.text('Output cleared when the app locked.'), findsOneWidget);
      expect(find.text('Hermes printed no output.'), findsNothing);
    });

    testWidgets('a stopped pass keeps its lines as the earlier pass\'s', (
      tester,
    ) async {
      await pump(
        tester,
        _model(run: CuratorRunView.stopped, lines: ['a line']),
        open: true,
      );
      expect(find.text('Show output of the earlier pass'), findsOneWidget);
      expect(find.text('a line'), findsOneWidget);
    });
  });

  group('announcements', () {
    late List<String> said;
    setUp(() => said = []);

    Future<void> listen(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final data = (message as Map)['data'];
            if (data is Map) said.add(data['message'] as String);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
    }

    testWidgets('a pass is announced once at its start and once at its end', (
      tester,
    ) async {
      await listen(tester);
      await pump(tester, _model());
      expect(said, isEmpty);
      await pump(tester, _model(run: CuratorRunView.following));
      await pump(tester, _model(run: CuratorRunView.following));
      await pump(tester, _model(run: CuratorRunView.finished));
      await pump(tester, _model(run: CuratorRunView.finished));
      expect(said, ['Curator pass started', 'Curator pass finished']);
    });

    testWidgets('a failed pass says Failed', (tester) async {
      await listen(tester);
      await pump(tester, _model());
      await pump(tester, _model(run: CuratorRunView.following));
      await pump(tester, _model(run: CuratorRunView.failed));
      expect(said, ['Curator pass started', 'Failed']);
    });

    testWidgets('the switch announces Paused and Resumed', (tester) async {
      await listen(tester);
      await pump(tester, _model());
      await pump(tester, _model(pause: CuratorPauseView.saving, paused: true));
      await pump(tester, _model(status: _status(paused: true), paused: true));
      await pump(tester, _model(pause: CuratorPauseView.saving, paused: false));
      await pump(tester, _model());
      expect(said, ['Paused', 'Resumed']);
    });
  });

  group('at the largest text', () {
    testWidgets('the status row keeps its words whole at 3.1x', (tester) async {
      await pump(tester, _model(), scale: 3.1, size: const Size(700, 6000));
      for (final word in ['Status', 'Schedule']) {
        final font = tester.widget<Text>(find.text(word)).style!.fontSize!;
        // One line at 3.1x is about 1.2 of the scaled size.
        expect(
          tester.getSize(find.text(word)).height,
          lessThan(font * 3.1 * 1.6),
          reason: '$word broke',
        );
      }
      final title = tester.getTopLeft(find.text('Status')).dy;
      expect(tester.getTopLeft(find.text('Active')).dy, greaterThan(title));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the status icon grows with the text', (tester) async {
      Size icon() => tester.getSize(
        find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.checkCircle,
        ),
      );
      await pump(tester, _model());
      final small = icon();
      await pump(tester, _model(), scale: 2, size: const Size(390, 4000));
      expect(icon().width, greaterThan(small.width * 1.5));
    });

    testWidgets('the pause switch box keeps the platform target', (
      tester,
    ) async {
      await pump(tester, _model(), scale: 1.2);
      final box = find.ancestor(
        of: find.byType(Switch),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(box.first).height, greaterThanOrEqualTo(44));
    });
  });

  group('Run now states', () {
    testWidgets('a not-started Try again follows canRunNow', (tester) async {
      await pump(
        tester,
        CuratorSectionModel(
          status: _status(),
          run: CuratorRunView.notStarted,
          notStarted: CuratorNotStartedView.refused,
          canRunNow: false,
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Try again'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a check that found nothing keeps the earlier pass', (
      tester,
    ) async {
      await pump(
        tester,
        _model(run: CuratorRunView.checkedNothing, lines: ['a line']),
        open: true,
      );
      expect(find.text('Show output of the earlier pass'), findsOneWidget);
    });

    testWidgets('the earlier pass tile has no line count in its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _model(run: CuratorRunView.stopped, lines: ['a']));
      expect(
        find.bySemanticsLabel('Show output of the earlier pass'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('1 line')), findsNothing);
      handle.dispose();
    });

    testWidgets('the output box is capped to 40 percent of a small window', (
      tester,
    ) async {
      await pump(
        tester,
        _model(
          run: CuratorRunView.finished,
          lines: [for (var i = 0; i < 80; i++) 'archived skill-$i'],
        ),
        open: true,
        size: const Size(800, 500),
      );
      final box = find.descendant(
        of: find.byType(OutputLinesTile),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.getSize(box.first).height, lessThanOrEqualTo(200));
    });

    testWidgets('opening has a reason for the disabled row', (tester) async {
      await pump(tester, _model(run: CuratorRunView.opening));
      expect(find.text('Checking…'), findsOneWidget);
    });
  });

  group('details', () {
    testWidgets('the pause failure shows Hermes\' cleaned text', (
      tester,
    ) async {
      await pump(
        tester,
        _model(
          pause: CuratorPauseView.failed,
          pauseDetail: 'value is not allowed',
        ),
      );
      expect(
        find.text("Couldn't change it: value is not allowed"),
        findsOneWidget,
      );
    });

    testWidgets('dropped output says it was cleared', (tester) async {
      await pump(tester, _model(run: CuratorRunView.finished, dropped: true));
      expect(find.text('Output cleared when the app locked.'), findsOne);
      expect(find.textContaining('Hidden while'), findsNothing);
    });
  });

  group('start announcement', () {
    testWidgets('waits for following and never follows a lost start', (
      tester,
    ) async {
      final said = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final data = (message as Map)['data'];
            if (data is Map) said.add(data['message'] as String);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await pump(tester, _model());
      await pump(tester, _model(run: CuratorRunView.starting));
      await pump(tester, _model(run: CuratorRunView.lostAnswer));
      await pump(tester, _model(run: CuratorRunView.starting));
      await pump(
        tester,
        _model(
          run: CuratorRunView.notStarted,
          notStarted: CuratorNotStartedView.refused,
        ),
      );
      expect(said, isEmpty);
      await pump(tester, _model(run: CuratorRunView.starting));
      await pump(tester, _model(run: CuratorRunView.following));
      expect(said, ['Curator pass started']);
    });
  });
}

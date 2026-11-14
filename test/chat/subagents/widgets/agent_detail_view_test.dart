import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_detail_view.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_output_view.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

const _goal =
    'Audit the dependency tree for packages with known vulnerabilities';

AgentDetailModel _m({
  AgentState state = AgentState.running,
  AgentStopStatus stop = AgentStopStatus.idle,
  bool offline = false,
  AgentOutputModel? output = const AgentOutputModel(
    text: '12:04:31 tool     | -> read_file(path="go.sum")',
  ),
  bool note = true,
  String? delivered,
  String? error,
}) => AgentDetailModel(
  goal: _goal,
  state: state,
  runTime: const Duration(minutes: 2, seconds: 14),
  toolCount: 7,
  currentTool: 'read_file',
  output: output,
  note: note
      ? AgentNoteModel(
          goal: _goal,
          text: 'Skip vendored',
          length: 13,
          canSend: true,
          offline: offline,
        )
      : null,
  stop: stop,
  offline: offline,
  delivered: delivered,
  error: error,
);

Future<void> _pump(
  WidgetTester tester,
  AgentDetailModel model, {
  VoidCallback? onStop,
  VoidCallback? onClose,
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: AgentDetailView(
            model: model,
            onBack: () {},
            onStop: onStop,
            onSendNote: () {},
            onNoteChanged: (_) {},
            onCopyNote: () {},
            onJumpToLatest: () {},
            onClose: onClose,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

final _stop = find.widgetWithText(DestructiveTintButton, 'Stop agent');

void main() {
  testWidgets('shows the goal and facts', (tester) async {
    await _pump(tester, _m());
    expect(find.text(_goal), findsOneWidget);
    expect(find.textContaining('Running'), findsWidgets);
    expect(find.textContaining('7 tools'), findsOneWidget);
    expect(find.text('read_file'), findsOneWidget);
    expect(find.text('Recent output'), findsOneWidget);
  });

  group('ended states', () {
    for (final (state, text) in [
      (
        AgentState.finished,
        'This agent has finished. Stop and notes no longer apply.',
      ),
      (AgentState.failed, 'This agent failed. Stop and notes no longer apply.'),
      (AgentState.stopped, 'This agent was stopped.'),
      (AgentState.ended, 'This agent is no longer running.'),
    ]) {
      testWidgets('$state says its sentence and offers no Stop', (
        tester,
      ) async {
        await _pump(tester, _m(state: state), onStop: () {});
        expect(find.text(text), findsOneWidget);
        expect(_stop, findsNothing);
      });
    }
  });

  group('stop banners', () {
    for (final (stop, texts) in [
      (
        AgentStopStatus.stopping,
        ['Stopping…', 'A tool that is running may be cut off.'],
      ),
      (AgentStopStatus.checking, ['Couldn\'t confirm the stop.', 'Checking…']),
      (
        AgentStopStatus.unconfirmed,
        ['Couldn\'t confirm the stop.', 'It may still be running.'],
      ),
      (AgentStopStatus.alreadyFinished, ['This agent had already finished.']),
      (AgentStopStatus.ended, ['That agent has ended.']),
      (AgentStopStatus.failed, ['Couldn\'t stop the agent.', 'Try again.']),
      (AgentStopStatus.unsupported, ['This server can\'t stop agents.']),
    ]) {
      testWidgets('$stop', (tester) async {
        await _pump(tester, _m(stop: stop), onStop: () {});
        for (final t in texts) {
          expect(find.text(t), findsWidgets, reason: t);
        }
      });
    }

    testWidgets('offline banner', (tester) async {
      await _pump(tester, _m(offline: true), onStop: () {});
      expect(
        find.text(
          'You\'re offline. This is the last output read. Stop and notes '
          'work again once Hermes is back.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Stop agent', () {
    for (final stop in AgentStopStatus.values) {
      final shown = const {
        AgentStopStatus.idle,
        AgentStopStatus.sending,
        AgentStopStatus.checking,
        AgentStopStatus.unconfirmed,
        AgentStopStatus.failed,
      }.contains(stop);
      testWidgets('$stop while active: ${shown ? "shown" : "hidden"}', (
        tester,
      ) async {
        await _pump(tester, _m(stop: stop), onStop: () {});
        expect(
          find.byType(DestructiveTintButton),
          shown ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('is enabled and calls onStop when idle', (tester) async {
      var stops = 0;
      await _pump(tester, _m(), onStop: () => stops++);
      await tester.ensureVisible(_stop);
      await tester.tap(_stop);
      expect(stops, 1);
    });

    testWidgets('is disabled while checking', (tester) async {
      var stops = 0;
      await _pump(
        tester,
        _m(stop: AgentStopStatus.checking),
        onStop: () => stops++,
      );
      await tester.ensureVisible(_stop);
      await tester.tap(_stop, warnIfMissed: false);
      expect(stops, 0);
    });

    testWidgets('is disabled offline', (tester) async {
      var stops = 0;
      await _pump(tester, _m(offline: true), onStop: () => stops++);
      await tester.ensureVisible(_stop);
      await tester.tap(_stop, warnIfMissed: false);
      expect(stops, 0);
    });

    testWidgets('says Stopping… and does not call onStop while sending', (
      tester,
    ) async {
      var stops = 0;
      await _pump(
        tester,
        _m(stop: AgentStopStatus.sending),
        onStop: () => stops++,
      );
      final busy = find.widgetWithText(DestructiveTintButton, 'Stopping…');
      expect(busy, findsOneWidget);
      await tester.ensureVisible(busy);
      await tester.tap(busy, warnIfMissed: false);
      expect(stops, 0);
    });

    testWidgets('is a tinted button and Send is the only FilledButton', (
      tester,
    ) async {
      await _pump(tester, _m(), onStop: () {});
      expect(find.byType(DestructiveTintButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Send to agent'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('comes after the output and the note section', (tester) async {
      await _pump(tester, _m(), onStop: () {});
      final output = tester.getTopLeft(find.text('Recent output')).dy;
      final note = tester.getTopLeft(find.text('Redirect this agent')).dy;
      final stop = tester.getTopLeft(_stop).dy;
      expect(output, lessThan(note));
      expect(note, lessThan(stop));
    });

    testWidgets('has the footnote', (tester) async {
      await _pump(tester, _m(), onStop: () {});
      expect(find.text('Programs it started keep running.'), findsOneWidget);
    });
  });

  testWidgets('notControllable leaves a neutral banner only', (tester) async {
    await _pump(
      tester,
      _m(stop: AgentStopStatus.notControllable),
      onStop: () {},
    );
    expect(
      find.text(
        'Hermes doesn\'t let this device stop or redirect this agent. It '
        'keeps running.',
      ),
      findsOneWidget,
    );
    expect(find.text('Recent output'), findsNothing);
    expect(find.byType(AgentNoteField), findsNothing);
    expect(find.byType(DestructiveTintButton), findsNothing);
  });

  testWidgets('failed delegation shows the error and no output', (
    tester,
  ) async {
    await _pump(
      tester,
      _m(
        state: AgentState.failed,
        output: null,
        note: false,
        error: 'The advisory service timed out.',
      ),
    );
    expect(find.text('What went wrong'), findsOneWidget);
    expect(find.text('The advisory service timed out.'), findsOneWidget);
    expect(find.byType(AgentOutputView), findsNothing);
  });

  testWidgets('shows what it delivered', (tester) async {
    await _pump(
      tester,
      _m(state: AgentState.finished, delivered: 'Two advisories apply.'),
    );
    expect(find.text('What it delivered'), findsOneWidget);
    expect(find.text('Two advisories apply.'), findsOneWidget);
  });

  group('back control', () {
    testWidgets('iOS shows the word Activity', (tester) async {
      await _pump(tester, _m(), platform: TargetPlatform.iOS);
      expect(find.text('Activity'), findsOneWidget);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      testWidgets('$platform names a Back to Activity button', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _m(), platform: platform);
        expect(find.bySemanticsLabel('Back to Activity'), findsWidgets);
        expect(find.text('Activity'), findsNothing);
        handle.dispose();
      });
    }
  });

  testWidgets('Close appears only with onClose', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _m());
    expect(find.bySemanticsLabel('Close'), findsNothing);
    await _pump(tester, _m(), onClose: () {});
    expect(find.bySemanticsLabel('Close'), findsWidgets);
    handle.dispose();
  });

  testWidgets('the state word sits in a live region', (tester) async {
    await _pump(tester, _m());
    final live = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(live, findsOneWidget);
    expect(
      find.descendant(of: live, matching: find.textContaining('Running')),
      findsOneWidget,
    );
  });

  testWidgets('German smoke test', (tester) async {
    await _pump(
      tester,
      _m(),
      onStop: () {},
      platform: TargetPlatform.iOS,
      locale: const Locale('de'),
    );
    expect(find.text('Aktivität'), findsOneWidget);
    expect(find.textContaining('Diesen Agenten'), findsWidgets);
  });

  testWidgets('does not overflow at the largest text size', (tester) async {
    await _pump(
      tester,
      _m(stop: AgentStopStatus.unconfirmed, offline: false),
      onStop: () {},
      scale: 3,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (locale, word) in [
    (const Locale('en'), 'Running'),
    (const Locale('de'), 'Läuft'),
  ]) {
    testWidgets('the state word stays whole at 3x (${locale.languageCode})', (
      tester,
    ) async {
      await _pump(
        tester,
        _m(),
        locale: locale,
        scale: 3,
        size: const Size(320, 800),
      );
      expect(tester.takeException(), isNull);
      final state = find.text(word);
      expect(state, findsOneWidget);
      // One line: the word is not broken inside.
      final box = tester.getSize(state);
      final style = tester.widget<Text>(state).style;
      expect(box.height, lessThan(3 * 3 * (style?.fontSize ?? 16) * 1.6));
      // The time line sits below it and does not start with a dot.
      final time = find.textContaining('2m', skipOffstage: false);
      expect(time, findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').trimLeft().startsWith('·'),
        ),
        findsNothing,
      );
    });
  }

  group('SubagentGroupCard details', () {
    const agents = [
      Subagent(
        id: 'a1',
        goal: 'Audit the dependency tree',
        lastTool: 'read_file',
      ),
    ];

    Future<void> pumpCard(
      WidgetTester tester, {
      ValueChanged<String>? onShowDetails,
    }) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SubagentGroupCard(
            subagents: agents,
            initiallyOpen: true,
            onShowDetails: onShowDetails,
          ),
        ),
      ),
    );

    testWidgets('a tap on a row opens the details with its id', (tester) async {
      final handle = tester.ensureSemantics();
      final opened = <String>[];
      await pumpCard(tester, onShowDetails: opened.add);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      final node = tester.getSemantics(find.byType(InkWell).first);
      expect(node.hint, contains('Shows details in Activity'));
      expect(node.flagsCollection.isButton, isTrue);
      await tester.tap(find.text('Audit the dependency tree'));
      expect(opened, ['a1']);
      handle.dispose();
    });

    testWidgets('without it there is no button and no chevron', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester.getSemantics(find.text('Audit the dependency tree')).hint,
        isNot(contains('Shows details')),
      );
      expect(
        tester
            .getSemantics(find.text('Audit the dependency tree'))
            .flagsCollection
            .isButton,
        isFalse,
      );
      handle.dispose();
    });
  });

  testWidgets('the bar keeps its normal text size at the largest text size, '
      'so its words never overlap', (tester) async {
    await _pump(
      tester,
      _m(),
      platform: TargetPlatform.iOS,
      scale: 3,
      size: const Size(390, 1600),
    );
    final back = tester.getRect(find.text('Activity'));
    final title = tester.getRect(find.text('Agent'));
    expect(back.overlaps(title), isFalse);
    expect(back.height, lessThan(30));
  });

  group('review fixes', () {
    testWidgets('an ended agent takes no note field', (tester) async {
      for (final state in [
        AgentState.finished,
        AgentState.failed,
        AgentState.stopped,
        AgentState.ended,
      ]) {
        await _pump(tester, _m(state: state));
        expect(
          find.text('Redirect this agent'),
          findsNothing,
          reason: '$state',
        );
        expect(find.text('Send to agent'), findsNothing, reason: '$state');
      }
    });

    testWidgets('typed text of an ended agent stays as Not sent', (
      tester,
    ) async {
      await _pump(
        tester,
        AgentDetailModel(
          goal: _goal,
          state: AgentState.finished,
          note: const AgentNoteModel(
            goal: _goal,
            text: 'Skip vendored',
            length: 13,
            frozen: true,
          ),
        ),
      );
      expect(find.text('Not sent'), findsOneWidget);
      expect(find.text('Send to agent'), findsNothing);
    });

    testWidgets('a missed note is said for an ended agent', (tester) async {
      await _pump(
        tester,
        const AgentDetailModel(
          goal: _goal,
          state: AgentState.finished,
          note: AgentNoteModel(
            goal: _goal,
            status: AgentNoteStatus.missed,
            frozen: true,
          ),
        ),
      );
      expect(find.text("Your note didn't reach the agent."), findsOneWidget);
      expect(find.text('Send to agent'), findsNothing);
    });

    testWidgets('offline on the detail alone disables Send and Stop', (
      tester,
    ) async {
      await _pump(
        tester,
        const AgentDetailModel(
          goal: _goal,
          state: AgentState.running,
          offline: true,
          note: AgentNoteModel(
            goal: _goal,
            text: 'x',
            length: 1,
            canSend: true,
          ),
        ),
        onStop: () {},
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DestructiveTintButton>(find.byType(DestructiveTintButton))
            .onPressed,
        isNull,
      );
    });

    testWidgets('only the state word is a live region, not the run time', (
      tester,
    ) async {
      await _pump(tester, _m());
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(
        find.descendant(of: live, matching: find.text('Running')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: live, matching: find.textContaining('2m')),
        findsNothing,
      );
    });
  });
}

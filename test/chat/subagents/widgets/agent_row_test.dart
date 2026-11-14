import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_row.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_state_glyph.dart';

Widget _app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(platform: platform),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: home!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

const _goal = 'Audit the dependency tree';

AgentRowModel _model(
  AgentState state, {
  Duration? runTime = const Duration(minutes: 1, seconds: 12),
  int tools = 4,
  String? tool = 'read_file',
  String? preview = 'go.sum',
}) => AgentRowModel(
  goal: _goal,
  state: state,
  runTime: runTime,
  toolCount: tools,
  currentTool: tool,
  currentPreview: preview,
);

Widget _row(AgentRowModel m, {bool details = true, bool stop = false}) =>
    AgentRow(
      model: m,
      onShowDetails: details ? () {} : null,
      onStop: stop ? () {} : null,
    );

void main() {
  const words = {
    AgentState.starting: 'Starting',
    AgentState.running: 'Running',
    AgentState.finished: 'Finished',
    AgentState.failed: 'Failed',
    AgentState.stopped: 'Stopped',
    AgentState.ended: 'Ended',
  };

  testWidgets('line two starts with the state word, with time and tools', (
    tester,
  ) async {
    for (final MapEntry(key: state, value: word) in words.entries) {
      await tester.pumpWidget(_app(_row(_model(state))));
      expect(find.text('$word · 1m 12s · 4 tools'), findsOneWidget);
    }
  });

  testWidgets('tools are left out while 0; no time shows only the word', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_row(_model(AgentState.finished, tools: 0))));
    expect(find.text('Finished · 1m 12s'), findsOneWidget);
    await tester.pumpWidget(
      _app(_row(_model(AgentState.starting, runTime: null, tools: 0))),
    );
    expect(find.text('Starting'), findsOneWidget);
  });

  testWidgets('the third line shows only while running', (tester) async {
    await tester.pumpWidget(_app(_row(_model(AgentState.running))));
    expect(find.text('read_file · go.sum'), findsOneWidget);
    await tester.pumpWidget(
      _app(_row(_model(AgentState.running, preview: null))),
    );
    expect(find.text('read_file'), findsOneWidget);
    for (final state in AgentState.values.where(
      (s) => s != AgentState.running,
    )) {
      await tester.pumpWidget(_app(_row(_model(state))));
      expect(find.textContaining('read_file'), findsNothing);
    }
  });

  testWidgets('every state has its own glyph shape', (tester) async {
    final seen = <Object>{};
    for (final state in AgentState.values) {
      await tester.pumpWidget(
        _app(AgentStateGlyph(state: state), platform: TargetPlatform.android),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final spinner = find.byType(CircularProgressIndicator);
      seen.add(
        icons.isNotEmpty ? icons.first.icon! : spinner.evaluate().isNotEmpty,
      );
    }
    expect(seen, hasLength(AgentState.values.length));
  });

  testWidgets('reduced motion shows a still dot, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_row(_model(AgentState.running))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(
      _app(_row(_model(AgentState.running)), reduceMotion: true),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('agent-glyph-running-still')), findsOne);
  });

  testWidgets('screen reader label order and custom actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_row(_model(AgentState.running), stop: true)));
    final node = tester.getSemantics(find.byType(AgentRow));
    expect(node.label, '$_goal, Running, 4 tools, 1m 12s');
    expect(node.hint, 'Shows details in Activity');
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    final labels = [
      for (final id in data.customSemanticsActionIds ?? <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, containsAll(['Show details', 'Stop agent']));
    handle.dispose();
  });

  testWidgets('no Stop action once the agent is over', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_row(_model(AgentState.finished), stop: true)),
    );
    final data = tester.getSemantics(find.byType(AgentRow)).getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds ?? <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, ['Show details']);
    handle.dispose();
  });

  testWidgets('no tap handler means no button and no chevron', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_row(_model(AgentState.running), details: false)),
    );
    final data = tester.getSemantics(find.byType(AgentRow)).getSemanticsData();
    expect(data.flagsCollection.isButton, isFalse);
    handle.dispose();
  });

  testWidgets('tapping the row shows details', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        AgentRow(
          model: _model(AgentState.finished),
          onShowDetails: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text(_goal));
    expect(taps, 1);
  });

  testWidgets('tap target sizes per platform', (tester) async {
    final model = _model(AgentState.finished, runTime: null, tools: 0);
    for (final (platform, min) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      await tester.pumpWidget(_app(_row(model), platform: platform));
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(min),
        reason: '$platform',
      );
    }
  });

  testWidgets('indent grows 16 per level and stops at 2', (tester) async {
    Future<double> left(int level) async {
      await tester.pumpWidget(
        _app(
          _row(
            AgentRowModel(goal: _goal, state: AgentState.ended, level: level),
          ),
        ),
      );
      return tester.getTopLeft(find.byType(AgentStateGlyph)).dx;
    }

    final base = await left(0);
    expect(await left(1), base + 16);
    expect(await left(2), base + 32);
    expect(await left(3), base + 32);
  });

  testWidgets('stacks at the largest text size and clamps nothing', (
    tester,
  ) async {
    final long = 'Audit ' * 40;
    await tester.pumpWidget(
      _app(
        _row(
          AgentRowModel(
            goal: long,
            state: AgentState.running,
            runTime: const Duration(seconds: 5),
            currentTool: 'read_file',
            currentPreview: 'go.sum',
          ),
        ),
        textScale: 3,
      ),
    );
    final glyph = tester.getRect(find.byType(AgentStateGlyph));
    final goal = tester.getRect(find.textContaining('Audit'));
    expect(goal.top, greaterThanOrEqualTo(glyph.bottom));
    expect(tester.widget<Text>(find.textContaining('Audit')).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('German state word', (tester) async {
    await tester.pumpWidget(
      _app(_row(_model(AgentState.running)), locale: const Locale('de')),
    );
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(find.textContaining(de.chatSubagentsStateRunning), findsOneWidget);
    expect(de.chatSubagentsStateRunning, isNot('Running'));
  });
}

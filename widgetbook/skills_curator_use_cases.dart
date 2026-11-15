import 'package:flutter/material.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';
import 'package:hermes_app/src/skills/widgets/curator_section.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// The skill curator section in every state of the design brief
// (docs/design-briefs/skills-curator.md). The model is plain, so each case
// is one value; the callbacks only resolve.

final _now = DateTime.utc(2026, 11, 15, 12);
final _ranAt = DateTime.utc(2026, 11, 12, 9, 12);

CuratorStatusView _status({
  bool? enabled,
  bool? paused = false,
  int? hours = 168,
  CuratorLastRunView lastRun = CuratorLastRunView.at,
  int? stale = 14,
  int? archive = 30,
}) => CuratorStatusView(
  enabled: enabled,
  paused: paused,
  intervalHours: hours,
  lastRun: lastRun,
  lastRunAt: lastRun == CuratorLastRunView.at ? _ranAt : null,
  staleAfterDays: stale,
  archiveAfterDays: archive,
);

// The controller's rules for when Run now and Check status are offered.
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
  CuratorLoadView load = CuratorLoadView.loaded,
  CuratorStatusView? status,
  bool refreshing = false,
  CuratorPauseView pause = CuratorPauseView.idle,
  bool? paused,
  CuratorRunView run = CuratorRunView.idle,
  CuratorNotStartedView? notStarted,
  String? notStartedDetail,
  String? pauseDetail,
  String? failureLine,
  bool checking = false,
  bool checkFailed = false,
  List<String> lines = const [],
  int earlier = 0,
  bool? hasOutput,
  bool blanked = false,
  bool dropped = false,
}) {
  final shown = status ?? _status();
  return CuratorSectionModel(
    load: load,
    status: shown,
    refreshing: refreshing,
    pause: pause,
    paused: paused ?? shown.paused,
    run: run,
    notStarted: notStarted,
    notStartedDetail: notStartedDetail,
    pauseDetail: pauseDetail,
    failureLine: failureLine,
    checking: checking,
    checkFailed: checkFailed,
    startedAt: run == CuratorRunView.unconfirmed ? _ranAt : null,
    outputLines: lines,
    earlierLines: earlier,
    hasOutput: hasOutput ?? lines.isNotEmpty,
    outputBlanked: blanked,
    outputDropped: dropped,
    canRunNow: !checking && _canRun.contains(run),
    canCheck: !checking && _canCheck.contains(run),
    now: _now,
  );
}

Future<void> _later() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

final _callbacks = CuratorSectionCallbacks(
  onTryAgain: _later,
  onPausedChanged: (_) {},
  onRunNow: _later,
  onCheckStatus: _later,
);

Widget _section(CuratorSectionModel model, {bool open = false}) =>
    CuratorSection(
      model: model,
      callbacks: _callbacks,
      outputInitiallyOpen: open,
    );

Widget _framed(CuratorSectionModel model, {bool open = false}) =>
    frame(_section(model, open: open), maxWidth: 560);

/// The largest iOS text size.
Widget _huge(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(3.1)),
    child: child,
  ),
);

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

Widget _calm(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

final _output = [
  'curator: running review pass...',
  'auto: checked=42 stale=3 archived=2 reactivated=0',
  'curator: auto: stale=3 archived=2 | no changes; llm: skipped',
];

/// The section on a stateful host: the switch and Run now answer.
class _Live extends StatefulWidget {
  const _Live();

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  var _paused = false;
  var _view = _model();

  CuratorSectionModel _of({
    CuratorPauseView pause = CuratorPauseView.idle,
    CuratorRunView run = CuratorRunView.idle,
    List<String> lines = const [],
  }) => _model(
    status: _status(paused: _paused),
    pause: pause,
    run: run,
    lines: lines,
  );

  Future<void> _pause(bool value) async {
    final old = _paused;
    setState(() {
      _paused = value;
      _view = _model(
        status: _status(paused: old),
        pause: CuratorPauseView.saving,
        paused: value,
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _view = _of());
  }

  Future<void> _run() async {
    setState(() => _view = _of(run: CuratorRunView.following));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _view = _of(run: CuratorRunView.finished, lines: _output));
    }
  }

  @override
  Widget build(BuildContext context) => frame(
    CuratorSection(
      model: _view,
      callbacks: CuratorSectionCallbacks(
        onTryAgain: _later,
        onPausedChanged: _pause,
        onRunNow: _run,
        onCheckStatus: _later,
      ),
    ),
    maxWidth: 560,
  );
}

/// One use case per platform where the brief asks for a Mac and an Android
/// variant, and one for the rest.
List<WidgetbookUseCase> _states(
  String name,
  CuratorSectionModel model, {
  bool open = false,
  bool platforms = false,
  bool largest = false,
}) => [
  if (platforms)
    ...onEachPlatform(name, (_) => _calm(_framed(model, open: open)))
  else
    WidgetbookUseCase(
      name: name,
      builder: (_) => _calm(_framed(model, open: open)),
    ),
  if (largest)
    WidgetbookUseCase(
      name: '$name, largest text',
      builder: (_) => _largest(_calm(_framed(model, open: open))),
    ),
];

/// The Skills screen's states around the section, built from the real
/// chrome, list and message widgets. The screen itself wires the section in
/// a later change; this fixes where it sits.
Widget _placed({
  required CuratorSectionModel model,
  bool hub = true,
  _Body body = _Body.list,
}) {
  final section = _section(model);
  final groups = [
    const SkillGroup('github', [
      HermesSkill(
        name: 'pr-review',
        description: 'Review a pull request',
        category: 'github',
        source: SkillSource.agent,
      ),
    ]),
  ];
  final Widget content = switch (body) {
    _Body.list => InstalledSkillsList(
      groups: groups,
      onOpen: (_) {},
      onToggle: (_, _) {},
      onClearFilters: () {},
      header: section,
    ),
    _Body.loading => GroupedListView(
      children: [
        section,
        const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ],
    ),
    _Body.empty => GroupedListView(
      children: [
        section,
        const SizedBox(
          height: 200,
          child: StateMessage(title: 'This profile has no skills yet.'),
        ),
      ],
    ),
    _Body.failed => GroupedListView(
      children: [
        section,
        SizedBox(
          height: 200,
          child: StateMessage(
            title: 'Could not load skills',
            action: FilledButton(onPressed: () {}, child: const Text('Retry')),
          ),
        ),
      ],
    ),
    _Body.unsupported => const StateMessage(
      title: 'The connected Hermes does not support skills.',
    ),
  };
  return _Screen(hub: hub, body: content);
}

/// The real chrome of the Skills screen, with its tabs when there is a hub.
class _Screen extends StatefulWidget {
  const _Screen({required this.hub, required this.body});

  final bool hub;
  final Widget body;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Skills',
    subtitle: 'default',
    tabs: widget.hub ? const ['Installed', 'Discover'] : null,
    tabController: _tabs,
    body: widget.body,
  );
}

enum _Body { list, loading, empty, failed, unsupported }

WidgetbookNode skillsCuratorNode() => WidgetbookFolder(
  name: 'Skill curator',
  children: [
    WidgetbookComponent(
      name: 'CuratorSection',
      useCases: [
        WidgetbookUseCase(name: 'Interactive', builder: (_) => const _Live()),
        ..._states('Ran', _model(), platforms: true, largest: true),
        WidgetbookUseCase(
          name: 'Ran, 3.1x text',
          builder: (_) => _huge(_calm(_framed(_model()))),
        ),
        WidgetbookUseCase(
          name: 'Paused, 3.1x text',
          builder: (_) =>
              _huge(_calm(_framed(_model(status: _status(paused: true))))),
        ),
        ..._states(
          'Never run',
          _model(status: _status(lastRun: CuratorLastRunView.never)),
        ),
        ..._states('Paused', _model(status: _status(paused: true))),
        ..._states(
          'Off in config',
          _model(status: _status(enabled: false, paused: null)),
        ),
        ..._states(
          'Unknown fields',
          _model(
            status: const CuratorStatusView(
              lastRun: CuratorLastRunView.unknown,
            ),
          ),
          largest: true,
        ),
        ..._states('Interval in days', _model(status: _status(hours: 48))),
        ..._states('Interval in hours', _model(status: _status(hours: 36))),
        WidgetbookUseCase(
          name: 'Loading',
          builder: (_) => _calm(
            frame(
              _section(
                const CuratorSectionModel(load: CuratorLoadView.loading),
              ),
              maxWidth: 560,
            ),
          ),
        ),
        ..._states('Refreshing', _model(refreshing: true)),
        for (final (name, load) in [
          ('Offline', CuratorLoadView.offline),
          ('Curator could not load', CuratorLoadView.unavailable),
          ('Other failure', CuratorLoadView.failed),
          ('Profile gone', CuratorLoadView.profileGone),
          ('Status read lost', CuratorLoadView.lost),
        ])
          ..._states(name, _model(load: load), largest: name == 'Offline'),
      ],
    ),
    WidgetbookComponent(
      name: 'Pause switch',
      useCases: [
        ..._states('Idle, on', _model(status: _status(paused: true))),
        ..._states(
          'Saving',
          _model(pause: CuratorPauseView.saving, paused: true),
          largest: true,
        ),
        ..._states(
          'Failed with Hermes\' text',
          _model(
            pause: CuratorPauseView.failed,
            pauseDetail: 'the value is not allowed',
          ),
        ),
        ..._states('Failed', _model(pause: CuratorPauseView.failed)),
        ..._states('Offline', _model(pause: CuratorPauseView.offline)),
        ..._states('Lost answer', _model(pause: CuratorPauseView.lost)),
        ..._states('Profile gone', _model(pause: CuratorPauseView.profileGone)),
        ..._states(
          'Pause setting unknown',
          _model(status: _status(paused: null)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Run now row',
      useCases: [
        ..._states('Idle', _model()),
        ..._states('Opening', _model(run: CuratorRunView.opening)),
        ..._states(
          'Running',
          _model(run: CuratorRunView.following),
          platforms: true,
          largest: true,
        ),
        ..._states(
          'Finished with output',
          _model(run: CuratorRunView.finished, lines: _output),
          open: true,
          platforms: true,
          largest: true,
        ),
        ..._states(
          'Finished, output hidden',
          _model(run: CuratorRunView.finished, hasOutput: true, blanked: true),
          open: true,
        ),
        ..._states(
          'Finished with no output',
          _model(run: CuratorRunView.finished),
        ),
        ..._states(
          'Finished, 40 lines',
          _model(
            run: CuratorRunView.finished,
            lines: [for (var i = 1; i <= 30; i++) 'archived skill-$i'],
            earlier: 12,
          ),
          open: true,
        ),
        ..._states(
          'Failed',
          _model(
            run: CuratorRunView.failed,
            failureLine:
                'curator: disabled via config; enable with '
                '`curator.enabled: true`',
            lines: ['curator: running review pass...'],
          ),
          platforms: true,
          largest: true,
        ),
        ..._states(
          'Stopped, no exit code',
          _model(run: CuratorRunView.stopped),
        ),
        ..._states(
          'Stopped, earlier lines',
          _model(run: CuratorRunView.stopped, lines: _output),
          open: true,
          largest: true,
        ),
        ..._states(
          'Checked, earlier lines',
          _model(run: CuratorRunView.checkedNothing, lines: _output),
          open: true,
        ),
        ..._states(
          'Output dropped by App Lock',
          _model(run: CuratorRunView.finished, dropped: true),
        ),
        ..._states('Unconfirmed', _model(run: CuratorRunView.unconfirmed)),
        ..._states(
          'Not started, profile gone',
          _model(
            run: CuratorRunView.notStarted,
            notStarted: CuratorNotStartedView.profileGone,
          ),
        ),
        ..._states(
          'Not started, refused as unnamed',
          _model(
            run: CuratorRunView.notStarted,
            notStarted: CuratorNotStartedView.refused,
          ),
        ),
        ..._states(
          'Not started, spawn failure',
          _model(
            run: CuratorRunView.notStarted,
            notStarted: CuratorNotStartedView.spawnFailed,
            notStartedDetail: 'Failed to run curator: no such file',
          ),
          largest: true,
        ),
        ..._states(
          'Not started, offline',
          _model(
            run: CuratorRunView.notStarted,
            notStarted: CuratorNotStartedView.offline,
          ),
        ),
        ..._states('Lost answer', _model(run: CuratorRunView.lostAnswer)),
        ..._states('Progress lost', _model(run: CuratorRunView.progressLost)),
        ..._states('Still running', _model(run: CuratorRunView.stillRunning)),
        ..._states(
          'A pass is running on the server',
          _model(run: CuratorRunView.elsewhere),
          platforms: true,
          largest: true,
        ),
        ..._states('Could not check', _model(run: CuratorRunView.unchecked)),
        ..._states(
          'Check status without an answer',
          _model(run: CuratorRunView.lostAnswer, checkFailed: true),
        ),
        ..._states(
          'Checking',
          _model(run: CuratorRunView.lostAnswer, checking: true),
        ),
        ..._states(
          'Checked, nothing running',
          _model(run: CuratorRunView.checkedNothing),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Skills screen states',
      useCases: [
        for (final (name, body) in [
          ('Installed list', _Body.list),
          ('Loading skills', _Body.loading),
          ('No skills', _Body.empty),
          ('Skills failed to load', _Body.failed),
          ('Unsupported, section hidden', _Body.unsupported),
        ])
          ...onEachPlatform(
            name,
            (_) => _calm(_placed(model: _model(), body: body)),
          ),
        WidgetbookUseCase(
          name: 'No hub, no tabs',
          builder: (_) => _placed(model: _model(), hub: false),
        ),
      ],
    ),
  ],
);

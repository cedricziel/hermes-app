import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line_model.dart';
import 'package:hermes_app/src/chat/activity/widgets/mac_toolbar_subtitle.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/windows/widgets/conversation_window_toolbar.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _goal = 'Ship the weekly digest by Friday';
const _longSentence =
    'Checking the quarterly numbers against last year and drafting the '
    'summary for the Lisbon team';

/// The sentence of each Working source, as the server or the app words it.
WorkingSentence _sentence(WorkingSentenceKind kind, {String? text, int? n}) =>
    WorkingSentence(kind, at: 1, text: text, count: n);

final _sources = <(String, WorkingSummary)>[
  (
    'Recalled 5 memories',
    WorkingSummary(
      sentence: _sentence(
        WorkingSentenceKind.status,
        text: 'Recalled 5 memories',
      ),
    ),
  ),
  (
    'Waiting for background process',
    WorkingSummary(
      sentence: _sentence(
        WorkingSentenceKind.status,
        text: 'Waiting for background process',
      ),
    ),
  ),
  (
    'Running 2 processes',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.processes, n: 2)),
  ),
  (
    'Asking 3 models',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.askingModels, n: 3)),
  ),
  (
    'Combining answers',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.combiningAnswers)),
  ),
  (
    'Restoring the chat',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.restoring)),
  ),
  (
    'Goal',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.goal, text: _goal)),
  ),
  (
    'Working on the plan',
    WorkingSummary(sentence: _sentence(WorkingSentenceKind.plan)),
  ),
];

WorkingSummary _with(WorkingSummary base, List<WorkingCounter> counters) =>
    WorkingSummary.compute(
      sentences: [base.sentence],
      planOpen: true,
      counters: counters,
    )!;

final _plan = WorkingCounter.plan(done: 2, total: 5, at: 3);
final _processes = WorkingCounter.processes(running: 1, at: 2);
final _references = WorkingCounter.references(done: 3, total: 5, at: 1);

ActivityLineModel _model(BuildContext context, WorkingSummary summary) =>
    ActivityLineModel.fromSummary(context.l10n, summary);

Widget _line(BuildContext context, WorkingSummary summary) =>
    ActivityLine(model: _model(context, summary), onOpen: () {});

Widget _column(List<(String, Widget)> lines) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final (label, line) in lines) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Builder(
          builder: (context) =>
              Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
      line,
    ],
  ],
);

/// A column the width of [width], at the top left, in a scroll view.
Widget _at(double width, Widget child) => SingleChildScrollView(
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _still(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// A short, a medium and a long sentence, each with the same two counters, to
/// show the chips giving way: words, then icon and number, then one chip.
Widget _roomSteps(BuildContext context, {bool german = false}) {
  WorkingSummary goal(String text) =>
      WorkingSummary(sentence: _sentence(WorkingSentenceKind.goal, text: text));
  final counters = [_processes, _plan];
  final (short, medium, long) = german
      ? (
          'Notizen sortieren',
          'Zahlen prüfen',
          'Prüft die Quartalszahlen und schreibt die Zusammenfassung für das Team',
        )
      : ('Recalled 5 memories', _goal, _longSentence);
  return _column([
    (
      'The sentence fits: counters keep their words',
      _line(context, _with(goal(short), counters)),
    ),
    (
      'Tight: icon and number only',
      _line(context, _with(goal(medium), counters)),
    ),
    (
      'Still tight: only the chip that changed last',
      _line(context, _with(goal(long), counters)),
    ),
  ]);
}

/// A toggle that shows and hides the line, to see it fold in and out.
class _Appearing extends StatefulWidget {
  const _Appearing();

  @override
  State<_Appearing> createState() => _AppearingState();
}

class _AppearingState extends State<_Appearing> {
  bool _on = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ActivityLine(
        model: _on ? _model(context, _sources[0].$2) : null,
        onOpen: () {},
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () => setState(() => _on = !_on),
          child: Text(_on ? 'Settle the turn' : 'Start working'),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('The transcript starts here.'),
      ),
    ],
  );
}

WidgetbookNode activityLineNode() => WidgetbookComponent(
  name: 'ActivityLine',
  useCases: [
    ...onEachPlatform(
      'Every source',
      (_) => _at(
        390,
        Builder(
          builder: (context) => _column([
            for (final (name, summary) in _sources)
              (name, _line(context, summary)),
          ]),
        ),
      ),
    ).where((use) => !use.name.contains('Mac')),
    ...onEachPlatform(
      'With counters',
      (_) => _at(
        390,
        Builder(
          builder: (context) {
            final recall = _sources[0].$2;
            return _column([
              (
                'Plan and processes',
                _line(context, _with(recall, [_plan, _processes])),
              ),
              (
                'Models answered and plan',
                _line(context, _with(_sources[0].$2, [_references, _plan])),
              ),
              (
                'Three known, the two newest shown',
                _line(context, _with(recall, [_plan, _processes, _references])),
              ),
              ('Plan only', _line(context, _with(_sources[7].$2, [_plan]))),
              ('Goal and plan', _line(context, _with(_sources[6].$2, [_plan]))),
            ]);
          },
        ),
      ),
    ).where((use) => !use.name.contains('Mac')),
    ...onEachPlatform(
      'Sentence before counters',
      (_) => _at(390, Builder(builder: (context) => _roomSteps(context))),
    ).where((use) => !use.name.contains('Mac')),
    ...onEachPlatform(
      'German, 320 pt',
      (_) => _at(
        320,
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('de'),
            child: Builder(
              builder: (context) => _roomSteps(context, german: true),
            ),
          ),
        ),
      ),
    ).where((use) => !use.name.contains('Mac')),
    ...onEachPlatform(
      'Long sentence',
      (_) => _at(
        390,
        Builder(
          builder: (context) {
            final long = WorkingSummary(
              sentence: _sentence(
                WorkingSentenceKind.goal,
                text: _longSentence,
              ),
            );
            return _column([
              ('90 characters, no counters', _line(context, long)),
              (
                '90 characters, two counters',
                _line(context, _with(long, [_plan, _processes])),
              ),
            ]);
          },
        ),
      ),
    ).where((use) => !use.name.contains('Mac')),
    for (final (name, width) in [('iPad', 820.0), ('Desktop Material', 1100.0)])
      WidgetbookUseCase(
        name: 'Wide, $name',
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            platform: width == 820
                ? TargetPlatform.iOS
                : TargetPlatform.windows,
          ),
          child: Builder(
            builder: (context) => _at(
              width,
              _column([
                (
                  'Recall with two counters',
                  _line(context, _with(_sources[0].$2, [_plan, _processes])),
                ),
                ('Goal', _line(context, _sources[6].$2)),
              ]),
            ),
          ),
        ),
      ),
    for (final (name, scale) in [('2x', 2.0), ('3x', 3.0)])
      ...onEachPlatform(
        'Largest text $name',
        (_) => _at(
          390,
          _scaled(
            scale,
            Builder(
              builder: (context) => _column([
                (
                  'Two counters',
                  _line(context, _with(_sources[0].$2, [_plan, _processes])),
                ),
                ('No counters', _line(context, _sources[1].$2)),
                (
                  'Long sentence',
                  _line(
                    context,
                    WorkingSummary(
                      sentence: _sentence(
                        WorkingSentenceKind.goal,
                        text: _longSentence,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ).where((use) => !use.name.contains('Mac')),
    WidgetbookUseCase(
      name: 'Text 1.5x, two rows',
      builder: (_) => _at(
        390,
        _scaled(
          1.5,
          Builder(
            builder: (context) => _column([
              (
                'Two counters',
                _line(context, _with(_sources[0].$2, [_plan, _processes])),
              ),
              ('No counters', _line(context, _sources[2].$2)),
            ]),
          ),
        ),
      ),
    ),
    for (final (name, scale) in [('', 1.0), (', text 2x', 2.0)])
      WidgetbookUseCase(
        name: 'Reduced motion$name',
        builder: (_) => _at(
          390,
          _still(
            _scaled(
              scale,
              Builder(
                builder: (context) => _column([
                  (
                    'Static indicator, no size transition',
                    _line(context, _with(_sources[0].$2, [_references, _plan])),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    WidgetbookUseCase(
      name: 'Appears and disappears',
      builder: (_) => _at(390, const _Appearing()),
    ),
  ],
);

/// "profile · model" with a Working sentence behind it, at [width].
Widget _subtitle(
  double width, {
  String? status,
  bool busy = false,
  String profile = 'default',
}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: frame(
      SizedBox(
        width: width,
        child: MacToolbarSubtitle(
          profile: profile,
          model: 'hermes-4',
          status: status,
          busy: busy,
        ),
      ),
      maxWidth: width,
    ),
  ),
);

Widget _macToolbar(double windowWidth, {String? status}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(size: Size(windowWidth, 760)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: windowWidth - 280,
          child: MacChatToolbar(
            title: 'Weekly digest',
            subtitle: 'default · hermes-4',
            subtitleBuilder: (_, plain) => status == null
                ? plain
                : MacToolbarSubtitle(
                    profile: 'default',
                    model: 'hermes-4',
                    status: status,
                    busy: true,
                  ),
            onNewChat: () {},
            onShowConnection: () {},
            onCopyTranscript: () {},
            searchQuery: '',
            searchActive: false,
            onSearchBegin: () {},
            onSearchChanged: (_) {},
            onSearchEnd: () {},
          ),
        ),
      ),
    ),
  ),
);

Widget _windowToolbar(double width, {String? status}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: ConversationWindowToolbar(
          title: 'Weekly digest',
          subtitle: 'default · hermes-4',
          subtitleBuilder: (_, plain) => status == null
              ? plain
              : MacToolbarSubtitle(
                  profile: 'default',
                  model: 'hermes-4',
                  status: status,
                  busy: true,
                ),
          pinned: false,
          onShowInMain: () {},
          onTogglePin: () {},
          onShare: (_) {},
          onAction: (_) {},
        ),
      ),
    ),
  ),
);

WidgetbookNode macToolbarSubtitleNode() => WidgetbookComponent(
  name: 'MacToolbarSubtitle',
  useCases: [
    WidgetbookUseCase(name: 'Idle', builder: (_) => _subtitle(360)),
    WidgetbookUseCase(
      name: 'Working',
      builder: (_) => _subtitle(360, status: 'Recalled 5 memories', busy: true),
    ),
    WidgetbookUseCase(
      name: 'Long goal, narrow',
      builder: (_) => _subtitle(240, status: _goal, busy: true),
    ),
    for (final width in [0.0, 10.0])
      WidgetbookUseCase(
        name: 'No room, ${width.toInt()} px',
        builder: (_) => _subtitle(width, status: _goal, busy: true),
      ),
    WidgetbookUseCase(
      name: 'Too narrow for profile and model',
      builder: (_) => _subtitle(110, status: _goal, busy: true),
    ),
    WidgetbookUseCase(
      name: 'In MacChatToolbar, working',
      builder: (_) => _macToolbar(1160, status: 'Running 2 processes'),
    ),
    WidgetbookUseCase(
      name: 'In MacChatToolbar, long goal in a compact window',
      builder: (_) => _macToolbar(680, status: _longSentence),
    ),
    WidgetbookUseCase(
      name: 'In MacChatToolbar, idle',
      builder: (_) => _macToolbar(900),
    ),
    WidgetbookUseCase(
      name: 'In conversation window, working',
      builder: (_) => _windowToolbar(760, status: 'Asking 3 models'),
    ),
    WidgetbookUseCase(
      name: 'In conversation window, long goal',
      builder: (_) => _windowToolbar(560, status: _longSentence),
    ),
  ],
);

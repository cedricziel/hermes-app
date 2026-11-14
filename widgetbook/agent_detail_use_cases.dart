import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_detail_view.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_output_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _goal =
    'Audit the dependency tree for packages with known vulnerabilities';
const _typed = 'Skip the vendored packages and check only the direct ones.';
const _output = '''
12:04:31 tool     | -> read_file(path="go.sum")
12:04:31 tool     | <- read_file ok (412 lines)
12:04:33 agent    | Checking 38 direct dependencies against the advisory list.
12:04:36 tool     | -> web_search(query="golang.org/x/net advisory")
12:04:39 tool     | <- web_search ok (6 results)
12:04:41 agent    | Two packages have advisories; reading the fixed versions.''';

const _ready = AgentOutputModel(text: _output);

/// Whether a use case shows once or on each platform.
enum _Where { once, platforms }

WidgetbookNode agentDetailNode() => WidgetbookComponent(
  name: 'Agent detail',
  useCases: [
    ..._case(
      'Running, truncated output',
      output: const AgentOutputModel(text: _output, truncated: true),
    ),
    ..._case(
      'Reading output',
      output: const AgentOutputModel(status: AgentOutputStatus.loading),
    ),
    ..._case(
      'No output yet',
      output: const AgentOutputModel(status: AgentOutputStatus.none),
    ),
    ..._case(
      'Paused',
      output: const AgentOutputModel(text: _output, paused: true),
    ),
    ..._case(
      'Refresh failed',
      output: const AgentOutputModel(text: _output, refreshFailed: true),
    ),
    ..._case(
      'Output never available',
      output: const AgentOutputModel(status: AgentOutputStatus.never),
    ),
    ..._case(
      'Finished',
      state: AgentState.finished,
      output: const AgentOutputModel(text: _output, last: true),
      delivered:
          'Two direct dependencies have advisories: golang.org/x/net '
          '(fixed in 0.23.0) and gopkg.in/yaml.v3 (fixed in 3.0.1).',
    ),
    ..._case(
      'Failed delegation',
      state: AgentState.failed,
      output: null,
      hasNote: false,
      error: 'The advisory service did not answer: connection timed out.',
    ),
    ..._case(
      'Stopped',
      state: AgentState.stopped,
      output: const AgentOutputModel(text: _output, last: true),
    ),
    ..._case(
      'Ended (unknown)',
      state: AgentState.ended,
      output: const AgentOutputModel(status: AgentOutputStatus.none),
    ),
    ..._case(
      'Older server, no tail and no stop',
      output: null,
      hasNote: false,
      stop: AgentStopStatus.unsupported,
    ),
    ..._case(
      'Offline',
      output: _ready,
      offline: true,
      text: _typed,
      canSend: false,
    ),
    ..._case('Stop in flight', output: _ready, stop: AgentStopStatus.sending),
    ..._case(
      'Stop accepted, typed note frozen',
      output: _ready,
      stop: AgentStopStatus.stopping,
      text: _typed,
      frozen: true,
    ),
    ..._case(
      'Had already finished',
      state: AgentState.finished,
      output: const AgentOutputModel(text: _output, last: true),
      stop: AgentStopStatus.alreadyFinished,
    ),
    ..._case(
      'Stop unconfirmed, checking',
      output: _ready,
      stop: AgentStopStatus.checking,
    ),
    ..._case(
      'Stop still unconfirmed',
      output: _ready,
      stop: AgentStopStatus.unconfirmed,
    ),
    ..._case(
      'Offline with a stop unconfirmed',
      output: _ready,
      stop: AgentStopStatus.unconfirmed,
      offline: true,
    ),
    ..._case(
      'Agent ended while confirming',
      state: AgentState.ended,
      output: const AgentOutputModel(text: _output, last: true),
      stop: AgentStopStatus.ended,
    ),
    ..._case('Stop failed', output: _ready, stop: AgentStopStatus.failed),
    ..._case(
      'Cannot be controlled here',
      output: null,
      hasNote: false,
      stop: AgentStopStatus.notControllable,
    ),
    ..._case(
      'Server cannot stop',
      output: _ready,
      stop: AgentStopStatus.unsupported,
    ),
    ..._case(
      'Note queued with Your notes',
      output: _ready,
      noteStatus: AgentNoteStatus.queued,
      sent: const ['Use the lockfile as the source of truth.'],
    ),
    ..._case(
      'Note rejected',
      output: _ready,
      text: _typed,
      noteStatus: AgentNoteStatus.rejected,
    ),
    ..._case(
      'Note lost',
      output: _ready,
      text: _typed,
      noteStatus: AgentNoteStatus.lost,
    ),
    ..._case(
      'Note failed',
      output: _ready,
      text: _typed,
      noteStatus: AgentNoteStatus.failed,
    ),
    ..._case(
      'Note over limit',
      output: _ready,
      text: 'x' * 4100,
      length: 4100,
      canSend: false,
    ),
    ..._case(
      'Note missed',
      state: AgentState.finished,
      output: const AgentOutputModel(text: _output, last: true),
      text: _typed,
      noteStatus: AgentNoteStatus.missed,
      frozen: true,
    ),
    ..._case(
      'Notes unsupported',
      output: _ready,
      noteStatus: AgentNoteStatus.unsupported,
    ),
    ..._case(
      'Phone sheet',
      output: _ready,
      text: _typed,
      close: true,
      where: _Where.platforms,
    ),
    ..._case(
      'Inspector',
      output: _ready,
      text: _typed,
      width: 340,
      outputMaxHeight: 230,
    ),
    ..._case(
      'Mac',
      output: _ready,
      text: _typed,
      width: 340,
      outputMaxHeight: 230,
      platform: TargetPlatform.macOS,
      where: _Where.once,
    ),
    ..._case(
      'Long goal',
      goal: List.filled(8, _goal).join('. '),
      output: _ready,
    ),
    ..._case('Largest text size', output: _ready, text: _typed, scale: 3),
  ],
);

List<WidgetbookUseCase> _case(
  String name, {
  AgentState state = AgentState.running,
  required AgentOutputModel? output,
  String goal = _goal,
  AgentStopStatus stop = AgentStopStatus.idle,
  bool offline = false,
  bool hasNote = true,
  String? delivered,
  String? error,
  String text = '',
  int? length,
  bool canSend = true,
  bool frozen = false,
  AgentNoteStatus noteStatus = AgentNoteStatus.idle,
  List<String> sent = const [],
  double width = 390,
  double? outputMaxHeight,
  double scale = 1,
  bool close = false,
  TargetPlatform? platform,
  _Where where = _Where.platforms,
}) {
  Widget build(BuildContext context) => _Detail(
    width: width,
    scale: scale,
    close: close,
    outputMaxHeight: outputMaxHeight,
    initialText: text,
    model: (typed) {
      final count = length ?? typed.trim().length;
      return AgentDetailModel(
        goal: goal,
        state: state,
        runTime: const Duration(minutes: 2, seconds: 14),
        toolCount: 7,
        currentTool: state.active ? 'read_file' : null,
        startedByAgent: false,
        output: output,
        note: hasNote
            ? AgentNoteModel(
                goal: goal,
                text: typed,
                length: count,
                status: noteStatus,
                frozen: frozen,
                canSend: canSend && count > 0 && count <= 4000,
                sentNotes: sent,
                offline: offline,
              )
            : null,
        stop: stop,
        offline: offline,
        delivered: delivered,
        error: error,
      );
    },
  );

  if (platform != null) {
    return [
      WidgetbookUseCase(
        name: name,
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(platform: platform),
          child: Builder(builder: build),
        ),
      ),
    ];
  }
  return where == _Where.once
      ? [WidgetbookUseCase(name: name, builder: build)]
      : onEachPlatform(name, build);
}

/// Holds the note text so typing works in the catalog.
class _Detail extends StatefulWidget {
  const _Detail({
    required this.model,
    required this.initialText,
    required this.width,
    required this.scale,
    required this.close,
    required this.outputMaxHeight,
  });

  final AgentDetailModel Function(String typed) model;
  final String initialText;
  final double width;
  final double scale;
  final bool close;
  final double? outputMaxHeight;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  late var _text = widget.initialText;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(widget.scale)),
    child: fill(
      SizedBox(
        height: 760,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: AgentDetailView(
            model: widget.model(_text),
            onBack: () {},
            onStop: () {},
            onSendNote: () {},
            onNoteChanged: (value) => setState(() => _text = value),
            onCopyNote: () {},
            onJumpToLatest: () {},
            onClose: widget.close ? () {} : null,
            outputMaxHeight: widget.outputMaxHeight,
          ),
        ),
      ),
      width: widget.width,
    ),
  );
}

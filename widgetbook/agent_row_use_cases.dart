import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_row.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _goal =
    'Audit the dependency tree for packages with known vulnerabilities';

WidgetbookNode agentRowNode() => WidgetbookComponent(
  name: 'Agent row',
  useCases: [
    ...onEachPlatform(
      'Starting',
      (_) => _row(const AgentRowModel(goal: _goal, state: AgentState.starting)),
    ),
    ...onEachPlatform('Running', (_) => _row(_running)),
    WidgetbookUseCase(
      name: 'Running, reduced motion',
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: _row(_running),
      ),
    ),
    ...onEachPlatform('Finished', (_) => _row(_ended(AgentState.finished))),
    ...onEachPlatform('Failed', (_) => _row(_ended(AgentState.failed))),
    ...onEachPlatform('Stopped', (_) => _row(_ended(AgentState.stopped))),
    ...onEachPlatform(
      'Ended',
      (_) => _row(const AgentRowModel(goal: _goal, state: AgentState.ended)),
    ),
    ...onEachPlatform(
      'Long goal',
      (_) => _row(
        AgentRowModel(
          goal: List.filled(6, _goal).join('. '),
          state: AgentState.running,
          runTime: const Duration(minutes: 3, seconds: 5),
          toolCount: 12,
          currentTool: 'read_file',
          currentPreview:
              'packages/vulnerability_scanner/lib/src/advisories.dart',
        ),
      ),
    ),
    ...onEachPlatform(
      'No tools yet',
      (_) => _row(
        const AgentRowModel(
          goal: _goal,
          state: AgentState.running,
          runTime: Duration(seconds: 4),
        ),
      ),
    ),
    ...onEachPlatform(
      'Nested levels',
      (_) => frame(
        Column(
          children: [
            for (final level in [0, 1, 2, 2])
              AgentRow(
                model: AgentRowModel(
                  goal: 'Level ${level == 2 ? "2 (or deeper)" : level}: $_goal',
                  state: AgentState.running,
                  runTime: const Duration(seconds: 40),
                  toolCount: 2,
                  currentTool: 'read_file',
                  currentPreview: 'go.sum',
                  level: level,
                ),
                onShowDetails: () {},
                onStop: () {},
              ),
          ],
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Largest text size',
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3)),
        child: _row(_running),
      ),
    ),
    WidgetbookUseCase(
      name: 'Mac row with Stop',
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
        child: _row(_running, stop: true),
      ),
    ),
  ],
);

const _running = AgentRowModel(
  goal: _goal,
  state: AgentState.running,
  runTime: Duration(minutes: 1, seconds: 12),
  toolCount: 4,
  currentTool: 'read_file',
  currentPreview: 'go.sum',
);

AgentRowModel _ended(AgentState state) => AgentRowModel(
  goal: _goal,
  state: state,
  runTime: const Duration(minutes: 2, seconds: 30),
  toolCount: 7,
);

Widget _row(AgentRowModel model, {bool stop = true}) => frame(
  AgentRow(model: model, onShowDetails: () {}, onStop: stop ? () {} : null),
);

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

final _agents = [
  Subagent(
    id: 'agent-1',
    goal: 'Audit the dependency tree for packages with known vulnerabilities',
    count: 3,
    toolCount: 6,
    lastTool: 'read_file',
    lastToolPreview: 'go.sum',
    startedAt: DateTime.now().subtract(const Duration(minutes: 1, seconds: 20)),
  ),
  const Subagent(
    id: 'agent-2',
    goal: 'Summarize the open advisories for the release notes',
    index: 1,
    count: 3,
    status: SubagentStatus.completed,
    toolCount: 4,
    summary: 'Two advisories apply; both are fixed in the next patch release.',
    duration: Duration(seconds: 48),
  ),
  const Subagent(
    id: 'agent-3',
    goal: 'Check whether the vendored copy of yaml.v3 is affected',
    parentId: 'agent-1',
    depth: 1,
    toolCount: 2,
    lastTool: 'search_files',
    lastToolPreview: 'vendor/gopkg.in/yaml.v3',
    startedAt: null,
  ),
];

WidgetbookNode subagentCardNode() => WidgetbookComponent(
  name: 'Agent card with details',
  useCases: [
    ...onEachPlatform('With details', (_) => _card(onShowDetails: (_) {})),
    ...onEachPlatform('Read-only (quick panel)', (_) => _card()),
  ],
);

Widget _card({ValueChanged<String>? onShowDetails}) => frame(
  SubagentGroupCard(
    subagents: _agents,
    initiallyOpen: true,
    onShowDetails: onShowDetails,
  ),
  maxWidth: 420,
);

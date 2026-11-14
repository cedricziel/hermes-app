import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_output_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _lines = [
  '12:04:29 model    | Looking at the module graph before changing anything.',
  '12:04:31 tool     | -> read_file(path="go.sum")',
  '12:04:31 result   | 212 lines, 14 KB',
  '12:04:33 tool     | -> search(query="golang.org/x/net", glob="**/*.go")',
  '12:04:34 result   | 9 matches in 4 files',
  '12:04:36 model    | Two of them pin an old release. Checking the changelog.',
  '12:04:40 tool     | -> read_file(path="docs/upgrading.md")',
  '12:04:41 result   | 88 lines, 3 KB',
  '12:04:44 model    | The upgrade needs no code change; drafting the summary.',
];

final _text = _lines.join('\n');

const _wrapping =
    '12:04:44 model    | A very long sentence that goes on well past the width '
    'of a phone so that it has to wrap onto several lines, and every wrapped '
    'line should sit under the message column instead of under the time.\n'
    '12:04:45 tool     | -> read_file(path="a/very/long/path/to/a/file/that/'
    'has/many/segments/and/no/spaces/to/break/on.txt")\n'
    '12:04:46 result   | Links and markup stay plain: https://example.com/x '
    '**bold** [label](https://example.com)';

WidgetbookNode agentOutputNode() => WidgetbookComponent(
  name: 'Agent output',
  useCases: [
    ...onEachPlatform(
      'Streaming and truncated',
      (_) => _view(AgentOutputModel(text: _text, truncated: true)),
    ),
    ...onEachPlatform(
      'Reading output',
      (_) => _view(const AgentOutputModel(status: AgentOutputStatus.loading)),
    ),
    ...onEachPlatform(
      'No output yet',
      (_) => _view(const AgentOutputModel(status: AgentOutputStatus.none)),
    ),
    ...onEachPlatform(
      'Paused with a held selection',
      (_) => _view(AgentOutputModel(text: _text, paused: true)),
    ),
    ...onEachPlatform(
      'Refresh failed',
      (_) => _view(AgentOutputModel(text: _text, refreshFailed: true)),
    ),
    ...onEachPlatform(
      'Never available',
      (_) => _view(const AgentOutputModel(status: AgentOutputStatus.never)),
    ),
    ...onEachPlatform(
      'Last output (ended)',
      (_) => _view(AgentOutputModel(text: _text, last: true)),
    ),
    ...onEachPlatform(
      'Long wrapping lines',
      (_) => _view(const AgentOutputModel(text: _wrapping), width: 320),
    ),
    ...onEachPlatform(
      'Largest text size',
      (_) => _view(AgentOutputModel(text: _text), scale: 3, width: 390),
    ),
  ],
);

Widget _view(AgentOutputModel model, {double scale = 1, double width = 390}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: frame(
          AgentOutputView(model: model, onJumpToLatest: () {}),
          maxWidth: width,
        ),
      ),
    );

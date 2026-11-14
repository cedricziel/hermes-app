import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/subagents/widgets/confirm_stop_agent.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

const _goal =
    'Audit the dependency tree for packages with known vulnerabilities';

WidgetbookNode agentConfirmNode() => WidgetbookComponent(
  name: 'Stop agent confirmation',
  useCases: [
    ...onEachPlatform('Open', (_) => _open(_goal)),
    ...onEachPlatform(
      'Very long goal',
      (_) => _open(List.filled(10, _goal).join('. ')),
    ),
  ],
);

Widget _open(String goal) => openOnShow(
  (context) => confirmStopAgent(context, goal: goal),
  behind: Center(
    child: Builder(
      builder: (context) => FilledButton(
        onPressed: () => confirmStopAgent(context, goal: goal),
        child: const Text('Ask again'),
      ),
    ),
  ),
);

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/confirm_stop_program.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

WidgetbookNode processOutputNode() => WidgetbookComponent(
  name: 'Process output',
  useCases: [
    ...onEachPlatform(
      'Compact',
      (_) => _card(
        const ProcessOutput(processId: 'worker', text: 'Received output'),
      ),
    ),
    ...onEachPlatform(
      'Expanded',
      (_) => _card(
        const ProcessOutput(processId: 'worker', text: 'Line one\nLine two'),
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Closed before output',
      (_) => _card(
        const ProcessOutput(processId: 'worker', closed: true),
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Omitted output',
      (_) => _card(
        const ProcessOutput(
          processId: 'worker',
          text: 'Newest tail',
          omitted: true,
        ),
        expanded: true,
        omittedCards: true,
      ),
    ),
    ...onEachPlatform(
      'Long output',
      (_) => _card(
        ProcessOutput(
          processId: 'worker',
          text: List.filled(4000, 'Received output line').join('\n'),
          omitted: true,
        ),
        expanded: true,
      ),
    ),
    ...onEachPlatform('Unavailable', (_) => _card(null)),
    ...onEachPlatform(
      'Running, collapsed',
      (_) => _listed(_running(), text: 'PASS src/app.test.js'),
    ),
    ...onEachPlatform(
      'Running, expanded with Stop program',
      (_) => _listed(
        _running(),
        text: 'PASS src/app.test.js\nPASS src/api.test.js',
        expanded: true,
        onStop: () {},
      ),
    ),
    ...onEachPlatform(
      'Stopped (exit code -15)',
      (_) => _listed(
        const ProcessCardInfo(
          command: 'npm test',
          status: ProcessCardStatus.stopped,
          exitCode: -15,
          runTime: Duration(minutes: 2, seconds: 5),
        ),
        text: 'PASS src/app.test.js',
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Exited with code 1',
      (_) => _listed(
        const ProcessCardInfo(
          command: 'npm test',
          status: ProcessCardStatus.exited,
          exitCode: 1,
          runTime: Duration(seconds: 14),
        ),
        text: 'FAIL src/app.test.js',
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Exited with code 0',
      (_) => _listed(
        const ProcessCardInfo(
          command: 'npm test',
          status: ProcessCardStatus.exited,
          exitCode: 0,
          runTime: Duration(seconds: 14),
        ),
        text: 'PASS src/app.test.js',
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Ended, no code',
      (_) => _listed(
        const ProcessCardInfo(
          command: 'python -m http.server 8000',
          status: ProcessCardStatus.ended,
          runTime: Duration(minutes: 12),
        ),
        text: 'Serving HTTP on 0.0.0.0 port 8000',
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Closed without a list entry',
      (_) => _card(
        const ProcessOutput(processId: 'worker', closed: true),
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Output without a list entry',
      (_) => _card(
        const ProcessOutput(processId: 'worker', text: 'Received output'),
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'Long command',
      (_) => _listed(
        ProcessCardInfo(
          command: _longCommand,
          status: ProcessCardStatus.running,
          runTime: const Duration(seconds: 3),
        ),
        text: 'Building...',
      ),
    ),
    ...onEachPlatform(
      'Seeded, earlier output omitted',
      (_) => _listed(
        const ProcessCardInfo(
          command: 'npm test',
          status: ProcessCardStatus.running,
          runTime: Duration(minutes: 1),
          seeded: true,
        ),
        text: 'PASS src/api.test.js',
        expanded: true,
        onStop: () {},
      ),
    ),
    for (final stop in ProcessStopStatus.values)
      if (stop != ProcessStopStatus.idle)
        ...onEachPlatform(
          switch (stop) {
            ProcessStopStatus.sending => 'Stopping',
            ProcessStopStatus.checking => 'Stop: checking',
            ProcessStopStatus.killed => 'Stop: stopped',
            ProcessStopStatus.alreadyEnded => 'Stop: already ended',
            ProcessStopStatus.notListed => 'Stop: no longer listed',
            ProcessStopStatus.failed => 'Stop: failed',
            ProcessStopStatus.unconfirmed => 'Stop: unconfirmed',
            ProcessStopStatus.unsupported =>
              'Stop: server can\'t stop programs',
            ProcessStopStatus.idle => '',
          },
          (_) => _listed(
            _running(stop: stop),
            text: 'PASS src/app.test.js',
            expanded: true,
            onStop: () {},
          ),
        ),
    ...onEachPlatform(
      'Confirmation',
      (_) => openOnShow(
        (context) => confirmStopProgram(context, command: 'npm test'),
        behind: const SizedBox.expand(),
      ),
    ),
    ...onEachPlatform(
      'Confirmation, long command',
      (_) => openOnShow(
        (context) => confirmStopProgram(context, command: _longCommand),
        behind: const SizedBox.expand(),
      ),
    ),
  ],
);

final _longCommand = List.filled(10, 'python -m http.server 8000').join(' && ');

ProcessCardInfo _running({ProcessStopStatus stop = ProcessStopStatus.idle}) =>
    ProcessCardInfo(
      command: 'npm test',
      status: ProcessCardStatus.running,
      runTime: const Duration(minutes: 2, seconds: 5),
      stop: stop,
    );

Widget _listed(
  ProcessCardInfo info, {
  required String text,
  bool expanded = false,
  VoidCallback? onStop,
}) => frame(
  ProcessOutputCard(
    output: ProcessOutput(processId: 'worker', text: text),
    initiallyOpen: expanded,
    info: info,
    onStop: onStop,
  ),
);
Widget _card(
  ProcessOutput? output, {
  bool expanded = false,
  bool omittedCards = false,
}) => Scaffold(
  body: ProcessOutputCard(
    output: output,
    initiallyOpen: expanded,
    omittedCards: omittedCards,
  ),
);

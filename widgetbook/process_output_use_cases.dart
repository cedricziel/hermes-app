import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

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
  ],
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

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/widgets/connector_operation_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode connectorOperationNode() => WidgetbookComponent(
  name: 'Connector operations',
  useCases: [
    ...onEachPlatform('Compact', (_) => _card()),
    ...onEachPlatform('Expanded', (_) => _card(expanded: true)),
    ...onEachPlatform('No targets', (_) => _card(expanded: true, empty: true)),
    ...onEachPlatform(
      'Awaiting final status',
      (_) => _card(expanded: true, deadline: true),
    ),
    ...onEachPlatform(
      'Unavailable installation',
      (_) => _card(expanded: true, installation: true),
    ),
    ...onEachPlatform(
      'Refused response',
      (_) => _card(expanded: true, error: 'The server refused this response.'),
    ),
  ],
);

Widget _card({
  bool expanded = false,
  bool empty = false,
  bool deadline = false,
  bool installation = false,
  String? error,
}) => frame(
  ConnectorOperationCard(
    operation: ConnectorOperationSnapshot(
      owner: const ConnectorOwner.session('sample'),
      opId: 'sample',
      seq: 1,
      deadlineAt: DateTime.utc(2030),
      targets: empty
          ? []
          : [
              ConnectorOperationTarget(
                name: 'Calendar',
                kind: installation ? 'plugin' : 'connector',
                action: installation ? 'install' : 'authorize',
                state: 'initiated',
                instructions: 'Continue in the browser to approve access.',
                connectUrl: 'https://connect.invalid/verify',
              ),
            ],
    ),
    initiallyOpen: expanded,
    awaitingFinalStatus: deadline,
    error: error,
    canOpen: (_) => true,
    canSkip: (_) => true,
    onOpen: (_) {},
    onSkip: (_) {},
    onContinue: () {},
  ),
);

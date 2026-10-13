import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';
import 'package:hermes_app/src/chat/widgets/moa_progress_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode moaProgressNode() => WidgetbookComponent(
  name: 'Advisor progress',
  useCases: [
    ...onEachPlatform(
      'Reported counts',
      (_) => _card(
        const MoaProgress(turn: 'sample', phase: 'Advisors', done: 1, total: 3),
      ),
    ),
    ...onEachPlatform(
      'Aggregation',
      (_) => _card(
        const MoaProgress(
          turn: 'sample',
          phase: 'aggregator',
          aggregator: 'Reported model',
        ),
      ),
    ),
    ...onEachPlatform(
      'Expanded references',
      (_) => _card(
        const MoaProgress(
          turn: 'sample',
          live: false,
          references: [
            MoaReference(
              eventIdentity: 'first',
              label: 'Same advisor label',
              text: 'First received reference',
            ),
            MoaReference(
              eventIdentity: 'second',
              label: 'Same advisor label',
              text: 'Second received reference',
            ),
          ],
        ),
        expanded: true,
      ),
    ),
    ...onEachPlatform(
      'No references yet',
      (_) => _card(const MoaProgress(turn: 'sample'), expanded: true),
    ),
    ...onEachPlatform(
      'Unavailable details',
      (_) => _card(
        const MoaProgress(
          turn: 'sample',
          live: false,
          referencesAvailable: false,
        ),
        expanded: true,
      ),
    ),
  ],
);
Widget _card(MoaProgress progress, {bool expanded = false}) => Scaffold(
  body: MoaProgressCard(progress: progress, initiallyOpen: expanded),
);

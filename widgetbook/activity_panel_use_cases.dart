import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_panel.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/side_results/side_result_card.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/widgets/agent_notice_card.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/memory/memory_recall.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

TodoPlanState _plan() {
  final scope = TodoScope(
    connection: Object(),
    runtimeId: 'fixture',
    profile: null,
  );
  return TodoPlanState()
    ..adopt(scope)
    ..updated(scope, {
      'revision': 1,
      'todos': [
        {
          'id': 'a',
          'content': "Define the agent's role",
          'status': 'completed',
        },
        {
          'id': 'b',
          'content': 'List the agents it oversees',
          'status': 'completed',
        },
        {
          'id': 'c',
          'content': 'Draft the daily brief',
          'status': 'in_progress',
        },
        {'id': 'd', 'content': 'Schedule the brief', 'status': 'pending'},
      ],
    });
}

List<Widget> _now() => [
  SessionStatusCard(
    state: ChatSessionState()
      ..waits['process'] = 'Waiting for background process',
  ),
];

List<Widget> _session() => [
  MemoryActivityCard(
    recalls: [
      MemoryRecall(
        summary: 'robot-notes — recalled 5 memories',
        receivedAt: DateTime(2030, 1, 1, 9, 41),
      ),
    ],
  ),
  const SideResultCard(
    result: SideResult(
      kind: SideResultKind.btw,
      taskId: 'fixture',
      question: 'What does a chief of staff agent do?',
      text: 'It reads what other agents produce and brings you decisions.',
    ),
  ),
  const AgentNoticeCard(notice: AgentNotice(text: 'Capabilities refreshed.')),
];

/// [panel] at a phone sheet's or an inspector's size.
Widget _sized(Widget panel, {required bool phone}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: phone ? 390 : 380,
    height: phone ? 520 : 720,
    child: Material(child: panel),
  ),
);

WidgetbookNode activityPanelNode() => WidgetbookComponent(
  name: 'Activity panel',
  useCases: [
    for (final state in [
      'Recall',
      'Expanded recall',
      'Repeated recalls',
      'Review only',
      'Recall and review',
    ])
      WidgetbookUseCase(
        name: 'Memory, $state',
        builder: (_) => frame(
          MemoryActivityCard(
            recalls: state == 'Review only'
                ? const []
                : [
                    if (state == 'Repeated recalls')
                      MemoryRecall(
                        summary: 'robot-notes — recalled 5 memories',
                        receivedAt: DateTime(2030, 1, 1, 9, 40),
                      ),
                    MemoryRecall(
                      summary: 'robot-notes — recalled 5 memories',
                      receivedAt: DateTime(2030, 1, 1, 9, 41),
                    ),
                  ],
            reviewNotes: state == 'Review only' || state == 'Recall and review'
                ? const [
                    'Memory updated',
                    'Proposed memory changes await your approval. Review them with /memory pending.',
                  ]
                : const [],
            initiallyOpen: state != 'Recall',
          ),
        ),
      ),
    for (final phone in [true, false]) ...[
      ...onEachPlatform(
        'All sections, ${phone ? 'phone sheet' : 'inspector'}',
        (_) => _sized(
          ActivityPanel(
            now: _now(),
            plan: TodoPlanCard(state: _plan(), initiallyOpen: true),
            session: _session(),
            onClose: phone ? () {} : null,
          ),
          phone: phone,
        ),
      ),
      WidgetbookUseCase(
        name: 'Plan only, ${phone ? 'phone sheet' : 'inspector'}',
        builder: (_) => _sized(
          ActivityPanel(
            plan: TodoPlanCard(state: _plan(), initiallyOpen: true),
            onClose: phone ? () {} : null,
          ),
          phone: phone,
        ),
      ),
      WidgetbookUseCase(
        name: 'This session only, ${phone ? 'phone sheet' : 'inspector'}',
        builder: (_) => _sized(
          ActivityPanel(session: _session(), onClose: phone ? () {} : null),
          phone: phone,
        ),
      ),
      WidgetbookUseCase(
        name: 'Empty, ${phone ? 'phone sheet' : 'inspector'}',
        builder: (_) =>
            _sized(ActivityPanel(onClose: phone ? () {} : null), phone: phone),
      ),
    ],
  ],
);

WidgetbookNode activityButtonNode() => WidgetbookComponent(
  name: 'ActivityButton',
  useCases: [
    for (final open in [false, true])
      ...onEachPlatform(
        open ? 'Inspector open' : 'Closed',
        (_) => frame(ActivityButton(open: open, onPressed: () {})),
      ),
  ],
);

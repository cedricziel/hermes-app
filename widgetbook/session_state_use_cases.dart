import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode sessionStateNode() => WidgetbookComponent(
  name: 'Session status',
  useCases: [
    WidgetbookUseCase(
      name: 'Paused goal',
      builder: (_) => frame(
        SessionStatusCard(
          state: ChatSessionState()
            ..control = const SessionControlSnapshot(
              revision: 'opaque',
              goal: {
                'title': 'Review the change',
                'status': 'paused',
                'turns_used': 2,
                'max_turns': 5,
                'paused_reason': 'Waiting for review',
              },
            ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Loop and heartbeat expanded',
      builder: (_) => frame(
        SessionStatusCard(
          initiallyOpen: true,
          state: ChatSessionState()
            ..control = const SessionControlSnapshot(
              revision: 'opaque',
              loop: {
                'status': 'running',
                'ticks_fired': 4,
                'next_due_at': 1791849600,
              },
              heartbeat: {'status': 'running', 'fire_count': 3},
            ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Empty control',
      builder: (_) => frame(
        SessionStatusCard(
          state: ChatSessionState()
            ..control = const SessionControlSnapshot(revision: 'empty'),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unavailable control (draws nothing)',
      builder: (_) => frame(
        SessionStatusCard(
          state: ChatSessionState()..unavailable = true,
          initiallyOpen: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Reclaimed session',
      builder: (_) => frame(
        SessionStatusCard(
          state: ChatSessionState()
            ..reclaimedReason = 'Another client reopened this session.',
          initiallyOpen: true,
          onReopen: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Failed hydration',
      builder: (_) => frame(
        SessionStatusCard(
          state: ChatSessionState()
            ..resume = const ResumeProgress(
              'history',
              'failed',
              message: 'History remains available. Reopen to try restoring session activity again.',
            ),
          initiallyOpen: true,
          onReopen: () {},
        ),
      ),
    ),
  ],
);

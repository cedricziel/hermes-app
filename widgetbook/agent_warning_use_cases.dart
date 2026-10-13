import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/widgets/agent_notice_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode agentWarningNode() => WidgetbookComponent(
  name: 'Agent warnings',
  useCases: [
    WidgetbookUseCase(
      name: 'Credit warning',
      builder: (_) => frame(
        AgentNoticeCard(
          notice: const AgentNotice(
            text: 'Credits are running low. Review your account before continuing.',
            level: 'warn',
          ),
          onDismiss: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unknown level expanded',
      builder: (_) => frame(
        AgentNoticeCard(
          notice: const AgentNotice(
            text: 'Capabilities refreshed',
            level: 'future',
          ),
          initiallyOpen: true,
          onDismiss: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Startup notice',
      builder: (_) => frame(
        AgentNoticeCard(
          notice: const AgentNotice(
            text: 'Preparing your agent. This is taking longer than expected.',
          ),
          onDismiss: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Redacted tool output',
      builder: (_) => frame(
        const ToolCallCard(
          call: ToolCall(
            name: 'terminal',
            summary: 'Read configuration',
            outputRisk: ToolOutputRisk(
              risk: 'secret',
              findings: ['A credential was removed from the output.'],
              redacted: true,
            ),
          ),
          initiallyOpen: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Risk without findings',
      builder: (_) => frame(
        const ToolCallCard(
          call: ToolCall(
            name: 'web_fetch',
            summary: '',
            outputRisk: ToolOutputRisk(
              risk: 'injection',
              findings: [],
              redacted: false,
            ),
          ),
          initiallyOpen: true,
        ),
      ),
    ),
  ],
);

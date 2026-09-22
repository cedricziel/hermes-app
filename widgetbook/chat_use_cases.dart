import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/chat/widgets/unsupported_request_card.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:provider/provider.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Future<void> _answers(Object? _) =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _fails(Object? _) async => throw StateError('offline');

Future<void> _skips() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _skipFails() async => throw StateError('offline');

Widget _noStore(Widget child) =>
    Provider<MediaStore?>.value(value: null, child: child);

WidgetbookUseCase _tool(String name, Widget card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card));

WidgetbookNode chatNode() => WidgetbookFolder(
  name: 'Chat',
  children: [
    WidgetbookComponent(
      name: 'ToolCallCard',
      useCases: [
        _tool('Running', const ToolCallCard(call: runningToolCall)),
        _tool('Finished', const ToolCallCard(call: finishedToolCall)),
        _tool('Failed', const ToolCallCard(call: failedToolCall)),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolCallGroup',
      useCases: [
        _tool('Single call', const ToolCallGroup(calls: [runningToolCall])),
        _tool('Finished run', const ToolCallGroup(calls: finishedToolRun)),
        _tool('Running', const ToolCallGroup(calls: runningToolRun)),
        _tool('Failed', const ToolCallGroup(calls: failedToolRun)),
      ],
    ),
    WidgetbookComponent(
      name: 'ApprovalCard',
      useCases: [
        _tool(
          'Pending',
          ApprovalCard(request: pendingApproval, onAnswer: _answers),
        ),
        _tool(
          'Answer fails',
          ApprovalCard(request: pendingApproval, onAnswer: _fails),
        ),
        _tool('Answered', ApprovalCard(request: answeredApproval)),
        _tool('Expired', ApprovalCard(request: expiredApproval)),
      ],
    ),
    WidgetbookComponent(
      name: 'ClarifyCard',
      useCases: [
        _tool(
          'Choices',
          ClarifyCard(request: singleChoiceClarify, onAnswer: _answers),
        ),
        _tool(
          'Free text',
          ClarifyCard(request: openClarify, onAnswer: _answers),
        ),
        _tool(
          'Several questions',
          ClarifyCard(request: batchClarify, onAnswer: _answers),
        ),
        _tool('Answered', ClarifyCard(request: answeredClarify)),
      ],
    ),
    WidgetbookComponent(
      name: 'UnsupportedRequestCard',
      useCases: [
        _tool(
          'Secret',
          UnsupportedRequestCard(request: secretRequest, onSkip: _skips),
        ),
        _tool(
          'Sudo',
          UnsupportedRequestCard(request: sudoRequest, onSkip: _skips),
        ),
        _tool(
          'Skip fails',
          UnsupportedRequestCard(request: secretRequest, onSkip: _skipFails),
        ),
        _tool('Skipped', UnsupportedRequestCard(request: skippedSecretRequest)),
        _tool('Expired', UnsupportedRequestCard(request: expiredSecretRequest)),
      ],
    ),
    WidgetbookComponent(
      name: 'ReasoningBlock',
      useCases: [
        _tool('Folded', const ReasoningBlock(text: reasoningText)),
        _tool(
          'Still reasoning',
          const ReasoningBlock(text: reasoningText, active: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'WelcomeView',
      useCases: [
        WidgetbookUseCase(
          name: 'Greeting with name',
          builder: (_) => WelcomeView(greetingName: 'Ada', onPick: (_) {}),
        ),
        WidgetbookUseCase(
          name: 'No name',
          builder: (_) => WelcomeView(greetingName: null, onPick: (_) {}),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MessageActions',
      useCases: [
        _tool('Copy', const MessageActions(text: 'The build finished.')),
        _tool(
          'Copy and retry',
          MessageActions(text: 'The build finished.', onRetry: () {}),
        ),
        _tool(
          'Retry only (failed reply)',
          MessageActions(text: 'Timed out', showCopy: false, onRetry: () {}),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AttachmentCard',
      useCases: [
        _tool(
          'With size',
          _noStore(const AttachmentCard(attachment: pdfAttachment)),
        ),
        _tool(
          'Size unknown',
          _noStore(const AttachmentCard(attachment: relativeAttachment)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThinkingIndicator',
      useCases: [
        _tool(
          'Thinking',
          ThinkingIndicator(
            startedAt: DateTime.now().subtract(const Duration(seconds: 4)),
            activity: 'Thinking…',
          ),
        ),
        _tool(
          'Running a tool, over a minute in',
          ThinkingIndicator(
            startedAt: DateTime.now().subtract(
              const Duration(minutes: 1, seconds: 12),
            ),
            activity: 'Running git_show…',
          ),
        ),
      ],
    ),
  ],
);

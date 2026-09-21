import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Future<void> _answers(Object? _) =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _fails(Object? _) async => throw StateError('offline');

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
      name: 'ThinkingIndicator',
      useCases: [_tool('Default', const ThinkingIndicator())],
    ),
  ],
);

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/widgets/memory_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_tool_outcome.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _replace = {
  'action': 'patch',
  'target': 'memory',
  'old_text': 'Uses tabs for indentation in every project',
  'content': 'Uses two spaces for indentation in every project',
};

MemoryToolOutcome _saved({int? percent = 66}) => MemoryToolOutcome.parse(
  args: const {
    'action': 'add',
    'target': 'user',
    'content': 'Prefers short answers and metric units',
  },
  result: {
    'success': true,
    if (percent != null) 'usage': '$percent% — 912/1,375 chars',
  },
)!;

MemoryToolOutcome _staged() => MemoryToolOutcome.parse(
  args: _replace,
  result: const {'success': true, 'staged': true, 'pending_id': '1a2b3c4d'},
)!;

MemoryToolOutcome _full() => MemoryToolOutcome.parse(
  args: _replace,
  result: const {
    'success': false,
    'error': 'Memory at 2,100/2,200 chars; this entry does not fit.',
    'usage': '2,100/2,200',
  },
)!;

Widget _body(
  MemoryToolOutcome outcome, {
  MemoryDecisionState decision = MemoryDecisionState.idle,
  bool actions = true,
  double width = 480,
}) => frame(
  maxWidth: width,
  Container(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x33808080)),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: MemoryToolBody(
      outcome: outcome,
      decision: decision,
      onDecide: actions ? (_) {} : null,
    ),
  ),
);

WidgetbookNode memoryToolNode() => WidgetbookFolder(
  name: 'Memory tool call',
  children: [
    WidgetbookComponent(
      name: 'MemoryToolBody',
      useCases: [
        WidgetbookUseCase(name: 'Saved', builder: (_) => _body(_saved())),
        WidgetbookUseCase(
          name: 'Saved, no percentage',
          builder: (_) => _body(_saved(percent: null)),
        ),
        WidgetbookUseCase(
          name: 'Waiting for approval',
          builder: (_) => _body(_staged()),
        ),
        WidgetbookUseCase(
          name: 'Waiting, phone width',
          builder: (_) => _body(_staged(), width: 320),
        ),
        WidgetbookUseCase(
          name: 'Waiting, no actions',
          builder: (_) => _body(_staged(), actions: false),
        ),
        WidgetbookUseCase(
          name: 'Deciding',
          builder: (_) => _body(
            _staged(),
            decision: const MemoryDecisionState(MemoryDecisionPhase.running),
          ),
        ),
        WidgetbookUseCase(
          name: 'Approved',
          builder: (_) => _body(
            _staged(),
            decision: const MemoryDecisionState(MemoryDecisionPhase.saved),
          ),
        ),
        WidgetbookUseCase(
          name: 'Rejected',
          builder: (_) => _body(
            _staged(),
            decision: const MemoryDecisionState(MemoryDecisionPhase.rejected),
          ),
        ),
        WidgetbookUseCase(
          name: 'Failed, Hermes reason',
          builder: (_) => _body(
            _staged(),
            decision: const MemoryDecisionState(
              MemoryDecisionPhase.failed,
              'The entry changed since it was staged.',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Failed, unreachable',
          builder: (_) => _body(
            _staged(),
            decision: const MemoryDecisionState(
              MemoryDecisionPhase.failed,
              "Couldn't reach Hermes. Try again.",
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Memory is full',
          builder: (_) => _body(_full()),
        ),
        WidgetbookUseCase(
          name: 'Memory is full, phone width',
          builder: (_) => _body(_full(), width: 320),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolCallCard (memory)',
      useCases: [
        WidgetbookUseCase(
          name: 'Memory is full, warning status',
          builder: (_) => frame(
            const ToolCallCard(
              initiallyOpen: true,
              call: ToolCall(
                name: 'memory',
                summary: 'memory',
                status: ToolCallStatus.warning,
                args: _replace,
                resultData: {
                  'success': false,
                  'error':
                      'Memory at 2,100/2,200 chars; this entry does not fit.',
                  'usage': '2,100/2,200',
                },
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MemoryActivityCard (review link)',
      useCases: [
        WidgetbookUseCase(
          name: 'Review with Memory link',
          builder: (_) => frame(
            MemoryActivityCard(
              initiallyOpen: true,
              reviewNotes: const ['Memory updated'],
              onOpenMemory: () {},
            ),
          ),
        ),
      ],
    ),
  ],
);

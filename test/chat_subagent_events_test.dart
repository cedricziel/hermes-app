import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show CustomMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';

void main() {
  ChatMessage reply() => ChatMessage(
    id: 'm1',
    role: ChatRole.assistant,
    content: '',
    createdAt: DateTime.utc(2026, 10, 4, 12),
    status: MessageStatus.streaming,
  );

  void apply(ChatMessage r, ChatEvent e) => applyReplyEvent(r, e);

  test('spawn, tool and complete frames build one subagent', () {
    final r = reply();
    apply(
      r,
      const SubagentUpdated(
        Subagent(
          id: 'a1',
          goal: 'Fix the retry double-call',
          count: 2,
          model: 'glm-5.3',
        ),
      ),
    );
    apply(
      r,
      const SubagentUpdated(
        Subagent(
          id: 'a1',
          goal: '',
          lastTool: 'terminal',
          lastToolPreview: 'pytest tests/ingest -x',
        ),
      ),
    );
    apply(
      r,
      const SubagentUpdated(
        Subagent(
          id: 'a1',
          goal: '',
          status: SubagentStatus.completed,
          summary: '44 passed',
          duration: Duration(seconds: 123),
          toolCount: 6,
        ),
      ),
    );

    expect(r.subagents, hasLength(1));
    final agent = r.subagents.single;
    expect(agent.id, 'a1');
    expect(agent.goal, 'Fix the retry double-call');
    expect(agent.status, SubagentStatus.completed);
    expect(agent.summary, '44 passed');
    expect(agent.duration, const Duration(seconds: 123));
    expect(agent.toolCount, 6);
    expect(agent.model, 'glm-5.3');
    expect(agent.lastTool, 'terminal');
  });

  test('a nested child files beneath its parent; a failure is terminal', () {
    final r = reply();
    apply(
      r,
      const SubagentUpdated(Subagent(id: 'a2', goal: 'Update the docs')),
    );
    apply(
      r,
      const SubagentUpdated(
        Subagent(
          id: 'a3',
          goal: 'Verify the examples',
          parentId: 'a2',
          depth: 1,
        ),
      ),
    );
    expect(r.subagents[1].parentId, 'a2');
    apply(
      r,
      const SubagentUpdated(
        Subagent(
          id: 'a3',
          goal: '',
          status: SubagentStatus.failed,
          summary: 'timed out',
        ),
      ),
    );
    expect(r.subagents[1].status, SubagentStatus.failed);
    expect(r.subagents[1].parentId, 'a2');
  });

  test('the reply renders one subagents card carrying the list', () {
    final r = reply()
      ..subagents = [
        const Subagent(
          id: 'a1',
          goal: 'Fix it',
          status: SubagentStatus.completed,
        ),
      ];
    final card = chatMessageToFlyer(r)
        .whereType<CustomMessage>()
        .where((m) => m.metadata?[kMetaKind] == kKindSubagents);
    expect(card, hasLength(1));
    expect(
      card.single.metadata![kMetaSubagents] as List<Subagent>,
      r.subagents,
    );
  });

  testWidgets('a running batch is open, a done batch folds and opens on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubagentGroupCard(
            subagents: const [
              Subagent(
                id: 'a1',
                goal: 'Review the diff',
                status: SubagentStatus.completed,
                summary: 'Two comments.',
              ),
              Subagent(
                id: 'a2',
                goal: 'Update the docs',
                lastTool: 'terminal',
                lastToolPreview: 'make docs',
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Review the diff'),
      findsNothing,
      reason: 'the header names the running child; the done one stays folded',
    );
    expect(find.textContaining('Update the docs'), findsOneWidget);

    const done = [
      Subagent(
        id: 'a1',
        goal: 'Review the diff',
        status: SubagentStatus.completed,
      ),
      Subagent(
        id: 'a2',
        goal: 'Update the docs',
        status: SubagentStatus.completed,
      ),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SubagentGroupCard(subagents: done)),
      ),
    );
    expect(find.textContaining('Used 2 agents'), findsOneWidget);
    expect(find.textContaining('Update the docs'), findsNothing);
    await tester.tap(find.textContaining('Used 2 agents'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Update the docs'), findsOneWidget);
  });
}

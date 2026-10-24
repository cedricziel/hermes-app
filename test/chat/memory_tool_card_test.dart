import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/chat/widgets/memory_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/memory/memory_decisions.dart';
import 'package:hermes_app/src/memory/memory_tool_outcome.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../memory/memory_tool_fixtures.dart';
import '../support/fake_chat_transport.dart';

ToolCall memoryCall(
  Map<String, Object?> result, [
  Map<String, Object?> args = replaceArgs,
]) => ToolCall(
  name: 'memory',
  summary: 'memory',
  args: args,
  resultData: result,
  status: toolStatusOf(result),
);

ToolCallStatus toolStatusOf(Map<String, Object?> result) =>
    result['success'] == false
    ? (MemoryToolOutcome.parse(result: result) == null
          ? ToolCallStatus.error
          : ToolCallStatus.warning)
    : ToolCallStatus.completed;

Widget host(Widget child) => MaterialApp(
  theme: buildHermesLightTheme(),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  group('MemoryToolBody', () {
    Future<void> pumpBody(
      WidgetTester tester,
      Map<String, Object?> result, {
      Map<String, Object?> args = replaceArgs,
      MemoryDecisionState decision = MemoryDecisionState.idle,
      ValueChanged<bool>? onDecide,
    }) => tester.pumpWidget(
      host(
        MemoryToolBody(
          outcome: MemoryToolOutcome.parse(args: args, result: result)!,
          decision: decision,
          onDecide: onDecide,
        ),
      ),
    );

    testWidgets('saved shows the summary and the saved text', (tester) async {
      await pumpBody(tester, savedResult, args: addArgs);
      expect(find.text('Saved to memory · About you · 66% full'), findsOne);
      expect(find.text('+ Prefers short answers'), findsOne);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('saved without a percentage ends after the tab', (
      tester,
    ) async {
      await pumpBody(tester, {'success': true}, args: addArgs);
      expect(find.text('Saved to memory · About you'), findsOne);
    });

    testWidgets('staged shows the change, the note and both buttons', (
      tester,
    ) async {
      final decided = <bool>[];
      await pumpBody(tester, stagedResult, onDecide: decided.add);
      expect(find.text('− Uses tabs'), findsOne);
      expect(find.text('+ Uses spaces'), findsOne);
      expect(find.text('Not saved yet.'), findsOne);
      await tester.tap(find.text('Approve'));
      await tester.tap(find.text('Reject'));
      expect(decided, [true, false]);
    });

    testWidgets('staged without actions has no buttons', (tester) async {
      await pumpBody(tester, stagedResult);
      expect(find.text('Not saved yet.'), findsOne);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('running disables the buttons', (tester) async {
      await pumpBody(
        tester,
        stagedResult,
        decision: const MemoryDecisionState(MemoryDecisionPhase.running),
        onDecide: (_) {},
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a failure shows Hermes text and keeps the buttons', (
      tester,
    ) async {
      await pumpBody(
        tester,
        stagedResult,
        decision: const MemoryDecisionState(
          MemoryDecisionPhase.failed,
          'The entry changed since it was staged.',
        ),
        onDecide: (_) {},
      );
      expect(find.text('The entry changed since it was staged.'), findsOne);
      expect(find.text('Approve'), findsOne);
      expect(find.text('Reject'), findsOne);
    });

    testWidgets('saved and rejected replace the buttons', (tester) async {
      await pumpBody(
        tester,
        stagedResult,
        decision: const MemoryDecisionState(MemoryDecisionPhase.saved),
        onDecide: (_) {},
      );
      expect(find.text('Saved to memory · Agent notes'), findsOne);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Not saved yet.'), findsNothing);
      await pumpBody(
        tester,
        stagedResult,
        decision: const MemoryDecisionState(MemoryDecisionPhase.rejected),
        onDecide: (_) {},
      );
      expect(find.text('Rejected · Agent notes'), findsOne);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('full is a warning that nothing was saved', (tester) async {
      await pumpBody(tester, fullResult);
      expect(
        find.text(
          'Agent notes are at 2,180 of 2,200 characters, so this entry did '
          'not fit. Nothing was saved; Hermes usually makes room and tries '
          'again.',
        ),
        findsOne,
      );
    });
  });

  group('tool call card', () {
    testWidgets('memory calls get the memory body, others the generic one', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ToolCallCard(
            call: memoryCall(savedResult, addArgs),
            initiallyOpen: true,
          ),
        ),
      );
      expect(find.byType(MemoryToolBody), findsOne);
      expect(toolCallBody(memoryCall(otherErrorResult)), isNull);
    });

    testWidgets('a full memory shows the warning status, not failed', (
      tester,
    ) async {
      await tester.pumpWidget(host(ToolCallCard(call: memoryCall(fullResult))));
      expect(
        tester
            .widget<ToolCallStatusIcon>(find.byType(ToolCallStatusIcon))
            .status,
        ToolCallStatus.warning,
      );
    });

    testWidgets('buttons run the decision and the card shows the answer', (
      tester,
    ) async {
      final transport = FakeChatTransport()
        ..slashResult = const SlashCommandResult(
          threadId: 't',
          output: approvedAnswer,
        );
      final decisions = MemoryDecisions(
        available: () => true,
        run: (command) async => (await transport.runSlashCommand(
          threadId: 't',
          command: command,
        )).output,
      );
      addTearDown(decisions.dispose);
      await tester.pumpWidget(
        host(
          MemoryDecisionsScope(
            decisions: decisions,
            child: ToolCallCard(
              call: memoryCall(stagedResult),
              initiallyOpen: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(transport.slashRuns, ['/memory approve 1a2b3c4d']);
      expect(find.text('Saved to memory · Agent notes'), findsOne);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('no buttons while the chat has no stored thread', (
      tester,
    ) async {
      final decisions = MemoryDecisions(
        available: () => false,
        run: (_) async => '',
      );
      addTearDown(decisions.dispose);
      await tester.pumpWidget(
        host(
          MemoryDecisionsScope(
            decisions: decisions,
            child: ToolCallCard(
              call: memoryCall(stagedResult),
              initiallyOpen: true,
            ),
          ),
        ),
      );
      expect(find.text('Not saved yet.'), findsOne);
      expect(find.text('Approve'), findsNothing);
    });
  });

  group('events', () {
    GatewayEvent complete(Map<String, Object?> result) => GatewayEvent(
      type: 'tool.complete',
      sessionId: 's',
      payload: {'tool_id': 't1', 'name': 'memory', 'result': result},
    );

    test('a full memory completes the call with a warning', () {
      final reply = ChatMessage(
        id: 'r',
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime(2026),
        status: MessageStatus.thinking,
      );
      applyReplyEvent(
        reply,
        const ToolStarted(id: 't1', name: 'memory', args: replaceArgs),
      );
      applyReplyEvent(reply, mapGatewayEvent(complete(fullResult))!);
      expect(reply.toolCalls.single.status, ToolCallStatus.warning);
    });

    test('other memory errors still fail the call', () {
      final event =
          mapGatewayEvent(complete(otherErrorResult))! as ToolFinished;
      expect(event.failed, isTrue);
      expect(event.warning, isFalse);
    });
  });

  group('ChatController.memoryDecisionsIn', () {
    late FakeChatTransport transport;
    late ChatController chat;

    setUp(() {
      transport = FakeChatTransport();
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      addTearDown(() {
        chat.dispose();
        attention.dispose();
      });
    });

    test(
      'runs on the stored thread, offered only once the chat has one',
      () async {
        chat.newThread();
        final thread = chat.selectedThread!;
        final decisions = chat.memoryDecisionsIn(thread);
        expect(chat.memoryDecisionsIn(thread), same(decisions));
        expect(decisions.available(), isFalse);

        chat.submit('Remember this', const []);
        transport.sends.single
          ..emit(const ThreadBound('s1'))
          ..emit(const ReplyCompleted('Done'));
        await pumpEventQueue();
        expect(decisions.available(), isTrue);

        transport.slashResult = const SlashCommandResult(
          threadId: 's1',
          output: rejectedAnswer,
        );
        await decisions.decide('1a2b3c4d', approve: false);
        expect(transport.slashRuns, ['/memory reject 1a2b3c4d']);
        expect(transport.slashContexts.single.$1, 's1');
        expect(
          decisions.stateOf('1a2b3c4d').phase,
          MemoryDecisionPhase.rejected,
        );
      },
    );
  });
}

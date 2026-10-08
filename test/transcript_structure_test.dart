import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, Message, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show Chat, ChatAnimatedList;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller_sync.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/find_app_icon.dart';
import 'support/pump_chat.dart';

// Streaming replies, refetches and thread switches remove and insert
// transcript items a frame apart. Items that animated out used to leave the
// sliver's children out of order, and paint then hit the `childMainAxisPosition`
// null check, the top production crash; see `FollowingChatList`.
void main() {
  testWidgets('a reply that changes shape mid-stream keeps the transcript '
      'intact', (tester) async {
    final semantics = tester.ensureSemantics();
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Long thread', lastActive: 1780000600),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          for (var i = 1; i <= 30; i++)
            messageRow(
              id: i,
              role: i.isOdd ? 'user' : 'assistant',
              content: List.filled(4, 'Line of message $i.').join('\n\n'),
            ),
        ]),
      );
    final transport = FakeChatTransport();
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Long thread');

    await tester.enterText(composerField, 'Investigate');
    await tester.pump();
    await tester.tap(findAppIcon(AppIcons.sendArrow));
    await tester.pump();
    final reply = transport.sends.single;

    // One frame between events, far shorter than any animation.
    Future<void> emit(ChatEvent event) async {
      reply.emit(event);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: '$event');
    }

    await emit(const ReplyStarted());
    await emit(const ReasoningUpdated('Looking at the logs.'));
    await emit(const ToolStarted(name: 'terminal', id: 't1'));
    await emit(const ReplyDelta('The first run failed. '));
    await emit(const ReplyCheckpoint('The first run failed.'));
    await emit(const ToolFinished(name: 'terminal', id: 't1'));
    await emit(const ToolStarted(name: 'web_search', id: 't2'));
    await emit(const ReasoningUpdated(' Checking the second one.'));
    await emit(const ToolFinished(name: 'web_search', id: 't2'));
    await emit(const ReplyDelta('Interim notes.'));
    await emit(const ReplyCheckpoint('Interim notes.'));
    await emit(const ToolStarted(name: 'terminal', id: 't3'));
    await emit(const ToolFinished(name: 'terminal', id: 't3'));
    for (var i = 0; i < 5; i++) {
      await emit(ReplyDelta('Line $i of the answer.\n\n'));
    }
    await emit(const ReplyCompleted('The answer.'));

    await tester.pumpAndSettle();
    semantics.dispose();
  });

  // Seeded churn: streaming changes mixed with refetches, scroll jumps,
  // thread switches and frames of every length.
  for (var seed = 0; seed < 8; seed++) {
    testWidgets('structural churn keeps the transcript intact (seed $seed)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final random = Random(seed);

      var history = List.generate(
        6 + random.nextInt(10),
        (i) => ChatMessage(
          id: 'h$i',
          role: i.isEven ? ChatRole.user : ChatRole.assistant,
          content: _paragraphs(random, i),
          createdAt: DateTime(2026),
        ),
      );
      var controller = InMemoryChatController(
        messages: history.expand(chatMessageToFlyer).toList(),
      );
      late StateSetter switchThread;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                switchThread = setState;
                return FlyerMaterialScope(
                  child: Chat(
                    key: ValueKey(controller),
                    chatController: controller,
                    currentUserId: kUserAuthorId,
                    resolveUser: (id) async => User(id: id),
                    theme: buildChatTheme(Theme.of(context)),
                    builders: buildChatBuilders(onPickPrompt: (_) {}),
                  ),
                );
              },
            ),
          ),
        ),
      );

      for (var round = 0; round < 3; round++) {
        final prompt = ChatMessage(
          id: 'p$round',
          role: ChatRole.user,
          content: 'Prompt $round',
          createdAt: DateTime(2026),
        );
        await controller.insertMessage(chatMessageToFlyer(prompt).single);
        late ChatMessage reply;
        List<Message> before = const [];
        for (var step = 0; step < 15; step++) {
          reply = _reply('r$round', step, random);
          final after = chatMessageToFlyer(reply);
          syncMessage(controller, before, after);
          before = after;
          switch (random.nextInt(8)) {
            case 0:
              await tester.pump();
            case 1:
              await tester.pump(const Duration(milliseconds: 150));
            case 2:
              final position = tester
                  .state<ScrollableState>(
                    find
                        .descendant(
                          of: find.byType(ChatAnimatedList),
                          matching: find.byType(Scrollable),
                        )
                        .first,
                  )
                  .position;
              position.jumpTo(random.nextDouble() * position.maxScrollExtent);
              await tester.pump();
            case 3:
              await controller.setMessages(
                [...history, prompt, reply].expand(chatMessageToFlyer).toList(),
              );
              await tester.pump(const Duration(milliseconds: 16));
            default:
              await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            tester.takeException(),
            isNull,
            reason: 'round $round, step $step',
          );
        }
        history = [...history, prompt, reply];
        if (random.nextBool()) {
          final previous = controller;
          switchThread(
            () => controller = InMemoryChatController(
              messages: history.expand(chatMessageToFlyer).toList(),
            ),
          );
          await tester.pump();
          previous.dispose();
        }
      }
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  }
}

String _paragraphs(Random random, int i) => List.generate(
  1 + random.nextInt(6),
  (j) => 'Line $j of message $i.',
).join('\n\n');

/// Step [step] of a reply's life: thinking, then reasoning, tool calls,
/// sealed prose and text in turn, then done.
ChatMessage _reply(String id, int step, Random random) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  content: step > 9 ? _paragraphs(random, step) : '',
  createdAt: DateTime(2026),
  status: step < 2
      ? MessageStatus.thinking
      : step < 13
      ? MessageStatus.streaming
      : MessageStatus.sent,
  reasoning: step.isOdd ? 'Thinking about step $step.' : '',
  toolCalls: [
    for (var i = 0; i < min(step ~/ 2, 5); i++)
      ToolCall(
        name: 'tool$i',
        summary: 'Call $i',
        status: i == step ~/ 2 - 1 && step < 12
            ? ToolCallStatus.running
            : ToolCallStatus.completed,
        reasoning: i == 2 && step > 6 ? 'Why call $i.' : '',
      ),
  ],
  sealedProse: [
    if (step > 4) SealedProse(_paragraphs(random, step), beforeToolCall: 1),
    if (step > 8) SealedProse('More prose at step $step.', beforeToolCall: 3),
  ],
);

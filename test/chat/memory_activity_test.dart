import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/memory/memory_recall.dart';

void main() {
  test(
    'recognizes provider recall indicators without guessing note identities',
    () {
      for (final text in [
        '🧠 robot-notes — recalled 5 memories',
        '🧠 Provider — recalled 1 memory',
        '🧠 Provider — recalled relevant memory',
        '🧠 One — recalled 2 memories  🧠 Two — recalled 1 memory',
      ]) {
        expect(MemoryRecall.fromStatus(text), isNotNull);
      }
      for (final text in [
        'Waiting for memory search',
        'Background review needs your approval',
        'robot-notes — recalling 5 memories',
        'Memory updated',
        'The user said they recalled 5 memories yesterday',
        '',
      ]) {
        expect(MemoryRecall.fromStatus(text), isNull);
      }
    },
  );

  test(
    'repeated counts are separate bounded events and retire with the runtime',
    () {
      final state = ChatSessionState()..adopt('one');
      for (var i = 0; i < 25; i++) {
        state.recordMemoryRecall(
          '🧠 robot-notes — recalled 5 memories',
          receivedAt: DateTime(2030, 1, 1, 9, i),
        );
      }
      expect(state.visible, isFalse, reason: 'recall is reference activity');
      expect(state.memoryRecalls, hasLength(20));
      expect(state.memoryRecalls.first.receivedAt.minute, 5);
      expect(state.earlierRecallsOmitted, isTrue);
      state.adopt('two');
      expect(state.memoryRecalls, isEmpty);
      expect(state.earlierRecallsOmitted, isFalse);
    },
  );

  testWidgets(
    'expansion explains missing detail without repeating latest recall',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryActivityCard(
              recalls: [
                MemoryRecall(
                  summary: 'robot-notes — recalled 5 memories',
                  receivedAt: DateTime(2030, 1, 1, 9, 41),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('robot-notes — recalled 5 memories'), findsOneWidget);
      expect(find.textContaining('did not include'), findsNothing);
      await tester.tap(find.text('Memory & review'));
      await tester.pumpAndSettle();
      expect(find.text('robot-notes — recalled 5 memories'), findsOneWidget);
      expect(
        find.textContaining('did not include the note titles or contents'),
        findsOneWidget,
      );
      expect(
        find.textContaining('same count can refer to different memories'),
        findsOneWidget,
      );
      expect(find.textContaining('Received at'), findsOneWidget);
    },
  );

  testWidgets(
    'review reports retain proposed approval text without claiming it was saved',
    (tester) async {
      const pending =
          'Proposed memory changes await approval. Review with /memory pending.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemoryActivityCard(
              reviewNotes: [pending],
              initiallyOpen: true,
            ),
          ),
        ),
      );
      expect(find.text(pending), findsOneWidget);
      expect(find.textContaining('saved'), findsNothing);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';

void main() {
  testWidgets('recovered entries require review and explicit send next', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueuedPrompts(
            prompts: const [
              QueuedPrompt('first', []),
              QueuedPrompt('second', []),
            ],
            reviewRequired: true,
            onRemove: (_) {},
            onSendNow: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Recovered queue. Review before sending.'),
      findsOneWidget,
    );
    expect(find.text('Send next'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
  });
  testWidgets('uncertain submission cannot use ordinary send control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueuedPrompts(
            prompts: const [
              QueuedPrompt(
                'possibly sent',
                [],
                durable: QueueRecord(
                  id: 'entry',
                  sequence: 0,
                  text: 'possibly sent',
                  state: QueueRecordState.submissionStarted,
                ),
              ),
            ],
            reviewRequired: true,
            onRemove: (_) {},
            onSendNow: () {},
            onInspect: () {},
          ),
        ),
      ),
    );
    expect(find.text('Submission outcome unknown'), findsOneWidget);
    expect(find.text('Send next'), findsNothing);
    expect(find.text('Inspect conversation'), findsOneWidget);
    expect(
      find.textContaining('may already have reached Hermes'),
      findsOneWidget,
    );
  });
  testWidgets('app lock hides recovered text and attachments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueuedPrompts(
            prompts: const [QueuedPrompt('private recovered text', [])],
            locked: true,
            reviewRequired: true,
            onRemove: (_) {},
            onSendNow: () {},
          ),
        ),
      ),
    );
    expect(find.text('private recovered text'), findsNothing);
    expect(find.text('Unlock to review queued prompts.'), findsOneWidget);
  });
}

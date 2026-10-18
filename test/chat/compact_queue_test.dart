import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';
import 'package:hermes_app/src/chat/widgets/composer_stop_button.dart';

void main() {
  testWidgets('thirty ordinary entries occupy one row until expanded', (
    tester,
  ) async {
    final prompts = [
      for (var i = 0; i < 30; i++) QueuedPrompt('Follow-up $i', []),
    ];
    QueuedPrompt? removed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: QueuedPrompts(
              prompts: prompts,
              onRemove: (prompt) => removed = prompt,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(QueuedPrompts)).height,
      lessThanOrEqualTo(56),
    );
    expect(find.text('30 queued · Follow-up 0'), findsOneWidget);
    expect(find.text('Follow-up 1'), findsNothing);
    await tester.tap(find.text('30 queued · Follow-up 0'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(QueuedPrompts)).height,
      lessThanOrEqualTo(260),
    );
    await tester.tap(find.byTooltip('Remove from queue').first);
    expect(removed, same(prompts.first));
  });

  testWidgets(
    'Stop remains one accessible action and prevents duplicate requests',
    (tester) async {
      final stopped = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerStopButton(
              onStop: () {
                calls++;
                return stopped.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Stop response'));
      await tester.pump();
      expect(calls, 1);
      await tester.tap(find.bySemanticsLabel('Stop response'));
      expect(calls, 1);
      stopped.complete();
      await tester.pumpAndSettle();
      expect(find.text('Hermes is replying…'), findsNothing);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_dialog.dart';

void main() {
  testWidgets('explains connection change and allows cancellation', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandoffDialog(
            serverUrl: 'https://example.test',
            onCancel: () => cancelled = true,
            onContinue: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('queued messages'), findsOneWidget);
    expect(find.text('https://example.test'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });
  testWidgets('retryable failure offers retry and dismissal', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandoffDialog(
            error: 'Could not reach the dashboard.',
            onCancel: () {},
            onContinue: () => retried = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

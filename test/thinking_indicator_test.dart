import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  group('formatThinkingElapsed', () {
    test('shows seconds alone under a minute', () {
      expect(formatThinkingElapsed(const Duration(seconds: 12)), '12s');
      expect(formatThinkingElapsed(Duration.zero), '0s');
    });

    test('shows minutes and seconds from a minute on', () {
      expect(formatThinkingElapsed(const Duration(seconds: 65)), '1m 5s');
      expect(formatThinkingElapsed(const Duration(minutes: 2)), '2m 0s');
    });

    test('never goes negative for a start time ahead of the clock', () {
      expect(formatThinkingElapsed(const Duration(seconds: -3)), '0s');
    });
  });

  testWidgets('shows the elapsed time and the activity beside a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: ThinkingIndicator(
            startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
            activity: 'Running git_show…',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Running git_show…'), findsOneWidget);
    expect(find.textContaining('5s'), findsOneWidget);
  });

  testWidgets('cancels its timer once unmounted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: ThinkingIndicator(startedAt: DateTime.now(), activity: '…'),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    // A leftover Timer.periodic would fail this pump once its next tick is
    // due, since nothing is left mounted to call setState on safely.
    await tester.pump(const Duration(seconds: 2));
  });
}

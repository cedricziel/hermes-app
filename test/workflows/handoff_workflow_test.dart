import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_dialog.dart';

import '../support/screenshot_recorder.dart';

void main() {
  testWidgets('handoff connection and failure states', (tester) async {
    final shots = ScreenshotRecorder('handoff');
    await shots.start(tester, phoneSize);
    await tester.pumpWidget(
      shots.frame(
        MaterialApp(
          theme: withScreenshotFont(ThemeData()),
          home: Scaffold(
            body: HandoffDialog(
              serverUrl: 'https://dashboard.example.test',
              onCancel: () {},
              onContinue: () {},
            ),
          ),
        ),
      ),
    );
    await shots.capture(tester, 'connect-dashboard');
    expect(find.text('Cancel'), findsOneWidget);
    await tester.pumpWidget(
      shots.frame(
        MaterialApp(
          theme: withScreenshotFont(ThemeData()),
          home: Scaffold(
            body: HandoffDialog(
              error: 'Could not reach the dashboard. Try again.',
              onCancel: () {},
              onContinue: () {},
            ),
          ),
        ),
      ),
    );
    await shots.capture(tester, 'retry');
    expect(find.text('Retry'), findsOneWidget);
  });
}

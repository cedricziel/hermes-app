import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/background_check_status.dart';
import 'package:hermes_app/src/notifications/background_check_section.dart';

void main() {
  testWidgets('permission and iOS refresh denial remain separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BackgroundCheckSection(
            platform: TargetPlatform.iOS,
            permission: true,
            capability: 'denied',
          ),
        ),
      ),
    );
    expect(find.text('Notifications: Allowed'), findsOneWidget);
    expect(find.text('Background App Refresh: Denied'), findsOneWidget);
    expect(find.text('No background check recorded.'), findsOneWidget);
  });
  testWidgets('unknown capability never implies scheduling success', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BackgroundCheckSection(platform: TargetPlatform.android),
        ),
      ),
    );
    expect(find.text('Notifications: Unknown'), findsOneWidget);
    expect(find.text('Periodic work: Unknown'), findsOneWidget);
    expect(find.textContaining('late or never'), findsOneWidget);
  });
  testWidgets('interrupted record does not claim completed work', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackgroundCheckSection(
            platform: TargetPlatform.android,
            capability: 'registered',
            status: BackgroundCheckStatus(
              attemptedAt: DateTime.utc(2026, 1, 2),
              outcome: BackgroundCheckOutcome.incomplete,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Latest check: Interrupted or incomplete'),
      findsOneWidget,
    );
    expect(find.text('Last completed: None recorded'), findsOneWidget);
  });
}

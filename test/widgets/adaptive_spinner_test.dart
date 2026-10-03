import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';

Future<void> _pump(WidgetTester tester, TargetPlatform platform) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: ThinkingIndicator(
            startedAt: DateTime.now(),
            activity: 'Thinking',
          ),
        ),
      ),
    );

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('busy spinner is an activity indicator on $platform', (
      tester,
    ) async {
      await _pump(tester, platform);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  }

  testWidgets('busy spinner stays Material on Android', (tester) async {
    await _pump(tester, TargetPlatform.android);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

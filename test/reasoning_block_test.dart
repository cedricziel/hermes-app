import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/accessibility.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    required String text,
    bool active = true,
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: ReasoningBlock(text: text, active: active),
        ),
      ),
    ),
  );

  testWidgets('expansion survives streaming and completion', (tester) async {
    await show(tester, text: 'Checking');
    expect(find.text('Checking'), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.tap(find.text('Thinking…'));
    await tester.pump();
    await show(tester, text: 'Checking the logs');
    expect(find.text('Checking the logs'), findsOneWidget);
    await show(tester, text: 'Checking the logs', active: false);
    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.text('Checking the logs'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion keeps the disclosure static and usable', (
    tester,
  ) async {
    await show(tester, text: 'Checking', reduced: true);
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thinking…'));
    await tester.pumpAndSettle();
    expect(find.text('Checking'), findsOneWidget);
  });

  testWidgets('VoiceOver receives a named expanded-state button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, text: 'Checking', reduced: true);
    expect(
      tester.getSemantics(find.byType(InkWell)),
      disclosure('Thinking…', open: false),
    );
    await tester.tap(find.text('Thinking…'));
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(InkWell)),
      disclosure('Thinking…', open: true),
    );
    expect(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}

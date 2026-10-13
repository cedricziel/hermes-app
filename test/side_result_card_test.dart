import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:hermes_app/src/chat/side_results/side_result_card.dart';

import 'support/accessibility.dart';

void main() {
  testWidgets(
    'side answer remains compact until details open and text stays untrusted',
    (tester) async {
      final result = SideResult.decode('btw.complete', {
        'task_id': 'one',
        'text': '[Answer](https://example.invalid)',
        'question': 'What changed?',
      })!;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SideResultCard(result: result)),
        ),
      );
      expect(find.text('[Answer](https://example.invalid)'), findsNothing);
      await tester.tap(find.text('Side question answer'));
      await tester.pumpAndSettle();
      expect(find.text('Question: What changed?'), findsOneWidget);
      expect(find.text('[Answer](https://example.invalid)'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Side question answer')),
        disclosure('Side question answer', open: true),
      );
      semantics.dispose();
    },
  );

  testWidgets('empty side output is neutral rather than a failed main answer', (
    tester,
  ) async {
    final result = SideResult.decode('background.complete', {
      'task_id': 'one',
      'text': '',
    })!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SideResultCard(result: result, initiallyOpen: true),
        ),
      ),
    );
    expect(find.text('Background result'), findsOneWidget);
    expect(find.text('No result text reported'), findsOneWidget);
    expect(find.textContaining('failed'), findsNothing);
  });

  testWidgets(
    'unavailable side result details are explicit on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SideResultCard(result: null))),
      );
      expect(find.text('Side result unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

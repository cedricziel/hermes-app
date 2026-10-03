import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );

  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget(find.byType(LinearProgressIndicator));

  testWidgets('an unknown amount slides while motion is on', (tester) async {
    await pump(tester, const BusyBar());

    expect(bar(tester).value, isNull);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an unknown amount holds still under Reduce Motion', (
    tester,
  ) async {
    await pump(tester, const BusyBar(), reduceMotion: true);

    expect(bar(tester).value, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the iOS Reduce Motion setting holds the bar still too', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester, const BusyBar());

    expect(bar(tester).value, 1);
    expect(find.bySemanticsLabel('In progress'), findsNothing);
    expect(find.semantics.byValue('In progress'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'a bar already on screen stills when iOS Reduce Motion turns on',
    (tester) async {
      await pump(tester, const BusyBar());
      expect(bar(tester).value, isNull);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();

      expect(bar(tester).value, 1);
    },
  );

  testWidgets('a known amount is shown as it is under Reduce Motion', (
    tester,
  ) async {
    await pump(tester, const BusyBar(value: 0.25), reduceMotion: true);

    expect(bar(tester).value, 0.25);
  });

  testWidgets('a running Kanban task without children does not slide under '
      'Reduce Motion', (tester) async {
    await pump(
      tester,
      const KanbanCard(
        task: KanbanTask(id: 't1', title: 'Rotate keys', status: 'running'),
      ),
      reduceMotion: true,
    );

    expect(find.byType(BusyBar), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_add_action.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late SchedulesController controller;

  setUp(() {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/cron/jobs', <Object?>[]);
    controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpSchedules(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('$platform puts New in the bar, not in a floating button', (
      tester,
    ) async {
      await pumpSchedules(tester, platform);
      expect(find.byType(FloatingActionButton), findsNothing);
      final add = find.byTooltip('New scheduled task');
      expect(add, findsOneWidget);
      expect(
        tester.getTopRight(add).dx,
        greaterThan(tester.getTopRight(find.byTooltip('Refresh')).dx),
        reason: 'the add button sits at the trailing edge',
      );
      expect(tester.getSize(add).shortestSide, greaterThanOrEqualTo(44));
    });
  }

  testWidgets('Android keeps the floating button', (tester) async {
    await pumpSchedules(tester, TargetPlatform.android);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.byTooltip('New scheduled task'), findsNothing);
  });

  testWidgets('the floating button clears the bottom inset', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            floatingActionButton: const AdaptiveAddAction(
              label: 'New',
              onPressed: _noop,
            ).floatingButton(context),
          ),
        ),
      ),
    );
    expect(
      tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
      lessThanOrEqualTo(800 - 34),
    );
  });
}

void _noop() {}

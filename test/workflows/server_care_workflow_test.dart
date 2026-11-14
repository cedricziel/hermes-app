import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/server_screen.dart';
import 'package:provider/provider.dart';

import '../server_care/server_care_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Server care: the status with its headline, the Update page, and Usage, on
/// a phone and a desktop window, in light and dark.
void main() {
  late FakeHermesServer server;

  /// Lets the fake server answer (it runs on real time) and the screen draw.
  Future<void> answered(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // The bars rise over 200 ms once the report is in.
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/status', {
        ...statusHealthy(),
        'gateway_running': false,
        'gateway_state': 'stopped',
        'disk': {'pressure': 'elevated', 'free_mb': 8600, 'used_percent': 91.0},
      })
      ..on('GET', '/api/hermes/update/check', updateCheckBehind())
      ..on('GET', '/api/analytics/usage', usage30());
  });

  final variants = [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
    ('desktop-dark', desktopSize, Brightness.dark),
  ];

  for (final (name, size, brightness) in variants) {
    testWidgets('$name: status, update and usage', (tester) async {
      final shots = ScreenshotRecorder('server-care-$name');
      final repositories = HermesRepositories(server.client());
      final care = ServerCareController(
        repository: ServerCareRepository(server.client()),
        profile: 'default',
      );
      addTearDown(care.dispose);
      await tester.runAsync(care.refresh);

      await pumpScreen(
        tester,
        shots,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showServerScreen(context, source: 'menu'),
                child: const Text('Open Server'),
              ),
            ),
          ),
        ),
        size: size,
        brightness: brightness,
        providers: [
          Provider<HermesRepositories>.value(value: repositories),
          ChangeNotifierProvider<ServerCareController>.value(value: care),
        ],
      );
      await tester.tap(find.text('Open Server'));
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'status');
      expect(find.text('The messaging gateway is off'), findsOneWidget);

      await tester.tap(find.textContaining('Update available'));
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'update');
      expect(find.text("What's new"), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.scrollUntilVisible(
        find.text('Usage'),
        300,
        scrollable: find
            .ancestor(
              of: find.text('Messaging gateway'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Usage'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Usage'));
      await tester.pump(const Duration(milliseconds: 600));
      await answered(tester);
      await shots.capture(tester, 'usage');
      await letSocketsIdle(tester);
    });
  }
}

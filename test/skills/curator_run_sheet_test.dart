import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/skills/curator/curator_config.dart';
import 'package:hermes_app/src/skills/curator/curator_controller.dart';
import 'package:hermes_app/src/skills/curator/curator_run_sheet.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';
import 'package:hermes_app/src/skills/widgets/curator_run_confirmation.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/skills/curator/curator_telemetry.dart';

import '../support/fake_hermes_server.dart';
import 'curator_fixtures.dart';
import '../support/test_localizations.dart';

/// `askToRunCurator` on its own, with a real controller against the fake
/// dashboard: a question that the controller drops (a profile switch) closes
/// the sheet and sends nothing. The single-guard survivors (`_decided` in
/// `_run`, `!controller.disposed`) stay accepted as defence in depth
/// (Cancel's `pop(false)` is only caught together with its `cancelRun`).
void main() {
  late FakeHermesServer server;
  late CuratorController controller;

  int posts() => server.requestsTo('POST', '/api/curator/run').length;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/config', recordedConfigCurator);
    serveRecordedCurator(server, status: recordedCuratorRan);
    controller = CuratorController(
      repository: HermesCuratorRepository(
        server.client(),
        timeout: const Duration(seconds: 5),
      ),
      readConfig: CuratorConfigReader(server.client()).call,
      profile: 'default',
      telemetry: CuratorTelemetry(
        const ConnectionTelemetry(),
        Breadcrumbs.none,
      ),
    );
    addTearDown(() {
      if (!controller.disposed) controller.dispose();
    });
  });

  Future<void> pumpHarness(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppThemeScopes(child: child!),
        theme: buildHermesLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => askToRunCurator(context, controller),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
    controller.start();
    await tester.pumpAndSettle();
  }

  testWidgets('a profile switch while the question is open closes the sheet '
      'and sends nothing', (tester) async {
    await pumpHarness(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.byType(CuratorRunConfirmation), findsOneWidget);

    controller.switchProfile('work');
    await tester.pumpAndSettle();

    expect(find.byType(CuratorRunConfirmation), findsNothing);
    expect(controller.confirmation, isNull);
    expect(posts(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a controller disposed while the sheet is open sends nothing', (
    tester,
  ) async {
    await pumpHarness(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(CuratorRunConfirmation),
        matching: find.text('Run now'),
      ),
    );
    controller.dispose();
    await tester.pumpAndSettle();

    expect(posts(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel sends nothing and drops the question', (tester) async {
    await pumpHarness(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(controller.confirmation, isNotNull);

    await tester.tap(
      find.descendant(
        of: find.byType(CuratorRunConfirmation),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CuratorRunConfirmation), findsNothing);
    expect(controller.confirmation, isNull);
    expect(posts(), 0);
  });

  testWidgets('Run now closes the sheet, then sends one POST', (tester) async {
    await pumpHarness(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(CuratorRunConfirmation),
        matching: find.text('Run now'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CuratorRunConfirmation), findsNothing);
    expect(posts(), 1);
    // Ends the status polling the run started.
    controller.dispose();
    await tester.pump(const Duration(seconds: 6));
  });
}

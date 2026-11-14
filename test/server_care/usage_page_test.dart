import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/usage_controller.dart';
import 'package:hermes_app/src/server_care/usage_page.dart';
import 'package:hermes_app/src/server_care/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/server_care/widgets/usage_day_list.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late ServerCareController care;
  late VoidCallback? runCheck;

  setUp(() {
    UsageController.resetRemembered();
    runCheck = null;
    trail = BreadcrumbTrail();
    server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on('GET', '/api/analytics/usage', usage30());
    care = ServerCareController(
      repository: ServerCareRepository(server.client()),
      profile: 'default',
    );
  });

  tearDown(() => care.dispose());

  Future<void> pump(
    WidgetTester tester, {
    double width = 400,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(care.refresh);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HermesRepositories>.value(
            value: HermesRepositories(server.client()),
          ),
          ChangeNotifierProvider<ServerCareController>.value(value: care),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.android),
          home: UsagePage(onRunCheck: runCheck),
        ),
      ),
    );
    // A loading skeleton pulses for as long as it is on screen.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  List<Map<String, dynamic>> reads() => server
      .requestsTo('GET', '/api/analytics/usage')
      .map((r) => r.queryParameters)
      .toList();

  testWidgets('shows totals, chart and models, and reads 30 days', (
    tester,
  ) async {
    await pump(tester);
    expect(reads(), [
      {'days': 30, 'profile': 'default'},
    ]);
    expect(find.text('Usage'), findsWidgets);
    expect(find.byType(UsageChart), findsOneWidget);
    expect(find.text('<model id>'), findsOneWidget);
    expect(find.textContaining('Days follow'), findsOneWidget);
  });

  testWidgets('window and metric switches send days and keep the profile', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('90 days'));
    await tester.pumpAndSettle();
    expect(reads().map((r) => r['days']), [30, 7, 90]);
    expect(reads().every((r) => r['profile'] == 'default'), isTrue);

    await tester.tap(find.text('Estimated cost'));
    await tester.pumpAndSettle();
    expect(reads(), hasLength(3));
    expect(
      tester.widget<UsageChart>(find.byType(UsageChart)).metric,
      UsageChartMetric.cost,
    );
  });

  testWidgets('the profile menu offers the server profiles', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings-subtitle-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('work').last);
    await tester.pumpAndSettle();
    expect(reads().last, {'days': 30, 'profile': 'work'});
  });

  testWidgets('Show as table swaps the chart for the day list', (tester) async {
    await pump(tester);
    expect(find.byType(UsageDayList), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.byType(UsageChart), findsNothing);
    expect(find.byType(UsageDayList), findsOneWidget);
    expect(find.text('By day'), findsOneWidget);
  });

  testWidgets('side by side controls at desktop width', (tester) async {
    await pump(tester, width: 900);
    await tester.tap(find.text('90 days'));
    await tester.pumpAndSettle();
    expect(reads().last['days'], 90);
  });

  testWidgets('503 says usage cannot be read, with Run a check when given', (
    tester,
  ) async {
    server.on('GET', '/api/analytics/usage', {'detail': 'x'}, status: 503);
    await pump(tester);
    expect(find.text("Usage can't be read"), findsOneWidget);
    expect(find.text('Run a check'), findsNothing);
  });

  testWidgets('503 offers Run a check when the page has somewhere to go', (
    tester,
  ) async {
    var ran = 0;
    runCheck = () => ran++;
    server.on('GET', '/api/analytics/usage', {'detail': 'x'}, status: 503);
    await pump(tester);
    await tester.tap(find.text('Run a check'));
    expect(ran, 1);
  });

  testWidgets('empty window', (tester) async {
    server.on('GET', '/api/analytics/usage', {'daily': [], 'totals': {}});
    await pump(tester);
    expect(find.text('No usage in the last 30 days'), findsOneWidget);
    expect(
      find.text(
        'Usage appears here after Hermes answers a chat, a message or a '
        'scheduled task.',
      ),
      findsOneWidget,
    );
    expect(find.byType(UsageChart), findsNothing);
  });

  testWidgets('offline, then Try again', (tester) async {
    server.onRequest(
      'GET',
      '/api/analytics/usage',
      (_) => throw TimeoutException('x'),
    );
    await pump(tester);
    expect(find.text("Can't reach Hermes"), findsOneWidget);
    server.on('GET', '/api/analytics/usage', usage30());
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("Can't reach Hermes"), findsNothing);
    expect(find.byType(UsageChart), findsOneWidget);
  });

  testWidgets("a refused read shows Hermes' text", (tester) async {
    server.on('GET', '/api/analytics/usage', {
      'detail': 'Not now',
    }, status: 400);
    await pump(tester);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('a late answer for a replaced window is dropped', (tester) async {
    final slow = Completer<void>();
    var calls = 0;
    server.onRequest('GET', '/api/analytics/usage', (request) async {
      // The first read (30 days) is answered after the switch to 7.
      if (calls++ == 0) await slow.future;
      return (
        status: 200,
        body: request.queryParameters['days'] == 7
            ? usage30()
            : {'daily': [], 'totals': {}},
      );
    });
    await pump(tester, settle: false);
    expect(find.byType(LoadingSkeleton), findsOneWidget);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageChart), findsOneWidget);
    slow.complete();
    await tester.pumpAndSettle();
    expect(find.byType(UsageChart), findsOneWidget);
    expect(find.textContaining('No usage'), findsNothing);
  });

  testWidgets('the breadcrumb carries only the window', (tester) async {
    await pump(tester);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final crumbs = trail.recent.toList();
    expect(crumbs.single.name, 'server_care.usage.opened');
    expect(crumbs.single.attributes, {'days': 30});
    final all = [for (final c in crumbs) '${c.name} ${c.attributes}'].join();
    for (final secret in ['default', 'work', '<model id>', '876', '1.2']) {
      expect(all, isNot(contains(secret)));
    }
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/care_result.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/usage_controller.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late UsageController controller;
  var unsupported = 0;

  UsageController build({String? profile = 'default'}) => UsageController(
    repository: ServerCareRepository(server.client()),
    profile: profile,
    today: () => DateTime(2026, 11, 14, 22),
    onUnsupported: () => unsupported++,
  );

  setUp(() {
    UsageController.resetRemembered();
    unsupported = 0;
    server = FakeHermesServer()..on('GET', '/api/analytics/usage', usage30());
    controller = build();
  });

  tearDown(() => controller.dispose());

  Iterable<Map<String, dynamic>> reads() => server
      .requestsTo('GET', '/api/analytics/usage')
      .map((r) => r.queryParameters);

  test('reads 30 days of tokens for the explicit profile', () async {
    expect(controller.window, UsageChartWindow.days30);
    expect(controller.metric, UsageChartMetric.tokens);
    await controller.load();
    expect(reads().single, {'days': 30, 'profile': 'default'});
    expect(controller.report!.days, hasLength(30));
    expect(controller.loading, isFalse);
    expect(controller.failure, isNull);
  });

  test('nothing is read without a profile', () async {
    controller.dispose();
    controller = build(profile: null);
    await controller.load();
    expect(reads(), isEmpty);
    controller.setProfile('work');
    await pumpEventQueue();
    expect(reads().single['profile'], 'work');
  });

  test(
    'a window switch reads again with its days; a metric switch does not',
    () async {
      await controller.load();
      controller.setWindow(UsageChartWindow.days90);
      await pumpEventQueue();
      expect(reads().last, {'days': 90, 'profile': 'default'});
      expect(controller.report!.days, hasLength(90));
      controller.setMetric(UsageChartMetric.cost);
      await pumpEventQueue();
      expect(reads(), hasLength(2));
      expect(
        controller.chartDays.map((d) => d.value).reduce((a, b) => a + b),
        closeTo(1.2, 1e-9),
      );
    },
  );

  test('a profile switch reads that profile', () async {
    await controller.load();
    controller.setProfile('work');
    await pumpEventQueue();
    expect(reads().last['profile'], 'work');
  });

  test('maps the report to chart, day and model rows', () async {
    await controller.load();
    final days = controller.chartDays;
    expect(days.last.day, DateTime.utc(2026, 11, 14));
    expect(days.firstWhere((d) => d.value > 800000).conversations, 9);
    expect(controller.dayEntries.first.day, DateTime.utc(2026, 11, 14));
    final models = controller.modelEntries;
    expect(models.map((m) => m.model), ['<model id>', '<small model>']);
    expect(models.first.share, closeTo(850000 / 877500, 1e-9));
  });

  test('an answer for a replaced window is dropped', () async {
    final slow = Completer<void>();
    server.onRequest('GET', '/api/analytics/usage', (request) async {
      if (request.queryParameters['days'] == 30) await slow.future;
      return (status: 200, body: usage30());
    });
    final first = controller.load();
    controller.setWindow(UsageChartWindow.days7);
    await pumpEventQueue();
    expect(controller.report!.windowDays, 7);
    slow.complete();
    await first;
    await pumpEventQueue();
    expect(controller.report!.windowDays, 7);
    expect(controller.window, UsageChartWindow.days7);
  });

  test('an answer for a replaced profile is dropped', () async {
    final slow = Completer<void>();
    server.onRequest('GET', '/api/analytics/usage', (request) async {
      if (request.queryParameters['profile'] == 'default') {
        await slow.future;
        return (status: 200, body: {'daily': [], 'totals': {}});
      }
      return (status: 200, body: usage30());
    });
    final first = controller.load();
    controller.setProfile('work');
    await pumpEventQueue();
    slow.complete();
    await first;
    await pumpEventQueue();
    expect(controller.report!.isEmpty, isFalse);
  });

  test('keeps the window and metric for the next page', () async {
    controller.setWindow(UsageChartWindow.days7);
    controller.setMetric(UsageChartMetric.cost);
    await pumpEventQueue();
    final next = build();
    addTearDown(next.dispose);
    expect(next.window, UsageChartWindow.days7);
    expect(next.metric, UsageChartMetric.cost);
  });

  group('failures', () {
    Future<void> failWith(int status, [Object? body]) async {
      server.on('GET', '/api/analytics/usage', body, status: status);
      await controller.load();
    }

    test('503 is the store being unreadable', () async {
      await failWith(503, {'detail': 'store'});
      expect(controller.failure, CareFailureKind.storeUnreadable);
      expect(controller.report, isNull);
    });

    test('a 4xx carries Hermes text', () async {
      await failWith(400, {'detail': 'Bad window'});
      expect(controller.failure, CareFailureKind.refused);
      expect(controller.failureMessage, 'Bad window');
    });

    test('a missing route is unsupported and reported once', () async {
      await failWith(404, {'detail': 'Not Found'});
      expect(controller.unsupported, isTrue);
      expect(controller.failure, isNull);
      expect(unsupported, 1);
    });

    test('a connection error is offline', () async {
      server.onRequest(
        'GET',
        '/api/analytics/usage',
        (_) => throw TimeoutException('x'),
      );
      await controller.load();
      expect(controller.failure, CareFailureKind.offline);
    });

    test('a later success clears the failure', () async {
      await failWith(503, {'detail': 'store'});
      server.on('GET', '/api/analytics/usage', usage30());
      await controller.load();
      expect(controller.failure, isNull);
      expect(controller.report, isNotNull);
    });
  });
}

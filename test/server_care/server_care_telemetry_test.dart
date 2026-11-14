import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/update_check_controller.dart';
import 'package:hermes_app/src/server_care/usage_controller.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

/// The spans of the update check and the usage read carry only their fixed
/// attributes: no profile, version, command or figure.
void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;

  ConnectionTelemetry telemetry() => ConnectionTelemetry(
    events: (name, [attributes = const {}]) => events(name, attributes),
    tracer: tracer,
    serverAttributes: const {'hermes.version': '0.22.2'},
  );

  setUp(() {
    tracer = RecordingTracer();
    events = RecordedEvents();
    server = FakeHermesServer();
    UsageController.resetRemembered();
  });

  group('server_care.update.check', () {
    UpdateCheckController build() => UpdateCheckController(
      repository: ServerCareRepository(server.client()),
      telemetry: telemetry(),
    );

    test('an available update is flags and a method, not text', () async {
      server.on('GET', '/api/hermes/update/check', updateCheckBehind());
      final controller = build();
      await controller.check(force: true);
      controller.dispose();
      final span = tracer.spans.single;
      expect(span.name, 'server_care.update.check');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'forced': true,
        'update_available': true,
        'can_apply': true,
        'install_method': 'git',
        'outcome': 'success',
      });
      expect(span.ended, isTrue);
      final text = span.attributes.values.join(' ');
      expect(text, isNot(contains('1a2b3c4')));
      expect(text, isNot(contains('docker')));
    });

    test('a managed install uses the snake case name', () async {
      server.on('GET', '/api/hermes/update/check', updateCheckManaged());
      final controller = build();
      await controller.check();
      controller.dispose();
      final span = tracer.spans.single;
      expect(span.attributes['install_method'], 'managed_runtime');
      expect(span.attributes['forced'], false);
      expect(span.attributes['update_available'], false);
      expect(span.attributes['can_apply'], false);
    });

    test('a failed check ends its span with the failure kind', () async {
      server.on('GET', '/api/hermes/update/check', {}, status: 500);
      final controller = build();
      await controller.check();
      controller.dispose();
      final span = tracer.spans.single;
      expect(span.attributes['outcome'], 'server');
      expect(span.attributes.containsKey('install_method'), isFalse);
      expect(span.ended, isTrue);
    });

    test('a missing route is unsupported', () async {
      server.on('GET', '/api/hermes/update/check', {
        'detail': 'Not Found',
      }, status: 404);
      final controller = build();
      await controller.check();
      controller.dispose();
      expect(tracer.spans.single.attributes['outcome'], 'unsupported');
    });
  });

  group('server_care.usage.fetch', () {
    UsageController build() => UsageController(
      repository: ServerCareRepository(server.client()),
      profile: 'secret-profile-name',
      today: () => DateTime(2026, 11, 14, 22),
      telemetry: telemetry(),
    );

    test('carries the window and the outcome, never the profile', () async {
      server.on('GET', '/api/analytics/usage', usage30());
      final controller = build();
      await controller.load();
      controller.dispose();
      final span = tracer.spans.single;
      expect(span.name, 'server_care.usage.fetch');
      expect(span.attributes, {
        'hermes.version': '0.22.2',
        'days': 30,
        'outcome': 'success',
      });
      expect(span.ended, isTrue);
      expect(
        span.attributes.values.join(' '),
        isNot(contains('secret-profile-name')),
      );
    });

    test('an empty window and a window switch are told apart', () async {
      server.on('GET', '/api/analytics/usage', recordedUsageEmpty());
      final controller = build();
      await controller.load();
      controller.setWindow(UsageChartWindow.days90);
      await pumpEventQueue();
      controller.dispose();
      expect(tracer.spans.map((s) => s.attributes['days']), [30, 90]);
      expect(tracer.spans.map((s) => s.attributes['outcome']), [
        'empty',
        'empty',
      ]);
    });

    test('an unreadable store is store_unreadable', () async {
      server.on('GET', '/api/analytics/usage', {
        'detail': {'path': '/secret/state.db'},
      }, status: 503);
      final controller = build();
      await controller.load();
      controller.dispose();
      final span = tracer.spans.single;
      expect(span.attributes['outcome'], 'store_unreadable');
      expect(span.attributes.values.join(' '), isNot(contains('secret')));
    });
  });
}

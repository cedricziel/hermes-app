import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/attention.dart';
import 'package:hermes_app/src/server_care/care_result.dart';
import 'package:hermes_app/src/server_care/server_attention_mark.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';
import 'server_care_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late DateTime clock;
  late bool covered;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late ServerCareController controller;

  ServerCareController build() => ServerCareController(
    repository: ServerCareRepository(server.client()),
    telemetry: ConnectionTelemetry(
      events: (name, [attributes = const {}]) => events(name, attributes),
      tracer: tracer,
      serverAttributes: const {'hermes.version': '0.22.2'},
    ),
    covered: () => covered,
    now: () => clock,
  );

  setUp(() {
    server = FakeHermesServer()..on('GET', '/api/status', statusHealthy());
    clock = DateTime(2026, 11, 14, 9);
    covered = false;
    events = RecordedEvents();
    tracer = RecordingTracer();
    controller = build();
  });

  tearDown(() => controller.dispose());

  int reads() => server.requestsTo('GET', '/api/status').length;

  test('reads the status for the chat profile and ranks it', () async {
    controller.profileChanged('work');
    await pumpEventQueue();
    expect(controller.status?.version, '0.22.2');
    expect(controller.attention, Attention.allGood);
    expect(controller.mark, ServerAttentionMark.none);
    expect(server.requestsTo('GET', '/api/status').single.queryParameters, {
      'profile': 'work',
    });
  });

  test('attention follows the status', () async {
    server.on('GET', '/api/status', {
      ...statusHealthy(),
      'gateway_running': false,
      'gateway_state': 'stopped',
    });
    await controller.refresh();
    expect(controller.attention, Attention.gatewayOff);
    expect(controller.mark, ServerAttentionMark.needsAttention);
    expect(controller.mark.accountLabel, 'Account, server needs attention');
    expect(controller.mark.menuLabel, 'Server · needs attention');
    expect(controller.mark.caption, 'Needs attention');
  });

  test('a running restart hides the gateway rows of the headline', () async {
    server.on('GET', '/api/status', {
      ...statusHealthy(),
      'gateway_running': false,
      'gateway_state': 'stopped',
    });
    await controller.refresh();
    controller.gatewayBusy = true;
    expect(controller.attention, Attention.allGood);
    controller.gatewayBusy = false;
    expect(controller.attention, Attention.gatewayOff);
  });

  test('updating and restarting outrank the problem mark', () async {
    controller.restarting = true;
    expect(controller.mark.caption, 'Restarting…');
    controller.updating = true;
    expect(controller.mark.caption, 'Updating…');
    expect(controller.mark.showsDot, isFalse);
  });

  test('an unreachable server is the offline headline', () async {
    server.on('GET', '/api/status', {}, status: 500);
    await controller.refresh();
    expect(controller.failure, CareFailureKind.server);
    expect(controller.attention, isNull);

    server.onRequest('GET', '/api/status', (o) {
      throw DioException.connectionError(requestOptions: o, reason: 'down');
    });
    await controller.refresh();
    expect(controller.attention, Attention.offline);
    expect(controller.mark, ServerAttentionMark.needsAttention);
  });

  test('a missing route hides the part and logs it once', () async {
    server.on('GET', '/api/status', {'detail': 'Not Found'}, status: 404);
    await controller.refresh();
    await controller.refresh();
    expect(controller.supported, isFalse);
    expect(controller.attention, isNull);
    expect(events.named('server_care.unsupported'), [
      {'part': 'status'},
    ]);
  });

  test('resume reads at most every five minutes', () async {
    await controller.refresh();
    expect(reads(), 1);
    clock = clock.add(const Duration(minutes: 4));
    await controller.resumed();
    expect(reads(), 1);
    clock = clock.add(const Duration(minutes: 2));
    await controller.resumed();
    expect(reads(), 2);
  });

  test('a first resume reads at once', () async {
    await controller.resumed();
    expect(reads(), 1);
  });

  test('nothing is read while App Lock covers the app', () async {
    covered = true;
    await controller.refresh();
    await controller.resumed();
    expect(reads(), 0);
    covered = false;
    await controller.refresh();
    expect(reads(), 1);
  });

  test('a late answer for the old profile is dropped', () async {
    final slow = Completer<FakeResponse>();
    server.onRequest(
      'GET',
      '/api/status',
      (o) => o.queryParameters['profile'] == 'old'
          ? slow.future
          : (status: 200, body: {...statusHealthy(), 'version': '9.9.9'}),
    );
    controller.profileChanged('old');
    await pumpEventQueue();
    controller.profileChanged('new');
    await pumpEventQueue();
    slow.complete((
      status: 200,
      body: {...statusHealthy(), 'version': '1.0.0'},
    ));
    await pumpEventQueue();
    expect(controller.status?.version, '9.9.9');
  });

  test('a failed read does not hold off the next resume', () async {
    server.on('GET', '/api/status', {}, status: 500);
    await controller.refresh();
    server.on('GET', '/api/status', statusHealthy());
    await controller.resumed();
    expect(controller.failure, isNull);
    expect(reads(), 2);
  });

  test('a resume while a read runs does not send a second one', () async {
    final slow = Completer<FakeResponse>();
    server.onRequest('GET', '/api/status', (_) => slow.future);
    final first = controller.refresh();
    await controller.resumed();
    slow.complete((status: 200, body: statusHealthy()));
    await first;
    expect(reads(), 1);
  });

  test('a read dropped under App Lock does not leave loading on', () async {
    final slow = Completer<FakeResponse>();
    server.onRequest('GET', '/api/status', (_) => slow.future);
    final read = controller.refresh();
    expect(controller.loading, isTrue);
    covered = true;
    controller.profileChanged('other');
    slow.complete((status: 200, body: statusHealthy()));
    await read;
    expect(controller.loading, isFalse);
    expect(controller.status, isNull);
  });

  test('a busy gateway of the old profile does not carry over', () async {
    await controller.refresh();
    controller.gatewayBusy = true;
    controller.profileChanged('other');
    await pumpEventQueue();
    server.on('GET', '/api/status', {
      ...statusHealthy(),
      'gateway_running': false,
      'gateway_state': 'stopped',
    });
    await controller.refresh();
    expect(controller.attention, Attention.gatewayOff);
  });

  test('the span carries only its fixed attributes, not the profile', () async {
    controller.profileChanged('secret-profile-name');
    await pumpEventQueue();
    final span = tracer.spans.single;
    expect(span.name, 'server_care.status.fetch');
    expect(span.attributes, {'hermes.version': '0.22.2', 'outcome': 'success'});
    expect(span.ended, isTrue);
  });
}

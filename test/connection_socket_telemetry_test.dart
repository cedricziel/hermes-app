import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/local_dashboard.dart';
import 'support/memory_token_store.dart';
import 'support/recording_tracer.dart';

void main() {
  late RecordingTracer tracer;
  late ConnectionTelemetry connection;

  setUp(() {
    tracer = RecordingTracer();
    connection = ConnectionTelemetry(
      tracer: tracer,
      serverAttributes: const {
        'hermes.version': '0.14.2',
        'hermes.install_id': 'inst_42',
      },
    );
  });

  test('gateway socket spans describe the server', () async {
    final gateway = connection.gateway()!;

    await gateway.connecting(() async {}, route: '/api/ws');
    gateway.finishRequest(gateway.startRequest('prompt.submit', 1));
    gateway.event('message.complete');

    expect(tracer.spans.map((s) => s.name), [
      'HTTP GET',
      'prompt.submit send',
      'message.complete receive',
    ]);
    for (final span in tracer.spans) {
      expect(span.attributes['hermes.install_id'], 'inst_42');
    }
    expect(tracer.spans.last.attributes['messaging.system'], 'hermes.gateway');
  });

  test('Kanban socket spans describe the server', () async {
    final kanban = connection.kanban()!;

    await kanban.connecting(() async {}, route: '/api/plugins/kanban/events');
    kanban.event('claimed');

    expect(tracer.spans.map((s) => s.name), ['HTTP GET', 'claimed receive']);
    for (final span in tracer.spans) {
      expect(span.attributes['hermes.version'], '0.14.2');
    }
    expect(tracer.spans.last.attributes['messaging.system'], 'hermes.kanban');
  });

  test(
    'two gateway sockets link their messages to their own upgrade',
    () async {
      final chat = connection.gateway()!;
      final shell = connection.gateway()!;

      await chat.connecting(() async {}, route: '/api/ws');
      final chatUpgrade = tracer.spans.last.spanContext;
      await shell.connecting(() async {}, route: '/api/ws');
      final shellUpgrade = tracer.spans.last.spanContext;
      chat.finishRequest(chat.startRequest('prompt.submit', 1));
      final chatRequest = tracer.spans.last;
      shell.finishRequest(shell.startRequest('session.active_list', 2));
      final shellRequest = tracer.spans.last;

      expect(chatRequest.links.single.context, chatUpgrade);
      expect(shellRequest.links.single.context, shellUpgrade);
    },
  );

  test('builds no socket tracer when telemetry is off', () {
    const off = ConnectionTelemetry();

    expect(off.gateway(), isNull);
    expect(off.kanban(), isNull);
  });

  group('HermesRepositories', () {
    late LocalDashboard a;
    late LocalDashboard b;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      a = await LocalDashboard.start({
        '/api/status': {'version': '0.14.2', 'auth_required': false},
      });
      b = await LocalDashboard.start({
        '/api/status': {'version': '0.15.0', 'auth_required': false},
      });
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    test('carry the telemetry of the connection they were built for', () async {
      final auth = AuthController(
        tokenStore: MemoryTokenStore(),
        telemetry: (attributes) =>
            ConnectionTelemetry(serverAttributes: attributes),
      );
      addTearDown(auth.dispose);

      await auth.connect(a.url);
      final first = HermesRepositories.forAuth(auth, null)!;
      await auth.connect(b.url);
      final second = HermesRepositories.forAuth(auth, first)!;

      expect(first.telemetry, isNot(same(second.telemetry)));
      expect(second.telemetry, same(auth.connectionTelemetry));
      expect(first.telemetry.serverAttributes['hermes.version'], '0.14.2');
      expect(second.telemetry.serverAttributes['hermes.version'], '0.15.0');
    });
  });
}

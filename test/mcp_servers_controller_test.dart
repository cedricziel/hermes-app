import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late McpServersController controller;
  late Completer<FakeResponse> answer;

  final grafana = mcpServerRow(name: 'grafana', url: 'https://mcp.test/mcp');

  setUp(() async {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([grafana]))
      ..on('DELETE', '/api/mcp/servers/grafana', {'ok': true});
    answer = Completer<FakeResponse>();
    server.onRequest(
      'POST',
      '/api/mcp/servers/grafana/test',
      (_) => answer.future,
    );
    controller = McpServersController(
      repository: HermesMcpRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
    addTearDown(controller.dispose);
    await controller.load();
  });

  Future<void> startTest() {
    final running = controller.test(controller.serverNamed('grafana')!);
    expect(controller.testOf('grafana'), isA<McpTestRunning>());
    return running;
  }

  test('an answer for a server removed meanwhile leaves no result', () async {
    final running = startTest();
    await controller.remove(controller.serverNamed('grafana')!);

    answer.complete((status: 200, body: mcpTestBody()));
    await running;
    await controller.load();

    expect(controller.serverNamed('grafana'), isNotNull);
    expect(controller.testOf('grafana'), isNull);
  });

  test(
    'an answer for a server listed again meanwhile leaves no result',
    () async {
      final running = startTest();
      await controller.remove(controller.serverNamed('grafana')!);
      await controller.load();

      answer.complete((status: 200, body: mcpTestBody()));
      await running;

      expect(controller.serverNamed('grafana'), isNotNull);
      expect(controller.testOf('grafana'), isNull);
    },
  );

  test('a failed request for a removed server leaves no result', () async {
    final running = startTest();
    await controller.remove(controller.serverNamed('grafana')!);
    await controller.load();

    answer.complete((status: 500, body: {'detail': 'boom'}));
    await running;

    expect(controller.testOf('grafana'), isNull);
  });

  test('an answer for a server that is still listed is kept', () async {
    final running = startTest();

    answer.complete((status: 200, body: mcpTestBody()));
    await running;

    expect(controller.testOf('grafana'), isA<McpTestFinished>());
  });
}

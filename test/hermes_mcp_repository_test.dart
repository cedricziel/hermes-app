import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesMcpRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesMcpRepository(server.client().raw);
  });

  HermesMcpServer oauthServer() => const HermesMcpServer(
    name: 'grafana',
    transport: McpTransport.remote,
    url: 'https://mcp.grafana.com/mcp',
    auth: 'oauth',
  );

  group('loadServers', () {
    test('maps a remote and a command server', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(
            name: 'grafana',
            url: 'https://mcp.grafana.com/mcp',
            auth: 'oauth',
          ),
          mcpServerRow(
            name: 'filesystem',
            command: 'npx',
            args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
            enabled: false,
          ),
        ]),
      );

      final servers = await repository.loadServers();

      expect(servers.map((s) => s.name), ['grafana', 'filesystem']);
      final grafana = servers.first;
      expect(grafana.transport, McpTransport.remote);
      expect(grafana.address, 'https://mcp.grafana.com/mcp');
      expect(grafana.auth, 'oauth');
      expect(grafana.enabled, isTrue);
      final filesystem = servers.last;
      expect(filesystem.transport, McpTransport.command);
      expect(
        filesystem.address,
        'npx -y @modelcontextprotocol/server-filesystem /tmp',
      );
      expect(filesystem.auth, isNull);
      expect(filesystem.enabled, isFalse);
    });

    test('treats a row without an enabled flag as on', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'a', url: 'https://a.test', enabled: null),
        ]),
      );

      expect((await repository.loadServers()).single.enabled, isTrue);
    });

    test('skips rows without a usable name', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'a', url: 'https://a.test'),
          {...mcpServerRow(name: 'x'), 'name': ''},
          {...mcpServerRow(name: 'x'), 'name': 7},
          {'transport': 'http'},
        ]),
      );

      final servers = await repository.loadServers();

      expect(servers.map((s) => s.name), ['a']);
    });

    test('falls back to defaults for malformed fields', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          {
            'name': 'odd',
            'transport': 3,
            'url': 4,
            'command': 'run',
            'args': 'nope',
            'auth': 5,
          },
        ]),
      );

      final odd = (await repository.loadServers()).single;

      expect(odd.transport, McpTransport.unknown);
      expect(odd.address, 'run');
      expect(odd.auth, isNull);
    });

    test('never keeps environment values', () async {
      server.on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(
            name: 'db',
            command: 'db-mcp',
            env: {'DB_PASSWORD': 'hunter2'},
          ),
        ]),
      );

      final db = (await repository.loadServers()).single;

      expect(db.address, 'db-mcp');
    });

    test('sends the profile when one is known', () async {
      server.on('GET', '/api/mcp/servers', mcpServerListBody([]));

      await repository.loadServers(profile: 'work');
      await repository.loadServers();

      final requests = server.requestsTo('GET', '/api/mcp/servers').toList();
      expect(requests.first.queryParameters['profile'], 'work');
      expect(requests.last.queryParameters.containsKey('profile'), isFalse);
    });

    test('throws when the body is not an object with a servers array', () {
      server.on('GET', '/api/mcp/servers', {'servers': 'nope'});

      expect(repository.loadServers(), throwsA(isA<FormatException>()));
    });

    test('surfaces a server error as a DioException', () {
      server.on('GET', '/api/mcp/servers', {'detail': 'boom'}, status: 500);

      expect(repository.loadServers(), throwsA(isA<DioException>()));
    });
  });

  group('setEnabled', () {
    test('puts the new value with the profile', () async {
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {
        'ok': true,
        'name': 'grafana',
        'enabled': false,
      });

      await repository.setEnabled('grafana', false, profile: 'work');

      final request = server
          .requestsTo('PUT', '/api/mcp/servers/grafana/enabled')
          .single;
      expect(jsonBody(request), {'enabled': false});
      expect(request.queryParameters['profile'], 'work');
    });

    test('surfaces a 404 as a DioException the caller can recognise', () {
      expect(
        repository.setEnabled('gone', true),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });

  group('testServer', () {
    const path = '/api/mcp/servers/grafana/test';

    test('maps the tools, prompts and resources', () async {
      server.on(
        'POST',
        path,
        mcpTestBody(
          tools: [
            mcpToolRow(
              name: 'query_prometheus',
              description: 'Run a PromQL query.',
              schemaChars: 1200,
            ),
            mcpToolRow(name: 'search_dashboards'),
          ],
          prompts: 2,
          resources: 1,
        ),
      );

      final result = await repository.testServer(
        oauthServer(),
        profile: 'work',
      );

      expect(result.ok, isTrue);
      expect(result.tools.map((t) => t.name), [
        'query_prometheus',
        'search_dashboards',
      ]);
      expect(result.tools.first.description, 'Run a PromQL query.');
      expect(result.tools.first.schemaChars, 1200);
      expect(result.tools.last.schemaChars, isNull);
      expect(result.prompts, 2);
      expect(result.resources, 1);
      expect(server.requestsTo('POST', path).single.queryParameters, {
        'profile': 'work',
      });
    });

    test('skips tools without a name', () async {
      server.on(
        'POST',
        path,
        mcpTestBody(
          tools: [
            mcpToolRow(name: 'a'),
            {'description': 'nameless'},
            {'name': '', 'description': 'empty'},
          ],
        ),
      );

      final result = await repository.testServer(oauthServer());

      expect(result.tools.map((t) => t.name), ['a']);
    });

    test('reports a failed probe with the dashboard error', () async {
      server.on('POST', path, mcpTestFailureBody('connection refused'));

      final result = await repository.testServer(oauthServer());

      expect(result.ok, isFalse);
      expect(result.error, 'connection refused');
      expect(result.signInNeeded, isFalse);
      expect(result.tools, isEmpty);
    });

    test('recognises the missing OAuth token by its prefix', () async {
      server.on(
        'POST',
        path,
        mcpTestFailureBody('OAuth authentication required — no token found.'),
      );

      final result = await repository.testServer(oauthServer());

      expect(result.signInNeeded, isTrue);
    });

    test('recognises Hermes\' non-interactive OAuth refusal', () async {
      server.on(
        'POST',
        path,
        mcpTestFailureBody(
          "MCP OAuth for 'grafana': non-interactive environment and no cached "
          'tokens found. Run `hermes mcp login grafana` interactively first '
          'to complete initial authorization.',
        ),
      );

      final result = await repository.testServer(oauthServer());

      expect(result.signInNeeded, isTrue);
    });

    test('does not read every OAuth failure as a missing token', () async {
      server.on(
        'POST',
        path,
        mcpTestFailureBody("MCP OAuth for 'grafana': token refresh failed"),
      );

      final result = await repository.testServer(oauthServer());

      expect(result.signInNeeded, isFalse);
    });

    test('only asks for sign-in on a server that uses OAuth', () async {
      server.on(
        'POST',
        path,
        mcpTestFailureBody('OAuth authentication required — no token found.'),
      );

      final result = await repository.testServer(
        const HermesMcpServer(
          name: 'grafana',
          transport: McpTransport.remote,
          url: 'https://mcp.grafana.com/mcp',
        ),
      );

      expect(result.signInNeeded, isFalse);
    });

    test('throws when the answer is not an object with ok', () {
      server.on('POST', path, ['nope']);

      expect(
        repository.testServer(oauthServer()),
        throwsA(isA<FormatException>()),
      );
    });

    test('surfaces a 404 as a DioException the caller can recognise', () {
      expect(
        repository.testServer(oauthServer()),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });

  group('removeServer', () {
    test('deletes the server with the profile', () async {
      server.on('DELETE', '/api/mcp/servers/grafana', {'ok': true});

      await repository.removeServer('grafana', profile: 'work');

      final request = server
          .requestsTo('DELETE', '/api/mcp/servers/grafana')
          .single;
      expect(request.queryParameters['profile'], 'work');
    });

    test('surfaces a 404 as a DioException the caller can recognise', () {
      expect(
        repository.removeServer('gone'),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });
}

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
      server.on('PUT', '/api/mcp/servers/gone/enabled', {
        'detail': 'Not Found',
      }, status: 404);

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
      server.on('POST', path, {'detail': 'Not Found'}, status: 404);

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
      server.on('DELETE', '/api/mcp/servers/gone', {
        'detail': 'Not Found',
      }, status: 404);

      expect(
        repository.removeServer('gone'),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });

  group('server names in paths', () {
    const awkward = {'a b?c': 'a%20b%3Fc', 'a#b': 'a%23b', 'a/b': 'a%2Fb'};

    for (final MapEntry(key: name, value: encoded) in awkward.entries) {
      test('encodes "$name" in every request', () async {
        server
          ..on('PUT', '/api/mcp/servers/$encoded/enabled', {'ok': true})
          ..on('POST', '/api/mcp/servers/$encoded/test', mcpTestBody())
          ..on('DELETE', '/api/mcp/servers/$encoded', {'ok': true});

        await repository.setEnabled(name, false);
        await repository.testServer(
          HermesMcpServer(
            name: name,
            transport: McpTransport.remote,
            url: 'https://a.test',
          ),
        );
        await repository.removeServer(name);

        expect(server.requests.map((r) => r.path), [
          '/api/mcp/servers/$encoded/enabled',
          '/api/mcp/servers/$encoded/test',
          '/api/mcp/servers/$encoded',
        ]);
        expect(server.requests.every((r) => r.queryParameters.isEmpty), isTrue);
      });
    }
  });

  group('loadCatalog', () {
    const path = '/api/mcp/catalog';

    test(
      'maps a remote OAuth entry and a command entry with a build',
      () async {
        server.on(
          'GET',
          path,
          mcpCatalogBody([
            mcpCatalogEntry(
              name: 'asana',
              description: 'Tasks, projects and workspaces.',
              source: 'https://asana.com/docs',
              url: 'https://mcp.asana.com/sse',
              authType: 'oauth',
              installed: true,
              enabled: true,
            ),
            mcpCatalogEntry(
              name: 'buildkite',
              command: 'node',
              args: ['dist/index.js'],
              installUrl: 'https://github.com/buildkite/mcp-server',
              installRef: 'v1.2.0',
              bootstrap: ['npm ci', 'npm run build'],
              requiredEnv: [
                mcpCredentialRow(name: 'BUILDKITE_TOKEN', prompt: 'API token'),
                mcpCredentialRow(name: 'BUILDKITE_ORG', required: false),
              ],
              authType: 'api_key',
            ),
          ]),
        );

        final catalog = await repository.loadCatalog(profile: 'work');

        expect(catalog.entries.map((e) => e.name), ['asana', 'buildkite']);
        final asana = catalog.entries.first;
        expect(asana.description, 'Tasks, projects and workspaces.');
        expect(asana.source, 'https://asana.com/docs');
        expect(asana.transport, McpTransport.remote);
        expect(asana.url, 'https://mcp.asana.com/sse');
        expect(asana.authKind, McpAuthKind.oauth);
        expect(asana.installed, isTrue);
        expect(asana.enabled, isTrue);
        expect(asana.buildsLocally, isFalse);
        expect(asana.requiredEnv, isEmpty);
        final buildkite = catalog.entries.last;
        expect(buildkite.transport, McpTransport.command);
        expect(buildkite.command, 'node');
        expect(buildkite.args, ['dist/index.js']);
        expect(buildkite.authKind, McpAuthKind.apiKey);
        expect(buildkite.buildsLocally, isTrue);
        expect(buildkite.installUrl, 'https://github.com/buildkite/mcp-server');
        expect(buildkite.installRef, 'v1.2.0');
        expect(buildkite.bootstrap, ['npm ci', 'npm run build']);
        expect(buildkite.installed, isFalse);
        expect(buildkite.requiredEnv.map((e) => e.name), [
          'BUILDKITE_TOKEN',
          'BUILDKITE_ORG',
        ]);
        expect(buildkite.requiredEnv.first.prompt, 'API token');
        expect(buildkite.requiredEnv.first.required, isTrue);
        expect(buildkite.requiredEnv.last.required, isFalse);
        expect(
          server.requestsTo('GET', path).single.queryParameters['profile'],
          'work',
        );
      },
    );

    test('skips entries without a usable name', () async {
      server.on('GET', path, {
        'entries': [
          mcpCatalogEntry(name: 'a', url: 'https://a.test'),
          {...mcpCatalogEntry(name: 'x'), 'name': ''},
          {...mcpCatalogEntry(name: 'x'), 'name': 7},
          {'transport': 'http'},
          'nope',
        ],
      });

      final catalog = await repository.loadCatalog();

      expect(catalog.entries.map((e) => e.name), ['a']);
    });

    test(
      'shows an entry without credentials and build steps as plain',
      () async {
        server.on(
          'GET',
          path,
          mcpCatalogBody([
            {'name': 'bare', 'transport': 'http', 'url': 'https://bare.test'},
          ]),
        );

        final bare = (await repository.loadCatalog()).entries.single;

        expect(bare.requiredEnv, isEmpty);
        expect(bare.bootstrap, isEmpty);
        expect(bare.buildsLocally, isFalse);
        expect(bare.installed, isFalse);
        expect(bare.authKind, McpAuthKind.none);
        expect(bare.description, '');
      },
    );

    test('falls back to defaults for malformed fields', () async {
      server.on(
        'GET',
        path,
        mcpCatalogBody([
          {
            'name': 'odd',
            'transport': 3,
            'auth_type': 4,
            'required_env': [
              {'name': 'OK', 'prompt': 1},
              {'prompt': 'no name'},
              'nope',
            ],
            'args': 'nope',
            'bootstrap': [1, 'make'],
            'installed': 'yes',
          },
        ]),
      );

      final odd = (await repository.loadCatalog()).entries.single;

      expect(odd.transport, McpTransport.unknown);
      expect(odd.authKind, McpAuthKind.unknown);
      expect(odd.requiredEnv.map((e) => e.name), ['OK']);
      expect(odd.requiredEnv.single.prompt, 'OK');
      expect(odd.args, isEmpty);
      expect(odd.bootstrap, ['make']);
      expect(odd.installed, isFalse);
    });

    test('counts the diagnostics', () async {
      server.on(
        'GET',
        path,
        mcpCatalogBody(
          [],
          diagnostics: [
            {'name': 'broken', 'kind': 'invalid', 'message': 'bad yaml'},
          ],
        ),
      );

      expect((await repository.loadCatalog()).hasDiagnostics, isTrue);
    });

    test('throws when the body is not an object with entries', () {
      server.on('GET', path, {'entries': 'nope'});

      expect(repository.loadCatalog(), throwsA(isA<FormatException>()));
    });

    test('surfaces a server error as a DioException', () {
      server.on('GET', path, {'detail': 'boom'}, status: 500);

      expect(repository.loadCatalog(), throwsA(isA<DioException>()));
    });
  });

  group('installEntry', () {
    const path = '/api/mcp/catalog/install';

    HermesMcpCatalogEntry entry({List<HermesMcpCredential> env = const []}) =>
        HermesMcpCatalogEntry(
          name: 'airtable',
          transport: McpTransport.remote,
          url: 'https://mcp.airtable.com/mcp',
          authKind: McpAuthKind.apiKey,
          requiredEnv: env,
        );

    const key = HermesMcpCredential(name: 'AIRTABLE_API_KEY', prompt: 'Token');
    const optional = HermesMcpCredential(
      name: 'AIRTABLE_BASE',
      prompt: 'Base',
      required: false,
    );

    test('sends the name, the enable flag and the profile', () async {
      server.on('POST', path, mcpInstallBody(name: 'airtable'));

      final result = await repository.installEntry(
        entry(),
        enable: false,
        profile: 'work',
      );

      final request = server.requestsTo('POST', path).single;
      expect(jsonBody(request), {
        'name': 'airtable',
        'env': {},
        'enable': false,
      });
      expect(request.queryParameters['profile'], 'work');
      expect(result.background, isFalse);
      expect(result.action, isNull);
    });

    test('sends only the credentials the entry declares', () async {
      server.on('POST', path, mcpInstallBody(name: 'airtable'));

      await repository.installEntry(
        entry(env: [key]),
        env: {'AIRTABLE_API_KEY': 'pat-1', 'PATH': '/evil'},
      );

      expect(jsonBody(server.requestsTo('POST', path).single), {
        'name': 'airtable',
        'env': {'AIRTABLE_API_KEY': 'pat-1'},
        'enable': true,
      });
    });

    test('leaves out empty credentials', () async {
      server.on('POST', path, mcpInstallBody(name: 'airtable'));

      await repository.installEntry(
        entry(env: [key, optional]),
        env: {'AIRTABLE_API_KEY': 'pat-1', 'AIRTABLE_BASE': ''},
      );

      expect(
        (jsonBody(server.requestsTo('POST', path).single)! as Map)['env'],
        {'AIRTABLE_API_KEY': 'pat-1'},
      );
    });

    test('reads a background install', () async {
      server.on(
        'POST',
        path,
        mcpInstallBody(name: 'buildkite', action: 'mcp-install-buildkite-ab12'),
      );

      final result = await repository.installEntry(entry());

      expect(result.background, isTrue);
      expect(result.action, 'mcp-install-buildkite-ab12');
    });

    test('treats a background answer without an action as a failure', () {
      server.on('POST', path, {'ok': true, 'name': 'x', 'background': true});

      expect(repository.installEntry(entry()), throwsA(isA<FormatException>()));
    });

    test('turns a 400 into a refusal with Hermes\' reason', () {
      server.on('POST', path, {
        'detail': "Catalog entry 'airtable' does not declare environment variable(s): X",
      }, status: 400);

      expect(
        repository.installEntry(entry()),
        throwsA(
          isA<McpRefused>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.reason, 'reason', contains('does not declare')),
        ),
      );
    });

    test('surfaces a 404 as a DioException the caller can recognise', () {
      server.on('POST', path, {'detail': 'No catalog entry'}, status: 404);

      expect(
        repository.installEntry(entry()),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });

    test('leaves a server error as a DioException', () {
      server.on('POST', path, {'detail': 'boom'}, status: 500);

      expect(repository.installEntry(entry()), throwsA(isA<DioException>()));
    });
  });

  group('actionStatus', () {
    const path = '/api/actions/mcp-install-buildkite-ab12/status';

    test('reads a running build', () async {
      server.on('GET', path, jobStatusBody(running: true, exitCode: null));

      final action = await repository.actionStatus(
        'mcp-install-buildkite-ab12',
      );

      expect(action.running, isTrue);
      expect(action.exitCode, isNull);
    });

    test('reads the exit code and the log lines of a finished build', () async {
      server.on(
        'GET',
        path,
        jobStatusBody(exitCode: 1, lines: ['cloning', 'npm ERR! failed']),
      );

      final action = await repository.actionStatus(
        'mcp-install-buildkite-ab12',
      );

      expect(action.running, isFalse);
      expect(action.exitCode, 1);
      expect(action.lines, ['cloning', 'npm ERR! failed']);
    });

    test('takes what is there from a malformed body', () async {
      server.on('GET', path, {'running': 'yes', 'exit_code': 'x', 'lines': 3});

      final action = await repository.actionStatus(
        'mcp-install-buildkite-ab12',
      );

      expect(action.running, isFalse);
      expect(action.exitCode, isNull);
      expect(action.lines, isEmpty);
    });

    test('throws when the answer is not an object', () {
      server.on('GET', path, ['nope']);

      expect(
        repository.actionStatus('mcp-install-buildkite-ab12'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('startSignIn', () {
    const path = '/api/mcp/servers/asana/auth';

    test('reads the flow and sends the profile', () async {
      server.on('POST', path, mcpFlowBody(flowId: 'f1'));

      final flow = await repository.startSignIn('asana', profile: 'work');

      expect(flow.flowId, 'f1');
      expect(flow.serverName, 'asana');
      expect(flow.status, McpFlowStatus.authorizationRequired);
      expect(flow.authorizationUrl, 'https://auth.example/authorize?state=s1');
      expect(server.requestsTo('POST', path).single.queryParameters, {
        'profile': 'work',
      });
    });

    test('reads a flow that already ended in an error', () async {
      server.on(
        'POST',
        path,
        mcpFlowBody(status: 'error', authorizationUrl: null, error: 'no dice'),
      );

      final flow = await repository.startSignIn('asana');

      expect(flow.status, McpFlowStatus.error);
      expect(flow.authorizationUrl, isNull);
      expect(flow.error, 'no dice');
    });

    test('throws when the flow has no id', () {
      server.on('POST', path, {'status': 'starting'});

      expect(repository.startSignIn('asana'), throwsA(isA<FormatException>()));
    });

    for (final (status, reason) in [
      (409, "MCP OAuth for 'asana' is already in progress"),
      (429, 'Too many MCP OAuth flows are already in progress'),
      (400, 'stdio servers authenticate via env keys, not OAuth'),
    ]) {
      test('turns a $status into a refusal', () {
        server.on('POST', path, {'detail': reason}, status: status);

        expect(
          repository.startSignIn('asana'),
          throwsA(
            isA<McpRefused>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.reason, 'reason', reason),
          ),
        );
      });
    }

    test('surfaces a 404 as a DioException the caller can recognise', () {
      expect(
        repository.startSignIn('asana'),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });

  group('flowStatus', () {
    const path = '/api/mcp/oauth/flows/f1';

    test('maps each status Hermes reports', () async {
      for (final (raw, expected) in [
        ('starting', McpFlowStatus.starting),
        ('authorization_required', McpFlowStatus.authorizationRequired),
        ('approved', McpFlowStatus.approved),
        ('error', McpFlowStatus.error),
        ('surprise', McpFlowStatus.unknown),
      ]) {
        server.on('GET', path, {...mcpFlowBody(status: raw), 'tools': []});

        expect((await repository.flowStatus('f1')).status, expected);
      }
    });

    test('surfaces a 404 as a DioException the caller can recognise', () {
      expect(
        repository.flowStatus('f1'),
        throwsA(
          isA<DioException>().having(isMcpNotFound, 'isMcpNotFound', isTrue),
        ),
      );
    });
  });

  group('cancelFlow', () {
    test('deletes the flow', () async {
      server.on('DELETE', '/api/mcp/oauth/flows/f1', {
        'ok': true,
        'status': 'error',
      });

      await repository.cancelFlow('f1');

      expect(
        server.requestsTo('DELETE', '/api/mcp/oauth/flows/f1'),
        hasLength(1),
      );
    });
  });
}

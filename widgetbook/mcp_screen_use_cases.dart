import 'package:flutter/material.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_add_server_screen.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_controller.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_screen.dart';
import 'package:hermes_app/src/mcp/mcp_install_panel.dart';
import 'package:hermes_app/src/mcp/mcp_json_editor_screen.dart';
import 'package:hermes_app/src/mcp/mcp_server_detail.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/mcp/mcp_sign_in_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'host.dart';

/// A profile with an OAuth server, a switched-off command server and a catalog
/// of a few entries, for every MCP screen.
FakeHermesServer mcpServer({bool empty = false}) => FakeHermesServer()
  ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
  ..on(
    'GET',
    '/api/mcp/servers',
    mcpServerListBody(
      empty
          ? []
          : [
              mcpServerRow(
                name: 'grafana',
                url: 'https://mcp.grafana.com/mcp',
                auth: 'oauth',
              ),
              mcpServerRow(
                name: 'filesystem',
                command: 'npx',
                args: ['-y', '@modelcontextprotocol/server-filesystem'],
                env: {'FS_TOKEN': 'x'},
                enabled: false,
              ),
            ],
    ),
  )
  ..on(
    'POST',
    '/api/mcp/servers/grafana/test',
    mcpTestBody(
      tools: [
        mcpToolRow(
          name: 'search_dashboards',
          description: 'Find dashboards by title or tag.',
          schemaChars: 320,
        ),
        mcpToolRow(
          name: 'query_prometheus',
          description: 'Run a PromQL query.',
        ),
      ],
      prompts: 1,
    ),
  )
  ..on('POST', '/api/mcp/servers', mcpServerRow(name: 'new'))
  ..on('PUT', '/api/mcp/servers', {'ok': true})
  ..on('GET', '/api/config', {
    'model': 'hermes-4',
    'mcp_servers': {
      'grafana': {'url': 'https://mcp.grafana.com/mcp', 'auth': 'oauth'},
      'filesystem': {
        'command': 'npx',
        'args': ['-y', '@modelcontextprotocol/server-filesystem'],
        'env': {'FS_TOKEN': 'x'},
        'enabled': false,
      },
    },
  })
  ..on(
    'GET',
    '/api/mcp/catalog',
    mcpCatalogBody([
      mcpCatalogEntry(
        name: 'airtable',
        description: 'Read and write Airtable bases.',
        url: 'https://mcp.airtable.com/mcp',
        authType: 'api_key',
        requiredEnv: [
          mcpCredentialRow(
            name: 'AIRTABLE_API_KEY',
            prompt: 'Personal access token',
          ),
        ],
      ),
      mcpCatalogEntry(
        name: 'buildkite',
        description: 'Pipelines and builds.',
        command: 'node',
        args: ['dist/index.js', '--stdio'],
        installUrl: 'https://github.com/buildkite/mcp-server',
        installRef: 'v1.2.0',
        bootstrap: ['npm ci', 'npm run build'],
      ),
      mcpCatalogEntry(
        name: 'grafana',
        description: 'Dashboards and metrics.',
        url: 'https://mcp.grafana.com/mcp',
        authType: 'oauth',
        installed: true,
        enabled: true,
      ),
      mcpCatalogEntry(
        name: 'context7',
        description: 'Up-to-date library docs.',
        url: 'https://mcp.context7.com/mcp',
      ),
    ]),
  )
  ..on(
    'GET',
    '/api/mcp/oauth/flows/flow-1',
    mcpFlowBody(authorizationUrl: 'https://auth.example/authorize?state=s1'),
  );

Future<McpServersController> _servers(FakeHermesServer server) async {
  final controller = McpServersController(
    repository: HermesMcpRepository(server.client().raw),
    profiles: HermesProfilesRepository(server.client().raw),
    launchLink: (_) async => true,
  );
  await controller.load();
  return controller;
}

WidgetbookUseCase _withServers(
  String name,
  Widget Function(McpServersController servers) build, {
  FakeHermesServer Function()? server,
  Future<void> Function(McpServersController servers)? prepare,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<McpServersController>(
    create: () async {
      final servers = await _servers((server ?? mcpServer)());
      await prepare?.call(servers);
      return servers;
    },
    dispose: (servers) => servers.dispose(),
    builder: (_, servers) => build(servers),
  ),
);

WidgetbookUseCase _list(String name, {bool empty = false}) => WidgetbookUseCase(
  name: name,
  builder: (_) => McpServersScreen(
    repository: HermesMcpRepository(mcpServer(empty: empty).client().raw),
    profiles: HermesProfilesRepository(mcpServer().client().raw),
    launchLink: (_) async => true,
  ),
);

WidgetbookNode mcpScreensNode() => WidgetbookFolder(
  name: 'MCP screens',
  children: [
    WidgetbookComponent(
      name: 'McpServersScreen',
      useCases: [_list('Servers'), _list('No servers', empty: true)],
    ),
    WidgetbookComponent(
      name: 'McpServerDetail',
      useCases: [
        _withServers(
          'Tested OAuth server',
          (servers) => Scaffold(
            body: McpServerDetail(controller: servers, name: 'grafana'),
          ),
          prepare: (servers) => servers.test(servers.serverNamed('grafana')!),
        ),
        _withServers(
          'Command server, switched off',
          (servers) => Scaffold(
            body: McpServerDetail(controller: servers, name: 'filesystem'),
          ),
        ),
        _withServers(
          'Page',
          (servers) => McpServerPage(controller: servers, name: 'grafana'),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpAddServerScreen',
      useCases: [
        _withServers('Form', (servers) => McpAddServerScreen(servers: servers)),
      ],
    ),
    WidgetbookComponent(
      name: 'McpJsonEditorScreen',
      useCases: [
        _withServers(
          'Editor',
          (servers) => McpJsonEditorScreen(servers: servers),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpCatalogScreen',
      useCases: [
        _withServers(
          'Catalog',
          (servers) => McpCatalogScreen(servers: servers),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpInstallPanel',
      useCases: [
        for (final (name, entry) in [
          ('Needs a credential', 'airtable'),
          ('Built on the server', 'buildkite'),
          ('No setup', 'context7'),
        ])
          WidgetbookUseCase(
            name: name,
            builder: (_) =>
                Hosted<(McpServersController, McpCatalogController)>(
                  create: () async {
                    final servers = await _servers(mcpServer());
                    final catalog = McpCatalogController(servers);
                    await catalog.load();
                    return (servers, catalog);
                  },
                  dispose: (pair) {
                    pair.$2.dispose();
                    pair.$1.dispose();
                  },
                  builder: (_, pair) => Scaffold(
                    body: McpInstallPanel(
                      servers: pair.$1,
                      catalog: pair.$2,
                      entry: pair.$2.entries!.firstWhere(
                        (e) => e.name == entry,
                      ),
                    ),
                  ),
                ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'McpSignInScreen',
      useCases: [
        _withServers(
          'Waiting for approval',
          (servers) => McpSignInScreen(
            controller: servers,
            server: servers.serverNamed('grafana')!,
            flow: const HermesMcpFlow(
              flowId: 'flow-1',
              status: McpFlowStatus.authorizationRequired,
              authorizationUrl: 'https://auth.example/authorize?state=s1',
            ),
            pollInterval: const Duration(days: 1),
          ),
        ),
      ],
    ),
  ],
);

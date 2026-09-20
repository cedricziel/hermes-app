import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The MCP servers screen and everything reached from it: the detail with its
/// tools, sign-in, the catalog and install, the add-server form, the JSON
/// editor and the review of a command server. The widest layout starts at 900
/// logical pixels, where the detail sits beside the list.
void main() {
  late FakeHermesServer server;
  final launched = <Uri>[];

  const approvalUrl = 'https://auth.example/authorize?state=s1';
  const longName = 'a-really-long-server-name-that-keeps-going-on';
  const longUrl =
      'https://mcp.internal.example-corp.com/tenants/engineering/platform/'
      'observability/v2/streamable-http-endpoint';

  final grafana = mcpServerRow(
    name: 'grafana',
    url: 'https://mcp.grafana.com/mcp',
    auth: 'oauth',
  );
  final asana = mcpServerRow(
    name: 'asana',
    url: 'https://mcp.asana.com/sse',
    auth: 'oauth',
  );
  final flaky = mcpServerRow(name: 'flaky', url: 'https://flaky.example/mcp');
  final notes = mcpServerRow(
    name: 'notes-fs',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem', '/srv/my notes'],
    env: {'NOTES_TOKEN': 'secret'},
  );
  final filesystem = mcpServerRow(
    name: 'filesystem',
    command: 'uvx',
    args: ['mcp-server-filesystem'],
    enabled: false,
  );
  final long = mcpServerRow(name: longName, url: longUrl, auth: 'oauth');

  final allServers = [grafana, asana, flaky, notes, filesystem, long];

  void listServers(List<Map<String, Object?>> rows) =>
      server.on('GET', '/api/mcp/servers', mcpServerListBody(rows));

  setUp(() {
    launched.clear();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'POST',
        '/api/mcp/servers/grafana/test',
        mcpTestBody(
          tools: [
            mcpToolRow(
              name: 'query_prometheus',
              description: 'Run a PromQL query against a data source.',
              schemaChars: 1200,
            ),
            mcpToolRow(
              name: 'search_dashboards',
              description:
                  'Find dashboards by title, tag, folder or the panels they '
                  'contain, and return their uids so they can be opened',
              schemaChars: 640,
            ),
            mcpToolRow(name: 'get_dashboard_by_uid', schemaChars: 900),
            mcpToolRow(
              name: 'list_alert_rules_in_a_very_long_named_folder_group',
              description: 'Alert rules.',
              schemaChars: 300,
            ),
          ],
          prompts: 2,
          resources: 1,
        ),
      )
      ..on(
        'POST',
        '/api/mcp/servers/asana/test',
        mcpTestFailureBody('OAuth authentication required — no token found.'),
      )
      ..on(
        'POST',
        '/api/mcp/servers/flaky/test',
        mcpTestFailureBody(
          'Connection refused: could not reach https://flaky.example/mcp '
          '(ECONNREFUSED after 3 retries)',
        ),
      )
      ..on(
        'POST',
        '/api/mcp/servers/notes-fs/test',
        mcpTestBody(tools: [mcpToolRow(name: 'read_file', schemaChars: 250)]),
      )
      ..on('POST', '/api/mcp/servers/$longName/test', {
        'detail': 'boom',
      }, status: 500)
      ..on('PUT', '/api/mcp/servers/grafana/enabled', {'ok': true});
    listServers(allServers);
  });

  Future<void> pumpMcp(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      shots,
      McpServersScreen(
        repository: HermesMcpRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        launchLink: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
      size: size,
      brightness: brightness,
    );
  }

  Finder row(String name) => find.byKey(ValueKey('mcp-row-$name'));

  bool isWide(Size size) => size.width >= mcpWideBreakpointForTest;

  /// Opens a server: a page on a phone, the pane beside the list on desktop.
  Future<void> select(WidgetTester tester, Size size, String name) async {
    await tester.tap(row(name));
    await tester.pumpAndSettle();
  }

  Future<void> leaveDetail(WidgetTester tester, Size size) async {
    if (!isWide(size)) await popRoute(tester);
  }

  Future<void> testConnection(WidgetTester tester) async {
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
  }

  /// Lets requests and page transitions get going without waiting for a
  /// spinner, which never settles.
  Future<void> frames(WidgetTester tester, [int count = 8]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> openAddMenu(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Future<void> openCatalog(WidgetTester tester) async {
    await openAddMenu(tester);
    await tester.tap(find.text('Browse the catalog'));
    await tester.pumpAndSettle();
  }

  Future<void> openCustomForm(WidgetTester tester) async {
    await openAddMenu(tester);
    await tester.tap(find.text('Add a custom server'));
    await tester.pumpAndSettle();
  }

  Future<void> openJsonEditor(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit as JSON'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: servers, detail and tools', (tester) async {
      final shots = ScreenshotRecorder('mcp-servers-$name');
      await pumpMcp(tester, shots, size: size);
      await shots.capture(tester, 'list');

      await select(tester, size, 'grafana');
      await shots.capture(tester, 'detail');
      await testConnection(tester);
      await shots.capture(tester, 'tools');
      await leaveDetail(tester, size);

      await select(tester, size, 'asana');
      await testConnection(tester);
      await shots.capture(tester, 'sign-in-needed');
      await leaveDetail(tester, size);

      await select(tester, size, 'flaky');
      await testConnection(tester);
      await shots.capture(tester, 'failing');
      await leaveDetail(tester, size);

      await select(tester, size, 'notes-fs');
      await testConnection(tester);
      await shots.capture(tester, 'command-server');
      await leaveDetail(tester, size);

      await select(tester, size, 'filesystem');
      await shots.capture(tester, 'disabled');
      await leaveDetail(tester, size);

      await select(tester, size, longName);
      await shots.capture(tester, 'long-name');
      await testConnection(tester);
      await shots.capture(tester, 'could-not-test');
      await leaveDetail(tester, size);

      await shots.capture(tester, 'list-after-tests');
    });

    testWidgets('$name: remove and switch failure', (tester) async {
      final shots = ScreenshotRecorder('mcp-manage-$name');
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {
        'detail': 'boom',
      }, status: 500);
      await pumpMcp(tester, shots, size: size);

      await tester.tap(
        find.descendant(of: row('grafana'), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switch-failed');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      await select(tester, size, 'flaky');
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'remove-dialog');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('$name: sign in', (tester) async {
      final shots = ScreenshotRecorder('mcp-sign-in-$name');
      server
        ..on(
          'POST',
          '/api/mcp/servers/grafana/auth',
          mcpFlowBody(server: 'grafana', authorizationUrl: approvalUrl),
        )
        ..on(
          'GET',
          '/api/mcp/oauth/flows/flow-1',
          mcpFlowBody(server: 'grafana', authorizationUrl: approvalUrl),
        )
        ..on('DELETE', '/api/mcp/oauth/flows/flow-1', {
          'ok': true,
          'status': 'error',
        });
      await pumpMcp(tester, shots, size: size);
      await select(tester, size, 'grafana');
      await tester.tap(find.text('Sign in'));
      await frames(tester);
      await shots.capture(tester, 'waiting');

      server.on(
        'GET',
        '/api/mcp/oauth/flows/flow-1',
        mcpFlowBody(
          server: 'grafana',
          status: 'error',
          error: 'Authorization failed: the provider rejected the request',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await frames(tester);
      await shots.capture(tester, 'failed');

      server.on('GET', '/api/mcp/oauth/flows/flow-1', {
        'detail': 'OAuth flow not found or expired',
      }, status: 404);
      await tester.tap(find.text('Try again'));
      await frames(tester);
      await tester.pump(const Duration(seconds: 2));
      await frames(tester);
      await shots.capture(tester, 'expired');

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await drain(tester);
    });

    testWidgets('$name: empty, loading and error states', (tester) async {
      final shots = ScreenshotRecorder('mcp-states-$name');
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', '/api/mcp/servers', (_) => answer.future);
      await shots.start(tester, size);
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: withScreenshotFont(buildHermesLightTheme()),
            home: McpServersScreen(
              repository: HermesMcpRepository(server.client().raw),
              profiles: HermesProfilesRepository(server.client().raw),
            ),
          ),
        ),
      );
      await frames(tester, 4);
      await shots.capture(tester, 'loading');
      answer.complete((status: 200, body: mcpServerListBody([])));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'empty');

      server.on('GET', '/api/mcp/servers', {'detail': 'boom'}, status: 500);
      await pumpMcp(tester, shots, size: size);
      await shots.capture(tester, 'error');
    });
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: catalog and install', (tester) async {
      final shots = ScreenshotRecorder('mcp-catalog-$name');
      final serverRows = [grafana];
      var catalogRows = [
        mcpCatalogEntry(
          name: 'grafana',
          description: 'Dashboards and metrics.',
          url: 'https://mcp.grafana.com/mcp',
          authType: 'oauth',
          installed: true,
          enabled: true,
        ),
        mcpCatalogEntry(
          name: 'airtable',
          description: 'Read and write Airtable bases.',
          source: 'https://airtable.com/developers',
          url: 'https://mcp.airtable.com/mcp',
          authType: 'api_key',
          requiredEnv: [
            mcpCredentialRow(
              name: 'AIRTABLE_API_KEY',
              prompt: 'Personal access token',
            ),
            mcpCredentialRow(
              name: 'AIRTABLE_BASE',
              prompt: 'Default base',
              required: false,
            ),
          ],
        ),
        mcpCatalogEntry(
          name: 'buildkite',
          description:
              'Pipelines and builds, with a description long enough that it '
              'has to wrap onto a second line and then be cut off after that',
          command: 'node',
          args: ['dist/index.js', '--stdio'],
          installUrl: 'https://github.com/buildkite/mcp-server',
          installRef: 'v1.2.0',
          bootstrap: ['npm ci', 'npm run build'],
        ),
        mcpCatalogEntry(
          name: 'context7',
          description: 'Up-to-date library docs.',
          url: 'https://mcp.context7.com/mcp',
        ),
        mcpCatalogEntry(
          name: 'mystery',
          description: 'Hermes did not say how this one connects.',
        )..['transport'] = 'unknown',
      ];
      server
        ..onRequest(
          'GET',
          '/api/mcp/servers',
          (_) => (status: 200, body: mcpServerListBody(serverRows)),
        )
        ..onRequest(
          'GET',
          '/api/mcp/catalog',
          (_) => (
            status: 200,
            body: mcpCatalogBody(
              catalogRows,
              diagnostics: [
                {'entry': 'broken', 'error': 'no transport'},
              ],
            ),
          ),
        )
        ..onRequest('POST', '/api/mcp/catalog/install', (request) {
          final body = jsonBodyOf(request);
          final entry = body['name'] as String;
          if (entry == 'buildkite') {
            return (
              status: 200,
              body: mcpInstallBody(name: entry, action: 'mcp-install-bk'),
            );
          }
          serverRows.add(mcpServerRow(name: entry, url: 'https://$entry.test'));
          catalogRows = [
            for (final r in catalogRows)
              r['name'] == entry ? {...r, 'installed': true} : r,
          ];
          return (status: 200, body: mcpInstallBody(name: entry));
        })
        ..on(
          'GET',
          '/api/actions/mcp-install-bk/status',
          jobStatusBody(name: 'mcp-install-bk', running: true, exitCode: null),
        );

      await pumpMcp(tester, shots, size: size);
      await openAddMenu(tester);
      await shots.capture(tester, 'add-menu');
      await tester.tap(find.text('Browse the catalog'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'catalog');

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'no-match');
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      final wide = isWide(size);
      Future<void> openEntry(String entry) async {
        await tester.tap(find.byKey(ValueKey('mcp-catalog-row-$entry')));
        await tester.pumpAndSettle();
      }

      await openEntry('mystery');
      await shots.capture(tester, 'unknown-transport');
      if (!wide) await popRoute(tester);

      await openEntry('airtable');
      await shots.capture(tester, 'install-form');
      await tester.enterText(field('AIRTABLE_API_KEY'), 'pat-123456');
      await animate(tester);
      await shots.capture(tester, 'install-form-filled');
      if (!wide) await popRoute(tester);

      await openEntry('buildkite');
      await shots.capture(tester, 'builds-locally');
      final button = find.byKey(const ValueKey('mcp-install-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await frames(tester, 4);
      await tester.pump(const Duration(seconds: 2));
      await frames(tester, 4);
      await shots.capture(tester, 'building');

      server.on(
        'GET',
        '/api/actions/mcp-install-bk/status',
        jobStatusBody(
          name: 'mcp-install-bk',
          exitCode: 1,
          lines: [
            for (var i = 1; i <= 8; i++) 'npm ci: step $i of 8 done',
            'npm ERR! code ELIFECYCLE',
            'npm ERR! errno 1',
            'npm ERR! buildkite-mcp@1.2.0 build: `tsc -p .` failed with a very '
                'long line that has to wrap inside the log box',
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'build-failed');
      if (!wide) await popRoute(tester);

      await openEntry('context7');
      await shots.capture(tester, 'remote-no-auth');
      final install = find.byKey(const ValueKey('mcp-install-button'));
      await tester.ensureVisible(install);
      await tester.tap(install);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'installed');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      await openEntry('grafana');
      await shots.capture(tester, 'installed-entry-detail');
      await drain(tester);
    });
  }

  testWidgets('desktop: catalog before anything is picked', (tester) async {
    final shots = ScreenshotRecorder('mcp-catalog-desktop-empty-pane');
    server.on(
      'GET',
      '/api/mcp/catalog',
      mcpCatalogBody([
        mcpCatalogEntry(name: 'context7', description: 'Library docs.'),
      ]),
    );
    await pumpMcp(tester, shots, size: desktopSize);
    await openCatalog(tester);
    await shots.capture(tester, 'nothing-picked');
    server.on('GET', '/api/mcp/catalog', {'detail': 'boom'}, status: 500);
    await popRoute(tester);
    await openCatalog(tester);
    await shots.capture(tester, 'catalog-error');
  });

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: add a custom server', (tester) async {
      final shots = ScreenshotRecorder('mcp-add-$name');
      server.onRequest('POST', '/api/mcp/servers', (request) {
        final body = jsonBodyOf(request);
        if (body['name'] == 'grafana') {
          return (status: 409, body: {'detail': 'exists'});
        }
        return (status: 200, body: mcpServerRow(name: 'x'));
      });
      await pumpMcp(tester, shots, size: size);
      await openCustomForm(tester);
      await shots.capture(tester, 'remote-empty');

      await tester.enterText(field('Name'), 'linear');
      await tester.enterText(field('URL'), 'ftp://nope');
      await animate(tester);
      await shots.capture(tester, 'bad-url');

      await tester.enterText(field('URL'), 'https://mcp.linear.app/mcp');
      await tester.tap(find.text('Bearer token'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Bearer token'), 'lin_api_secret');
      await animate(tester);
      await shots.capture(tester, 'bearer-token');

      await tester.tap(find.text('OAuth').last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'oauth');

      await tester.enterText(field('Name'), 'grafana');
      await animate(tester);
      await tester.tap(find.byKey(const ValueKey('mcp-add-server-button')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'name-taken');

      await tester.tap(find.text('Command').first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'command-empty');

      await tester.enterText(field('Name'), 'notes-fs');
      await tester.enterText(field('Command'), 'npx');
      await tester.enterText(
        field('Arguments (one per line)'),
        '-y\n@modelcontextprotocol/server-filesystem\n/srv/my notes',
      );
      await tester.ensureVisible(find.text('Add variable'));
      await tester.tap(find.text('Add variable'));
      await animate(tester);
      await tester.enterText(field('Variable name').last, 'NOTES_TOKEN');
      await tester.enterText(field('Value').last, 'hunter2');
      await tester.tap(find.text('Add variable'));
      await animate(tester);
      await tester.enterText(field('Variable name').last, '1BAD NAME');
      await animate(tester);
      await shots.capture(tester, 'command-env-error');

      await tester.enterText(field('Variable name').last, 'NOTES_DIR');
      await tester.enterText(field('Value').last, '/srv/my notes');
      await animate(tester);
      await shots.capture(tester, 'command-filled');

      await tester.tap(find.byKey(const ValueKey('mcp-add-server-button')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'review');

      await tester.tap(find.byKey(const ValueKey('mcp-review-back')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'back-to-edit');
    });

    testWidgets('$name: edit as JSON', (tester) async {
      final shots = ScreenshotRecorder('mcp-json-$name');
      server
        ..on('GET', '/api/config', {
          'model': 'x',
          'mcp_servers': {
            'grafana': {
              'url': 'https://mcp.grafana.com/mcp',
              'auth': 'oauth',
              'timeout': 45,
              'headers': {'X-Team': 'infra'},
            },
            'fs': {
              'command': 'npx',
              'args': ['-y', 'pkg'],
              'env': {'FS_TOKEN': 'env-secret-value'},
              'enabled': false,
            },
          },
        })
        ..on('PUT', '/api/mcp/servers', {
          'detail': "Server 'fs': expected an object; Server 'x': needs a url",
        }, status: 400);
      await pumpMcp(tester, shots, size: size);
      await openJsonEditor(tester);
      await shots.capture(tester, 'loaded');

      final editor = find.byKey(const ValueKey('mcp-json-text'));
      await tester.enterText(editor, '{\n  "grafana": {\n    "url": ');
      await animate(tester);
      await shots.capture(tester, 'invalid-json');

      await tester.enterText(
        editor,
        '{\n  "grafana": {"url": "https://mcp.grafana.com/mcp", '
        '"auth": "oauth", "timeout": 45, "headers": {"X-Team": "infra"}},\n'
        '  "fs": {"command": "npx", "args": ["-y", "pkg"], '
        '"env": {"FS_TOKEN": "env-secret-value"}, "enabled": false},\n'
        '  "x": {}\n}',
      );
      await animate(tester);
      await tester.tap(find.byKey(const ValueKey('mcp-json-save')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'server-refused');

      await tester.enterText(
        editor,
        '{\n  "grafana": {"url": "https://g.test"}\n}',
      );
      await animate(tester);
      await tester.tap(find.byKey(const ValueKey('mcp-json-save')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'delete-confirm');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.enterText(
        editor,
        '{\n  "fs2": {"command": "bash", "args": ["-c", "echo hi"], '
        '"env": {"TOKEN": "x"}},\n'
        '  "grafana": {"url": "https://mcp.grafana.com/mcp"},\n'
        '  "fs": {"command": "npx"}\n}',
      );
      await animate(tester);
      await tester.tap(find.byKey(const ValueKey('mcp-json-save')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'command-review');
      await tester.tap(find.byKey(const ValueKey('mcp-review-back')));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      await shots.capture(tester, 'discard-changes');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
    });

    testWidgets('$name: JSON editor could not load', (tester) async {
      final shots = ScreenshotRecorder('mcp-json-error-$name');
      server.on('GET', '/api/config', {'detail': 'boom'}, status: 500);
      await pumpMcp(tester, shots, size: size);
      await openJsonEditor(tester);
      await shots.capture(tester, 'load-failed');
    });
  }

  testWidgets('dark: list, tools, catalog and add form', (tester) async {
    final shots = ScreenshotRecorder('mcp-dark-desktop');
    server.on(
      'GET',
      '/api/mcp/catalog',
      mcpCatalogBody([
        mcpCatalogEntry(
          name: 'airtable',
          description: 'Read and write Airtable bases.',
          url: 'https://mcp.airtable.com/mcp',
          authType: 'api_key',
          requiredEnv: [mcpCredentialRow(name: 'AIRTABLE_API_KEY')],
        ),
      ]),
    );
    await pumpMcp(
      tester,
      shots,
      size: desktopSize,
      brightness: Brightness.dark,
    );
    await testConnection(tester);
    await shots.capture(tester, 'list-and-tools');
    await select(tester, desktopSize, 'asana');
    await testConnection(tester);
    await shots.capture(tester, 'sign-in-needed');
    await select(tester, desktopSize, 'flaky');
    await testConnection(tester);
    await shots.capture(tester, 'failing');
    await openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('mcp-catalog-row-airtable')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'catalog-install');
    await popRoute(tester);
    await openCustomForm(tester);
    await shots.capture(tester, 'add-form');
  });

  testWidgets('dark phone: list, tools and add form', (tester) async {
    final shots = ScreenshotRecorder('mcp-dark-phone');
    await pumpMcp(tester, shots, size: phoneSize, brightness: Brightness.dark);
    await shots.capture(tester, 'list');
    await select(tester, phoneSize, 'grafana');
    await testConnection(tester);
    await shots.capture(tester, 'tools');
    await popRoute(tester);
    await select(tester, phoneSize, 'asana');
    await testConnection(tester);
    await shots.capture(tester, 'sign-in-needed');
    await popRoute(tester);
    await openCustomForm(tester);
    await shots.capture(tester, 'add-form');
  });
}

/// The breakpoint at which the MCP screens lay out a detail beside the list.
const mcpWideBreakpointForTest = McpServersScreen.wideBreakpoint;

Map<String, Object?> jsonBodyOf(RequestOptions request) =>
    (jsonBody(request)! as Map).cast<String, Object?>();

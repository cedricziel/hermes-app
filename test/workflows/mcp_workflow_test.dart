import 'dart:async';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';

import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_add_server_screen.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/mcp_install_panel.dart';
import 'package:hermes_app/src/mcp/mcp_json_editor_screen.dart';
import 'package:hermes_app/src/mcp/mcp_server_detail.dart';
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

  bool isWide(Size size) => size.width >= kWideLayoutBreakpoint;

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
    await tester.tap(find.byTooltip('Add server'));
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

  Finder field(String label) => find.byWidgetPredicate((widget) {
    if (widget is! TextField) return false;
    if (widget.decoration?.labelText == label) return true;
    return find
        .ancestor(
          of: find.byWidget(widget),
          matching: find.byWidgetPredicate(
            (row) => row is GroupedTextFieldRow && row.label == label,
          ),
        )
        .evaluate()
        .isNotEmpty;
  });

  void see(String text) => expect(find.text(text), findsOneWidget);

  void notSeen(String text) => expect(find.text(text), findsNothing);

  /// [matching] inside the server detail: the pane beside the list, or the
  /// page a phone opens.
  Finder inDetail(Finder matching) =>
      find.descendant(of: find.byType(McpServerDetail), matching: matching);

  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(McpInstallPanel), matching: matching);

  void seeInPanel(String text) =>
      expect(inPanel(find.text(text)), findsOneWidget);

  void notInPanel(String text) =>
      expect(inPanel(find.text(text)), findsNothing);

  Finder inReview(Finder matching) =>
      find.descendant(of: find.byType(McpCommandReview), matching: matching);

  void seeInReview(String text) =>
      expect(inReview(find.text(text)), findsOneWidget);

  void notInReview(String text) =>
      expect(inReview(find.text(text)), findsNothing);

  Finder inRow(String name, Finder matching) =>
      find.descendant(of: row(name), matching: matching);

  /// The requests of [method] to [path] the screen has sent so far.
  List<RequestOptions> sent(String method, String path) =>
      server.requestsTo(method, path).toList();

  bool switchOn(WidgetTester tester, String name) =>
      tester.widget<Switch>(inRow(name, find.byType(Switch))).value;

  /// Whether the filled or text button with [key] can be pressed.
  bool pressable(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: servers, detail and tools', (tester) async {
      final shots = ScreenshotRecorder('mcp-servers-$name');
      const testPath = '/api/mcp/servers';
      await pumpMcp(tester, shots, size: size);
      await shots.capture(tester, 'list');

      // The list names the profile it acts on and every server with how it
      // connects; nothing has been tested yet.
      see('MCP servers');
      see('work');
      see(
        'Changes apply from the next chat, not to one that is already '
        'running.',
      );
      for (final (server, address, facts) in [
        ('grafana', 'https://mcp.grafana.com/mcp', 'Remote · OAuth'),
        ('asana', 'https://mcp.asana.com/sse', 'Remote · OAuth'),
        ('flaky', 'https://flaky.example/mcp', 'Remote · No auth'),
        (
          'notes-fs',
          'npx -y @modelcontextprotocol/server-filesystem /srv/my notes',
          'Command',
        ),
        ('filesystem', 'uvx mcp-server-filesystem', 'Command · Off'),
        (longName, longUrl, 'Remote · OAuth'),
      ]) {
        expect(inRow(server, find.text(address)), findsOneWidget);
        expect(inRow(server, find.text(facts)), findsOneWidget);
      }
      // The rows follow the order Hermes listed the servers in.
      final tops = [
        for (final name in [
          'grafana',
          'asana',
          'flaky',
          'notes-fs',
          'filesystem',
          longName,
        ])
          tester.getTopLeft(row(name)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(6));
      expect(switchOn(tester, 'grafana'), isTrue);
      expect(switchOn(tester, 'filesystem'), isFalse);
      for (final name in [
        'grafana',
        'asana',
        'flaky',
        'notes-fs',
        'filesystem',
        longName,
      ]) {
        expect(inRow(name, find.byType(Switch)), findsOneWidget);
      }
      expect(
        server.requests.where((r) => r.path.endsWith('/test')),
        isEmpty,
        reason: 'a test runs only when asked for',
      );
      expect(
        sent('GET', '/api/mcp/servers').single.queryParameters['profile'],
        'work',
      );

      await select(tester, size, 'grafana');
      await shots.capture(tester, 'detail');
      expect(inDetail(find.text('Remote · OAuth')), findsOneWidget);
      expect(
        inDetail(find.text('https://mcp.grafana.com/mcp')),
        findsOneWidget,
      );
      expect(inDetail(find.text('Used from the next chat')), findsOneWidget);
      for (final action in ['Sign in', 'Test connection', 'Remove']) {
        expect(inDetail(find.text(action)), findsOneWidget);
      }
      expect(inDetail(find.text('Connected')), findsNothing);
      expect(sent('POST', '$testPath/grafana/test'), isEmpty);
      await testConnection(tester);
      await shots.capture(tester, 'tools');
      final grafanaTest = sent('POST', '$testPath/grafana/test').single;
      expect(grafanaTest.queryParameters['profile'], 'work');
      expect(inDetail(find.text('Connected')), findsOneWidget);
      expect(
        inDetail(find.text('4 tools · 2 prompts · 1 resource')),
        findsOneWidget,
      );
      expect(inDetail(find.text('Tools · 4')), findsOneWidget);
      for (final tool in [
        'query_prometheus',
        'search_dashboards',
        'get_dashboard_by_uid',
        'list_alert_rules_in_a_very_long_named_folder_group',
      ]) {
        expect(inDetail(find.text(tool)), findsOneWidget);
      }
      expect(
        inDetail(find.text('Run a PromQL query against a data source.')),
        findsOneWidget,
      );
      // The tools follow the order Hermes listed them in.
      final toolTops = [
        for (final tool in [
          'query_prometheus',
          'search_dashboards',
          'get_dashboard_by_uid',
          'list_alert_rules_in_a_very_long_named_folder_group',
        ])
          tester.getTopLeft(inDetail(find.text(tool))).dy,
      ];
      expect(toolTops, [...toolTops]..sort());
      expect(toolTops.toSet(), hasLength(4));
      for (final cost in [
        '1.2k chars',
        '640 chars',
        '900 chars',
        '300 chars',
      ]) {
        expect(inDetail(find.text(cost)), findsOneWidget);
      }
      if (isWide(size)) {
        expect(
          inRow('grafana', find.text('Remote · OAuth · 4 tools')),
          findsOneWidget,
        );
      }
      await leaveDetail(tester, size);
      expect(
        inRow('grafana', find.text('Remote · OAuth · 4 tools')),
        findsOneWidget,
      );

      await select(tester, size, 'asana');
      await testConnection(tester);
      await shots.capture(tester, 'sign-in-needed');
      expect(inDetail(find.text('Sign in needed')), findsOneWidget);
      expect(
        inDetail(
          find.text(
            'Hermes has no OAuth token for this server yet, so it cannot '
            'list tools.',
          ),
        ),
        findsOneWidget,
      );
      // The row's own "Sign in" is replaced by the one on the banner.
      expect(inDetail(find.text('Sign in')), findsOneWidget);
      expect(inDetail(find.text('Connected')), findsNothing);
      expect(sent('POST', '$testPath/asana/auth'), isEmpty);
      await leaveDetail(tester, size);
      expect(inRow('asana', find.text('Sign in needed')), findsOneWidget);

      await select(tester, size, 'flaky');
      await testConnection(tester);
      await shots.capture(tester, 'failing');
      expect(inDetail(find.text('Could not connect')), findsOneWidget);
      expect(
        inDetail(
          find.text(
            'Connection refused: could not reach https://flaky.example/mcp '
            '(ECONNREFUSED after 3 retries)',
          ),
        ),
        findsOneWidget,
      );
      expect(inDetail(find.text('Connected')), findsNothing);
      expect(inDetail(find.text('Sign in')), findsNothing);
      await leaveDetail(tester, size);

      await select(tester, size, 'notes-fs');
      await testConnection(tester);
      await shots.capture(tester, 'command-server');
      expect(inDetail(find.text('Command')), findsOneWidget);
      expect(
        inDetail(
          find.text(
            'npx -y @modelcontextprotocol/server-filesystem /srv/my notes',
          ),
        ),
        findsOneWidget,
      );
      expect(inDetail(find.text('Sign in')), findsNothing);
      expect(inDetail(find.text('Connected')), findsOneWidget);
      expect(
        inDetail(find.text('1 tool · 0 prompts · 0 resources')),
        findsOneWidget,
      );
      expect(inDetail(find.text('read_file')), findsOneWidget);
      expect(inDetail(find.text('250 chars')), findsOneWidget);
      await leaveDetail(tester, size);

      await select(tester, size, 'filesystem');
      await shots.capture(tester, 'disabled');
      expect(
        inDetail(find.text('Not used from the next chat')),
        findsOneWidget,
      );
      expect(inDetail(find.text('Used from the next chat')), findsNothing);
      expect(inDetail(find.text('uvx mcp-server-filesystem')), findsOneWidget);
      expect(inDetail(find.text('Connected')), findsNothing);
      expect(sent('POST', '$testPath/filesystem/test'), isEmpty);
      await leaveDetail(tester, size);

      await select(tester, size, longName);
      await shots.capture(tester, 'long-name');
      expect(inDetail(find.text(longUrl)), findsOneWidget);
      await testConnection(tester);
      await shots.capture(tester, 'could-not-test');
      expect(inDetail(find.text('Could not test $longName')), findsOneWidget);
      expect(inDetail(find.text('Retry')), findsOneWidget);
      expect(inDetail(find.text('Connected')), findsNothing);
      await leaveDetail(tester, size);

      await shots.capture(tester, 'list-after-tests');
      expect(inRow('notes-fs', find.text('Command · 1 tool')), findsOneWidget);
      expect(inRow('asana', find.text('Sign in needed')), findsOneWidget);
      expect(inRow('filesystem', find.text('Command · Off')), findsOneWidget);
      expect(inRow('flaky', find.text('Remote · No auth')), findsOneWidget);
      // One test per server asked for, in the order it was asked for, and
      // each on the profile the list names.
      final tested = server.requests.where((r) => r.path.endsWith('/test'));
      expect(
        [for (final r in tested) r.path],
        [
          '$testPath/grafana/test',
          '$testPath/asana/test',
          '$testPath/flaky/test',
          '$testPath/notes-fs/test',
          '$testPath/$longName/test',
        ],
      );
      expect(
        tested.every((r) => r.queryParameters['profile'] == 'work'),
        isTrue,
      );
    });

    testWidgets('$name: remove and switch failure', (tester) async {
      final shots = ScreenshotRecorder('mcp-manage-$name');
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {
        'detail': 'boom',
      }, status: 500);
      await pumpMcp(tester, shots, size: size);
      expect(switchOn(tester, 'grafana'), isTrue);
      expect(sent('PUT', '/api/mcp/servers/grafana/enabled'), isEmpty);

      await tester.tap(
        find.descendant(of: row('grafana'), matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switch-failed');
      // One request to turn it off, on the listed profile; the server said no,
      // so the list still shows it on and says so.
      final turnOff = sent('PUT', '/api/mcp/servers/grafana/enabled').single;
      expect(turnOff.queryParameters['profile'], 'work');
      expect(jsonBodyOf(turnOff)['enabled'], isFalse);
      see('Could not turn grafana off');
      expect(switchOn(tester, 'grafana'), isTrue);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      notSeen('Could not turn grafana off');
      expect(sent('PUT', '/api/mcp/servers/grafana/enabled'), hasLength(1));

      await select(tester, size, 'flaky');
      await tester.tap(find.byKey(const Key('mcp-remove')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'remove-dialog');
      see('Remove flaky?');
      see(
        'flaky is deleted from the work profile, not just switched off. '
        'This cannot be undone.',
      );
      see('Cancel');
      expect(sent('DELETE', '/api/mcp/servers/flaky'), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      notSeen('Remove flaky?');
      expect(sent('DELETE', '/api/mcp/servers/flaky'), isEmpty);
      // Still on flaky's detail, which still offers the removal.
      expect(inDetail(find.text('Test connection')), findsOneWidget);
      await leaveDetail(tester, size);
      expect(row('flaky'), findsOneWidget);
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
      expect(sent('POST', '/api/mcp/servers/grafana/auth'), isEmpty);
      expect(launched, isEmpty);
      await tester.tap(find.text('Sign in'));
      await frames(tester);
      await shots.capture(tester, 'waiting');
      // One sign-in on the listed profile, whose address opens in the
      // browser once.
      expect(
        sent(
          'POST',
          '/api/mcp/servers/grafana/auth',
        ).single.queryParameters['profile'],
        'work',
      );
      see('Sign in to grafana');
      see('Waiting for you to approve');
      see(
        'Approve the sign-in in your browser. It finishes on your Hermes '
        'server, so this screen closes by itself.',
      );
      see('Open the browser again');
      see('Cancel');
      expect(launched, [Uri.parse(approvalUrl)]);
      notSeen('Could not sign in');

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
      see('Could not sign in');
      see('Authorization failed: the provider rejected the request');
      see('Try again');
      see('Close');
      notSeen('Waiting for you to approve');
      expect(sent('GET', '/api/mcp/oauth/flows/flow-1'), hasLength(1));
      expect(sent('POST', '/api/mcp/servers/grafana/auth'), hasLength(1));
      expect(launched, hasLength(1));

      server.on('GET', '/api/mcp/oauth/flows/flow-1', {
        'detail': 'OAuth flow not found or expired',
      }, status: 404);
      await tester.tap(find.text('Try again'));
      await frames(tester);
      await tester.pump(const Duration(seconds: 2));
      await frames(tester);
      await shots.capture(tester, 'expired');
      // Trying again started a second sign-in, which Hermes then forgot.
      expect(sent('POST', '/api/mcp/servers/grafana/auth'), hasLength(2));
      see('The sign-in expired');
      see('Hermes dropped it. Start it again to get a new link.');
      notSeen('Could not sign in');
      expect(launched, hasLength(2));

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      // Closing a sign-in that ended cancels nothing and tests nothing.
      notSeen('The sign-in expired');
      notSeen('Sign in to grafana');
      expect(inDetail(find.text('Test connection')), findsOneWidget);
      expect(sent('DELETE', '/api/mcp/oauth/flows/flow-1'), isEmpty);
      expect(sent('POST', '/api/mcp/servers/grafana/test'), isEmpty);
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      see('MCP servers');
      notSeen('No MCP servers');
      expect(find.byTooltip('Add server'), findsNothing);
      answer.complete((status: 200, body: mcpServerListBody([])));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'empty');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      see('No MCP servers on "work"');
      see(
        'MCP servers give the agent extra tools, such as searching your '
        'documents or reading a calendar.',
      );
      see('Browse the catalog');
      see('Add a custom server');
      expect(find.byTooltip('Add server'), findsOneWidget);

      server.on('GET', '/api/mcp/servers', {'detail': 'boom'}, status: 500);
      await pumpMcp(tester, shots, size: size);
      await shots.capture(tester, 'error');
      see('Could not load MCP servers');
      see('Retry');
      notSeen('No MCP servers on "work"');
      expect(find.byTooltip('Add server'), findsNothing);
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
      see('Browse the catalog');
      see('Add a custom server');
      expect(sent('GET', '/api/mcp/catalog'), isEmpty);
      await tester.tap(find.text('Browse the catalog'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'catalog');
      expect(
        sent('GET', '/api/mcp/catalog').single.queryParameters['profile'],
        'work',
      );
      see('Catalog');
      see('Installing into: work');
      see('Search 5 servers');
      expect(find.byKey(const Key('settings-search-filter')), findsOneWidget);
      see('Some catalog entries could not be read.');
      for (final (entry, facts) in [
        ('grafana', 'Remote · OAuth · Installed'),
        ('airtable', 'Remote · API key'),
        ('buildkite', 'Command · No auth · Builds locally'),
        ('context7', 'Remote · No auth'),
        ('mystery', 'No auth'),
      ]) {
        final catalogRow = find.byKey(ValueKey('mcp-catalog-row-$entry'));
        expect(
          find.descendant(of: catalogRow, matching: find.text(entry)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: catalogRow, matching: find.text(facts)),
          findsOneWidget,
          reason: entry,
        );
      }
      see('Read and write Airtable bases.');
      expect(sent('POST', '/api/mcp/catalog/install'), isEmpty);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'no-match');
      see('No servers match');
      notSeen('Some catalog entries could not be read.');
      expect(
        find.byKey(const ValueKey('mcp-catalog-row-grafana')),
        findsNothing,
      );
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      notSeen('No servers match');
      expect(
        find.byKey(const ValueKey('mcp-catalog-row-grafana')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mcp-catalog-row-mystery')),
        findsOneWidget,
      );

      final wide = isWide(size);
      Future<void> openEntry(String entry) async {
        await tester.tap(find.byKey(ValueKey('mcp-catalog-row-$entry')));
        await tester.pumpAndSettle();
      }

      const installKey = ValueKey('mcp-install-button');

      await openEntry('mystery');
      await shots.capture(tester, 'unknown-transport');
      seeInPanel('Install mystery');
      seeInPanel('What Hermes will run');
      seeInPanel('Hermes did not say how this server connects.');
      // Nothing to run is named, so there is nothing to install.
      expect(pressable(tester, installKey), isFalse);
      if (!wide) await popRoute(tester);

      await openEntry('airtable');
      await shots.capture(tester, 'install-form');
      seeInPanel('Install airtable');
      seeInPanel('Read and write Airtable bases.');
      seeInPanel('remote (http)');
      seeInPanel('https://mcp.airtable.com/mcp');
      seeInPanel('API key');
      seeInPanel('Credentials');
      seeInPanel('Saved on your Hermes server. It is never shown again.');
      seeInPanel('Personal access token');
      seeInPanel('Default base (optional)');
      seeInPanel('Turn on after installing');
      seeInPanel('Install on "work"');
      // The required key is empty, so the button waits.
      expect(pressable(tester, installKey), isFalse);
      await tester.enterText(field('AIRTABLE_API_KEY'), 'pat-123456');
      await animate(tester);
      await shots.capture(tester, 'install-form-filled');
      expect(pressable(tester, installKey), isTrue);
      expect(
        tester.widget<TextField>(field('AIRTABLE_API_KEY')).obscureText,
        isTrue,
      );
      expect(sent('POST', '/api/mcp/catalog/install'), isEmpty);
      if (!wide) await popRoute(tester);
      expect(sent('POST', '/api/mcp/catalog/install'), isEmpty);

      await openEntry('buildkite');
      await shots.capture(tester, 'builds-locally');
      // The panel says what the server would run before anything is sent.
      seeInPanel('Install buildkite');
      seeInPanel('command (stdio)');
      seeInPanel('node');
      seeInPanel('dist/index.js --stdio');
      seeInPanel('https://github.com/buildkite/mcp-server');
      seeInPanel('v1.2.0');
      seeInPanel('npm ci');
      seeInPanel('npm run build');
      seeInPanel(
        'The build runs on your Hermes server, not on this device, and '
        'can take a while.',
      );
      expect(sent('POST', '/api/mcp/catalog/install'), isEmpty);
      final button = find.byKey(installKey);
      await tester.ensureVisible(button);
      expect(pressable(tester, installKey), isTrue);
      await tester.tap(button);
      await frames(tester, 4);
      await tester.pump(const Duration(seconds: 2));
      await frames(tester, 4);
      await shots.capture(tester, 'building');
      // Only the press sent the install, once, and the build is followed.
      final buildkite = sent('POST', '/api/mcp/catalog/install').single;
      expect(buildkite.queryParameters['profile'], 'work');
      expect(jsonBodyOf(buildkite), {
        'name': 'buildkite',
        'env': <String, Object?>{},
        'enable': true,
      });
      seeInPanel('Building on your server…');
      expect(pressable(tester, installKey), isFalse);
      expect(sent('GET', '/api/actions/mcp-install-bk/status'), hasLength(1));

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
      seeInPanel('The build failed');
      notInPanel('Building on your server…');
      expect(
        inPanel(find.textContaining('npm ERR! code ELIFECYCLE')),
        findsOneWidget,
      );
      expect(
        inPanel(find.textContaining('npm ci: step 1 of 8 done')),
        findsOneWidget,
      );
      expect(
        find.textContaining('failed with a very long line'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(installKey),
        200,
        scrollable: inPanel(find.byType(Scrollable)).first,
      );
      expect(pressable(tester, installKey), isTrue);
      expect(sent('POST', '/api/mcp/catalog/install'), hasLength(1));
      expect(sent('GET', '/api/mcp/servers'), hasLength(1));
      if (!wide) await popRoute(tester);

      await openEntry('context7');
      await shots.capture(tester, 'remote-no-auth');
      seeInPanel('Install context7');
      seeInPanel('Up-to-date library docs.');
      seeInPanel('https://mcp.context7.com/mcp');
      expect(sent('POST', '/api/mcp/catalog/install'), hasLength(1));
      final install = find.byKey(installKey);
      await tester.ensureVisible(install);
      await tester.tap(install);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'installed');
      final context7 = sent('POST', '/api/mcp/catalog/install').last;
      expect(sent('POST', '/api/mcp/catalog/install'), hasLength(2));
      expect(jsonBodyOf(context7)['name'], 'context7');
      expect(jsonBodyOf(context7)['enable'], isTrue);
      see('Installed context7');
      // A phone offers to open the new server; a wide layout shows it.
      expect(find.text('Open'), wide ? findsNothing : findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mcp-catalog-row-context7')),
          matching: find.text('Remote · No auth · Installed'),
        ),
        findsOneWidget,
      );
      expect(sent('GET', '/api/mcp/servers'), hasLength(2));
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      // The phone's note carries an action, which keeps it until it is used.
      expect(
        find.text('Installed context7'),
        wide ? findsNothing : findsOneWidget,
      );

      await openEntry('grafana');
      await shots.capture(tester, 'installed-entry-detail');
      expect(inDetail(find.text('Remote · OAuth')), findsOneWidget);
      expect(
        inDetail(find.text('https://mcp.grafana.com/mcp')),
        findsOneWidget,
      );
      expect(inDetail(find.text('Used from the next chat')), findsOneWidget);
      notSeen('Install grafana');
      expect(sent('POST', '/api/mcp/catalog/install'), hasLength(2));
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
    see('Catalog');
    see('Pick a server to see what Hermes would run.');
    expect(
      find.byKey(const ValueKey('mcp-catalog-row-context7')),
      findsOneWidget,
    );
    expect(find.byType(McpInstallPanel), findsNothing);
    expect(sent('GET', '/api/mcp/catalog'), hasLength(1));
    server.on('GET', '/api/mcp/catalog', {'detail': 'boom'}, status: 500);
    await popRoute(tester);
    await openCatalog(tester);
    await shots.capture(tester, 'catalog-error');
    expect(sent('GET', '/api/mcp/catalog'), hasLength(2));
    see('Could not load the catalog');
    see('Retry');
    notSeen('Pick a server to see what Hermes would run.');
    expect(
      find.byKey(const ValueKey('mcp-catalog-row-context7')),
      findsNothing,
    );
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
      const addKey = ValueKey('mcp-add-server-button');
      const addPath = '/api/mcp/servers';
      await pumpMcp(tester, shots, size: size);
      await openCustomForm(tester);
      await shots.capture(tester, 'remote-empty');
      see('Add server');
      see('Remote (URL)');
      see('Authentication');
      expect(field('Name'), findsOneWidget);
      expect(field('URL'), findsOneWidget);
      expect(field('Command'), findsNothing);
      expect(field('Bearer token'), findsNothing);
      expect(pressable(tester, addKey), isFalse);

      await tester.enterText(field('Name'), 'linear');
      await tester.enterText(field('URL'), 'ftp://nope');
      await animate(tester);
      await shots.capture(tester, 'bad-url');
      see('Enter an http or https address');
      expect(pressable(tester, addKey), isFalse);

      await tester.enterText(field('URL'), 'https://mcp.linear.app/mcp');
      await tester.tap(find.text('Bearer token'));
      await tester.pumpAndSettle();
      notSeen('Enter an http or https address');
      // A bearer token is asked for, and until it is there nothing can be
      // added.
      expect(field('Bearer token'), findsOneWidget);
      expect(pressable(tester, addKey), isFalse);
      await tester.enterText(field('Bearer token'), 'lin_api_secret');
      await animate(tester);
      await shots.capture(tester, 'bearer-token');
      expect(
        tester.widget<TextField>(field('Bearer token')).obscureText,
        isTrue,
      );
      see('Kept on your Hermes server. It is never shown again.');
      expect(pressable(tester, addKey), isTrue);

      await tester.tap(find.text('OAuth').last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'oauth');
      see("After adding, you sign in from the server's page.");
      expect(field('Bearer token'), findsNothing);
      expect(pressable(tester, addKey), isTrue);
      expect(sent('POST', addPath), isEmpty);

      await tester.enterText(field('Name'), 'grafana');
      await animate(tester);
      await tester.tap(find.byKey(addKey));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'name-taken');
      // A remote server is not a program on the host: it goes out at once,
      // without a review, and the form says the name is taken.
      final taken = sent('POST', addPath).single;
      expect(taken.queryParameters['profile'], 'work');
      expect(jsonBodyOf(taken)['name'], 'grafana');
      expect(jsonBodyOf(taken)['url'], 'https://mcp.linear.app/mcp');
      expect(jsonBodyOf(taken)['auth'], 'oauth');
      expect(jsonBodyOf(taken).containsKey('bearer_token'), isFalse);
      see('A server with this name already exists');
      notSeen('Run this on your server?');
      expect(find.byType(McpAddServerScreen), findsOneWidget);

      await tester.tap(find.text('Command').first);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'command-empty');
      expect(field('Command'), findsOneWidget);
      expect(field('Arguments (one per line)'), findsOneWidget);
      expect(field('URL'), findsNothing);
      see('Environment variables');
      expect(pressable(tester, addKey), isFalse);

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
      see('Use letters, digits and underscores, not starting with a digit');
      expect(pressable(tester, addKey), isFalse);

      await tester.enterText(field('Variable name').last, 'NOTES_DIR');
      await tester.enterText(field('Value').last, '/srv/my notes');
      await animate(tester);
      await shots.capture(tester, 'command-filled');
      notSeen('Use letters, digits and underscores, not starting with a digit');
      expect(pressable(tester, addKey), isTrue);
      expect(sent('POST', addPath), hasLength(1));

      await tester.tap(find.byKey(addKey));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'review');
      // The program is shown before anything is sent: the command, each
      // argument and the names of the variables, never their values.
      seeInReview('Run this on your server?');
      seeInReview(
        'A command server is a program that runs on your Hermes host, with '
        "that machine's permissions, every time a chat uses it.",
      );
      seeInReview('notes-fs');
      seeInReview('npx');
      seeInReview('-y');
      seeInReview('@modelcontextprotocol/server-filesystem');
      seeInReview('/srv/my notes');
      seeInReview('NOTES_TOKEN');
      seeInReview('NOTES_DIR');
      notInReview('hunter2');
      seeInReview('Only add commands you recognise.');
      seeInReview('Add and run on server');
      seeInReview('Back to edit');
      expect(sent('POST', addPath), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('mcp-review-back')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'back-to-edit');
      // Backing out confirms nothing: no second request, and the form is
      // as it was.
      notSeen('Run this on your server?');
      expect(sent('POST', addPath), hasLength(1));
      expect(find.byType(McpAddServerScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Command')).controller!.text,
        'npx',
      );
      expect(
        tester.widget<TextField>(field('Name')).controller!.text,
        'notes-fs',
      );
      expect(pressable(tester, addKey), isTrue);
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
      const saveKey = ValueKey('mcp-json-save');
      const replacePath = '/api/mcp/servers';
      await pumpMcp(tester, shots, size: size);
      await openJsonEditor(tester);
      await shots.capture(tester, 'loaded');
      see('Edit as JSON');
      see('work · mcp_servers');
      see('Replaces all servers of this profile.');
      expect(
        sent('GET', '/api/config').single.queryParameters['profile'],
        'work',
      );

      final editor = find.byKey(const ValueKey('mcp-json-text'));
      String text() => tester.widget<TextField>(editor).controller!.text;
      expect(text(), contains('"url": "https://mcp.grafana.com/mcp"'));
      expect(text(), contains('"FS_TOKEN": "env-secret-value"'));
      expect(text(), contains('"enabled": false'));
      expect(pressable(tester, saveKey), isFalse);
      await tester.enterText(editor, '{\n  "grafana": {\n    "url": ');
      await animate(tester);
      await shots.capture(tester, 'invalid-json');
      expect(find.byKey(const ValueKey('mcp-json-error')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mcp-json-error'))).data,
        startsWith('Line 3: '),
      );
      expect(pressable(tester, saveKey), isFalse);

      await tester.enterText(
        editor,
        '{\n  "grafana": {"url": "https://mcp.grafana.com/mcp", '
        '"auth": "oauth", "timeout": 45, "headers": {"X-Team": "infra"}},\n'
        '  "fs": {"command": "npx", "args": ["-y", "pkg"], '
        '"env": {"FS_TOKEN": "env-secret-value"}, "enabled": false},\n'
        '  "x": {}\n}',
      );
      await animate(tester);
      expect(find.byKey(const ValueKey('mcp-json-error')), findsNothing);
      expect(pressable(tester, saveKey), isTrue);
      expect(sent('PUT', replacePath), isEmpty);
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'server-refused');
      // Nothing here runs a new program, so it goes out without a review
      // and Hermes' reasons are shown under the editor.
      final refused = sent('PUT', replacePath).single;
      expect(refused.queryParameters['profile'], 'work');
      expect(
        (jsonBodyOf(refused)['servers']! as Map).keys,
        unorderedEquals(['grafana', 'fs', 'x']),
      );
      expect(find.byKey(const ValueKey('mcp-json-problems')), findsOneWidget);
      see("Server 'fs': expected an object");
      see("Server 'x': needs a url");
      notSeen('Run this on your server?');
      notSeen('Run these on your server?');
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);

      await tester.enterText(
        editor,
        '{\n  "grafana": {"url": "https://g.test"}\n}',
      );
      await animate(tester);
      expect(find.byKey(const ValueKey('mcp-json-problems')), findsNothing);
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'delete-confirm');
      see('Delete a server?');
      see('"fs" will be deleted, not just switched off.');
      see('Delete and save');
      expect(sent('PUT', replacePath), hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      notSeen('Delete a server?');
      expect(sent('PUT', replacePath), hasLength(1));

      await tester.enterText(
        editor,
        '{\n  "fs2": {"command": "bash", "args": ["-c", "echo hi"], '
        '"env": {"TOKEN": "x"}},\n'
        '  "grafana": {"url": "https://mcp.grafana.com/mcp"},\n'
        '  "fs": {"command": "npx"}\n}',
      );
      await animate(tester);
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'command-review');
      // Two command servers are new or changed, so both are reviewed and
      // nothing has been sent beyond the first refused save.
      seeInReview('Run these on your server?');
      seeInReview(
        'Command servers are programs that run on your Hermes host, with '
        "that machine's permissions, every time a chat uses them.",
      );
      seeInReview('fs2');
      seeInReview('bash');
      seeInReview('-c');
      seeInReview('echo hi');
      seeInReview('TOKEN');
      seeInReview('fs');
      seeInReview('npx');
      notInReview('grafana');
      seeInReview('Save and run on server');
      seeInReview('Back to edit');
      expect(sent('PUT', replacePath), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('mcp-review-back')));
      await tester.pumpAndSettle();
      notSeen('Run these on your server?');
      expect(sent('PUT', replacePath), hasLength(1));
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      await shots.capture(tester, 'discard-changes');
      see('Discard changes?');
      see('Your edits have not been saved.');
      see('Discard');
      see('Keep editing');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      notSeen('Discard changes?');
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);
      expect(sent('PUT', replacePath), hasLength(1));
    });

    testWidgets('$name: edit a long config as JSON', (tester) async {
      final shots = ScreenshotRecorder('mcp-json-long-$name');
      server.on('GET', '/api/config', {
        'model': 'x',
        'mcp_servers': {
          for (var i = 0; i < 30; i++)
            'server-$i': {
              'url': 'https://mcp.example.com/$i/mcp',
              'auth': 'oauth',
              'timeout': 45,
              'headers': {'X-Team': 'infra'},
            },
        },
      });
      await pumpMcp(tester, shots, size: size);
      await openJsonEditor(tester);
      await shots.capture(tester, 'loaded');
      see('Edit as JSON');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mcp-json-text')))
            .controller!
            .text,
        allOf(contains('"server-0"'), contains('"server-29"')),
      );

      // The editor keeps to the page however long the text is, so the error
      // under it stays on screen.
      await tester.enterText(
        find.byKey(const ValueKey('mcp-json-text')),
        '{\n  "grafana": {\n    "url": ',
      );
      await animate(tester);
      await shots.capture(tester, 'invalid-json');
      final error = find.byKey(const ValueKey('mcp-json-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, startsWith('Line 3: '));
      expect(tester.getRect(error).bottom, lessThanOrEqualTo(size.height));
      expect(tester.getRect(error).top, greaterThanOrEqualTo(0));
    });

    testWidgets('$name: JSON editor could not load', (tester) async {
      final shots = ScreenshotRecorder('mcp-json-error-$name');
      server.on('GET', '/api/config', {'detail': 'boom'}, status: 500);
      await pumpMcp(tester, shots, size: size);
      await openJsonEditor(tester);
      await shots.capture(tester, 'load-failed');
      see('Could not load the configuration');
      see('Retry');
      expect(find.byKey(const ValueKey('mcp-json-text')), findsNothing);
      expect(pressable(tester, const ValueKey('mcp-json-save')), isFalse);
      expect(sent('GET', '/api/config'), hasLength(1));
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
    expect(
      Theme.of(tester.element(find.byType(McpServersScreen))).brightness,
      Brightness.dark,
    );
    await testConnection(tester);
    await shots.capture(tester, 'list-and-tools');
    expect(inDetail(find.text('Connected')), findsOneWidget);
    expect(inDetail(find.text('Tools · 4')), findsOneWidget);
    expect(
      inRow('grafana', find.text('Remote · OAuth · 4 tools')),
      findsOneWidget,
    );
    await select(tester, desktopSize, 'asana');
    await testConnection(tester);
    await shots.capture(tester, 'sign-in-needed');
    expect(inDetail(find.text('Sign in needed')), findsOneWidget);
    expect(inRow('asana', find.text('Sign in needed')), findsOneWidget);
    await select(tester, desktopSize, 'flaky');
    await testConnection(tester);
    await shots.capture(tester, 'failing');
    expect(inDetail(find.text('Could not connect')), findsOneWidget);
    expect(
      [
        for (final r in server.requests.where((r) => r.path.endsWith('/test')))
          r.path,
      ],
      [
        '/api/mcp/servers/grafana/test',
        '/api/mcp/servers/asana/test',
        '/api/mcp/servers/flaky/test',
      ],
    );
    await openCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('mcp-catalog-row-airtable')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'catalog-install');
    seeInPanel('Install airtable');
    seeInPanel('https://mcp.airtable.com/mcp');
    seeInPanel('Install on "work"');
    expect(pressable(tester, const ValueKey('mcp-install-button')), isFalse);
    expect(sent('POST', '/api/mcp/catalog/install'), isEmpty);
    await popRoute(tester);
    await openCustomForm(tester);
    await shots.capture(tester, 'add-form');
    see('Add server');
    see('Remote (URL)');
    expect(field('URL'), findsOneWidget);
    expect(pressable(tester, const ValueKey('mcp-add-server-button')), isFalse);
    expect(sent('POST', '/api/mcp/servers'), isEmpty);
  });

  testWidgets('dark phone: list, tools and add form', (tester) async {
    final shots = ScreenshotRecorder('mcp-dark-phone');
    await pumpMcp(tester, shots, size: phoneSize, brightness: Brightness.dark);
    await shots.capture(tester, 'list');
    expect(
      Theme.of(tester.element(find.byType(McpServersScreen))).brightness,
      Brightness.dark,
    );
    see('MCP servers');
    expect(inRow('grafana', find.text('Remote · OAuth')), findsOneWidget);
    expect(row('filesystem'), findsOneWidget);
    await select(tester, phoneSize, 'grafana');
    await testConnection(tester);
    await shots.capture(tester, 'tools');
    expect(inDetail(find.text('Connected')), findsOneWidget);
    expect(inDetail(find.text('query_prometheus')), findsOneWidget);
    expect(inDetail(find.text('Tools · 4')), findsOneWidget);
    await popRoute(tester);
    await select(tester, phoneSize, 'asana');
    await testConnection(tester);
    await shots.capture(tester, 'sign-in-needed');
    expect(inDetail(find.text('Sign in needed')), findsOneWidget);
    await popRoute(tester);
    expect(inRow('asana', find.text('Sign in needed')), findsOneWidget);
    await openCustomForm(tester);
    await shots.capture(tester, 'add-form');
    see('Add server');
    see('Remote (URL)');
    expect(field('URL'), findsOneWidget);
    expect(pressable(tester, const ValueKey('mcp-add-server-button')), isFalse);
    expect(sent('POST', '/api/mcp/servers'), isEmpty);
  });
}

Map<String, Object?> jsonBodyOf(RequestOptions request) =>
    (jsonBody(request)! as Map).cast<String, Object?>();

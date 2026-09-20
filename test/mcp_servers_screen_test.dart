import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_add_server_screen.dart';
import 'package:hermes_app/src/mcp/mcp_server_detail.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// The MCP servers screen against a fake dashboard, through the real generated
/// client.
void main() {
  late FakeHermesServer server;

  final grafana = mcpServerRow(
    name: 'grafana',
    url: 'https://mcp.grafana.com/mcp',
    auth: 'oauth',
  );
  final filesystem = mcpServerRow(
    name: 'filesystem',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem'],
    env: {'FS_TOKEN': 'hunter2'},
    enabled: false,
  );

  void listServers(List<Map<String, Object?>> rows) =>
      server.on('GET', '/api/mcp/servers', mcpServerListBody(rows));

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    listServers([grafana, filesystem]);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: McpServersScreen(
          repository: HermesMcpRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder row(String name) => find.byKey(ValueKey('mcp-row-$name'));

  Finder inRow(String name, Finder matching) =>
      find.descendant(of: row(name), matching: matching);

  Switch switchOf(WidgetTester tester, String name) =>
      tester.widget<Switch>(inRow(name, find.byType(Switch)));

  Future<void> openDetail(WidgetTester tester, String name) async {
    await tester.tap(inRow(name, find.text(name)));
    await tester.pumpAndSettle();
  }

  Future<void> tapTest(WidgetTester tester) async {
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
  }

  group('profile', () {
    testWidgets('names the active profile and asks for its servers', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Profile: work'), findsOneWidget);
      expect(
        server
            .requestsTo('GET', '/api/mcp/servers')
            .single
            .queryParameters['profile'],
        'work',
      );
    });

    testWidgets('acts without a profile when the dashboard has none', (
      tester,
    ) async {
      server.on('GET', '/api/profiles/active', {
        'detail': 'Not Found',
      }, status: 404);

      await pumpScreen(tester);

      expect(find.textContaining('Profile:'), findsNothing);
      expect(
        server
            .requestsTo('GET', '/api/mcp/servers')
            .single
            .queryParameters
            .containsKey('profile'),
        isFalse,
      );
      expect(row('grafana'), findsOneWidget);
    });

    testWidgets('lists nothing when the profile cannot be learned', (
      tester,
    ) async {
      server.on('GET', '/api/profiles/active', {'detail': 'boom'}, status: 500);

      await pumpScreen(tester);

      expect(find.text('Could not load MCP servers'), findsOneWidget);
      expect(server.requestsTo('GET', '/api/mcp/servers'), isEmpty);
      expect(find.byType(Switch), findsNothing);

      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(row('grafana'), findsOneWidget);
      expect(find.text('Profile: work'), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets('shows a spinner while the servers load', (tester) async {
      await pumpScreen(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows each server with its address and chips', (tester) async {
      await pumpScreen(tester);

      expect(
        inRow('grafana', find.text('https://mcp.grafana.com/mcp')),
        findsOne,
      );
      expect(inRow('grafana', find.text('Remote')), findsOneWidget);
      expect(inRow('grafana', find.text('OAuth')), findsOneWidget);
      expect(inRow('grafana', find.text('Off')), findsNothing);
      expect(switchOf(tester, 'grafana').value, isTrue);

      expect(
        inRow(
          'filesystem',
          find.text('npx -y @modelcontextprotocol/server-filesystem'),
        ),
        findsOne,
      );
      expect(inRow('filesystem', find.text('Command')), findsOneWidget);
      expect(inRow('filesystem', find.text('Off')), findsOneWidget);
      expect(switchOf(tester, 'filesystem').value, isFalse);
    });

    testWidgets('says "No auth" for a remote server without sign-in', (
      tester,
    ) async {
      listServers([mcpServerRow(name: 'docs', url: 'https://docs.test/mcp')]);

      await pumpScreen(tester);

      expect(inRow('docs', find.text('No auth')), findsOneWidget);
    });

    testWidgets('leaves out rows without a name', (tester) async {
      listServers([
        grafana,
        {'transport': 'http', 'url': 'https://x.test'},
      ]);

      await pumpScreen(tester);

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('treats a server without an enabled flag as on', (
      tester,
    ) async {
      listServers([
        mcpServerRow(name: 'docs', url: 'https://docs.test', enabled: null),
      ]);

      await pumpScreen(tester);

      expect(switchOf(tester, 'docs').value, isTrue);
    });

    testWidgets('never shows environment values', (tester) async {
      await pumpScreen(tester);

      void expectNoEnvironment() {
        expect(
          find.textContaining('hunter2', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.textContaining('FS_TOKEN', skipOffstage: false),
          findsNothing,
        );
        expect(find.text('***', skipOffstage: false), findsNothing);
      }

      expect(row('filesystem'), findsOneWidget);
      expectNoEnvironment();

      await openDetail(tester, 'filesystem');
      expectNoEnvironment();
    });

    testWidgets('says changes apply from the next chat', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('next chat'), findsOneWidget);
    });

    testWidgets('offers a retry when loading fails', (tester) async {
      server.on('GET', '/api/mcp/servers', {'detail': 'boom'}, status: 500);
      await pumpScreen(tester);

      expect(find.text('Could not load MCP servers'), findsOneWidget);

      listServers([grafana]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(row('grafana'), findsOneWidget);
    });

    testWidgets('treats an unexpected body as a failed load', (tester) async {
      server.on('GET', '/api/mcp/servers', {'servers': 'nope'});

      await pumpScreen(tester);

      expect(find.text('Could not load MCP servers'), findsOneWidget);
    });

    testWidgets('explains an empty profile, naming it', (tester) async {
      listServers([]);

      await pumpScreen(tester);

      expect(find.text('No MCP servers on "work"'), findsOneWidget);
      expect(find.textContaining('extra tools'), findsOneWidget);
    });

    testWidgets('explains an empty server without a profile name', (
      tester,
    ) async {
      server.on('GET', '/api/profiles/active', {}, status: 404);
      listServers([]);

      await pumpScreen(tester);

      expect(find.text('No MCP servers'), findsOneWidget);
    });
  });

  group('switch', () {
    testWidgets('turns a server off once the dashboard has said so', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'PUT',
        '/api/mcp/servers/grafana/enabled',
        (_) => answer.future,
      );
      await pumpScreen(tester);

      await tester.tap(inRow('grafana', find.byType(Switch)));
      await tester.pump();

      expect(switchOf(tester, 'grafana').value, isTrue);
      expect(switchOf(tester, 'grafana').onChanged, isNull);

      answer.complete((status: 200, body: {'ok': true}));
      await tester.pumpAndSettle();

      final request = server
          .requestsTo('PUT', '/api/mcp/servers/grafana/enabled')
          .single;
      expect(jsonBody(request), {'enabled': false});
      expect(request.queryParameters['profile'], 'work');
      expect(switchOf(tester, 'grafana').value, isFalse);
      expect(switchOf(tester, 'grafana').onChanged, isNotNull);
      expect(inRow('grafana', find.text('Off')), findsOneWidget);
    });

    testWidgets('turns a server on', (tester) async {
      server.on('PUT', '/api/mcp/servers/filesystem/enabled', {'ok': true});
      await pumpScreen(tester);

      await tester.tap(inRow('filesystem', find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(
        jsonBody(
          server
              .requestsTo('PUT', '/api/mcp/servers/filesystem/enabled')
              .single,
        ),
        {'enabled': true},
      );
      expect(switchOf(tester, 'filesystem').value, isTrue);
      expect(inRow('filesystem', find.text('Off')), findsNothing);
    });

    testWidgets('keeps its state and says so when the request fails', (
      tester,
    ) async {
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {
        'detail': 'boom',
      }, status: 500);
      await pumpScreen(tester);

      await tester.tap(inRow('grafana', find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(find.text('Could not turn grafana off'), findsOneWidget);
      expect(switchOf(tester, 'grafana').value, isTrue);
      expect(switchOf(tester, 'grafana').onChanged, isNotNull);
    });

    testWidgets('reloads the list when the server is gone', (tester) async {
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpScreen(tester);
      listServers([filesystem]);

      await tester.tap(inRow('grafana', find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(row('grafana'), findsNothing);
      expect(row('filesystem'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('opens on tap with the server described', (tester) async {
      await pumpScreen(tester);

      await openDetail(tester, 'grafana');

      expect(find.byType(McpServerDetail), findsOneWidget);
      expect(find.text('https://mcp.grafana.com/mcp'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Remote · OAuth'), findsOneWidget);
    });

    testWidgets('shows what a successful test found', (tester) async {
      server.on(
        'POST',
        '/api/mcp/servers/grafana/test',
        mcpTestBody(
          tools: [
            mcpToolRow(
              name: 'query_prometheus',
              description: 'Run a PromQL query.',
              schemaChars: 1200,
            ),
            mcpToolRow(name: 'search_dashboards', description: 'Find them.'),
            mcpToolRow(name: 'get_dashboard', schemaChars: 900),
          ],
          prompts: 2,
        ),
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapTest(tester);

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('3 tools · 2 prompts · 0 resources'), findsOneWidget);
      expect(find.text('query_prometheus'), findsOneWidget);
      expect(find.text('Run a PromQL query.'), findsOneWidget);
      expect(find.text('1.2k chars'), findsOneWidget);
      expect(find.text('900 chars'), findsOneWidget);
      expect(find.text('search_dashboards'), findsOneWidget);
      expect(find.textContaining('chars'), findsNWidgets(2));
      expect(
        server
            .requestsTo('POST', '/api/mcp/servers/grafana/test')
            .single
            .queryParameters['profile'],
        'work',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(inRow('grafana', find.text('3 tools')), findsOneWidget);
    });

    testWidgets('shows progress and refuses a second tap while testing', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/mcp/servers/grafana/test',
        (_) => answer.future,
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tester.tap(find.text('Test connection'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Test connection'), warnIfMissed: false);
      await tester.pump();

      answer.complete((status: 200, body: mcpTestBody()));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        server.requestsTo('POST', '/api/mcp/servers/grafana/test'),
        hasLength(1),
      );
    });

    testWidgets('ignores an answer that arrives after the screen closed', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/mcp/servers/grafana/test',
        (_) => answer.future,
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tester.tap(find.text('Test connection'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      answer.complete((status: 200, body: mcpTestBody()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows Hermes\' words when the test fails', (tester) async {
      server.on(
        'POST',
        '/api/mcp/servers/grafana/test',
        mcpTestFailureBody('connection refused'),
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapTest(tester);

      expect(find.text('Could not connect'), findsOneWidget);
      expect(find.text('connection refused'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('offers a retry when the test request fails', (tester) async {
      server.on('POST', '/api/mcp/servers/grafana/test', {
        'detail': 'boom',
      }, status: 500);
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapTest(tester);

      expect(find.text('Could not test grafana'), findsOneWidget);

      server.on('POST', '/api/mcp/servers/grafana/test', mcpTestBody());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('asks to sign in when an OAuth server has no token', (
      tester,
    ) async {
      server.on(
        'POST',
        '/api/mcp/servers/grafana/test',
        mcpTestFailureBody('OAuth authentication required — no token found.'),
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapTest(tester);

      expect(find.text('Sign in needed'), findsOneWidget);
      expect(
        find.text(
          'Hermes has no OAuth token for this server yet, so it cannot list tools.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not connect'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(inRow('grafana', find.text('Sign in needed')), findsOneWidget);
    });

    testWidgets('shows any other failure of an OAuth server as such', (
      tester,
    ) async {
      server.on(
        'POST',
        '/api/mcp/servers/grafana/test',
        mcpTestFailureBody('timed out'),
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapTest(tester);

      expect(find.text('Could not connect'), findsOneWidget);
      expect(find.text('Sign in needed'), findsNothing);
    });

    testWidgets('closes and reloads when the server is gone', (tester) async {
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      listServers([filesystem]);

      await tapTest(tester);

      expect(find.byType(McpServerDetail), findsNothing);
      expect(row('grafana'), findsNothing);
      expect(row('filesystem'), findsOneWidget);
    });

    testWidgets('shows the first remaining server on a wide layout', (
      tester,
    ) async {
      server.on('POST', '/api/mcp/servers/grafana/test', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpScreen(tester, size: const Size(1200, 800));
      listServers([filesystem]);

      await tapTest(tester);

      expect(row('grafana'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(McpServerDetail),
          matching: find.text('Command'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the empty state on a wide layout when none remain', (
      tester,
    ) async {
      server.on('POST', '/api/mcp/servers/grafana/test', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpScreen(tester, size: const Size(1200, 800));
      listServers([]);

      await tapTest(tester);

      expect(find.byType(McpServerDetail), findsNothing);
      expect(find.text('No MCP servers on "work"'), findsOneWidget);
    });

    testWidgets('switches the server from its detail', (tester) async {
      server.on('PUT', '/api/mcp/servers/grafana/enabled', {'ok': true});
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        jsonBody(
          server.requestsTo('PUT', '/api/mcp/servers/grafana/enabled').single,
        ),
        {'enabled': false},
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('removal', () {
    Future<void> tapRemove(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, naming the server', (tester) async {
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');

      await tapRemove(tester);

      expect(find.text('Remove grafana?'), findsOneWidget);
      expect(find.textContaining('deleted from the work profile'), findsOne);
    });

    testWidgets('deletes on confirmation and closes the detail', (
      tester,
    ) async {
      server.on('DELETE', '/api/mcp/servers/grafana', {'ok': true});
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tapRemove(tester);
      listServers([filesystem]);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(
        server
            .requestsTo('DELETE', '/api/mcp/servers/grafana')
            .single
            .queryParameters['profile'],
        'work',
      );
      expect(find.byType(McpServerDetail), findsNothing);
      expect(row('grafana'), findsNothing);
      expect(row('filesystem'), findsOneWidget);
    });

    testWidgets('leaves an open confirmation alone when the server vanishes, '
        'and closes the page after it', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/mcp/servers/grafana/test',
        (_) => answer.future,
      );
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tester.tap(find.text('Test connection'));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Remove grafana?'), findsOneWidget);
      listServers([filesystem]);

      answer.complete((status: 404, body: {'detail': 'Not Found'}));
      await tester.pumpAndSettle();

      expect(find.text('Remove grafana?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(McpServerDetail), findsNothing);
      expect(row('filesystem'), findsOneWidget);
    });

    testWidgets('does nothing when cancelled', (tester) async {
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tapRemove(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('DELETE', '/api/mcp/servers/grafana'), isEmpty);
      expect(find.byType(McpServerDetail), findsOneWidget);
    });

    testWidgets('keeps the server and says so when it fails', (tester) async {
      server.on('DELETE', '/api/mcp/servers/grafana', {
        'detail': 'boom',
      }, status: 500);
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tapRemove(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Could not remove grafana'), findsOneWidget);
      expect(find.byType(McpServerDetail), findsOneWidget);
    });

    testWidgets('counts a server that is already gone as removed', (
      tester,
    ) async {
      server.on('DELETE', '/api/mcp/servers/grafana', {
        'detail': 'Not Found',
      }, status: 404);
      await pumpScreen(tester);
      await openDetail(tester, 'grafana');
      await tapRemove(tester);
      listServers([filesystem]);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Could not remove grafana'), findsNothing);
      expect(row('grafana'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('shows the list alone below 900 pixels', (tester) async {
      await pumpScreen(tester, size: const Size(899, 800));

      expect(row('grafana'), findsOneWidget);
      expect(find.byType(McpServerDetail), findsNothing);

      await openDetail(tester, 'grafana');
      expect(find.byType(McpServerDetail), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('puts the list and the first server\'s detail side by side '
        'from 900 pixels', (tester) async {
      await pumpScreen(tester, size: const Size(900, 800));

      expect(row('grafana'), findsOneWidget);
      expect(find.byType(McpServerDetail), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(McpServerDetail),
          matching: find.text('https://mcp.grafana.com/mcp'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('follows the tapped server', (tester) async {
      await pumpScreen(tester, size: const Size(1200, 800));

      await tester.tap(inRow('filesystem', find.text('filesystem')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(McpServerDetail),
          matching: find.text('Command'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('moves to the first server when the selected one is removed', (
      tester,
    ) async {
      server.on('DELETE', '/api/mcp/servers/filesystem', {'ok': true});
      await pumpScreen(tester, size: const Size(1200, 800));
      await tester.tap(inRow('filesystem', find.text('filesystem')));
      await tester.pumpAndSettle();
      listServers([grafana]);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(row('filesystem'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(McpServerDetail),
          matching: find.text('https://mcp.grafana.com/mcp'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the empty state instead of a detail', (tester) async {
      listServers([]);

      await pumpScreen(tester, size: const Size(1200, 800));

      expect(find.byType(McpServerDetail), findsNothing);
      expect(find.text('No MCP servers on "work"'), findsOneWidget);
    });
  });

  group('adding', () {
    Future<void> tapAdd(WidgetTester tester) async {
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('the Add button opens a menu of two choices', (tester) async {
      await pumpScreen(tester);

      await tapAdd(tester);

      expect(find.text('Browse the catalog'), findsOneWidget);
      expect(find.text('Add a custom server'), findsOneWidget);
    });

    testWidgets('"Add a custom server" opens the form for the profile', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapAdd(tester);

      await tester.tap(find.text('Add a custom server'));
      await tester.pumpAndSettle();

      expect(find.byType(McpAddServerScreen), findsOneWidget);
      expect(find.text('Profile: work'), findsOneWidget);
    });

    testWidgets('the empty state offers both', (tester) async {
      listServers([]);
      await pumpScreen(tester);

      expect(find.text('Browse the catalog'), findsOneWidget);
      await tester.tap(find.text('Add a custom server'));
      await tester.pumpAndSettle();

      expect(find.byType(McpAddServerScreen), findsOneWidget);
    });

    Future<void> addLinear(WidgetTester tester, {bool oauth = false}) async {
      server.onRequest('POST', '/api/mcp/servers', (request) {
        listServers([
          grafana,
          filesystem,
          mcpServerRow(
            name: 'linear',
            url: 'https://mcp.linear.app/mcp',
            auth: oauth ? 'oauth' : null,
          ),
        ]);
        return (status: 200, body: mcpServerRow(name: 'linear'));
      });
      await tapAdd(tester);
      await tester.tap(find.text('Add a custom server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'linear');
      await tester.enterText(
        find.widgetWithText(TextField, 'URL'),
        'https://mcp.linear.app/mcp',
      );
      if (oauth) {
        await tester.tap(find.text('OAuth'));
        await tester.pumpAndSettle();
      }
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mcp-add-server-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('a new server opens its detail on a narrow layout', (
      tester,
    ) async {
      await pumpScreen(tester);

      await addLinear(tester);

      expect(find.byType(McpAddServerScreen), findsNothing);
      expect(find.byType(McpServerDetail), findsOneWidget);
      expect(find.text('https://mcp.linear.app/mcp'), findsOneWidget);
    });

    testWidgets('a new OAuth server shows its Sign in button', (tester) async {
      await pumpScreen(tester);

      await addLinear(tester, oauth: true);

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a new server is selected on a wide layout', (tester) async {
      await pumpScreen(tester, size: const Size(1200, 800));

      await addLinear(tester);

      expect(find.byType(McpAddServerScreen), findsNothing);
      expect(find.byType(McpServerDetail), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(McpServerDetail),
          matching: find.text('https://mcp.linear.app/mcp'),
        ),
        findsOneWidget,
      );
      expect(row('linear'), findsOneWidget);
    });
  });
}

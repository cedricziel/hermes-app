import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_controller.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// The catalog screen, reached from the MCP servers screen, against a fake
/// dashboard through the real generated client.
void main() {
  late FakeHermesServer server;

  final asana = mcpCatalogEntry(
    name: 'asana',
    description: 'Tasks, projects and workspaces.',
    url: 'https://mcp.asana.com/sse',
    authType: 'oauth',
    installed: true,
    enabled: true,
  );
  final buildkite = mcpCatalogEntry(
    name: 'buildkite',
    description: 'Pipelines and builds.',
    command: 'node',
    args: ['dist/index.js'],
    authType: 'api_key',
    installUrl: 'https://github.com/buildkite/mcp-server',
    installRef: 'v1',
    bootstrap: ['npm ci'],
  );
  final grafana = mcpCatalogEntry(
    name: 'grafana',
    description: 'Dashboards and metrics.',
    url: 'https://mcp.grafana.com/mcp',
    authType: 'oauth',
  );
  final context7 = mcpCatalogEntry(
    name: 'context7',
    description: 'Up-to-date library docs.',
    url: 'https://mcp.context7.com/mcp',
  );

  void listCatalog(
    List<Map<String, Object?>> entries, {
    List<Map<String, Object?>> diagnostics = const [],
  }) => server.on(
    'GET',
    '/api/mcp/catalog',
    mcpCatalogBody(entries, diagnostics: diagnostics),
  );

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'asana', url: 'https://mcp.asana.com/sse'),
        ]),
      );
    listCatalog([asana, buildkite, grafana, context7]);
  });

  Future<void> pumpServers(
    WidgetTester tester, {
    Size size = const Size(420, 900),
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
    await tester.pumpAndSettle();
  }

  Future<void> openCatalog(
    WidgetTester tester, {
    Size size = const Size(420, 900),
  }) async {
    await pumpServers(tester, size: size);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Finder row(String name) => find.byKey(ValueKey('mcp-catalog-row-$name'));

  Finder inRow(String name, String text) =>
      find.descendant(of: row(name), matching: find.text(text));

  group('entry points', () {
    testWidgets('the Add button opens the catalog for the same profile', (
      tester,
    ) async {
      await openCatalog(tester);

      expect(find.text('Installing into: work'), findsOneWidget);
      expect(row('asana'), findsOneWidget);
      expect(
        server
            .requestsTo('GET', '/api/mcp/catalog')
            .single
            .queryParameters['profile'],
        'work',
      );
    });

    testWidgets('the empty state has a button to the catalog', (tester) async {
      server.on('GET', '/api/mcp/servers', mcpServerListBody([]));
      await pumpServers(tester);

      await tester.tap(find.text('Browse the catalog'));
      await tester.pumpAndSettle();

      expect(find.text('Installing into: work'), findsOneWidget);
      expect(row('buildkite'), findsOneWidget);
    });

    testWidgets('no Add button while the servers could not be loaded', (
      tester,
    ) async {
      server.on('GET', '/api/mcp/servers', {'detail': 'boom'}, status: 500);
      await pumpServers(tester);

      expect(find.text('Could not load MCP servers'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });
  });

  group('list', () {
    testWidgets('shows a spinner while the catalog loads', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', '/api/mcp/catalog', (_) => answer.future);
      await pumpServers(tester);

      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      answer.complete((status: 200, body: mcpCatalogBody([asana])));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(row('asana'), findsOneWidget);
    });

    testWidgets('shows what each entry is and whether it is installed', (
      tester,
    ) async {
      await openCatalog(tester);

      expect(inRow('asana', 'Tasks, projects and workspaces.'), findsOneWidget);
      expect(inRow('asana', 'Remote'), findsOneWidget);
      expect(inRow('asana', 'OAuth'), findsOneWidget);
      expect(inRow('asana', 'Installed'), findsOneWidget);
      expect(inRow('buildkite', 'Command'), findsOneWidget);
      expect(inRow('buildkite', 'API key'), findsOneWidget);
      expect(inRow('buildkite', 'Builds locally'), findsOneWidget);
      expect(inRow('buildkite', 'Installed'), findsNothing);
      expect(inRow('context7', 'No auth'), findsOneWidget);
    });

    testWidgets('skips entries without a usable name', (tester) async {
      server.on('GET', '/api/mcp/catalog', {
        'entries': [
          asana,
          {...grafana, 'name': ''},
          {...grafana, 'name': 7},
        ],
        'diagnostics': [],
      });

      await openCatalog(tester);

      expect(row('asana'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.textContaining('Search 1 server'), findsOneWidget);
    });

    testWidgets('says when some catalog entries could not be read', (
      tester,
    ) async {
      listCatalog(
        [asana],
        diagnostics: [
          {'name': 'broken', 'kind': 'invalid', 'message': 'bad yaml'},
        ],
      );

      await openCatalog(tester);

      expect(
        find.text('Some catalog entries could not be read.'),
        findsOneWidget,
      );
    });

    testWidgets('does not mention diagnostics when there are none', (
      tester,
    ) async {
      await openCatalog(tester);

      expect(find.textContaining('could not be read'), findsNothing);
    });

    testWidgets('offers a retry when the catalog cannot be loaded', (
      tester,
    ) async {
      server.on('GET', '/api/mcp/catalog', {'detail': 'boom'}, status: 500);
      await openCatalog(tester);

      expect(find.text('Could not load the catalog'), findsOneWidget);

      listCatalog([asana]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(row('asana'), findsOneWidget);
    });

    testWidgets('a body that is not a catalog counts as failing to load', (
      tester,
    ) async {
      server.on('GET', '/api/mcp/catalog', {'entries': 'nope'});

      await openCatalog(tester);

      expect(find.text('Could not load the catalog'), findsOneWidget);
    });
  });

  group('search and filters', () {
    testWidgets('the field says how many servers it searches', (tester) async {
      await openCatalog(tester);

      expect(find.text('Search 4 servers'), findsOneWidget);
    });

    testWidgets('matches the name and the description, ignoring case', (
      tester,
    ) async {
      await openCatalog(tester);

      await tester.enterText(find.byType(TextField), 'GRAF');
      await tester.pump();
      expect(row('grafana'), findsOneWidget);
      expect(row('asana'), findsNothing);

      await tester.enterText(find.byType(TextField), 'pipelines');
      await tester.pump();
      expect(row('buildkite'), findsOneWidget);
      expect(row('grafana'), findsNothing);
    });

    testWidgets('filters by transport and by sign-in kind', (tester) async {
      await openCatalog(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'OAuth'));
      await tester.pump();
      expect(row('asana'), findsOneWidget);
      expect(row('grafana'), findsOneWidget);
      expect(row('buildkite'), findsNothing);
      expect(row('context7'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Command'));
      await tester.pump();
      expect(row('buildkite'), findsOneWidget);
      expect(row('asana'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Remote'));
      await tester.pump();
      expect(row('context7'), findsOneWidget);
      expect(row('buildkite'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pump();
      expect(row('buildkite'), findsOneWidget);
    });

    testWidgets('search and filter narrow the list together', (tester) async {
      await openCatalog(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'OAuth'));
      await tester.enterText(find.byType(TextField), 'dash');
      await tester.pump();

      expect(row('grafana'), findsOneWidget);
      expect(row('asana'), findsNothing);
    });

    testWidgets('says nothing matches and clears the search', (tester) async {
      await openCatalog(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No servers match'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.text('Clear search'));
      await tester.pump();

      expect(find.text('No servers match'), findsNothing);
      expect(row('asana'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });
  });

  group('installed entries', () {
    testWidgets('open that server\'s detail on a narrow layout', (
      tester,
    ) async {
      await openCatalog(tester);

      await tester.tap(row('asana'));
      await tester.pumpAndSettle();

      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Installing into: work'), findsNothing);
    });

    testWidgets('open that server\'s detail beside the list on a wide one', (
      tester,
    ) async {
      await openCatalog(tester, size: const Size(1200, 800));

      await tester.tap(row('asana'));
      await tester.pumpAndSettle();

      expect(find.text('Test connection'), findsOneWidget);
      expect(row('buildkite'), findsOneWidget);
    });
  });

  group('an installed entry the servers list does not have yet', () {
    void listsAsanaFromTheSecondRequest() {
      server.onRequest('GET', '/api/mcp/servers', (_) {
        final second = server.requestsTo('GET', '/api/mcp/servers').length > 1;
        return (
          status: 200,
          body: mcpServerListBody([
            mcpServerRow(name: 'other', url: 'https://other.test'),
            if (second)
              mcpServerRow(name: 'asana', url: 'https://mcp.asana.com/sse'),
          ]),
        );
      });
    }

    testWidgets('fills the pane after asking for the servers again', (
      tester,
    ) async {
      listsAsanaFromTheSecondRequest();
      await openCatalog(tester, size: const Size(1200, 800));

      await tester.tap(row('asana'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', '/api/mcp/servers'), hasLength(2));
      expect(find.text('Test connection'), findsOneWidget);
    });

    testWidgets('does not ask again for a server the list has', (tester) async {
      await openCatalog(tester, size: const Size(1200, 800));

      await tester.tap(row('asana'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', '/api/mcp/servers'), hasLength(1));
      expect(find.text('Test connection'), findsOneWidget);
    });

    testWidgets('opens on a narrow layout the same way', (tester) async {
      listsAsanaFromTheSecondRequest();
      await openCatalog(tester);

      await tester.tap(row('asana'));
      await tester.pumpAndSettle();

      expect(find.text('Test connection'), findsOneWidget);
    });
  });

  group('controller', () {
    test(
      'learns the profile itself and asks for nothing when it cannot',
      () async {
        server.on('GET', '/api/profiles/active', {
          'detail': 'boom',
        }, status: 500);
        final servers = McpServersController(
          repository: HermesMcpRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
        );
        final catalog = McpCatalogController(servers);

        await catalog.load();

        expect(catalog.failed, isTrue);
        expect(server.requestsTo('GET', '/api/mcp/catalog'), isEmpty);

        server.on(
          'GET',
          '/api/profiles/active',
          activeProfileBody(active: 'work'),
        );
        await catalog.load();

        expect(catalog.failed, isFalse);
        expect(catalog.entries, hasLength(4));
        expect(
          server
              .requestsTo('GET', '/api/mcp/catalog')
              .single
              .queryParameters['profile'],
          'work',
        );
        catalog.dispose();
        servers.dispose();
      },
    );
  });
}

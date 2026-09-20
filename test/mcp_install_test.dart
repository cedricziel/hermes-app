import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_controller.dart';
import 'package:hermes_app/src/mcp/mcp_install_controller.dart';
import 'package:hermes_app/src/mcp/mcp_install_panel.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// Installing a catalog entry from the sheet or the right-hand pane, against a
/// fake dashboard through the real generated client.
void main() {
  late FakeHermesServer server;
  late List<Map<String, Object?>> serverRows;
  late List<Map<String, Object?>> catalogRows;

  const installPath = '/api/mcp/catalog/install';

  final airtable = mcpCatalogEntry(
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
  );
  final buildkite = mcpCatalogEntry(
    name: 'buildkite',
    description: 'Pipelines and builds.',
    command: 'node',
    args: ['dist/index.js', '--stdio'],
    authType: 'none',
    installUrl: 'https://github.com/buildkite/mcp-server',
    installRef: 'v1.2.0',
    bootstrap: ['npm ci', 'npm run build'],
  );
  final context7 = mcpCatalogEntry(
    name: 'context7',
    description: 'Up-to-date library docs.',
    url: 'https://mcp.context7.com/mcp',
  );
  final asana = mcpCatalogEntry(
    name: 'asana',
    url: 'https://mcp.asana.com/sse',
    authType: 'oauth',
    installed: true,
    enabled: true,
  );

  setUp(() {
    serverRows = [
      mcpServerRow(name: 'asana', url: 'https://mcp.asana.com/sse'),
    ];
    catalogRows = [airtable, buildkite, context7, asana];
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..onRequest(
        'GET',
        '/api/mcp/servers',
        (_) => (status: 200, body: mcpServerListBody(serverRows)),
      )
      ..onRequest(
        'GET',
        '/api/mcp/catalog',
        (_) => (status: 200, body: mcpCatalogBody(catalogRows)),
      );
  });

  /// Answers the install as Hermes does when it succeeds: the entry becomes a
  /// server of the profile.
  void hermesInstalls(String name, {String? action}) =>
      server.onRequest('POST', installPath, (request) {
        final enable = (jsonBody(request)! as Map)['enable'] == true;
        serverRows.add(
          mcpServerRow(name: name, url: 'https://$name.test', enabled: enable),
        );
        catalogRows = [
          for (final row in catalogRows)
            row['name'] == name
                ? {...row, 'installed': true, 'enabled': enable}
                : row,
        ];
        return (status: 200, body: mcpInstallBody(name: name, action: action));
      });

  Future<void> openCatalog(
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
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Future<void> openEntry(
    WidgetTester tester,
    String name, {
    Size size = const Size(420, 900),
  }) async {
    await openCatalog(tester, size: size);
    await tester.tap(find.byKey(ValueKey('mcp-catalog-row-$name')));
    await tester.pumpAndSettle();
  }

  final installButton = find.byKey(const ValueKey('mcp-install-button'));

  bool installEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(installButton).onPressed != null;

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> fillKey(WidgetTester tester, [String value = 'pat-1']) async {
    await tester.enterText(field('AIRTABLE_API_KEY'), value);
    await tester.pump();
  }

  Future<void> tapInstall(WidgetTester tester) async {
    await tester.ensureVisible(installButton);
    await tester.tap(installButton);
    await tester.pump();
  }

  Finder inPanel(String text) => find.descendant(
    of: find.byType(McpInstallPanel),
    matching: find.text(text),
  );

  Finder row(String name) => find.byKey(ValueKey('mcp-catalog-row-$name'));

  group('opening an entry', () {
    testWidgets('opens the install sheet on a narrow layout', (tester) async {
      await openEntry(tester, 'airtable');

      expect(find.text('Install airtable'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('opens the install form in the right-hand pane when wide', (
      tester,
    ) async {
      await openEntry(tester, 'airtable', size: const Size(1200, 800));

      expect(find.text('Install airtable'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(row('buildkite'), findsOneWidget);
    });

    testWidgets('shows no install form for an installed entry', (tester) async {
      await openEntry(tester, 'asana');

      expect(find.text('Install asana'), findsNothing);
      expect(find.text('Test connection'), findsOneWidget);
    });
  });

  group('what will run', () {
    testWidgets('shows a remote entry without command or build steps', (
      tester,
    ) async {
      await openEntry(tester, 'airtable');

      expect(inPanel('Read and write Airtable bases.'), findsOneWidget);
      expect(inPanel('https://airtable.com/developers'), findsOneWidget);
      expect(inPanel('What Hermes will run'), findsOneWidget);
      expect(inPanel('remote (http)'), findsOneWidget);
      expect(inPanel('https://mcp.airtable.com/mcp'), findsOneWidget);
      expect(inPanel('API key'), findsOneWidget);
      expect(inPanel('command'), findsNothing);
      expect(inPanel('repository'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(McpInstallPanel),
          matching: find.textContaining('build runs on'),
        ),
        findsNothing,
      );
    });

    testWidgets('shows the command, the repository and every build step', (
      tester,
    ) async {
      await openEntry(tester, 'buildkite');

      expect(inPanel('command (stdio)'), findsOneWidget);
      expect(inPanel('node'), findsOneWidget);
      expect(inPanel('dist/index.js --stdio'), findsOneWidget);
      expect(
        inPanel('https://github.com/buildkite/mcp-server'),
        findsOneWidget,
      );
      expect(inPanel('v1.2.0'), findsOneWidget);
      expect(inPanel('npm ci'), findsOneWidget);
      expect(inPanel('npm run build'), findsOneWidget);
      expect(inPanel('No auth'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(McpInstallPanel),
          matching: find.textContaining('The build runs on your Hermes server'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('asks for no credentials when the entry declares none', (
      tester,
    ) async {
      await openEntry(tester, 'context7');

      expect(find.byType(TextField), findsOneWidget); // the catalog search
      expect(installEnabled(tester), isTrue);
    });
  });

  group('an entry whose transport Hermes did not name', () {
    Finder warning() =>
        find.text('Hermes did not say how this server connects.');

    testWidgets('still shows the command it would run', (tester) async {
      catalogRows = [
        {
          ...mcpCatalogEntry(name: 'odd', command: 'npx', args: ['-y', 'pkg']),
          'transport': 'sse',
        },
      ];
      await openEntry(tester, 'odd');

      expect(inPanel('npx'), findsOneWidget);
      expect(inPanel('-y pkg'), findsOneWidget);
      expect(warning(), findsOneWidget);
      expect(installEnabled(tester), isTrue);
    });

    testWidgets('still shows the address it would connect to', (tester) async {
      catalogRows = [
        {
          ...mcpCatalogEntry(name: 'odd', url: 'https://odd.test/mcp'),
          'transport': 'sse',
        },
      ];
      await openEntry(tester, 'odd');

      expect(inPanel('https://odd.test/mcp'), findsOneWidget);
      expect(warning(), findsOneWidget);
    });

    testWidgets('cannot be installed when it shows neither', (tester) async {
      catalogRows = [
        {...mcpCatalogEntry(name: 'odd'), 'transport': 'sse'},
        mcpCatalogEntry(name: 'bare'),
      ];
      await openEntry(tester, 'odd');

      expect(warning(), findsOneWidget);
      expect(installEnabled(tester), isFalse);
    });

    testWidgets('a named transport with neither is not installable either', (
      tester,
    ) async {
      catalogRows = [mcpCatalogEntry(name: 'bare')];
      await openEntry(tester, 'bare');

      expect(installEnabled(tester), isFalse);
    });
  });

  group('credentials', () {
    testWidgets('are obscured fields labelled with their name and prompt', (
      tester,
    ) async {
      await openEntry(tester, 'airtable');

      expect(field('AIRTABLE_API_KEY'), findsOneWidget);
      expect(find.text('Personal access token'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('AIRTABLE_API_KEY')).obscureText,
        isTrue,
      );
      expect(
        find.textContaining('Saved on your Hermes server'),
        findsOneWidget,
      );
    });

    testWidgets('keep Install disabled until every required one is filled', (
      tester,
    ) async {
      await openEntry(tester, 'airtable');
      expect(installEnabled(tester), isFalse);

      await tester.enterText(field('AIRTABLE_BASE'), 'appX');
      await tester.pump();
      expect(installEnabled(tester), isFalse);

      await fillKey(tester);
      expect(installEnabled(tester), isTrue);
    });

    testWidgets('send only the ones the entry declares, and skip empty ones', (
      tester,
    ) async {
      hermesInstalls('airtable');
      await openEntry(tester, 'airtable');

      await fillKey(tester, 'pat-1');
      await tapInstall(tester);
      await tester.pumpAndSettle();

      final body =
          jsonBody(server.requestsTo('POST', installPath).single)! as Map;
      expect(body['name'], 'airtable');
      expect(body['env'], {'AIRTABLE_API_KEY': 'pat-1'});
    });

    /// The panel on its own, so it stays on screen whatever the install
    /// does, and its fields can be read afterwards.
    Future<void> pumpPanel(WidgetTester tester, String name) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final servers = McpServersController(
        repository: HermesMcpRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
      );
      final catalog = McpCatalogController(servers);
      await tester.runAsync(catalog.load);
      addTearDown(() {
        catalog.dispose();
        servers.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: McpInstallPanel(
              servers: servers,
              catalog: catalog,
              entry: catalog.entryNamed(name)!,
            ),
          ),
        ),
      );
    }

    void expectFieldsEmpty(WidgetTester tester) {
      for (final label in ['AIRTABLE_API_KEY', 'AIRTABLE_BASE']) {
        expect(tester.widget<TextField>(field(label)).controller!.text, '');
      }
    }

    Future<void> fillBoth(WidgetTester tester) async {
      await fillKey(tester);
      await tester.enterText(field('AIRTABLE_BASE'), 'appX');
      await tapInstall(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('are cleared after Hermes accepts them', (tester) async {
      hermesInstalls('airtable');
      await pumpPanel(tester, 'airtable');

      await fillBoth(tester);

      expect(server.requestsTo('POST', installPath), hasLength(1));
      expectFieldsEmpty(tester);
    });

    testWidgets('are cleared after a server error', (tester) async {
      server.on('POST', installPath, {'detail': 'boom'}, status: 500);
      await pumpPanel(tester, 'airtable');

      await fillBoth(tester);

      expect(find.text('Could not install airtable'), findsOneWidget);
      expectFieldsEmpty(tester);
    });

    testWidgets('are cleared after the request could not be made', (
      tester,
    ) async {
      server.onRequest(
        'POST',
        installPath,
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        ),
      );
      await pumpPanel(tester, 'airtable');

      await fillBoth(tester);

      expect(find.text('Could not install airtable'), findsOneWidget);
      expectFieldsEmpty(tester);
    });

    testWidgets('are cleared once a build has started on the server', (
      tester,
    ) async {
      catalogRows = [
        mcpCatalogEntry(
          name: 'airtable',
          command: 'node',
          installUrl: 'https://github.com/x/y',
          installRef: 'v1',
          bootstrap: ['make'],
          requiredEnv: [
            mcpCredentialRow(name: 'AIRTABLE_API_KEY', prompt: 'Token'),
            mcpCredentialRow(
              name: 'AIRTABLE_BASE',
              prompt: 'Base',
              required: false,
            ),
          ],
        ),
      ];
      server
        ..on(
          'POST',
          installPath,
          mcpInstallBody(name: 'airtable', action: 'a-1'),
        )
        ..on(
          'GET',
          '/api/actions/a-1/status',
          jobStatusBody(name: 'a-1', running: true, exitCode: null),
        );
      await pumpPanel(tester, 'airtable');

      await fillKey(tester);
      await tester.enterText(field('AIRTABLE_BASE'), 'appX');
      await tapInstall(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Building on your server…'), findsOneWidget);
      expectFieldsEmpty(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('are cleared after Hermes refuses them', (tester) async {
      server.on('POST', installPath, {
        'detail': "Catalog entry 'airtable' does not declare environment variable(s): X",
      }, status: 400);
      await openEntry(tester, 'airtable');

      await fillKey(tester);
      await tester.enterText(field('AIRTABLE_BASE'), 'appX');
      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field('AIRTABLE_API_KEY')).controller!.text,
        '',
      );
      expect(
        tester.widget<TextField>(field('AIRTABLE_BASE')).controller!.text,
        '',
      );
      expect(installEnabled(tester), isFalse);
    });
  });

  group('installing', () {
    testWidgets('installs, closes the sheet and says so', (tester) async {
      hermesInstalls('context7');
      await openEntry(tester, 'context7');

      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Installed context7'), findsOneWidget);
      expect(
        find.descendant(of: row('context7'), matching: find.text('Installed')),
        findsOneWidget,
      );
      final request = server.requestsTo('POST', installPath).single;
      expect(request.queryParameters['profile'], 'work');
      expect((jsonBody(request)! as Map)['enable'], isTrue);
    });

    testWidgets('lets the user open the new server', (tester) async {
      hermesInstalls('context7');
      await openEntry(tester, 'context7');
      await tapInstall(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('context7'), findsWidgets);
      expect(find.text('Test connection'), findsOneWidget);
    });

    testWidgets('lists the new server on the MCP servers screen', (
      tester,
    ) async {
      hermesInstalls('context7');
      await openEntry(tester, 'context7');
      await tapInstall(tester);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mcp-row-context7')), findsOneWidget);
    });

    testWidgets('sends enable false when the switch is off', (tester) async {
      hermesInstalls('context7');
      await openEntry(tester, 'context7');

      await tester.tap(find.text('Turn on after installing'));
      await tester.pump();
      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(
        (jsonBody(server.requestsTo('POST', installPath).single)!
            as Map)['enable'],
        isFalse,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final installed = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const ValueKey('mcp-row-context7')),
          matching: find.byType(Switch),
        ),
      );
      expect(installed.value, isFalse);
    });

    testWidgets('shows progress while it runs', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', installPath, (_) => answer.future);
      await openEntry(tester, 'context7');

      await tapInstall(tester);

      expect(installEnabled(tester), isFalse);
      expect(
        find.descendant(
          of: installButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      answer.complete((status: 200, body: mcpInstallBody(name: 'context7')));
      await tester.pumpAndSettle();
    });

    testWidgets('sends one request however often install is called', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', installPath, (_) => answer.future);
      final servers = McpServersController(
        repository: HermesMcpRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
      );
      final catalog = McpCatalogController(servers);
      await tester.runAsync(catalog.load);
      final install = McpInstallController(
        servers: servers,
        catalog: catalog,
        entry: catalog.entryNamed('context7')!,
      );
      addTearDown(() {
        install.dispose();
        catalog.dispose();
        servers.dispose();
      });

      final first = install.install({}, enable: true);
      final second = install.install({}, enable: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(install.busy, isTrue);
      answer.complete((status: 200, body: mcpInstallBody(name: 'context7')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await Future.wait([first, second]);

      expect(server.requestsTo('POST', installPath), hasLength(1));
    });

    testWidgets('keeps the sheet open and shows Hermes\' reason on a 400', (
      tester,
    ) async {
      server.on('POST', installPath, {
        'detail': "Catalog entry 'context7' does not declare environment variable(s): X",
      }, status: 400);
      await openEntry(tester, 'context7');

      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('does not declare'), findsOneWidget);
      expect(
        find.descendant(of: row('context7'), matching: find.text('Installed')),
        findsNothing,
      );
      expect(installEnabled(tester), isTrue);
    });

    testWidgets('reloads the catalog and closes the sheet on a 404', (
      tester,
    ) async {
      server.on('POST', installPath, {
        'detail': 'No catalog entry',
      }, status: 404);
      await openEntry(tester, 'context7');
      catalogRows = [airtable, buildkite, asana];

      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(row('context7'), findsNothing);
      expect(server.requestsTo('GET', '/api/mcp/catalog'), hasLength(2));
    });

    testWidgets('says it could not install on any other failure', (
      tester,
    ) async {
      server.on('POST', installPath, {'detail': 'boom'}, status: 500);
      await openEntry(tester, 'context7');

      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Could not install context7'), findsOneWidget);
      expect(installEnabled(tester), isTrue);
    });

    testWidgets('in the pane, shows the server once it is installed', (
      tester,
    ) async {
      hermesInstalls('context7');
      await openEntry(tester, 'context7', size: const Size(1200, 800));

      await tapInstall(tester);
      await tester.pumpAndSettle();

      expect(find.text('Installed context7'), findsOneWidget);
      expect(find.text('Install context7'), findsNothing);
      expect(find.text('Test connection'), findsOneWidget);
    });
  });

  group('builds on the server', () {
    const action = 'mcp-install-buildkite-ab12';
    const statusPath = '/api/actions/$action/status';

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> startBuild(WidgetTester tester) async {
      hermesInstalls('buildkite', action: action);
      await openEntry(tester, 'buildkite');
      await tapInstall(tester);
      await tester.pump();
    }

    testWidgets('says it is building and offers no second install', (
      tester,
    ) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );

      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Building on your server…'), findsOneWidget);
      expect(installEnabled(tester), isFalse);
      expect(server.requestsTo('POST', installPath), hasLength(1));
    });

    testWidgets('shows the entry as installed when the build succeeds', (
      tester,
    ) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));

      server.on('GET', statusPath, jobStatusBody(name: action));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Installed buildkite'), findsOneWidget);
      expect(
        find.descendant(of: row('buildkite'), matching: find.text('Installed')),
        findsOneWidget,
      );
      final polls = server.requestsTo('GET', statusPath).length;
      await tester.pump(const Duration(seconds: 10));
      expect(server.requestsTo('GET', statusPath), hasLength(polls));
    });

    testWidgets('says the build failed and shows the last 20 log lines', (
      tester,
    ) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(
          name: action,
          exitCode: 1,
          lines: [for (var i = 1; i <= 25; i++) 'log line $i'],
        ),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('The build failed'), findsOneWidget);
      expect(
        find.textContaining('log line 25', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('log line 6\n', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('log line 5\n', findRichText: true),
        findsNothing,
      );
      expect(
        find.descendant(of: row('buildkite'), matching: find.text('Installed')),
        findsNothing,
      );
    });

    testWidgets('stops polling and does not cancel when the sheet closes', (
      tester,
    ) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));
      final before = server.requestsTo('GET', statusPath).length;
      expect(before, greaterThan(0));

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.pump(const Duration(seconds: 10));

      expect(server.requestsTo('GET', statusPath), hasLength(before));
      expect(server.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });

    testWidgets('does not follow a build that starts after the sheet closed', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', installPath, (_) => answer.future);
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await openEntry(tester, 'buildkite');
      await tapInstall(tester);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      answer.complete((
        status: 200,
        body: mcpInstallBody(name: 'buildkite', action: action),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 10));

      expect(server.requestsTo('GET', statusPath), isEmpty);
    });

    Finder building(String name) =>
        find.descendant(of: row(name), matching: find.text('Building'));

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    }

    testWidgets('marks the entry as building in the list', (tester) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(building('buildkite'), findsOneWidget);
    });

    testWidgets('picks the build up again when the entry is opened again', (
      tester,
    ) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));
      await closeSheet(tester);
      final before = server.requestsTo('GET', statusPath).length;

      await tester.tap(row('buildkite'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Building on your server…'), findsOneWidget);
      expect(installEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(server.requestsTo('GET', statusPath).length, greaterThan(before));
      expect(server.requestsTo('POST', installPath), hasLength(1));

      server.on('GET', statusPath, jobStatusBody(name: action));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Installed buildkite'), findsOneWidget);
      expect(building('buildkite'), findsNothing);
    });

    testWidgets('remembers a build whose answer came after the sheet closed', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', installPath, (_) => answer.future);
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await openEntry(tester, 'buildkite');
      await tapInstall(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await closeSheet(tester);
      answer.complete((
        status: 200,
        body: mcpInstallBody(name: 'buildkite', action: action),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(building('buildkite'), findsOneWidget);
      await tester.tap(row('buildkite'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Building on your server…'), findsOneWidget);
      expect(installEnabled(tester), isFalse);
    });

    testWidgets('forgets a build that failed', (tester) async {
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, exitCode: 1, lines: ['boom']),
      );
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(building('buildkite'), findsNothing);
      await closeSheet(tester);
      await tester.tap(row('buildkite'));
      await tester.pumpAndSettle();
      expect(installEnabled(tester), isTrue);
    });

    testWidgets('in the pane, follows the build again when selected again', (
      tester,
    ) async {
      hermesInstalls('buildkite', action: action);
      server.on(
        'GET',
        statusPath,
        jobStatusBody(name: action, running: true, exitCode: null),
      );
      await openEntry(tester, 'buildkite', size: const Size(1200, 800));
      await tapInstall(tester);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(row('context7'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Install context7'), findsOneWidget);
      final before = server.requestsTo('GET', statusPath).length;
      await tester.pump(const Duration(seconds: 6));
      expect(server.requestsTo('GET', statusPath), hasLength(before));

      await tester.tap(row('buildkite'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Building on your server…'), findsOneWidget);
      expect(installEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(server.requestsTo('GET', statusPath).length, greaterThan(before));
    });

    testWidgets('gives up when Hermes no longer knows the build', (
      tester,
    ) async {
      server.on('GET', statusPath, {'detail': 'Unknown action'}, status: 404);
      await startBuild(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not follow the build of buildkite'),
        findsOneWidget,
      );
      expect(installEnabled(tester), isTrue);
    });
  });
}

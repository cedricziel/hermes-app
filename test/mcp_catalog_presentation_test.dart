import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_catalog_screen.dart';
import 'package:hermes_app/src/mcp/mcp_install_panel.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';

const _install = '/api/mcp/catalog/install';
const _servers = '/api/mcp/servers';
const _catalog = '/api/mcp/catalog';
final _panel = find.byType(McpInstallPanel);
final _button = find.byKey(const ValueKey('mcp-install-button'));

void main() {
  late FakeHermesServer server;
  late List<Map<String, Object?>> serverRows;

  setUp(() {
    serverRows = [];
    server = FakeHermesServer()
      ..onRequest(
        'GET',
        _servers,
        (_) => (status: 200, body: mcpServerListBody(serverRows)),
      )
      ..on(
        'GET',
        _catalog,
        mcpCatalogBody([
          mcpCatalogEntry(name: 'context7', url: 'https://context7.test/mcp'),
          mcpCatalogEntry(
            name: 'buildkite',
            command: 'node',
            args: ['index.js'],
            installUrl: 'https://example.test/mcp-buildkite',
            bootstrap: ['npm ci'],
          ),
        ]),
      );
  });

  Future<void> open(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
    double width = 700,
    String entry = 'context7',
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final servers = McpServersController(
      repository: HermesMcpRepository(server.client().raw),
      forProfile: 'work',
    );
    addTearDown(servers.dispose);
    await tester.runAsync(servers.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: platform),
        home: McpCatalogScreen(servers: servers),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('mcp-catalog-row-$entry')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compact Mac catalog opens a dialog and dismisses to the catalog',
    (tester) async {
      await open(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.ancestor(of: _panel, matching: find.byType(Dialog)),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(_panel, findsNothing);
      expect(find.byType(McpCatalogScreen), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform compact catalog preserves its safe-area sheet', (
      tester,
    ) async {
      await open(tester, platform: platform, width: 390);

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      final route =
          ModalRoute.of(tester.element(_panel)) as ModalBottomSheetRoute;
      expect(route.useSafeArea, isTrue);
      expect(route.isScrollControlled, isTrue);
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('wide Mac catalog keeps its install pane', (tester) async {
    await open(tester, width: 1000);

    expect(_panel, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.byKey(const ValueKey('mcp-catalog-row-context7')),
      findsOneWidget,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Mac successful install closes its modal and offers the server', (
    tester,
  ) async {
    server.onRequest('POST', _install, (_) {
      serverRows.add(
        mcpServerRow(name: 'context7', url: 'https://context7.test/mcp'),
      );
      return (status: 200, body: mcpInstallBody(name: 'context7'));
    });
    await open(tester);

    await tester.tap(_button);
    await tester.pumpAndSettle();

    expect(_panel, findsNothing);
    expect(find.text('Installed context7'), findsOneWidget);
    expect(find.byType(McpCatalogScreen), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Test connection'), findsOneWidget);
    expect(
      server.requestsTo('POST', _install).single.queryParameters['profile'],
      'work',
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Mac refused install keeps the panel and its error', (
    tester,
  ) async {
    server.on('POST', _install, {'detail': 'Install refused'}, status: 400);
    await open(tester);

    await tester.tap(_button);
    await tester.pumpAndSettle();

    expect(_panel, findsOneWidget);
    expect(find.text('Install refused'), findsOneWidget);
    expect(tester.widget<FilledButton>(_button).onPressed, isNotNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a dismissed pending Mac install cannot pop its catalog later', (
    tester,
  ) async {
    final held = Completer<FakeResponse>();
    server.onRequest('POST', _install, (_) => held.future);
    await open(tester);

    await tester.tap(_button);
    await tester.pump();
    expect(tester.widget<FilledButton>(_button).onPressed, isNull);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_panel, findsNothing);
    serverRows.add(
      mcpServerRow(name: 'context7', url: 'https://context7.test/mcp'),
    );
    held.complete((status: 200, body: mcpInstallBody(name: 'context7')));
    await tester.pumpAndSettle();

    expect(find.byType(McpCatalogScreen), findsOneWidget);
    expect(find.text('Installed context7'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mcp-catalog-row-context7')),
        matching: find.textContaining('Installed'),
      ),
      findsOneWidget,
    );
    expect(server.requestsTo('POST', _install), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'dismissing a Mac server build stops local polling without cancel',
    (tester) async {
      server.on(
        'POST',
        _install,
        mcpInstallBody(name: 'buildkite', action: 'build-1'),
      );
      await open(tester, entry: 'buildkite');

      await tester.ensureVisible(_button);
      await tester.tap(_button);
      await tester.pump();
      expect(tester.widget<FilledButton>(_button).onPressed, isNull);
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 6));

      expect(_panel, findsNothing);
      expect(find.byType(McpCatalogScreen), findsOneWidget);
      expect(
        server.requests.where((r) => r.path.startsWith('/api/actions/')),
        isEmpty,
      );
      expect(server.requestsTo('POST', _install), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

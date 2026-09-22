import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../hermes_plugin_manager_repository_test.dart'
    show catalogBody, catalogRow, hubBody, hubRow, memoryOption, providersHub;
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The Plugins screen: installed plugins and their details, the catalog and
/// installing from it or from a Git URL, and the memory provider and context
/// engine. The details sit beside the list from 900 logical pixels.
void main() {
  late FakeHermesServer server;

  const hub = '/api/dashboard/plugins/hub';
  const catalog = '/api/dashboard/plugins/catalog';
  const agent = '/api/dashboard/agent-plugins';
  const install = '$agent/install';
  const saveProviders = '/api/dashboard/plugin-providers';
  const brvInstall = 'curl -fsSL https://byterover.dev/install.sh | sh';

  final longDescription =
      'Query and update NetBox from the agent: look up devices, prefixes, '
      'VLANs and cables, reserve addresses and keep the source of truth in '
      'sync with what the agent finds on the network. ${'More words. ' * 8}';

  Map<String, Object?> providers({
    String memory = 'honcho',
    String engine = 'compressor',
  }) => providersHub(
    memory: memory,
    memoryOptions: [
      memoryOption('honcho', description: 'Honcho memory'),
      memoryOption('holographic'),
      memoryOption('mem0', status: 'needs_config', env: ['MEM0_API_KEY']),
      memoryOption(
        'byterover',
        status: 'unavailable',
        external: [
          {'name': 'brv', 'install': brvInstall, 'check': 'brv --version'},
        ],
        pip: ['byterover-sdk'],
      ),
      memoryOption('retaindb', status: 'unavailable'),
    ],
    engine: engine,
    engines: [
      {'name': 'compressor', 'description': 'Default engine'},
      {'name': 'lossless', 'description': 'Keeps every message'},
    ],
  );

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', hub, {
        ...hubBody([
          hubRow(
            'netbox',
            description: longDescription,
            canUpdate: true,
            authRequired: true,
            authCommand: 'hermes auth netbox --profile work',
          ),
          hubRow('kanban', source: 'bundled', canRemove: false),
          hubRow('spotify', authRequired: true),
          hubRow('gmail-triage', status: 'disabled'),
          hubRow('idle-plugin', status: 'inactive'),
          hubRow('old', removedReason: 'unsafe network call'),
          hubRow(
            'a-plugin-with-a-really-long-name-for-the-list-to-cope-with',
            description: 'Short.',
          ),
        ]),
        'providers': providers()['providers'],
      })
      ..on(
        'GET',
        catalog,
        catalogBody([
          catalogRow(
            'hermes-plugin-chrome-profiles',
            tier: 'official',
            maintainer: 'Acme',
            description: 'Switch Chrome profiles from the agent',
            tools: ['chrome_switch_profile', 'chrome_list_profiles'],
            hooks: ['on_session_start'],
            middleware: ['profile_guard'],
            env: ['CHROME_BIN'],
            platforms: ['macos', 'linux'],
            requiresHermes: '>=0.9',
            docsUrl: 'https://example.com/docs/chrome',
          ),
          catalogRow(
            'hermes-plugin-netbox',
            installed: true,
            maintainer: 'someone-with-a-really-long-handle-on-github',
            description: longDescription,
          ),
          catalogRow(
            'hermes-snapcompact',
            installed: true,
            updateAvailable: true,
          ),
          catalogRow('hermes-plugin-weather', description: 'Forecasts.'),
        ]),
      )
      ..on('PUT', saveProviders, {'ok': true})
      ..on('POST', '$agent/netbox/disable', {'ok': true})
      ..on('POST', '$agent/netbox/update', {'ok': true, 'sha': 'abc'});
  });

  Future<void> pumpPlugins(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    shots,
    PluginsScreen(
      repository: HermesPluginManagerRepository(server.client().raw),
      events: (name, [attributes = const {}]) {},
      openLink: (uri) async => true,
    ),
    size: size,
    brightness: brightness,
  );

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Tab, name));
    await tester.pumpAndSettle();
  }

  Finder listRow(String name) => find.widgetWithText(ListTile, name);

  bool isWide(Size size) => size.width >= kWideLayoutBreakpoint;

  /// Closes the bottom sheet a phone opens for a detail; the pane on desktop
  /// stays.
  Future<void> closeDetail(WidgetTester tester, Size size) async {
    if (!isWide(size)) await popRoute(tester);
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: installed plugins and details', (tester) async {
      final shots = ScreenshotRecorder('plugins-installed-$name');
      await pumpPlugins(tester, shots, size: size);
      await shots.capture(tester, 'list');

      await tester.tap(listRow('netbox'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'detail-login-and-update');

      await tester.tap(find.byKey(const Key('plugin-update')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'updated');
      await drain(tester);

      server.on('GET', hub, {
        ...hubBody([hubRow('netbox', status: 'disabled', canUpdate: true)]),
      });
      await tester.tap(find.byKey(const Key('plugin-enabled')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switched-off');

      await tester.tap(find.byKey(const Key('plugin-remove')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'remove-dialog');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await closeDetail(tester, size);
    });

    testWidgets('$name: bundled, disabled and removed plugins', (tester) async {
      final shots = ScreenshotRecorder('plugins-installed-kinds-$name');
      await pumpPlugins(tester, shots, size: size);

      await tester.tap(listRow('kanban'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'bundled');
      await closeDetail(tester, size);

      await tester.tap(listRow('old'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'removed');
      await closeDetail(tester, size);

      await tester.tap(listRow('spotify'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'login-without-command');
      await closeDetail(tester, size);

      await tester.tap(
        listRow('a-plugin-with-a-really-long-name-for-the-list-to-cope-with'),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'long-name');
      server.on(
        'POST',
        '$agent/a-plugin-with-a-really-long-name-for-the-list-to-cope-with/disable',
        {'detail': 'Plugin is locked.'},
        status: 400,
      );
      await tester.tap(find.byKey(const Key('plugin-enabled')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'switch-refused');
      await drain(tester);
    });

    testWidgets('$name: catalog', (tester) async {
      final shots = ScreenshotRecorder('plugins-catalog-$name');
      await pumpPlugins(tester, shots, size: size);
      await tab(tester, 'Catalog');
      await shots.capture(tester, 'list');

      await tester.enterText(find.byKey(const Key('catalog-search')), 'snap');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search');
      await tester.enterText(find.byKey(const Key('catalog-search')), 'zzz');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'no-match');
      await tester.enterText(find.byKey(const Key('catalog-search')), '');
      await tester.pumpAndSettle();

      await tester.tap(listRow('hermes-plugin-chrome-profiles'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'detail');
      await closeDetail(tester, size);

      await tester.tap(listRow('hermes-snapcompact'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'detail-installed-with-update');
      await closeDetail(tester, size);

      await tester.tap(listRow('hermes-plugin-netbox'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'detail-long-text');
      await closeDetail(tester, size);
    });

    testWidgets('$name: install from the catalog', (tester) async {
      final shots = ScreenshotRecorder('plugins-install-$name');
      final gate = Completer<FakeResponse>();
      server.onRequest('POST', install, (_) => gate.future);
      await pumpPlugins(tester, shots, size: size);
      await tab(tester, 'Catalog');

      await tester.tap(listRow('hermes-plugin-chrome-profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-detail-install')));
      await frames(tester);
      await shots.capture(tester, 'installing');

      gate.complete((
        status: 200,
        body: {
          'ok': true,
          'plugin_name': 'chrome-profiles',
          'warnings': [
            'Insecure URL scheme; prefer https:// or git@.',
            'Plugin registers 3 shell tools.',
          ],
          'missing_env': ['CHROME_BIN', 'CHROME_PROFILE_DIR'],
        },
      ));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'report-set-env');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'report-warnings');
      await drain(tester);
      await closeDetail(tester, size);

      server.on('POST', install, {
        'detail':
            "Plugin 'hermes-plugin-weather' failed the safety scan: "
            'it opens a network socket on import.',
      }, status: 400);
      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-weather')),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'refused');
      await drain(tester);

      server.onRequest(
        'POST',
        install,
        (request) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: request,
        ),
      );
      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-weather')),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'still-installing');
      await drain(tester);

      server.onRequest(
        'POST',
        install,
        (_) => throw const SocketException('no route to host'),
      );
      await tester.tap(
        find.byKey(const Key('catalog-install-hermes-plugin-weather')),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'unreachable');
      await drain(tester);
    });

    testWidgets('$name: install from a Git URL', (tester) async {
      final shots = ScreenshotRecorder('plugins-git-$name');
      await pumpPlugins(tester, shots, size: size);
      await tab(tester, 'Catalog');

      await tester.tap(find.byKey(const Key('catalog-git-install')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'dialog-empty');

      await tester.enterText(
        find.byKey(const Key('git-url-field')),
        'https://github.com/someone/hermes-cool-plugin-with-a-rather-long-name.git',
      );
      await tester.tap(find.byKey(const Key('git-trust-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'dialog-filled-advanced');

      final gate = Completer<FakeResponse>();
      server.onRequest('POST', install, (_) => gate.future);
      await tester.tap(find.byKey(const Key('git-install')));
      await frames(tester);
      await shots.capture(tester, 'dialog-installing');

      gate.complete((
        status: 200,
        body: {
          'ok': true,
          'plugin_name': 'cool',
          'warnings': ['Insecure URL scheme; prefer https:// or git@.'],
          'missing_env': ['COOL_TOKEN'],
        },
      ));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'report');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await drain(tester);

      await tester.tap(find.byKey(const Key('catalog-git-install')));
      await tester.pumpAndSettle();
      server.on('POST', install, {
        'detail': 'Could not clone the repository: authentication failed.',
      }, status: 400);
      await tester.enterText(
        find.byKey(const Key('git-url-field')),
        'someone/private-plugin',
      );
      await tester.tap(find.byKey(const Key('git-trust-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('git-install')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'refused');
      await drain(tester);
    });

    testWidgets('$name: providers', (tester) async {
      final shots = ScreenshotRecorder('plugins-providers-$name');
      await pumpPlugins(tester, shots, size: size);
      await tab(tester, 'Providers');
      await shots.capture(tester, 'initial');

      await tester.ensureVisible(find.byKey(const Key('needs-mem0')));
      await tester.tap(find.byKey(const Key('needs-mem0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('needs-byterover')));
      await tester.tap(find.byKey(const Key('needs-byterover')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'needs-expanded');

      await tester.drag(
        find.byKey(const Key('providers-list')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'memory-chosen');

      await tester.scrollUntilVisible(
        find.byKey(const Key('engine-lossless')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('providers-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('engine-lossless')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'engine-chosen');

      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'saved');
      await drain(tester);

      server.on('PUT', saveProviders, {
        'detail': "Memory provider 'holographic' is not ready.",
      }, status: 400);
      await tester.tap(find.byKey(const Key('engine-lossless')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'save-refused');
      await drain(tester);
    });

    testWidgets('$name: empty, error and unsupported states', (tester) async {
      final shots = ScreenshotRecorder('plugins-states-$name');
      server.on('GET', hub, hubBody([]));
      server.on('GET', catalog, catalogBody([]));
      await pumpPlugins(tester, shots, size: size);
      await shots.capture(tester, 'installed-empty');
      await tab(tester, 'Catalog');
      await shots.capture(tester, 'catalog-empty');

      server.on('GET', hub, {'detail': 'boom'}, status: 500);
      server.on('GET', catalog, {'detail': 'boom'}, status: 500);
      await tester.pumpWidget(const SizedBox());
      await pumpPlugins(tester, shots, size: size);
      await shots.capture(tester, 'installed-error');
      await tab(tester, 'Catalog');
      await shots.capture(tester, 'catalog-error');
      await tab(tester, 'Providers');
      await shots.capture(tester, 'providers-error');

      server.on('GET', hub, {'detail': 'Not Found'}, status: 404);
      server.on('GET', catalog, {'detail': 'Not Found'}, status: 404);
      await tester.pumpWidget(const SizedBox());
      await pumpPlugins(tester, shots, size: size);
      await shots.capture(tester, 'installed-unsupported');
      await tab(tester, 'Catalog');
      await shots.capture(tester, 'catalog-unsupported');
      await tab(tester, 'Providers');
      await shots.capture(tester, 'providers-unsupported');
    });

    testWidgets('$name: loading', (tester) async {
      final shots = ScreenshotRecorder('plugins-loading-$name');
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', hub, (_) => gate.future);
      await shots.start(tester, size);
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: withScreenshotFont(buildHermesLightTheme()),
            home: PluginsScreen(
              repository: HermesPluginManagerRepository(server.client().raw),
              events: (name, [attributes = const {}]) {},
            ),
          ),
        ),
      );
      await frames(tester, 4);
      await shots.capture(tester, 'installed');
      gate.complete((status: 200, body: hubBody([])));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('dark phone: installed, catalog and providers', (tester) async {
    final shots = ScreenshotRecorder('plugins-dark-phone');
    await pumpPlugins(
      tester,
      shots,
      size: phoneSize,
      brightness: Brightness.dark,
    );
    await shots.capture(tester, 'installed');
    await tester.tap(listRow('netbox'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'detail');
    await popRoute(tester);
    await tab(tester, 'Catalog');
    await shots.capture(tester, 'catalog');
    await tester.tap(find.byKey(const Key('catalog-git-install')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'git-dialog');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tab(tester, 'Providers');
    await tester.ensureVisible(find.byKey(const Key('needs-mem0')));
    await tester.tap(find.byKey(const Key('needs-mem0')));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'providers');
  });

  testWidgets('dark desktop: installed, catalog and providers', (tester) async {
    final shots = ScreenshotRecorder('plugins-dark-desktop');
    await pumpPlugins(
      tester,
      shots,
      size: desktopSize,
      brightness: Brightness.dark,
    );
    await tester.tap(listRow('netbox'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'installed-detail');
    await tab(tester, 'Catalog');
    await tester.tap(listRow('hermes-plugin-chrome-profiles'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'catalog-detail');
    await tab(tester, 'Providers');
    await shots.capture(tester, 'providers');
  });
}

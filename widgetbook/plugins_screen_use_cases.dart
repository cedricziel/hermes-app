import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show noopAppEventLogger;
import 'package:hermes_app/src/plugins/catalog_controller.dart';
import 'package:hermes_app/src/plugins/catalog_tab.dart';
import 'package:hermes_app/src/plugins/git_install_dialog.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/installed_tab.dart';
import 'package:hermes_app/src/plugins/plugin_detail.dart';
import 'package:hermes_app/src/plugins/plugin_install_result.dart';
import 'package:hermes_app/src/plugins/plugins_controller.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/plugins/providers_controller.dart';
import 'package:hermes_app/src/plugins/providers_tab.dart';
import 'package:hermes_app/src/plugins/sheet_host.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'frame.dart';
import 'host.dart';

const _hub = '/api/dashboard/plugins/hub';
const _catalog = '/api/dashboard/plugins/catalog';

Map<String, Object?> _hubRow(
  String name, {
  String status = 'enabled',
  String source = 'user',
  bool canRemove = true,
  bool canUpdate = false,
  bool authRequired = false,
  String authCommand = '',
  bool hidden = false,
  String description = '',
}) => {
  'name': name,
  'version': '1.2.0',
  'description': description,
  'source': source,
  'runtime_status': status,
  'has_dashboard_manifest': false,
  'dashboard_manifest': null,
  'can_remove': canRemove,
  'can_update_git': canUpdate,
  'auth_required': authRequired,
  'auth_command': authCommand,
  'user_hidden': hidden,
  'removed_reason': null,
};

Map<String, Object?> _catalogRow(
  String name, {
  String tier = 'community',
  String maintainer = 'A community author',
  String description = '',
  bool installed = false,
  bool updateAvailable = false,
  List<String> tools = const [],
  List<String> env = const [],
}) => {
  'name': name,
  'repo': 'https://example.com/$name',
  'sha': 'a3f9c21d5e7b8a90123456789abcdef012345678',
  'sha_short': 'a3f9c21',
  'description': description,
  'maintainer': maintainer,
  'tier': tier,
  'requires_hermes': '>=0.20',
  'subdir': '',
  'docs_url': 'https://example.com/$name/docs',
  'platforms': ['macos', 'linux'],
  'capabilities': {
    'provides_tools': tools,
    'provides_hooks': <String>[],
    'provides_middleware': <String>[],
    'requires_env': env,
  },
  'installed': installed,
  'installed_sha': installed
      ? 'a3f9c21d5e7b8a90123456789abcdef012345678'
      : null,
  'update_available': updateAvailable,
  'runtime_status': installed ? 'enabled' : null,
};

Map<String, Object?> _memoryOption(
  String name, {
  bool ready = true,
  List<String> env = const [],
}) => {
  'name': name,
  'description': 'Remembers things with $name.',
  'available': ready,
  'configured': ready,
  'status': ready ? 'ready' : 'needs_setup',
  'setup': {
    'pip_dependencies': <String>[],
    'external_dependencies': <Object?>[],
    'required_env': env,
    'dependencies_installed': ready,
  },
};

/// A dashboard with a few plugins, a catalog and both kinds of provider.
FakeHermesServer pluginsServer({bool empty = false}) => FakeHermesServer()
  ..on('GET', _hub, {
    'plugins': empty
        ? <Object?>[]
        : [
            _hubRow(
              'netbox',
              description: 'Query NetBox for devices and prefixes.',
              canUpdate: true,
            ),
            _hubRow(
              'notes-sync',
              status: 'disabled',
              description: 'Keep a folder of notes in step with memory.',
            ),
            _hubRow(
              'calendar',
              status: 'inactive',
              authRequired: true,
              authCommand: 'hermes auth calendar',
              description: 'Read and create calendar events.',
            ),
            _hubRow(
              'terminal',
              source: 'bundled',
              canRemove: false,
              description: 'Run shell commands.',
            ),
          ],
    'orphan_dashboard_plugins': <Object?>[],
    'providers': {
      'memory_provider': 'holographic',
      'memory_options': [
        _memoryOption('holographic'),
        _memoryOption('vector-store', ready: false, env: ['VECTOR_STORE_URL']),
      ],
      'context_engine': 'compressor',
      'context_options': [
        {'name': 'compressor', 'description': 'Summarises old turns.'},
        {'name': 'sliding-window', 'description': 'Keeps the last turns.'},
      ],
    },
  })
  ..on('GET', _catalog, {
    'entries': [
      _catalogRow(
        'browser-tools',
        tier: 'official',
        maintainer: 'Nous Research',
        description: 'Drive a headless browser.',
        tools: ['browser_open', 'browser_read'],
        env: ['BROWSER_PATH'],
      ),
      _catalogRow(
        'notes-sync',
        description: 'Keep notes in step with memory.',
        installed: true,
        updateAvailable: true,
      ),
      _catalogRow('rss-reader', description: 'Read feeds and summarise them.'),
    ],
    'removed': <Object?>[],
    'generated_at': '2026-09-20T12:00:00Z',
  });

HermesPluginManagerRepository _repository(FakeHermesServer server) =>
    HermesPluginManagerRepository(server.client().raw);

WidgetbookUseCase _tab<T extends ChangeNotifier>(
  String name,
  FakeHermesServer Function() server,
  T Function(HermesPluginManagerRepository repository) create,
  Future<void> Function(T controller) load,
  Widget Function(T controller) tab,
) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<T>(
    create: () async {
      final controller = create(_repository(server()));
      await load(controller);
      return controller;
    },
    dispose: (controller) => controller.dispose(),
    builder: (_, controller) => Scaffold(body: tab(controller)),
  ),
);

WidgetbookUseCase _screen(String name, FakeHermesServer Function() server) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => PluginsScreen(
        repository: _repository(server()),
        openLink: (_) async => true,
      ),
    );

WidgetbookNode pluginsScreensNode() => WidgetbookFolder(
  name: 'Plugin screens',
  children: [
    WidgetbookComponent(
      name: 'PluginsScreen',
      useCases: [
        _screen('Installed', pluginsServer),
        _screen('Nothing installed', () => pluginsServer(empty: true)),
        _screen(
          'Load fails',
          () =>
              pluginsServer()..on('GET', _hub, {'detail': 'boom'}, status: 500),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'InstalledTab',
      useCases: [
        _tab<PluginsController>(
          'Selected',
          pluginsServer,
          (repository) =>
              PluginsController(repository, events: noopAppEventLogger),
          (controller) async {
            await controller.load();
            controller.select('netbox');
          },
          (controller) => InstalledTab(controller: controller),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CatalogTab',
      useCases: [
        _tab<CatalogController>(
          'Catalog',
          pluginsServer,
          (repository) =>
              CatalogController(repository, events: noopAppEventLogger),
          (_) async {},
          (controller) =>
              CatalogTab(controller: controller, openLink: (_) async => true),
        ),
        _tab<CatalogController>(
          'Empty',
          () => pluginsServer()
            ..on('GET', _catalog, {
              'entries': <Object?>[],
              'removed': <Object?>[],
              'generated_at': '2026-09-20T12:00:00Z',
            }),
          (repository) =>
              CatalogController(repository, events: noopAppEventLogger),
          (_) async {},
          (controller) => CatalogTab(controller: controller),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ProvidersTab',
      useCases: [
        _tab<ProvidersController>(
          'Providers',
          pluginsServer,
          (repository) =>
              ProvidersController(repository, events: noopAppEventLogger),
          (_) async {},
          (controller) => ProvidersTab(controller: controller),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PluginDetail',
      useCases: [
        for (final (name, plugin) in [
          (
            'Enabled, updatable',
            const InstalledPlugin(
              name: 'netbox',
              version: '1.2.0',
              description: 'Query NetBox for devices and prefixes.',
              source: 'user',
              status: PluginStatus.enabled,
              canRemove: true,
              canUpdate: true,
            ),
          ),
          (
            'Needs sign-in',
            const InstalledPlugin(
              name: 'calendar',
              version: '0.4.1',
              source: 'user',
              authRequired: true,
              authCommand: 'hermes auth calendar',
              canRemove: true,
            ),
          ),
          (
            'Bundled',
            const InstalledPlugin(
              name: 'terminal',
              version: '1.0.0',
              source: 'bundled',
              status: PluginStatus.enabled,
            ),
          ),
        ])
          _tab<PluginsController>(
            name,
            pluginsServer,
            (repository) =>
                PluginsController(repository, events: noopAppEventLogger),
            (controller) => controller.load(),
            (controller) =>
                PluginDetail(plugin: plugin, controller: controller),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'GitInstallDialog',
      useCases: [
        WidgetbookUseCase(
          name: 'Warning',
          builder: (_) => Center(
            child: GitInstallDialog(
              install: (identifier, {required enable, required force}) async =>
                  const PluginInstallResult(ok: true, pluginName: 'example'),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'InstallActions',
      useCases: [
        WidgetbookUseCase(
          name: 'Ready',
          builder: (_) =>
              frame(InstallActions(installing: false, onInstall: (_) {})),
        ),
        WidgetbookUseCase(
          name: 'Installing',
          builder: (_) =>
              frame(InstallActions(installing: true, onInstall: (_) {})),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ListWithDetail',
      useCases: [
        for (final wide in [false, true])
          WidgetbookUseCase(
            name: wide ? 'Wide (from 900 px), nothing selected' : 'Narrow',
            builder: (context) => ListWithDetail(
              wide: wide && MediaQuery.sizeOf(context).width >= 900,
              list: ListView(
                children: const [
                  ListTile(title: Text('netbox')),
                  ListTile(title: Text('notes-sync')),
                ],
              ),
              detail: null,
              placeholder: 'Select a plugin',
            ),
          ),
      ],
    ),
  ],
);

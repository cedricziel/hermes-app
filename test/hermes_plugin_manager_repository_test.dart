import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';
import 'package:hermes_app/src/plugins/catalog_entry.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';

import 'support/fake_hermes_server.dart';

Map<String, Object?> hubRow(
  String name, {
  String status = 'enabled',
  String source = 'user',
  bool canRemove = true,
  bool canUpdate = false,
  bool authRequired = false,
  String authCommand = '',
  bool hidden = false,
  String? removedReason,
  String? description,
}) => {
  'name': name,
  'version': '1.0.0',
  'description': description ?? 'About $name',
  'source': source,
  'runtime_status': status,
  'has_dashboard_manifest': false,
  'dashboard_manifest': null,
  'path': '/home/hermes/.hermes/plugins/$name',
  'can_remove': canRemove,
  'can_update_git': canUpdate,
  'auth_required': authRequired,
  'auth_command': authCommand,
  'user_hidden': hidden,
  'removed_reason': removedReason,
};

Map<String, Object?> hubBody(List<Object?> rows) => {
  'plugins': rows,
  'orphan_dashboard_plugins': <Object?>[],
  'providers': {'memory_provider': '', 'context_engine': 'default'},
};

Map<String, Object?> catalogRow(
  String name, {
  String tier = 'community',
  String maintainer = 'someone',
  String? description,
  bool installed = false,
  bool updateAvailable = false,
  List<String> tools = const [],
  List<String> hooks = const [],
  List<String> middleware = const [],
  List<String> env = const [],
  List<String> platforms = const [],
  String requiresHermes = '',
  String docsUrl = '',
}) => {
  'name': name,
  'repo': 'https://github.com/someone/$name',
  'sha': 'a3f9c21d5e7b8a90123456789abcdef012345678',
  'sha_short': 'a3f9c21',
  'description': description ?? 'About $name',
  'maintainer': maintainer,
  'tier': tier,
  'requires_hermes': requiresHermes,
  'subdir': '',
  'docs_url': docsUrl,
  'platforms': platforms,
  'capabilities': {
    'provides_tools': tools,
    'provides_hooks': hooks,
    'provides_middleware': middleware,
    'requires_env': env,
  },
  'capability_summary': 'unused',
  'installed': installed,
  'installed_sha': installed
      ? 'a3f9c21d5e7b8a90123456789abcdef012345678'
      : null,
  'update_available': updateAvailable,
  'runtime_status': installed ? 'enabled' : null,
};

Map<String, Object?> catalogBody(List<Object?> entries) => {
  'entries': entries,
  'removed': <Object?>[],
  'generated_at': '2026-09-20T12:00:00Z',
};

void main() {
  late FakeHermesServer server;
  late HermesPluginManagerRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesPluginManagerRepository(server.client().raw);
  });

  group('load', () {
    test('reads every field of a hub row', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([
          hubRow(
            'netbox',
            status: 'disabled',
            canUpdate: true,
            authRequired: true,
            authCommand: 'hermes auth netbox',
            hidden: true,
            removedReason: 'unsafe',
          ),
        ]),
      );

      final plugin = (await repository.load()).single;

      expect(plugin.name, 'netbox');
      expect(plugin.version, '1.0.0');
      expect(plugin.description, 'About netbox');
      expect(plugin.source, 'user');
      expect(plugin.status, PluginStatus.disabled);
      expect(plugin.canRemove, isTrue);
      expect(plugin.canUpdate, isTrue);
      expect(plugin.authRequired, isTrue);
      expect(plugin.authCommand, 'hermes auth netbox');
      expect(plugin.hidden, isTrue);
      expect(plugin.removedReason, 'unsafe');
    });

    test('keeps the order the server lists', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([hubRow('b'), hubRow('a'), hubRow('c')]),
      );

      expect((await repository.load()).map((p) => p.name), ['b', 'a', 'c']);
    });

    test('skips rows without a usable name', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([
          {'version': '1'},
          {'name': ''},
          {'name': 7},
          'nope',
          hubRow('kept'),
        ]),
      );

      expect((await repository.load()).map((p) => p.name), ['kept']);
    });

    test('defaults fields that are missing or the wrong type', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([
          {
            'name': 'bare',
            'version': 3,
            'can_remove': 'yes',
            'auth_command': 5,
            'removed_reason': '',
          },
        ]),
      );

      final plugin = (await repository.load()).single;

      expect(plugin.version, '');
      expect(plugin.description, '');
      expect(plugin.canRemove, isFalse);
      expect(plugin.canUpdate, isFalse);
      expect(plugin.authRequired, isFalse);
      expect(plugin.authCommand, isNull);
      expect(plugin.hidden, isFalse);
      expect(plugin.removedReason, isNull);
    });

    test('reads an unknown or missing status as inactive', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([
          hubRow('new', status: 'quarantined'),
          {'name': 'none'},
        ]),
      );

      final plugins = await repository.load();

      expect(plugins.map((p) => p.status), [
        PluginStatus.inactive,
        PluginStatus.inactive,
      ]);
    });

    test('marks bundled plugins', () async {
      server.on(
        'GET',
        '/api/dashboard/plugins/hub',
        hubBody([hubRow('kanban', source: 'bundled', canRemove: false)]),
      );

      expect((await repository.load()).single.bundled, isTrue);
    });

    test('does not list dashboard-only extensions', () async {
      server.on('GET', '/api/dashboard/plugins/hub', {
        'plugins': [hubRow('netbox')],
        'orphan_dashboard_plugins': [
          {'name': 'kanban', 'label': 'Kanban', 'source': 'bundled'},
        ],
      });

      expect((await repository.load()).map((p) => p.name), ['netbox']);
    });

    test('reads a body that is not the envelope as no plugins', () async {
      server.on('GET', '/api/dashboard/plugins/hub', ['x']);
      expect(await repository.load(), isEmpty);

      server.on('GET', '/api/dashboard/plugins/hub', {'plugins': 'x'});
      expect(await repository.load(), isEmpty);
    });

    test('reports a server without the route', () async {
      expect(repository.load(), throwsA(isA<PluginsUnsupported>()));
    });

    test('lets other failures through', () async {
      server.on('GET', '/api/dashboard/plugins/hub', {
        'detail': 'boom',
      }, status: 500);

      expect(repository.load(), throwsA(isNot(isA<PluginsUnsupported>())));
    });
  });

  group('actions', () {
    const enable = '/api/dashboard/agent-plugins/netbox/enable';

    test('enable and disable post to their routes', () async {
      server
        ..on('POST', enable, {'ok': true, 'name': 'netbox', 'unchanged': false})
        ..on('POST', '/api/dashboard/agent-plugins/netbox/disable', {
          'ok': true,
          'name': 'netbox',
          'unchanged': false,
        });

      final on = await repository.setEnabled('netbox', true);
      final off = await repository.setEnabled('netbox', false);

      expect(on.ok, isTrue);
      expect(off.ok, isTrue);
      expect(server.requestsTo('POST', enable), hasLength(1));
      expect(
        server.requestsTo(
          'POST',
          '/api/dashboard/agent-plugins/netbox/disable',
        ),
        hasLength(1),
      );
    });

    test('update reports whether anything changed', () async {
      const path = '/api/dashboard/agent-plugins/netbox/update';
      server.on('POST', path, {
        'ok': true,
        'name': 'netbox',
        'unchanged': true,
      });
      expect((await repository.update('netbox')).unchanged, isTrue);

      server.on('POST', path, {'ok': true, 'name': 'netbox', 'sha': 'abc'});
      final result = await repository.update('netbox');
      expect(result.ok, isTrue);
      expect(result.unchanged, isFalse);
    });

    test('remove deletes the plugin', () async {
      const path = '/api/dashboard/agent-plugins/netbox';
      server.on('DELETE', path, {'ok': true, 'name': 'netbox'});

      expect((await repository.remove('netbox')).ok, isTrue);
      expect(server.requestsTo('DELETE', path), hasLength(1));
    });

    test('hide sends the flag in the body', () async {
      const path = '/api/dashboard/plugins/netbox/visibility';
      server.on('POST', path, {'ok': true, 'name': 'netbox', 'hidden': true});

      await repository.setHidden('netbox', true);
      await repository.setHidden('netbox', false);

      final bodies = server.requestsTo('POST', path).map(jsonBody).toList();
      expect(bodies, [
        {'hidden': true},
        {'hidden': false},
      ]);
    });

    test('a refusal carries the server\'s reason', () async {
      server.on('POST', enable, {
        'detail': 'Plugin is not installed.',
      }, status: 400);

      final result = await repository.setEnabled('netbox', true);

      expect(result.ok, isFalse);
      expect(result.message, 'Plugin is not installed.');
    });

    test('a refusal without a usable reason has no message', () async {
      server.on('POST', enable, {'detail': ''}, status: 400);
      expect((await repository.setEnabled('netbox', true)).message, isNull);

      server.on('POST', enable, {
        'detail': ['x'],
      }, status: 422);
      expect((await repository.setEnabled('netbox', true)).message, isNull);

      server.on('POST', enable, {'detail': 'internal path /x'}, status: 500);
      final failed = await repository.setEnabled('netbox', true);
      expect(failed.ok, isFalse);
      expect(failed.message, isNull);
    });

    test('an unreachable server is a failure without a message', () async {
      server.onRequest(
        'POST',
        enable,
        (_) => throw const SocketException('no route to host'),
      );

      final result = await repository.setEnabled('netbox', true);

      expect(result.ok, isFalse);
      expect(result.message, isNull);
    });

    test('encodes a name so it cannot leave its path segment', () async {
      const path = '/api/dashboard/agent-plugins/odd%20name%23x/enable';
      server.on('POST', path, {'ok': true, 'name': 'odd name#x'});

      final result = await repository.setEnabled('odd name#x', true);

      expect(result.ok, isTrue);
      expect(server.requestsTo('POST', path), hasLength(1));
    });

    test('sends a nested name as one encoded segment', () async {
      const path = '/api/dashboard/agent-plugins/cat%2Fnetbox/enable';
      server.on('POST', path, {'ok': true, 'name': 'cat/netbox'});

      expect((await repository.setEnabled('cat/netbox', true)).ok, isTrue);
      expect(server.requestsTo('POST', path), hasLength(1));
    });
  });

  group('catalog', () {
    const path = '/api/dashboard/plugins/catalog';

    test('reads every field of an entry', () async {
      server.on(
        'GET',
        path,
        catalogBody([
          catalogRow(
            'netbox',
            tier: 'official',
            maintainer: 'andrew',
            installed: true,
            updateAvailable: true,
            tools: ['netbox_query'],
            hooks: ['pre_tool_call'],
            middleware: ['audit'],
            env: ['NETBOX_URL', 'NETBOX_TOKEN'],
            platforms: ['linux', 'macos'],
            requiresHermes: '>=0.20',
            docsUrl: 'https://example.com/docs',
          ),
        ]),
      );

      final entry = (await repository.loadCatalog()).single;

      expect(entry.name, 'netbox');
      expect(entry.description, 'About netbox');
      expect(entry.maintainer, 'andrew');
      expect(entry.tier, CatalogTier.official);
      expect(entry.commit, 'a3f9c21');
      expect(entry.requiresHermes, '>=0.20');
      expect(entry.platforms, ['linux', 'macos']);
      expect(entry.docsUrl, 'https://example.com/docs');
      expect(entry.providesTools, ['netbox_query']);
      expect(entry.providesHooks, ['pre_tool_call']);
      expect(entry.providesMiddleware, ['audit']);
      expect(entry.requiresEnv, ['NETBOX_URL', 'NETBOX_TOKEN']);
      expect(entry.installed, isTrue);
      expect(entry.updateAvailable, isTrue);
    });

    test(
      'keeps the server\'s order and skips entries without a name',
      () async {
        server.on(
          'GET',
          path,
          catalogBody([
            catalogRow('b'),
            {'description': 'nameless'},
            {'name': ''},
            'nope',
            catalogRow('a'),
          ]),
        );

        expect((await repository.loadCatalog()).map((e) => e.name), ['b', 'a']);
      },
    );

    test('defaults fields that are missing or the wrong type', () async {
      server.on(
        'GET',
        path,
        catalogBody([
          {
            'name': 'bare',
            'tier': 'gold',
            'platforms': 'linux',
            'installed': 'yes',
            'capabilities': {
              'provides_tools': ['ok', 3, null],
              'requires_env': 'X',
            },
          },
        ]),
      );

      final entry = (await repository.loadCatalog()).single;

      expect(entry.tier, CatalogTier.community);
      expect(entry.description, '');
      expect(entry.maintainer, '');
      expect(entry.commit, '');
      expect(entry.platforms, isEmpty);
      expect(entry.providesTools, ['ok']);
      expect(entry.requiresEnv, isEmpty);
      expect(entry.installed, isFalse);
      expect(entry.updateAvailable, isFalse);
    });

    test('takes the commit from sha when sha_short is missing', () async {
      server.on(
        'GET',
        path,
        catalogBody([
          {'name': 'x', 'sha': '4688c38295a7b86f8119d7a0ecc09cd0b83a2730'},
        ]),
      );

      expect((await repository.loadCatalog()).single.commit, '4688c38');
    });

    test('reads a body that is not the envelope as empty', () async {
      server.on('GET', path, ['x']);
      expect(await repository.loadCatalog(), isEmpty);

      server.on('GET', path, {'entries': 'x'});
      expect(await repository.loadCatalog(), isEmpty);
    });

    test('reports a server without the route', () async {
      expect(repository.loadCatalog(), throwsA(isA<PluginsUnsupported>()));
    });
  });

  group('installs', () {
    const install = '/api/dashboard/agent-plugins/install';

    test('a catalog install sends the catalog name and nothing else to '
        'resolve', () async {
      server.on('POST', install, {
        'ok': true,
        'plugin_name': 'netbox',
        'warnings': <Object?>[],
        'missing_env': <Object?>[],
        'enabled': true,
      });

      final result = await repository.installFromCatalog(
        'hermes-plugin-netbox',
        enable: false,
      );

      expect(result.ok, isTrue);
      expect(result.pluginName, 'netbox');
      expect(jsonBody(server.requestsTo('POST', install).single), {
        'identifier': '',
        'catalog_name': 'hermes-plugin-netbox',
        'enable': false,
        'force': false,
      });
    });

    test('a source install sends the identifier and no catalog name', () async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'cool'});

      await repository.installFromSource(
        'someone/hermes-cool-plugin',
        enable: true,
        force: true,
      );

      final body = jsonBody(
        server.requestsTo('POST', install).single,
      ) as Map<String, Object?>;
      expect(body['identifier'], 'someone/hermes-cool-plugin');
      expect(body.containsKey('catalog_name'), isFalse);
      expect(body['enable'], true);
      expect(body['force'], true);
    });

    test(
      'reads warnings and missing variables, dropping other items',
      () async {
        server.on('POST', install, {
          'ok': true,
          'plugin_name': 'cool',
          'warnings': ['Custom (unreviewed) source.', 4, ''],
          'missing_env': ['NETBOX_URL', null],
        });

        final result = await repository.installFromSource('x/y');

        expect(result.warnings, ['Custom (unreviewed) source.']);
        expect(result.missingEnv, ['NETBOX_URL']);
      },
    );

    test('a refusal carries the server\'s reason', () async {
      server.on('POST', install, {
        'detail': "'x' is on the removed list.",
      }, status: 400);

      final result = await repository.installFromCatalog('x');

      expect(result.ok, isFalse);
      expect(result.message, "'x' is on the removed list.");
      expect(result.timedOut, isFalse);
    });

    test('other failures carry no message', () async {
      server.on('POST', install, {'detail': ''}, status: 400);
      expect((await repository.installFromCatalog('x')).message, isNull);

      server.on('POST', install, {'detail': 'trace at /srv/x'}, status: 500);
      final failed = await repository.installFromCatalog('x');
      expect(failed.ok, isFalse);
      expect(failed.message, isNull);

      server.onRequest(
        'POST',
        install,
        (_) => throw const SocketException('no route to host'),
      );
      final unreachable = await repository.installFromCatalog('x');
      expect(unreachable.ok, isFalse);
      expect(unreachable.timedOut, isFalse);
    });

    test('a receive timeout is not a failure', () async {
      server.onRequest(
        'POST',
        install,
        (request) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: request,
        ),
      );

      final result = await repository.installFromCatalog('x');

      expect(result.timedOut, isTrue);
      expect(result.ok, isFalse);
      expect(result.message, isNull);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}

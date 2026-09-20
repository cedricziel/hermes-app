import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/plugins_controller.dart';

import 'hermes_plugin_manager_repository_test.dart' show hubBody, hubRow;
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late List<(String, Map<String, Object>)> events;
  late PluginsController controller;

  const hub = '/api/dashboard/plugins/hub';

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        hub,
        hubBody([hubRow('netbox'), hubRow('kanban', source: 'bundled')]),
      );
    events = [];
    controller = PluginsController(
      HermesPluginManagerRepository(server.client().raw),
      events: (name, [attributes = const {}]) => events.add((name, attributes)),
    );
  });

  tearDown(() => controller.dispose());

  group('loading', () {
    test('is loading until the first answer, then lists the rows', () async {
      final load = controller.load();
      expect(controller.loading, isTrue);

      await load;

      expect(controller.loading, isFalse);
      expect(controller.plugins.map((p) => p.name), ['netbox', 'kanban']);
      expect(controller.failure, isNull);
    });

    test('a failed first load says so and can be retried', () async {
      server.on('GET', hub, {'detail': 'boom'}, status: 500);
      await controller.load();
      expect(controller.failure, PluginsFailure.failed);

      server.on('GET', hub, hubBody([hubRow('netbox')]));
      await controller.load();

      expect(controller.failure, isNull);
      expect(controller.plugins, hasLength(1));
    });

    test('a server without the hub is unsupported', () async {
      server.on('GET', hub, {'detail': 'Not Found'}, status: 404);

      await controller.load();

      expect(controller.failure, PluginsFailure.unsupported);
    });

    test('a refresh keeps the rows while it runs', () async {
      await controller.load();
      final gate = Completer<void>();
      server.onRequest('GET', hub, (_) async {
        await gate.future;
        return (status: 200, body: hubBody([hubRow('only')]));
      });

      final refresh = controller.refresh();
      expect(controller.plugins.map((p) => p.name), ['netbox', 'kanban']);
      expect(controller.loading, isFalse);

      gate.complete();
      expect(await refresh, isTrue);
      expect(controller.plugins.map((p) => p.name), ['only']);
    });

    test('a failed refresh keeps the rows and reports it', () async {
      await controller.load();
      server.on('GET', hub, {'detail': 'boom'}, status: 500);

      expect(await controller.refresh(), isFalse);

      expect(controller.plugins, hasLength(2));
      expect(controller.failure, isNull);
    });
  });

  group('changes', () {
    const enable = '/api/dashboard/agent-plugins/netbox/enable';

    setUp(() => controller.load());

    test(
      'marks the plugin busy, then reloads and reports the outcome',
      () async {
        final gate = Completer<void>();
        server.onRequest('POST', enable, (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true, 'name': 'netbox'});
        });
        server.on('GET', hub, hubBody([hubRow('netbox', status: 'disabled')]));

        final change = controller.setEnabled('netbox', true);
        await Future<void>.delayed(Duration.zero);
        expect(controller.isBusy('netbox'), isTrue);
        expect(controller.isBusy('kanban'), isFalse);

        gate.complete();
        final result = await change;

        expect(result.ok, isTrue);
        expect(controller.isBusy('netbox'), isFalse);
        expect(controller.plugins.single.status, PluginStatus.disabled);
      },
    );

    test('leaves the list alone when the server refuses', () async {
      server.on('POST', enable, {'detail': 'No.'}, status: 400);
      final before = server.requestsTo('GET', hub).length;

      final result = await controller.setEnabled('netbox', true);

      expect(result.ok, isFalse);
      expect(result.message, 'No.');
      expect(server.requestsTo('GET', hub), hasLength(before));
      expect(controller.isBusy('netbox'), isFalse);
    });

    test('routes each action to its call', () async {
      server
        ..on('POST', '/api/dashboard/agent-plugins/netbox/disable', {
          'ok': true,
        })
        ..on('POST', '/api/dashboard/agent-plugins/netbox/update', {
          'ok': true,
          'unchanged': true,
        })
        ..on('DELETE', '/api/dashboard/agent-plugins/netbox', {'ok': true})
        ..on('POST', '/api/dashboard/plugins/netbox/visibility', {'ok': true});

      await controller.setEnabled('netbox', false);
      final update = await controller.update('netbox');
      await controller.remove('netbox');
      await controller.setHidden('netbox', true);

      expect(update.unchanged, isTrue);
      expect(
        server.requests.where((r) => r.method != 'GET').map((r) => r.path),
        [
          '/api/dashboard/agent-plugins/netbox/disable',
          '/api/dashboard/agent-plugins/netbox/update',
          '/api/dashboard/agent-plugins/netbox',
          '/api/dashboard/plugins/netbox/visibility',
        ],
      );
    });
  });

  group('selection', () {
    setUp(() => controller.load());

    test('follows the selected plugin through a reload', () async {
      controller.select('netbox');
      expect(controller.selected?.name, 'netbox');

      server.on('GET', hub, hubBody([hubRow('netbox', status: 'disabled')]));
      await controller.refresh();

      expect(controller.selected?.status, PluginStatus.disabled);
    });

    test('is cleared when the plugin is gone', () async {
      controller.select('netbox');
      server.on('GET', hub, hubBody([hubRow('kanban')]));

      await controller.refresh();

      expect(controller.selected, isNull);
      expect(controller.selectedName, isNull);
    });
  });

  group('telemetry', () {
    setUp(() => controller.load());

    test('logs one event per action with only the plugin name', () async {
      server
        ..on('POST', '/api/dashboard/agent-plugins/netbox/enable', {'ok': true})
        ..on('POST', '/api/dashboard/agent-plugins/netbox/disable', {
          'detail': 'secret /home/x',
        }, status: 400)
        ..on('POST', '/api/dashboard/agent-plugins/netbox/update', {
          'ok': true,
          'unchanged': true,
        })
        ..on('DELETE', '/api/dashboard/agent-plugins/netbox', {'ok': true})
        ..on('POST', '/api/dashboard/plugins/netbox/visibility', {'ok': true});

      await controller.setEnabled('netbox', true);
      await controller.setEnabled('netbox', false);
      await controller.update('netbox');
      await controller.remove('netbox');
      await controller.setHidden('netbox', true);

      expect(events.map((e) => e.$1), [
        'plugins.enable.ok',
        'plugins.disable.error',
        'plugins.update.unchanged',
        'plugins.remove.ok',
        'plugins.hide.ok',
      ]);
      for (final (_, attributes) in events) {
        expect(attributes, {'plugin.name': 'netbox'});
      }
    });

    test('logs an updated plugin as ok', () async {
      server.on('POST', '/api/dashboard/agent-plugins/netbox/update', {
        'ok': true,
      });

      await controller.update('netbox');

      expect(events.single.$1, 'plugins.update.ok');
    });
  });
}

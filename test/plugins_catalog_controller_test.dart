import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/catalog_controller.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_controller.dart'
    show PluginsFailure;

import 'hermes_plugin_manager_repository_test.dart'
    show catalogBody, catalogRow;
import 'support/fake_hermes_server.dart';

void main() {
  const catalog = '/api/dashboard/plugins/catalog';
  const install = '/api/dashboard/agent-plugins/install';

  late FakeHermesServer server;
  late List<(String, Map<String, Object>)> events;
  late int installed;
  late CatalogController controller;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        catalog,
        catalogBody([
          catalogRow('hermes-plugin-netbox', maintainer: 'Andrew'),
          catalogRow('chrome-profiles', description: 'Switch Chrome profiles'),
          catalogRow('snapcompact'),
        ]),
      );
    events = [];
    installed = 0;
    controller = CatalogController(
      HermesPluginManagerRepository(server.client().raw),
      events: (name, [attributes = const {}]) => events.add((name, attributes)),
      onInstalled: () => installed++,
    );
  });

  tearDown(() => controller.dispose());

  group('loading', () {
    test('is loading until the first answer, then lists the entries', () async {
      final load = controller.load();
      expect(controller.loading, isTrue);

      await load;

      expect(controller.loading, isFalse);
      expect(controller.entries.map((e) => e.name), [
        'hermes-plugin-netbox',
        'chrome-profiles',
        'snapcompact',
      ]);
    });

    test('a failed load says so and can be retried', () async {
      server.on('GET', catalog, {'detail': 'boom'}, status: 500);
      await controller.load();
      expect(controller.failure, PluginsFailure.failed);

      server.on('GET', catalog, catalogBody([catalogRow('a')]));
      await controller.load();

      expect(controller.failure, isNull);
      expect(controller.entries, hasLength(1));
    });

    test('a server without the catalog is unsupported', () async {
      server.on('GET', catalog, {'detail': 'Not Found'}, status: 404);

      await controller.load();

      expect(controller.failure, PluginsFailure.unsupported);
    });

    test('a failed refresh keeps the entries', () async {
      await controller.load();
      server.on('GET', catalog, {'detail': 'boom'}, status: 500);

      expect(await controller.refresh(), isFalse);

      expect(controller.entries, hasLength(3));
      expect(controller.failure, isNull);
    });
  });

  group('search', () {
    setUp(() => controller.load());

    test('shows everything without a query', () {
      expect(controller.visible, hasLength(3));
    });

    test('matches name, description and maintainer, ignoring case', () {
      controller.setQuery('NETBOX');
      expect(controller.visible.map((e) => e.name), ['hermes-plugin-netbox']);

      controller.setQuery('nothing like it');
      expect(controller.visible, isEmpty);

      controller.setQuery('switch chrome');
      expect(controller.visible.map((e) => e.name), ['chrome-profiles']);

      controller.setQuery('andrew');
      expect(controller.visible.map((e) => e.name), ['hermes-plugin-netbox']);
    });

    test('ignores surrounding blanks and clears', () {
      controller.setQuery('  snap ');
      expect(controller.visible.map((e) => e.name), ['snapcompact']);

      controller.setQuery('');
      expect(controller.visible, hasLength(3));
    });

    test('keeps the query across a reload', () async {
      controller.setQuery('snap');

      await controller.refresh();

      expect(controller.query, 'snap');
      expect(controller.visible, hasLength(1));
    });
  });

  group('selection', () {
    setUp(() => controller.load());

    test('follows the entry through a reload', () async {
      controller.select('snapcompact');
      server.on(
        'GET',
        catalog,
        catalogBody([catalogRow('snapcompact', installed: true)]),
      );

      await controller.refresh();

      expect(controller.selected?.installed, isTrue);
    });

    test('is cleared when the entry is gone', () async {
      controller.select('snapcompact');
      server.on('GET', catalog, catalogBody([catalogRow('other')]));

      await controller.refresh();

      expect(controller.selected, isNull);
    });
  });

  group('installing', () {
    setUp(() => controller.load());

    test(
      'marks the entry busy, then reloads and reports the install',
      () async {
        final gate = Completer<void>();
        server.onRequest('POST', install, (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true, 'plugin_name': 'snap'});
        });
        server.on(
          'GET',
          catalog,
          catalogBody([catalogRow('snapcompact', installed: true)]),
        );

        final run = controller.installFromCatalog('snapcompact');
        await Future<void>.delayed(Duration.zero);
        expect(controller.isInstalling('snapcompact'), isTrue);
        expect(controller.isInstalling('other'), isFalse);

        gate.complete();
        final result = await run;

        expect(result?.ok, isTrue);
        expect(controller.isInstalling('snapcompact'), isFalse);
        expect(controller.entries.single.installed, isTrue);
        expect(installed, 1);
      },
    );

    test('ignores a second install of an entry that is busy', () async {
      final gate = Completer<void>();
      server.onRequest('POST', install, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'plugin_name': 'snap'});
      });

      final first = controller.installFromCatalog('snapcompact');
      await Future<void>.delayed(Duration.zero);
      final second = await controller.installFromCatalog('snapcompact');
      gate.complete();
      await first;

      expect(second, isNull);
      expect(server.requestsTo('POST', install), hasLength(1));
    });

    test('a refusal changes nothing', () async {
      server.on('POST', install, {'detail': 'No.'}, status: 400);
      final before = server.requestsTo('GET', catalog).length;

      final result = await controller.installFromCatalog('snapcompact');

      expect(result?.message, 'No.');
      expect(server.requestsTo('GET', catalog), hasLength(before));
      expect(installed, 0);
    });

    test('a timeout reloads as if it had worked', () async {
      server.onRequest(
        'POST',
        install,
        (request) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: request,
        ),
      );
      final before = server.requestsTo('GET', catalog).length;

      final result = await controller.installFromCatalog('snapcompact');

      expect(result?.timedOut, isTrue);
      expect(server.requestsTo('GET', catalog), hasLength(before + 1));
      expect(installed, 1);
    });

    test('an install from a source reports and reloads the same way', () async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'cool'});

      final result = await controller.installFromSource(
        'someone/cool',
        enable: true,
        force: false,
      );

      expect(result.ok, isTrue);
      expect(installed, 1);
    });
  });

  group('telemetry', () {
    setUp(() => controller.load());

    test('logs a catalog install with the catalog name only', () async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'snap'});
      await controller.installFromCatalog('snapcompact');
      server.on('POST', install, {'detail': 'x'}, status: 400);
      await controller.installFromCatalog('snapcompact');

      expect(events.map((e) => e.$1), [
        'plugins.install.ok',
        'plugins.install.error',
      ]);
      for (final (_, attributes) in events) {
        expect(attributes, {'plugin.name': 'snapcompact'});
      }
    });

    test('logs a timeout as its own outcome', () async {
      server.onRequest(
        'POST',
        install,
        (request) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: request,
        ),
      );

      await controller.installFromCatalog('snapcompact');

      expect(events.single.$1, 'plugins.install.timeout');
    });

    test('logs a source install without the identifier', () async {
      server.on('POST', install, {'ok': true, 'plugin_name': 'cool'});
      await controller.installFromSource(
        'https://user:secret-token@example.com/x.git',
        enable: true,
        force: false,
      );
      server.on('POST', install, {'detail': 'nope'}, status: 400);
      await controller.installFromSource(
        'https://user:secret-token@example.com/x.git',
        enable: true,
        force: false,
      );

      expect(events.map((e) => e.$1), [
        'plugins.install_custom.ok',
        'plugins.install_custom.error',
      ]);
      expect(events.every((e) => e.$2.isEmpty), isTrue);
    });
  });
}

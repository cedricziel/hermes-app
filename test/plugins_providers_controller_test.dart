import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_controller.dart'
    show PluginsFailure;
import 'package:hermes_app/src/plugins/providers_controller.dart';

import 'hermes_plugin_manager_repository_test.dart'
    show memoryOption, providersHub;
import 'support/fake_hermes_server.dart';

void main() {
  const hub = '/api/dashboard/plugins/hub';
  const save = '/api/dashboard/plugin-providers';

  late FakeHermesServer server;
  late List<(String, Map<String, Object>)> events;
  late ProvidersController controller;

  void serve({
    String memory = 'honcho',
    String engine = 'compressor',
    List<Object?>? engines,
  }) => server.on(
    'GET',
    hub,
    providersHub(
      memory: memory,
      memoryOptions: [
        memoryOption('honcho'),
        memoryOption('mem0', status: 'needs_config'),
        memoryOption('holographic'),
      ],
      engine: engine,
      engines:
          engines ??
          [
            {'name': 'compressor', 'description': 'Default'},
            {'name': 'lossless', 'description': 'All'},
          ],
    ),
  );

  setUp(() {
    server = FakeHermesServer();
    serve();
    events = [];
    controller = ProvidersController(
      HermesPluginManagerRepository(server.client().raw),
      events: (name, [attributes = const {}]) => events.add((name, attributes)),
    );
  });

  tearDown(() => controller.dispose());

  group('loading', () {
    test(
      'is loading until the first answer, then holds the settings',
      () async {
        final load = controller.load();
        expect(controller.loading, isTrue);

        await load;

        expect(controller.loading, isFalse);
        expect(controller.memoryChoice, 'honcho');
        expect(controller.contextChoice, 'compressor');
        expect(controller.dirty, isFalse);
      },
    );

    test('a failed load says so and can be retried', () async {
      server.on('GET', hub, {'detail': 'boom'}, status: 500);
      await controller.load();
      expect(controller.failure, PluginsFailure.failed);

      serve();
      await controller.load();

      expect(controller.failure, isNull);
    });

    test('a server without the hub is unsupported', () async {
      server.on('GET', hub, {'detail': 'Not Found'}, status: 404);

      await controller.load();

      expect(controller.failure, PluginsFailure.unsupported);
    });

    test('a failed refresh keeps the settings and the draft', () async {
      await controller.load();
      controller.chooseMemory('holographic');
      server.on('GET', hub, {'detail': 'boom'}, status: 500);

      expect(await controller.refresh(), isFalse);

      expect(controller.settings.memoryOptions, hasLength(3));
      expect(controller.memoryChoice, 'holographic');
    });

    test('a refresh replaces the draft with what the server says', () async {
      await controller.load();
      controller.chooseMemory('holographic');
      controller.chooseContext('lossless');

      expect(await controller.refresh(), isTrue);

      expect(controller.memoryChoice, 'honcho');
      expect(controller.contextChoice, 'compressor');
      expect(controller.dirty, isFalse);
    });
  });

  group('choices', () {
    setUp(() => controller.load());

    test('are dirty only while they differ from the server', () {
      controller.chooseMemory('holographic');
      expect(controller.dirty, isTrue);

      controller.chooseMemory('honcho');
      expect(controller.dirty, isFalse);

      controller.chooseContext('lossless');
      expect(controller.dirty, isTrue);
    });

    test('built-in is the empty string', () {
      controller.chooseMemory('');

      expect(controller.dirty, isTrue);
      expect(controller.memoryChoice, '');
    });

    test('add the engine in use when the server does not list it', () async {
      serve(engine: 'custom-one');
      await controller.load();

      expect(controller.contextOptions.map((o) => o.name), [
        'custom-one',
        'compressor',
        'lossless',
      ]);
    });

    test(
      'list no engine when the server has none and none is in use',
      () async {
        serve(engine: '', engines: []);
        await controller.load();

        expect(controller.contextOptions, isEmpty);
      },
    );

    test('list only the engine in use when the server lists none', () async {
      serve(engines: []);
      await controller.load();

      expect(controller.contextOptions.map((o) => o.name), ['compressor']);
      expect(controller.hasContextChoice, isFalse);
    });
  });

  group('saving', () {
    setUp(() => controller.load());

    test(
      'sends only what changed, then reloads and clears the draft',
      () async {
        server.on('PUT', save, {'ok': true});
        serve(memory: 'holographic');
        controller.chooseMemory('holographic');

        final result = await controller.save();

        expect(result.ok, isTrue);
        expect(jsonBody(server.requestsTo('PUT', save).single), {
          'memory_provider': 'holographic',
        });
        expect(controller.settings.memoryProvider, 'holographic');
        expect(controller.dirty, isFalse);
        expect(controller.saving, isFalse);
      },
    );

    test(
      'sends an empty string for built-in and the engine when both changed',
      () async {
        server.on('PUT', save, {'ok': true});
        controller.chooseMemory('');
        controller.chooseContext('lossless');

        await controller.save();

        expect(jsonBody(server.requestsTo('PUT', save).single), {
          'memory_provider': '',
          'context_engine': 'lossless',
        });
      },
    );

    test('keeps the draft when the server refuses', () async {
      server.on('PUT', save, {'detail': 'not ready'}, status: 400);
      controller.chooseMemory('mem0');

      final result = await controller.save();

      expect(result.message, 'not ready');
      expect(controller.memoryChoice, 'mem0');
      expect(controller.dirty, isTrue);
      expect(controller.saving, isFalse);
    });
  });

  group('telemetry', () {
    setUp(() => controller.load());

    test('logs a save with only the fields it sent', () async {
      server.on('PUT', save, {'ok': true});
      controller.chooseMemory('holographic');
      await controller.save();

      expect(events.single.$1, 'plugins.providers.save.ok');
      expect(events.single.$2, {'memory.provider': 'holographic'});
    });

    test('logs built-in by name and a failure as an error', () async {
      server.on('PUT', save, {'detail': 'secret /srv/x'}, status: 400);
      controller.chooseMemory('');
      controller.chooseContext('lossless');
      await controller.save();

      expect(events.single.$1, 'plugins.providers.save.error');
      expect(events.single.$2, {
        'memory.provider': 'builtin',
        'context.engine': 'lossless',
      });
    });
  });
}

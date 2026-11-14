import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/toolset_setup_controller.dart';
import 'package:hermes_app/src/tools/tools_write.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

const _web = '/api/tools/toolsets/web';
const _image = '/api/tools/toolsets/image_gen';

Map<String, Object?> _webConfig({String active = 'Search Co'}) => {
  ...webConfigFixture,
  'active_provider': active,
  'providers': [
    for (final p in webConfigFixture['providers']! as List)
      {...(p as Map<String, Object?>), 'is_active': p['name'] == active},
  ],
};

Map<String, Object?> _images({String current = 'fast-1'}) => {
  ...imageModelsFixture,
  'models': [
    ...imageModelsFixture['models']! as List,
    {'id': 'slow-2', 'display': 'Slow Two'},
  ],
  'current': current,
};

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late List<String> events;
  late ToolsetSetupController web;

  ToolsetSetupController build(String toolset) => ToolsetSetupController(
    toolsRepository(server),
    toolset: toolset,
    checkTimeout: const Duration(milliseconds: 200),
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      events: (name, [attributes = const {}]) =>
          events.add('$name $attributes'),
    ),
  );

  Iterable<Object?> bodies(String path) =>
      server.requestsTo('PUT', path).map((r) => jsonDecode(r.data as String));

  void lose(String path) => server.onRequest('PUT', path, (r) {
    throw DioException.receiveTimeout(
      timeout: const Duration(seconds: 1),
      requestOptions: r,
    );
  });

  setUp(() async {
    server = FakeHermesServer()..on('GET', '$_web/config', _webConfig());
    tracer = RecordingTracer();
    events = [];
    web = build('web');
    await web.load();
  });

  tearDown(() => web.dispose());

  group('provider', () {
    test(
      'a pick sends the provider, reads the config back and selects it',
      () async {
        server
          ..on('PUT', '$_web/provider', {
            'ok': true,
            'provider': 'Local Driver',
          })
          ..on('GET', '$_web/config', _webConfig(active: 'Local Driver'));

        await web.pickProvider('Local Driver');

        expect(bodies('$_web/provider'), hasLength(1));
        expect(
          bodies('$_web/provider').single,
          containsPair('provider', 'Local Driver'),
        );
        expect(web.selectedProvider, 'Local Driver');
        expect(web.config!.activeProvider, 'Local Driver');
        expect(web.providerState, ToolsWriteState.idle);
        expect(web.needsNousAuth, isFalse);
        expect(web.writing, isFalse);
      },
    );

    test('needs_nous_auth is a flag, not text', () async {
      server.on('PUT', '$_web/provider', {
        'ok': true,
        'provider': 'Local Driver',
        'needs_nous_auth': true,
        'feature': 'web',
      });

      await web.pickProvider('Local Driver');

      expect(web.needsNousAuth, isTrue);
      server.on('PUT', '$_web/provider', {'ok': true});
      await web.pickProvider('Search Co');
      expect(web.needsNousAuth, isFalse);
    });

    test('a refusal keeps the old selection and holds the text', () async {
      server.on('PUT', '$_web/provider', {
        'detail': 'Unknown provider',
      }, status: 400);

      await web.pickProvider('Local Driver');

      expect(web.providerState, ToolsWriteState.refused);
      expect(web.providerRefusalDetail, 'Unknown provider');
      expect(web.selectedProvider, 'Search Co');
    });

    test('a failure sends nothing again', () async {
      server.on('PUT', '$_web/provider', {'detail': 'boom'}, status: 500);

      await web.pickProvider('Local Driver');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(web.providerState, ToolsWriteState.failed);
      expect(bodies('$_web/provider'), hasLength(1));
    });

    test('web search and extract picks send the capability', () async {
      server.on('PUT', '$_web/provider', {'ok': true});

      await web.pickProvider('Local Driver', capability: 'extract');

      expect(
        bodies('$_web/provider').single,
        containsPair('capability', 'extract'),
      );
      // The capability pick does not change the provider whose keys show.
      expect(web.selectedProvider, 'Search Co');
    });

    test(
      'a lost answer whose re-read shows the pick is ok, never resent',
      () async {
        lose('$_web/provider');
        server.on('GET', '$_web/config', _webConfig(active: 'Local Driver'));

        await web.pickProvider('Local Driver');

        expect(web.providerState, ToolsWriteState.idle);
        expect(web.selectedProvider, 'Local Driver');
        expect(bodies('$_web/provider'), hasLength(1));
      },
    );

    test(
      'a lost answer whose re-read shows no change is not applied',
      () async {
        lose('$_web/provider');

        await web.pickProvider('Local Driver');

        expect(web.providerState, ToolsWriteState.notApplied);
        expect(bodies('$_web/provider'), hasLength(1));
      },
    );

    test('a lost answer with a hanging re-read ends unconfirmed', () async {
      lose('$_web/provider');
      final hang = Completer<void>();
      server.onRequest('GET', '$_web/config', (_) async {
        await hang.future;
        return (status: 200, body: _webConfig());
      });

      await web.pickProvider('Local Driver');

      expect(web.providerState, ToolsWriteState.unconfirmed);
      expect(bodies('$_web/provider'), hasLength(1));
      hang.complete();
    });

    test('a lost capability pick is checked against the backend', () async {
      lose('$_web/provider');
      server.on('GET', '$_web/config', {
        ..._webConfig(),
        'active_extract_backend': 'searchco',
      });

      await web.pickProvider('Search Co', capability: 'extract');

      expect(web.providerState, ToolsWriteState.idle);
    });

    test(
      'one write at a time: a second pick while one runs is not sent',
      () async {
        final gate = Completer<void>();
        server.onRequest('PUT', '$_web/provider', (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true});
        });

        final first = web.pickProvider('Local Driver');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await web.pickProvider('Search Co');
        web.setKey('SEARCHCO_API_KEY', 'x');
        await web.saveKeys();
        gate.complete();
        await first;

        expect(bodies('$_web/provider'), hasLength(1));
        expect(server.requestsTo('PUT', '$_web/env'), isEmpty);
      },
    );

    test('a pick drops what was typed for another provider', () async {
      server.on('PUT', '$_web/provider', {'ok': true});
      web.setKey('SEARCHCO_API_KEY', 'typed');

      await web.pickProvider('Local Driver');

      expect(web.hasTypedKeys, isFalse);
    });

    test('a late answer after a profile switch is dropped', () async {
      final gate = Completer<void>();
      server.onRequest('PUT', '$_web/provider', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true, 'needs_nous_auth': true});
      });
      final pending = web.pickProvider('Local Driver');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      web.switchProfile(toolsRepository(server, profile: 'home'));
      gate.complete();
      await pending;

      expect(web.needsNousAuth, isFalse);
      expect(web.selectedProvider, isNull);
      expect(web.providerState, ToolsWriteState.idle);
      expect(web.writing, isFalse);
    });

    test('a dispose while a pick runs does not throw', () async {
      final gate = Completer<void>();
      server.onRequest('PUT', '$_web/provider', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });
      final other = build('web');
      await other.load();
      final pending = other.pickProvider('Local Driver');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      other.dispose();
      gate.complete();
      await pending;
    });

    test(
      'the span and the event carry the step and the outcome only',
      () async {
        server.on('PUT', '$_web/provider', {'ok': true});

        await web.pickProvider('Local Driver', capability: 'search');

        final span = tracer.spans.singleWhere((s) => s.name == 'tools.setup');
        expect(span.attributes['step'], 'provider');
        expect(span.attributes['outcome'], 'ok');
        expect(span.ended, isTrue);
        expect(
          events,
          contains('tools.setup_outcome {step: provider, outcome: ok}'),
        );
        final recorded = [
          for (final s in tracer.spans) '${s.name} ${s.attributes}',
          ...events,
        ].join('\n');
        expect(recorded, isNot(contains('Local Driver')));
        expect(recorded, isNot(contains('Search Co')));
        expect(recorded, isNot(contains('work')));
      },
    );
  });

  group('model', () {
    late ToolsetSetupController image;

    setUp(() async {
      server.on('GET', '$_image/models', _images());
      image = build('image_gen');
      await image.loadModels();
    });

    tearDown(() => image.dispose());

    test('loads the catalog of an image toolset', () {
      expect(image.hasModelCatalog, isTrue);
      expect(image.models!.models, hasLength(2));
      expect(image.models!.current, 'fast-1');
    });

    test('a toolset without a catalog sends nothing and has none', () async {
      server.on('GET', '/api/tools/toolsets/web/models', {
        'name': 'web',
        'has_models': false,
        'models': [],
      });

      await web.loadModels();

      expect(web.models, isNull);
      expect(web.hasModelCatalog, isFalse);
      expect(server.requestsTo('GET', '$_web/models'), isEmpty);
    });

    test('has_models false means no catalog', () async {
      server.on('GET', '$_image/models', {
        'name': 'image_gen',
        'has_models': false,
        'models': [],
        'current': null,
        'default': null,
      });

      await image.loadModels();

      expect(image.hasModelCatalog, isFalse);
      await image.pickModel('fast-1');
      expect(server.requestsTo('PUT', '$_image/model'), isEmpty);
    });

    test('a failed catalog read is a failure, not an exception', () async {
      server.on('GET', '$_image/models', {'detail': 'x'}, status: 500);

      await image.loadModels();

      expect(image.modelsFailure, isNotNull);
      expect(image.models, isNotNull, reason: 'the last good catalog stays');
    });

    test('a pick sends the id and reads the catalog back', () async {
      server
        ..on('PUT', '$_image/model', {'ok': true, 'model': 'slow-2'})
        ..on('GET', '$_image/models', _images(current: 'slow-2'));

      await image.pickModel('slow-2');

      expect(bodies('$_image/model').single, containsPair('model', 'slow-2'));
      expect(image.models!.current, 'slow-2');
      expect(image.modelState, ToolsWriteState.idle);
    });

    test('an id the catalog does not list is never sent', () async {
      await image.pickModel('invented');

      expect(server.requestsTo('PUT', '$_image/model'), isEmpty);
    });

    test('a refusal holds Hermes\' text', () async {
      server.on('PUT', '$_image/model', {
        'detail': 'Unknown model',
      }, status: 400);

      await image.pickModel('slow-2');

      expect(image.modelState, ToolsWriteState.refused);
      expect(image.modelRefusalDetail, 'Unknown model');
      expect(image.models!.current, 'fast-1');
    });

    test('a lost answer is checked in the catalog and never resent', () async {
      lose('$_image/model');
      server.on('GET', '$_image/models', _images(current: 'slow-2'));

      await image.pickModel('slow-2');

      expect(image.modelState, ToolsWriteState.idle);
      expect(bodies('$_image/model'), hasLength(1));
    });

    test('a lost answer with no change is not applied', () async {
      lose('$_image/model');

      await image.pickModel('slow-2');

      expect(image.modelState, ToolsWriteState.notApplied);
      expect(bodies('$_image/model'), hasLength(1));
    });

    test('a lost answer with a hanging read is unconfirmed', () async {
      lose('$_image/model');
      final hang = Completer<void>();
      server.onRequest('GET', '$_image/models', (_) async {
        await hang.future;
        return (status: 200, body: _images());
      });

      await image.pickModel('slow-2');

      expect(image.modelState, ToolsWriteState.unconfirmed);
      hang.complete();
    });

    test('the span carries the step and the outcome only', () async {
      server.on('PUT', '$_image/model', {'ok': true});

      await image.pickModel('slow-2');

      final span = tracer.spans.singleWhere((s) => s.name == 'tools.setup');
      expect(span.attributes['step'], 'model');
      expect('${span.attributes}', isNot(contains('slow-2')));
      expect(events.join(), isNot(contains('slow-2')));
    });
  });
}

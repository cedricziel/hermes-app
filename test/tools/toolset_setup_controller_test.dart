import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/toolset_setup_controller.dart';
import 'package:hermes_app/src/tools/tools_write.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

const _secret = 'sk-test-9876543210-NOT-A-REAL-KEY';
const _env = '/api/tools/toolsets/web/env';
const _key = 'SEARCHCO_API_KEY';

Map<String, Object?> _config({required bool isSet}) {
  final provider = {
    ...(webConfigFixture['providers']! as List).first as Map<String, Object?>,
    'env_vars': [
      {'key': _key, 'prompt': 'Search Co API key', 'is_set': isSet},
    ],
  };
  return {
    ...webConfigFixture,
    'providers': [provider],
  };
}

void main() {
  late FakeHermesServer server;
  late ToolsetSetupController controller;
  late RecordingTracer tracer;
  late List<String> events;

  Iterable<RequestOptions> saves() => server.requestsTo('PUT', _env);

  setUp(() async {
    server = FakeHermesServer()
      ..on('GET', '/api/tools/toolsets/web/config', _config(isSet: false));
    tracer = RecordingTracer();
    events = [];
    controller = ToolsetSetupController(
      toolsRepository(server),
      toolset: 'web',
      checkTimeout: const Duration(milliseconds: 200),
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
      ),
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('a save sends only the typed, non-blank key and clears it', () async {
    server
      ..on('PUT', _env, {
        'ok': true,
        'saved': [_key],
        'skipped': [],
        'is_set': {_key: true},
      })
      ..on('GET', '/api/tools/toolsets/web/config', _config(isSet: true));
    controller
      ..setKey(_key, _secret)
      ..setKey('OTHER_KEY', 'ignored: not a key of this toolset')
      ..setKey('SEARCHCO_BLANK', '   ');
    expect(controller.typedLength(_key), _secret.length);

    await controller.saveKeys();

    expect(saves(), hasLength(1));
    expect(saves().single.data.toString(), contains(_secret));
    expect(saves().single.data.toString(), isNot(contains('OTHER_KEY')));
    expect(controller.keysState, ToolsetKeysState.saved);
    expect(controller.typedLength(_key), 0);
    expect(controller.hasTypedKeys, isFalse);
    expect(controller.config!.providers.first.envVars.single.isSet, isTrue);
  });

  test('nothing typed sends nothing', () async {
    controller.setKey(_key, '  ');

    await controller.saveKeys();

    expect(saves(), isEmpty);
  });

  test('a failed save keeps the value, and nothing is sent again', () async {
    server.on('PUT', _env, {'detail': 'boom'}, status: 500);
    controller.setKey(_key, _secret);

    await controller.saveKeys();

    expect(controller.keysState, ToolsetKeysState.failed);
    expect(controller.typedLength(_key), _secret.length);
    expect(saves(), hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(saves(), hasLength(1));
  });

  test('a refused save shows Hermes\' text and keeps the value', () async {
    server.on('PUT', _env, {'detail': 'Unknown env var(s)'}, status: 400);
    controller.setKey(_key, _secret);

    await controller.saveKeys();

    expect(controller.refusalDetail, 'Unknown env var(s)');
    expect(controller.typedLength(_key), _secret.length);
  });

  test('editing after a failure allows another save by the user', () async {
    server.on('PUT', _env, {'detail': 'boom'}, status: 500);
    controller.setKey(_key, _secret);
    await controller.saveKeys();
    controller.setKey(_key, '$_secret-2');

    expect(controller.keysState, ToolsetKeysState.idle);
    await controller.saveKeys();

    expect(saves(), hasLength(2));
  });

  group('a lost answer', () {
    void lose() => server.onRequest('PUT', _env, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });

    test('clears the value and says saved when the re-read shows it '
        'set', () async {
      lose();
      server.on('GET', '/api/tools/toolsets/web/config', _config(isSet: true));
      controller.setKey(_key, _secret);

      await controller.saveKeys();

      expect(controller.typedLength(_key), 0);
      expect(controller.keysState, ToolsetKeysState.saved);
      expect(saves(), hasLength(1));
    });

    test('asks to paste it again when the re-read shows it not set', () async {
      lose();
      controller.setKey(_key, _secret);

      await controller.saveKeys();

      expect(controller.keysState, ToolsetKeysState.notSaved);
      expect(controller.typedLength(_key), 0);
      expect(saves(), hasLength(1));
    });

    test('ends in "couldn\'t confirm" when the read hangs', () async {
      lose();
      final hang = Completer<void>();
      server.onRequest('GET', '/api/tools/toolsets/web/config', (_) async {
        await hang.future;
        return (status: 200, body: _config(isSet: true));
      });
      controller.setKey(_key, _secret);

      await controller.saveKeys();

      expect(controller.keysState, ToolsetKeysState.unconfirmed);
      expect(controller.typedLength(_key), 0);
      hang.complete();
    });

    test('a replaced key that shows set either way is unconfirmed', () async {
      lose();
      server.on('GET', '/api/tools/toolsets/web/config', _config(isSet: true));
      await controller.load();
      controller.setKey(_key, _secret);

      await controller.saveKeys();

      expect(controller.keysState, ToolsetKeysState.unconfirmed);
    });
  });

  test('the typed values are cleared on App Lock, a profile switch and '
      'dispose', () async {
    controller.setKey(_key, _secret);
    controller.clearKeys();
    expect(controller.typedLength(_key), 0);

    controller
      ..setKey(_key, _secret)
      ..switchProfile(toolsRepository(server, profile: 'home'));
    expect(controller.typedLength(_key), 0);
    expect(controller.config, isNull);
  });

  test('a late answer after a profile switch is dropped', () async {
    final gate = Completer<void>();
    server.onRequest('GET', '/api/tools/toolsets/web/config', (_) async {
      await gate.future;
      return (status: 200, body: _config(isSet: true));
    });
    final late = controller.load();
    controller.switchProfile(toolsRepository(server, profile: 'home'));
    gate.complete();
    await late;

    expect(controller.config, isNull);
  });

  test('no key value reaches a span, an event or toString', () async {
    server.on('PUT', _env, {'detail': 'boom'}, status: 500);
    controller.setKey(_key, _secret);
    await controller.saveKeys();
    server.onRequest('PUT', _env, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });
    await controller.saveKeys();

    final recorded = [
      for (final span in tracer.spans) '${span.name} ${span.attributes}',
      ...events,
      controller.toString(),
      '${controller.config}',
    ].join('\n');
    expect(recorded, isNot(contains(_secret)));
    expect(recorded, isNot(contains(_key)));
    final span = tracer.spans.firstWhere((s) => s.name == 'tools.setup');
    expect(span.attributes['step'], 'env');
    expect(span.attributes['keys'], 1);
  });

  test('a profile switch during the re-read after a save drops the old '
      'matrix', () async {
    server.on('PUT', _env, {
      'ok': true,
      'saved': [_key],
      'skipped': [],
    });
    final gate = Completer<void>();
    server.onRequest('GET', '/api/tools/toolsets/web/config', (_) async {
      await gate.future;
      return (status: 200, body: _config(isSet: true));
    });
    controller.setKey(_key, _secret);
    final saving = controller.saveKeys();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    controller.switchProfile(toolsRepository(server, profile: 'home'));
    gate.complete();
    await saving;

    expect(controller.config, isNull);
  });

  test('values typed for another provider are never sent with this '
      "one's keys", () async {
    server.on('PUT', _env, {
      'ok': true,
      'saved': [_key],
      'skipped': [],
    });
    controller.setKey(_key, _secret);
    controller.selectProvider('Local Driver');

    expect(controller.hasTypedKeys, isFalse);
    await controller.saveKeys();
    expect(saves(), isEmpty);
  });

  test('typing is ignored while the lost answer is being checked', () async {
    server.onRequest('PUT', _env, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });
    final gate = Completer<void>();
    server.onRequest('GET', '/api/tools/toolsets/web/config', (_) async {
      await gate.future;
      return (status: 200, body: _config(isSet: false));
    });
    controller.setKey(_key, _secret);
    final saving = controller.saveKeys();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    controller.setKey(_key, 'typed during the check');

    expect(controller.typedLength(_key), 0);
    gate.complete();
    await saving;
  });

  group('acknowledge while a write runs changes nothing', () {
    test('a key save in flight', () async {
      final gate = Completer<void>();
      server.onRequest('PUT', _env, (_) async {
        await gate.future;
        return (
          status: 200,
          body: {
            'ok': true,
            'saved': [_key],
          },
        );
      });
      server.on('GET', '/api/tools/toolsets/web/config', _config(isSet: true));
      controller.setKey(_key, _secret);
      final saving = controller.saveKeys();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.keysState, ToolsetKeysState.saving);
      final selected = controller.selectedProvider;

      controller.acknowledge();

      expect(controller.keysState, ToolsetKeysState.saving);
      expect(controller.selectedProvider, selected);
      gate.complete();
      await saving;
      expect(controller.keysState, ToolsetKeysState.saved);
    });

    test('a lost answer being checked', () async {
      server.onRequest('PUT', _env, (r) {
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        );
      });
      final gate = Completer<void>();
      server.onRequest('GET', '/api/tools/toolsets/web/config', (_) async {
        await gate.future;
        return (status: 200, body: _config(isSet: false));
      });
      controller.setKey(_key, _secret);
      final saving = controller.saveKeys();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.keysState, ToolsetKeysState.checking);

      controller.acknowledge();

      expect(controller.keysState, ToolsetKeysState.checking);
      gate.complete();
      await saving;
      expect(controller.keysState, isNot(ToolsetKeysState.checking));
    });

    test('a provider pick in flight', () async {
      final gate = Completer<void>();
      server.onRequest('PUT', '/api/tools/toolsets/web/provider', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });
      final picking = controller.pickProvider('Local Driver');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.providerState, ToolsWriteState.saving);

      controller.acknowledge();

      expect(controller.providerState, ToolsWriteState.saving);
      gate.complete();
      await picking;
    });
  });
}

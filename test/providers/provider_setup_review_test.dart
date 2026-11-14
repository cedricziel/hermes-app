import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_setup_controller.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'fake_provider_backend.dart';

class _Rig {
  _Rig() {
    controller = ProviderSetupController(
      repository: ProvidersRepository(
        backend.server.client().raw,
        telemetry: ConnectionTelemetry(tracer: tracer),
        checkBudget: const Duration(milliseconds: 300),
        recommendBudget: const Duration(milliseconds: 300),
      ),
      profile: 'work',
      observeLifecycle: false,
    );
  }

  final backend = FakeProviderBackend();
  final tracer = RecordingTracer();
  late final ProviderSetupController controller;
  FakeHermesServer get server => backend.server;

  int count(String method, String path) =>
      server.requestsTo(method, path).length;

  Map<String, Object?> body(String method, String path) =>
      Map<String, Object?>.from(
        jsonBody(server.requestsTo(method, path).last)! as Map,
      );
}

const _key = 'sk-or-v1-test-aaaa-1111';

void _usableDefault(_Rig rig) => rig.backend
  ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
  ..defaultProvider = 'openrouter'
  ..defaultModel = 'example-model-a';

void main() {
  late _Rig rig;
  late ProviderSetupController c;

  setUp(() {
    rig = _Rig();
    c = rig.controller;
  });
  tearDown(() => c.dispose());

  group('cleartext check uses the address that is sent', () {
    test('a stale resolved address does not hide an http address', () async {
      await c.load();
      rig.server.on('POST', '/api/providers/custom-endpoints/validate', {
        'ok': true,
        'reachable': true,
        'models': ['m'],
        'resolved_base_url': 'https://models.example.net/v1',
      });
      await c.checkEndpoint(name: 'Lab', address: 'https://models.example.net');
      expect(
        await c.saveEndpoint(
          name: 'Lab',
          address: 'http://models.example.net/v1',
          model: 'm',
          apiKey: 'endpoint-key-0000',
        ),
        EndpointSubmit.needsCleartextConfirmation,
      );
      expect(rig.count('POST', '/api/providers/custom-endpoints'), 0);
    });

    test(
      'a fresh check that resolved to https needs no confirmation',
      () async {
        await c.load();
        rig.server.on('POST', '/api/providers/custom-endpoints/validate', {
          'ok': true,
          'reachable': true,
          'models': ['m'],
          'resolved_base_url': 'https://models.example.net/v1',
        });
        await c.checkEndpoint(
          name: 'Lab',
          address: 'http://models.example.net',
        );
        expect(
          await c.saveEndpoint(
            name: 'Lab',
            address: 'http://models.example.net',
            model: 'm',
            apiKey: 'endpoint-key-0000',
          ),
          EndpointSubmit.saved,
        );
        expect(
          rig.body('POST', '/api/providers/custom-endpoints')['base_url'],
          'https://models.example.net/v1',
        );
      },
    );
  });

  group('after saving an endpoint', () {
    test('a profile with a working default is asked, with Keep', () async {
      _usableDefault(rig);
      await c.load();
      await c.saveEndpoint(
        name: 'Lab',
        address: 'https://lab.example.com/v1',
        model: 'lab-model',
      );
      final step = c.step!;
      expect(step.kind, DefaultStepKind.ask);
      expect(step.model, 'lab-model');
      expect(step.currentModel, 'example-model-a');
      expect(step.providerId, 'custom:lab');
      expect(rig.count('POST', '/api/model/set'), 0);
    });

    test('the saved step comes from the re-read default', () async {
      await c.load();
      await c.saveEndpoint(
        name: 'Lab',
        address: 'https://lab.example.com/v1',
        model: 'lab-model',
      );
      expect(c.step!.kind, DefaultStepKind.saved);
      expect(c.step!.model, 'lab-model');
    });

    test(
      'make_default that did not take is asked, not shown as saved',
      () async {
        await c.load();
        rig.server.onRequest('POST', '/api/providers/custom-endpoints', (_) {
          rig.backend.endpoints.add({
            'id': 'lab',
            'name': 'Lab',
            'base_url': 'https://lab.example.com/v1',
            'model': 'lab-model',
            'models': ['lab-model'],
            'has_api_key': false,
            'is_current': false,
            'source': 'providers',
          });
          return (status: 200, body: {'ok': true, 'id': 'lab'});
        });
        await c.saveEndpoint(
          name: 'Lab',
          address: 'https://lab.example.com/v1',
          model: 'lab-model',
        );
        expect(c.step!.kind, DefaultStepKind.ask);
      },
    );
  });

  group('endpoint check and cleartext keys', () {
    test('the key is not sent to a non-local http address', () async {
      await c.load();
      await c.checkEndpoint(
        name: 'Lab',
        address: 'http://models.example.net/v1',
        apiKey: 'endpoint-key-0000',
      );
      expect(
        rig
            .body('POST', '/api/providers/custom-endpoints/validate')
            .containsKey('api_key'),
        isFalse,
      );
      expect(c.endpointForm.keyNotSent, isTrue);
    });

    test('a local or https address gets the key', () async {
      await c.load();
      await c.checkEndpoint(
        name: 'Lab',
        address: 'http://localhost:8000',
        apiKey: 'endpoint-key-0000',
      );
      expect(
        rig.body('POST', '/api/providers/custom-endpoints/validate')['api_key'],
        'endpoint-key-0000',
      );
      expect(c.endpointForm.keyNotSent, isFalse);
    });
  });

  group('after dispose or rebind', () {
    test('dispose during the save sends nothing more', () async {
      final gate = Completer<void>();
      rig.server.onRequest('PUT', '/api/env', (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });
      await c.load();
      c.openKeyForm('openrouter');
      final pending = c.submitKey(_key);
      await pumpEventQueue();
      final sent = rig.server.requests.length;
      c.dispose();
      gate.complete();
      await pending;
      await pumpEventQueue();
      expect(rig.server.requests.length, sent);
    });

    test(
      'dispose during a lost-answer re-read or removal sends nothing more',
      () async {
        _usableDefault(rig);
        await c.load();
        final gate = Completer<void>();
        rig.server.onRequest('DELETE', '/api/env', (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true});
        });
        final pending = c.remove(
          c.catalog!.byId('openrouter')!,
          const RemoveKeyAction('OPENROUTER_API_KEY'),
        );
        await pumpEventQueue();
        final sent = rig.server.requests.length;
        c.dispose();
        gate.complete();
        await pending;
        await pumpEventQueue();
        expect(rig.server.requests.length, sent);
      },
    );

    test(
      'rebind with a pending confirmation ends its span as declined',
      () async {
        rig.backend.expensiveModel = 'example-model-a';
        await c.load();
        c.openKeyForm('openrouter');
        await c.submitKey(_key);
        expect(c.confirmation, isNotNull);
        final span = rig.tracer.spans.singleWhere(
          (s) => s.name == 'providers.default_model.set',
        );
        expect(span.ended, isFalse);
        c.bind('home');
        expect(span.ended, isTrue);
        expect(span.attributes['outcome'], 'declined');
        expect(span.attributes['confirm_asked'], true);
      },
    );

    test(
      'a removal answered after a rebind does not set lastRemoval',
      () async {
        _usableDefault(rig);
        await c.load();
        final gate = Completer<void>();
        rig.server.onRequest('DELETE', '/api/env', (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true});
        });
        final pending = c.remove(
          c.catalog!.byId('openrouter')!,
          const RemoveKeyAction('OPENROUTER_API_KEY'),
        );
        await pumpEventQueue();
        c.bind('home');
        gate.complete();
        await pending;
        expect(c.lastRemoval, isNull);
      },
    );

    test(
      'a lost endpoint save does not overwrite a form reset meanwhile',
      () async {
        await c.load();
        rig.server.onRequest('POST', '/api/providers/custom-endpoints', (r) {
          throw DioException.connectionError(requestOptions: r, reason: 'x');
        });
        final gate = Completer<void>();
        final submit = c.saveEndpoint(
          name: 'Lab',
          address: 'https://lab.example.com',
          model: 'm',
        );
        await pumpEventQueue();
        rig.server.onRequest('GET', '/api/model/options', (_) async {
          await gate.future;
          return (status: 200, body: rig.backend.defaultModel);
        });
        await pumpEventQueue();
        c.resetEndpointForm();
        gate.complete();
        await submit;
        expect(c.endpointForm.phase, EndpointFormPhase.idle);
      },
    );
  });

  group('Save anyway', () {
    test('does nothing unless the form offers it', () async {
      await c.load();
      c.openKeyForm('openrouter');
      await c.saveKeyAnyway(_key);
      expect(rig.count('PUT', '/api/env'), 0);
      expect(c.keyForm!.phase, KeyFormPhase.editing);
    });
  });
}

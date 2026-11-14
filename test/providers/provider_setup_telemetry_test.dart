import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_setup_controller.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recording_tracer.dart';
import 'fake_provider_backend.dart';
import 'provider_fixtures.dart';

class _Rig {
  _Rig() {
    controller = ProviderSetupController(
      repository: ProvidersRepository(
        backend.server.client().raw,
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          serverAttributes: const {'hermes.version': 'test'},
          events: (name, [attributes = const {}]) =>
              events.add((name, Map<String, Object?>.from(attributes))),
        ),
        checkBudget: const Duration(milliseconds: 300),
        recommendBudget: const Duration(milliseconds: 300),
      ),
      profile: 'work',
      observeLifecycle: false,
    );
  }

  final backend = FakeProviderBackend();
  final tracer = RecordingTracer();
  final events = <(String, Map<String, Object?>)>[];
  late final ProviderSetupController controller;

  /// What a span carries besides the server attributes every span has.
  Map<String, Object?> span(String name, {int index = 0}) {
    final all = tracer.spans.where((s) => s.name == name).toList();
    final attributes = Map<String, Object?>.of(all[index].attributes)
      ..remove('hermes.version');
    return attributes;
  }

  int spans(String name) => tracer.spans.where((s) => s.name == name).length;

  List<Map<String, Object?>> logs(String name) => [
    for (final (n, attributes) in events)
      if (n == name) attributes,
  ];
}

const _key = 'sk-or-v1-test-aaaa-1111';

void main() {
  late _Rig rig;
  late ProviderSetupController c;
  late FakeProviderBackend backend;

  setUp(() {
    rig = _Rig();
    c = rig.controller;
    backend = rig.backend;
  });
  tearDown(() => c.dispose());

  Future<void> connect() async {
    await c.load();
    c.openKeyForm('openrouter');
    await c.submitKey(_key);
  }

  group('providers.key.save', () {
    test('an accepted key', () async {
      await connect();
      expect(rig.span('providers.key.save'), {
        'checked': 'accepted',
        'outcome': 'saved',
        'forced': false,
      });
    });

    test('every check kind is named', () async {
      for (final (answer, name) in [
        ({'ok': true, 'reachable': false, 'message': ''}, 'unchecked'),
        ({'ok': false, 'reachable': false, 'message': 'x'}, 'unreachable'),
      ]) {
        final r = _Rig();
        r.backend.validate = answer;
        await r.controller.load();
        r.controller.openKeyForm('openrouter');
        await r.controller.submitKey(_key);
        expect(r.span('providers.key.save')['checked'], name);
        r.controller.dispose();
      }
    });

    test('a rejection, then Save anyway', () async {
      backend.validate = {'ok': false, 'reachable': true, 'message': 'no'};
      await connect();
      await c.saveKeyAnyway(_key);
      expect(rig.span('providers.key.save'), {
        'checked': 'rejected',
        'outcome': 'not_saved',
        'forced': false,
      });
      expect(rig.span('providers.key.save', index: 1), {
        'checked': 'rejected',
        'outcome': 'saved',
        'forced': true,
      });
    });

    test('a provider error', () async {
      backend.validate = {
        'ok': false,
        'reachable': true,
        'message': 'Provider returned HTTP 503 for this key.',
      };
      await connect();
      expect(rig.span('providers.key.save')['checked'], 'provider_error');
    });

    test('refused and unknown outcomes', () async {
      backend
        ..saveStatus = 400
        ..saveDetail = 'locked';
      await connect();
      expect(rig.span('providers.key.save')['outcome'], 'failed');
      final r = _Rig();
      r.backend.lostSave = LostAnswer.beforeWrite;
      await r.controller.load();
      r.controller.openKeyForm('openrouter');
      await r.controller.submitKey(_key);
      expect(r.span('providers.key.save')['outcome'], 'unknown');
      r.controller.dispose();
    });

    test('the span is ended', () async {
      await connect();
      expect(
        rig.tracer.spans
            .where((s) => s.name.startsWith('providers.'))
            .every((s) => s.ended),
        isTrue,
      );
    });
  });

  group('providers.connected', () {
    test('a key counts the first connection once', () async {
      await connect();
      expect(rig.logs('providers.connected'), [
        {'method': 'key', 'first': true},
      ]);
    });

    test(
      'a second provider is not first, a replacement is not logged',
      () async {
        backend
          ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
          ..defaultProvider = 'openrouter'
          ..defaultModel = 'example-model-a';
        await c.load();
        c.openKeyForm('anthropic');
        await c.submitKey('ak-test-0000-1111');
        c.openKeyForm('openrouter');
        await c.submitKey('sk-or-v1-test-bbbb-2222');
        expect(rig.logs('providers.connected'), [
          {'method': 'key', 'first': false},
        ]);
      },
    );

    test('a refused save logs nothing', () async {
      backend
        ..saveStatus = 400
        ..saveDetail = 'locked';
      await connect();
      expect(rig.logs('providers.connected'), isEmpty);
    });
  });

  group('providers.default_model.set', () {
    test('saved, with no confirmation asked', () async {
      await connect();
      expect(rig.span('providers.default_model.set'), {
        'outcome': 'saved',
        'confirm_asked': false,
      });
    });

    test('confirmed after being asked', () async {
      backend.expensiveModel = 'example-model-a';
      await connect();
      expect(rig.spans('providers.default_model.set'), 1);
      await c.confirmExpensiveModel();
      expect(rig.spans('providers.default_model.set'), 1);
      expect(rig.span('providers.default_model.set'), {
        'outcome': 'saved',
        'confirm_asked': true,
      });
    });

    test('declined', () async {
      backend.expensiveModel = 'example-model-a';
      await connect();
      c.declineExpensiveModel();
      expect(rig.span('providers.default_model.set'), {
        'outcome': 'declined',
        'confirm_asked': true,
      });
    });

    test('failed', () async {
      rig.backend.server.on('POST', '/api/model/set', {}, status: 500);
      await connect();
      expect(rig.span('providers.default_model.set')['outcome'], 'failed');
    });
  });

  group('providers.remove', () {
    Future<void> removeKey() async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_key)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      await c.load();
      await c.remove(
        c.catalog!.byId('openrouter')!,
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
    }

    test('a key', () async {
      await removeKey();
      expect(rig.span('providers.remove'), {
        'kind': 'key',
        'outcome': 'removed',
      });
    });

    test('already gone, refused, unknown', () async {
      await removeKey();
      final entry = c.catalog!.byId('openrouter')!;
      await c.remove(entry, const RemoveKeyAction('OPENROUTER_API_KEY'));
      expect(rig.span('providers.remove', index: 1)['outcome'], 'already_gone');
      rig.backend.server.on('DELETE', '/api/env', {
        'detail': 'locked',
      }, status: 400);
      await c.remove(entry, const RemoveKeyAction('OPENROUTER_API_KEY'));
      expect(rig.span('providers.remove', index: 2)['outcome'], 'refused');
    });

    test('an account and an endpoint', () async {
      backend
        ..signedIn.add('nous')
        ..endpoints.add(endpointRow('lab', name: 'Lab'));
      await c.load();
      await c.remove(c.catalog!.byId('nous')!, const SignOutAction());
      await c.remove(c.catalog!.byId('lab')!, const DeleteEndpointAction());
      expect(rig.span('providers.remove'), {
        'kind': 'account',
        'outcome': 'removed',
      });
      expect(rig.span('providers.remove', index: 1), {
        'kind': 'endpoint',
        'outcome': 'removed',
      });
    });
  });

  group('providers.endpoint', () {
    test('check and save carry outcomes, a bucket and flags only', () async {
      await c.load();
      await c.checkEndpoint(name: 'Lab', address: 'http://localhost:8000');
      await c.saveEndpoint(
        name: 'Lab',
        address: 'http://localhost:8000',
        model: 'example-model-a',
      );
      expect(rig.span('providers.endpoint.check'), {
        'outcome': 'models',
        'models': '2-5',
      });
      expect(rig.span('providers.endpoint.save'), {
        'outcome': 'saved',
        'made_default': true,
        'edit': false,
      });
      expect(rig.logs('providers.connected'), [
        {'method': 'endpoint', 'first': true},
      ]);
    });

    test('warning, unreachable and failed checks', () async {
      await c.load();
      final server = rig.backend.server;
      for (final (answer, status) in [
        ({'ok': false, 'reachable': true, 'message': 'x', 'models': []}, 200),
        ({'ok': false, 'reachable': false}, 200),
        ({}, 500),
      ]) {
        server.on(
          'POST',
          '/api/providers/custom-endpoints/validate',
          answer,
          status: status,
        );
        await c.checkEndpoint(name: 'Lab', address: 'https://lab.example.com');
      }
      expect(
        [
          for (var i = 0; i < 3; i++)
            rig.span('providers.endpoint.check', index: i),
        ],
        [
          {'outcome': 'warning', 'models': '0'},
          {'outcome': 'unreachable', 'models': '0'},
          {'outcome': 'failed', 'models': '0'},
        ],
      );
    });

    test('an edit is flagged and is not a new connection', () async {
      backend.endpoints.add(endpointRow('lab', name: 'Lab'));
      await c.load();
      await c.saveEndpoint(
        id: 'lab',
        name: 'Lab',
        address: 'https://lab.example.com',
        model: 'm',
      );
      expect(rig.span('providers.endpoint.save')['edit'], true);
      expect(rig.logs('providers.connected'), isEmpty);
    });
  });

  test('a sign-in records its span and counts the connection', () {
    fakeAsync((async) {
      final r = _Rig();
      void settle() {
        for (var i = 0; i < 20; i++) {
          async.flushMicrotasks();
          async.elapse(Duration.zero);
        }
      }

      r.controller.load();
      settle();
      r.controller.startSignIn('nous');
      settle();
      r.backend.pollAnswer = {'session_id': 's-1', 'status': 'approved'};
      async.elapse(const Duration(seconds: 5));
      settle();
      expect(r.span('providers.signin'), {'outcome': 'approved', 'polls': '1'});
      expect(r.logs('providers.connected'), [
        {'method': 'account', 'first': true},
      ]);
      r.controller.dispose();
    });
  });

  test(
    'every provider signal is a fixed name, count, flag or outcome',
    () async {
      backend.validate = {'ok': false, 'reachable': true, 'message': 'no'};
      await connect();
      await c.saveKeyAnyway(_key);
      await c.checkEndpoint(
        name: 'Secret Lab',
        address: 'http://localhost:8000',
      );
      await c.saveEndpoint(
        name: 'Secret Lab',
        address: 'http://localhost:8000',
        model: 'example-model-a',
        apiKey: 'endpoint-key-0000',
      );
      await c.remove(
        c.catalog!.byId('openrouter')!,
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      const allowed = {
        'checked',
        'outcome',
        'forced',
        'kind',
        'models',
        'made_default',
        'edit',
        'confirm_asked',
        'sources_ok',
        'sources_failed',
        'connected',
        'polls',
        'method',
        'first',
        'source',
        'error_type',
      };
      final vocabulary = RegExp(r'^[a-z_0-9>\-]{1,16}$');
      final recorded = [
        for (final s in rig.tracer.spans.where(
          (s) => s.name.startsWith('providers.'),
        ))
          ...s.attributes.entries.where((e) => e.key != 'hermes.version'),
        for (final (_, a) in rig.events) ...a.entries,
      ];
      expect(recorded, isNotEmpty);
      for (final e in recorded) {
        expect(allowed, contains(e.key));
        final v = e.value;
        expect(
          v is bool || v is int || (v is String && vocabulary.hasMatch(v)),
          isTrue,
          reason: '${e.key}: $v',
        );
        expect(
          '$v',
          isNot(
            anyOf(
              contains('openrouter'),
              contains('example'),
              contains('work'),
              contains('lab'),
              contains('localhost'),
            ),
          ),
        );
      }
    },
  );
}

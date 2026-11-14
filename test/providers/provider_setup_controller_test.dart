import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_models.dart';
import 'package:hermes_app/src/providers/provider_setup_controller.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';

import '../support/fake_hermes_server.dart';
import 'fake_provider_backend.dart';
import 'provider_fixtures.dart';

const _key = 'sk-or-v1-test-aaaa-1111';
const _oldKey = 'sk-o-old-key-4f2a';
const _newKey = 'sk-o-new-key-4f2a';

class _Rig {
  _Rig({String? profile = 'work'}) {
    repository = ProvidersRepository(
      backend.server.client().raw,
      checkBudget: const Duration(milliseconds: 300),
      recommendBudget: const Duration(milliseconds: 300),
    );
    controller = ProviderSetupController(
      repository: repository,
      profile: profile,
      observeLifecycle: false,
    );
  }

  final backend = FakeProviderBackend();
  late final ProvidersRepository repository;
  late final ProviderSetupController controller;

  FakeHermesServer get server => backend.server;

  int count(String method, String path) =>
      server.requestsTo(method, path).length;

  Map<String, Object?> body(String method, String path) =>
      Map<String, Object?>.from(
        jsonBody(server.requestsTo(method, path).last)! as Map,
      );

  ProviderEntry entry(String id) => controller.catalog!.byId(id)!;

  /// Loads, opens the OpenRouter key form and submits [key].
  Future<void> connectOpenRouter([String key = _key]) async {
    await controller.load();
    controller.openKeyForm('openrouter');
    await controller.submitKey(key);
  }
}

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

  group('snapshot', () {
    test('reads the providers of the profile', () async {
      await c.load();
      expect(c.catalog!.connected, isEmpty);
      expect(c.catalog!.byId('openrouter')!.keyEnv, 'OPENROUTER_API_KEY');
      for (final path in [
        '/api/model/options',
        '/api/env',
        '/api/providers/oauth',
        '/api/providers/custom-endpoints',
      ]) {
        expect(
          rig.server.requestsTo('GET', path).single.queryParameters['profile'],
          'work',
        );
      }
      expect(c.loading, isFalse);
      expect(c.defaultModel, '');
    });

    test('answers of another profile are dropped after a rebind', () async {
      final slow = Completer<void>();
      rig.server.onRequest('GET', '/api/model/options', (request) async {
        if (request.queryParameters['profile'] == 'work') await slow.future;
        final home = request.queryParameters['profile'] == 'home';
        return (
          status: 200,
          body: optionsBody(
            [
              optionsRow(
                home ? 'anthropic' : 'openrouter',
                authenticated: true,
                models: ['m'],
              ),
            ],
            model: 'm',
            provider: home ? 'anthropic' : 'openrouter',
          ),
        );
      });
      final first = c.load();
      c.bind('home');
      await pumpEventQueue();
      slow.complete();
      await first;
      await pumpEventQueue();
      expect(c.profile, 'home');
      expect(c.catalog!.defaultProvider, 'anthropic');
    });

    test('a failed read keeps the list that was shown', () async {
      await c.load();
      rig.server.on('GET', '/api/model/options', {'detail': 'x'}, status: 500);
      await c.load();
      expect(c.failure, isNotNull);
      expect(c.catalog, isNotNull);
    });

    test('a server without model options is unsupported', () async {
      rig.server.on('GET', '/api/model/options', {'detail': 'x'}, status: 404);
      await c.load();
      expect(c.unsupported, isTrue);
      expect(c.catalog, isNull);
    });
  });

  group('key flow', () {
    test('an accepted key is saved and the first provider gets the '
        'recommended model at once', () async {
      await rig.connectOpenRouter();
      expect(rig.body('PUT', '/api/env'), {
        'key': 'OPENROUTER_API_KEY',
        'value': _key,
        'provider_setup': true,
      });
      expect(rig.server.requestsTo('PUT', '/api/env').single.queryParameters, {
        'profile': 'work',
      });
      expect(c.keyForm!.phase, KeyFormPhase.saved);
      expect(c.keyForm!.note, isNull);
      expect(backend.defaultModel, 'example-model-a');
      expect(c.step!.kind, DefaultStepKind.saved);
      expect(c.step!.model, 'example-model-a');
      expect(c.step!.note, isNull);
      expect(c.changes, greaterThanOrEqualTo(2));
      expect(rig.entry('openrouter').connected, isTrue);
    });

    test('a key without a probe is saved with the unchecked note', () async {
      backend.validate = {'ok': true, 'reachable': false, 'message': ''};
      await rig.connectOpenRouter();
      expect(c.keyForm!.note, KeyNote.unchecked);
      expect(c.step!.note, KeyNote.unchecked);
    });

    test('a check that cannot reach the provider still saves', () async {
      backend.validate = {'ok': false, 'reachable': false, 'message': 'x'};
      await rig.connectOpenRouter();
      expect(c.keyForm!.phase, KeyFormPhase.saved);
      expect(c.keyForm!.note, KeyNote.unreachable);
    });

    test('a failing check saves too', () async {
      rig.server.on('POST', '/api/providers/validate', {}, status: 500);
      await rig.connectOpenRouter();
      expect(c.keyForm!.note, KeyNote.unreachable);
      expect(rig.count('PUT', '/api/env'), 1);
    });

    test(
      'a rejected key is not saved; Edit key is the primary action',
      () async {
        backend.validate = {
          'ok': false,
          'reachable': true,
          'message':
              'That API key was rejected. Double-check it and try again.',
        };
        await rig.connectOpenRouter();
        final form = c.keyForm!;
        expect(rig.count('PUT', '/api/env'), 0);
        expect(form.phase, KeyFormPhase.rejected);
        expect(
          form.message,
          'That API key was rejected. Double-check it and try again.',
        );
        expect(form.saveVisible, isFalse);
        expect(form.offersSaveAnyway, isTrue);
        expect(form.offersTryAgain, isFalse);
        expect(form.primaryAction(hasText: true), KeyFormAction.editKey);
        expect(form.primaryAction(hasText: false), KeyFormAction.editKey);
      },
    );

    test('editing the key after a rejection brings Save back', () async {
      backend.validate = {'ok': false, 'reachable': true, 'message': 'no'};
      await rig.connectOpenRouter();
      c.keyEdited();
      expect(c.keyForm!.phase, KeyFormPhase.editing);
      expect(c.keyForm!.message, isNull);
      expect(c.keyForm!.saveVisible, isTrue);
      expect(c.keyForm!.primaryAction(hasText: true), KeyFormAction.save);
    });

    test('Save anyway after a rejection saves unchecked, without a second '
        'check', () async {
      backend.validate = {'ok': false, 'reachable': true, 'message': 'no'};
      await rig.connectOpenRouter();
      expect(rig.count('POST', '/api/providers/validate'), 1);
      await c.saveKeyAnyway(_key);
      expect(rig.count('POST', '/api/providers/validate'), 1);
      expect(rig.count('PUT', '/api/env'), 1);
      expect(c.keyForm!.note, KeyNote.unchecked);
      expect(c.step!.note, KeyNote.unchecked);
    });

    test('a provider error offers Save anyway as the primary action', () async {
      backend.validate = {
        'ok': false,
        'reachable': true,
        'message': 'Provider returned HTTP 503 for this key.',
      };
      await rig.connectOpenRouter();
      final form = c.keyForm!;
      expect(form.phase, KeyFormPhase.providerError);
      expect(form.message, 'Provider returned HTTP 503 for this key.');
      expect(form.saveVisible, isFalse);
      expect(form.offersTryAgain, isTrue);
      expect(form.primaryAction(hasText: true), KeyFormAction.saveAnyway);
      expect(rig.count('PUT', '/api/env'), 0);
      await c.saveKeyAnyway(_key);
      expect(c.keyForm!.note, KeyNote.unchecked);
      expect(rig.count('PUT', '/api/env'), 1);
    });

    test('Try again after a provider error checks again', () async {
      backend.validate = {
        'ok': false,
        'reachable': true,
        'message': 'Provider returned HTTP 503 for this key.',
      };
      await rig.connectOpenRouter();
      backend.validate = {'ok': true, 'reachable': true, 'message': ''};
      await c.submitKey(_key);
      expect(c.keyForm!.phase, KeyFormPhase.saved);
      expect(c.keyForm!.note, isNull);
    });

    test('Return does the primary action and nothing else', () async {
      await c.load();
      c.openKeyForm('openrouter');
      expect(await c.pressReturn(''), isFalse);
      expect(rig.count('POST', '/api/providers/validate'), 0);

      backend.validate = {'ok': false, 'reachable': true, 'message': 'no'};
      expect(await c.pressReturn(_key), isTrue);
      expect(c.keyForm!.phase, KeyFormPhase.rejected);
      final focus = c.keyFocusRequests;
      final checks = rig.count('POST', '/api/providers/validate');

      // After a rejection Return is "Edit key": it focuses, sends nothing.
      expect(await c.pressReturn(_key), isTrue);
      expect(c.keyFocusRequests, focus + 1);
      expect(rig.count('POST', '/api/providers/validate'), checks);
      expect(rig.count('PUT', '/api/env'), 0);
      expect(c.keyForm!.phase, KeyFormPhase.rejected);
    });

    test('a key of only spaces sends nothing', () async {
      await c.load();
      c.openKeyForm('openrouter');
      await c.submitKey('   ');
      expect(c.keyForm!.emptyKey, isTrue);
      expect(rig.count('POST', '/api/providers/validate'), 0);
      expect(rig.count('PUT', '/api/env'), 0);
      c.keyEdited();
      expect(c.keyForm!.emptyKey, isFalse);
    });

    test('the key is trimmed', () async {
      await rig.connectOpenRouter('  $_key \n');
      expect(rig.body('PUT', '/api/env')['value'], _key);
    });

    test('a refusal shows Hermes reason and is not resent', () async {
      backend
        ..saveStatus = 400
        ..saveDetail = 'This key is managed by your administrator.';
      await rig.connectOpenRouter();
      expect(c.keyForm!.phase, KeyFormPhase.refused);
      expect(c.keyForm!.message, 'This key is managed by your administrator.');
      expect(rig.count('PUT', '/api/env'), 1);
      expect(c.step, isNull);
      expect(c.changes, 0);
      c.keyEdited();
      expect(c.keyForm!.phase, KeyFormPhase.editing);
    });

    test('a lost answer for a first key that did arrive counts as saved, '
        'without a second request', () async {
      backend.lostSave = LostAnswer.afterWrite;
      await rig.connectOpenRouter();
      expect(rig.count('PUT', '/api/env'), 1);
      expect(c.keyForm!.phase, KeyFormPhase.saved);
      expect(rig.entry('openrouter').connected, isTrue);
    });

    test(
      'a lost answer for a first key that did not arrive stays unknown',
      () async {
        backend.lostSave = LostAnswer.beforeWrite;
        await rig.connectOpenRouter();
        expect(rig.count('PUT', '/api/env'), 1);
        expect(c.keyForm!.phase, KeyFormPhase.unknown);
        expect(c.keyForm!.primaryAction(hasText: false), isNull);
        expect(c.keyForm!.primaryAction(hasText: true), KeyFormAction.save);
        expect(c.step, isNull);
        expect(c.changes, 0);
      },
    );

    test('a lost answer for a replacement always stays unknown, even when '
        'it did arrive', () async {
      backend.keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey);
      await c.load();
      c.openKeyForm('openrouter');
      expect(c.keyForm!.replacing, isTrue);
      backend.lostSave = LostAnswer.afterWrite;
      await c.submitKey(_newKey);
      expect(rig.count('PUT', '/api/env'), 1);
      expect(c.keyForm!.phase, KeyFormPhase.unknown);
      expect(c.step, isNull);
    });

    test('the old and new key sharing their last four characters stay '
        'unknown, as the server shows the same preview', () async {
      backend.keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey);
      await c.load();
      final before = rig.entry('openrouter').credentials.single.lastFour;
      c.openKeyForm('openrouter');
      backend.lostSave = LostAnswer.beforeWrite;
      await c.submitKey(_newKey);
      expect(c.keyForm!.phase, KeyFormPhase.unknown);
      expect(rig.entry('openrouter').credentials.single.lastFour, before);
      expect(before, '4f2a');
      expect(rig.count('PUT', '/api/env'), 1);
    });

    test(
      'a replacement saved normally does not ask for a default model',
      () async {
        backend
          ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey)
          ..defaultProvider = 'openrouter'
          ..defaultModel = 'example-model-b';
        await c.load();
        c.openKeyForm('openrouter');
        await c.submitKey(_newKey);
        expect(c.keyForm!.phase, KeyFormPhase.saved);
        expect(c.step, isNull);
        expect(rig.count('GET', '/api/model/recommended-default'), 0);
        expect(c.changes, 1);
      },
    );

    test('closing the form during the check saves nothing', () async {
      final slow = Completer<void>();
      rig.server.onRequest('POST', '/api/providers/validate', (_) async {
        await slow.future;
        return (status: 200, body: {'ok': true, 'reachable': true});
      });
      await c.load();
      c.openKeyForm('openrouter');
      final pending = c.submitKey(_key);
      await pumpEventQueue();
      c.closeKeyForm();
      slow.complete();
      await pending;
      expect(rig.count('PUT', '/api/env'), 0);
      expect(c.keyForm, isNull);
    });

    test('state keeps no typed key', () async {
      await rig.connectOpenRouter();
      final text = [
        c.toString(),
        '${c.keyForm?.message}',
        '${c.step?.model}',
      ].join();
      expect(text, isNot(contains(_key)));
    });
  });

  group('default model', () {
    Future<void> withDefault() async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-b';
      await c.load();
    }

    test('a later provider is asked, with the current model to keep', () async {
      await withDefault();
      c.openKeyForm('anthropic');
      await c.submitKey('ak-test-0000-1111');
      expect(c.step!.kind, DefaultStepKind.ask);
      expect(c.step!.providerId, 'anthropic');
      expect(c.step!.model, 'example-model-b');
      expect(c.step!.currentModel, 'example-model-b');
      expect(rig.count('POST', '/api/model/set'), 0);
      c.dismissStep();
      expect(c.step, isNull);
      expect(rig.count('POST', '/api/model/set'), 0);
      expect(backend.defaultModel, 'example-model-b');
    });

    test('Use saves the recommended model', () async {
      await withDefault();
      backend.recommended['anthropic'] = 'example-model-a';
      c.openKeyForm('anthropic');
      await c.submitKey('ak-test-0000-1111');
      final changes = c.changes;
      expect(
        await c.setDefaultModel('anthropic', 'example-model-a'),
        DefaultSetOutcome.saved,
      );
      expect(rig.body('POST', '/api/model/set'), {
        'scope': 'main',
        'provider': 'anthropic',
        'model': 'example-model-a',
      });
      expect(c.step!.kind, DefaultStepKind.saved);
      expect(c.changes, changes + 1);
      expect(c.defaultModel, 'example-model-a');
    });

    test('no recommendation: nothing is saved and the first listed model is '
        'never taken', () async {
      backend.recommended.remove('openrouter');
      await rig.connectOpenRouter();
      expect(c.step!.kind, DefaultStepKind.choose);
      expect(rig.count('POST', '/api/model/set'), 0);
      expect(backend.defaultModel, '');
    });

    test('a failed recommendation asks to choose', () async {
      backend.recommendationFails = true;
      await rig.connectOpenRouter();
      expect(c.step!.kind, DefaultStepKind.choose);
      expect(rig.count('POST', '/api/model/set'), 0);
    });

    test(
      'a provider with no models yet shows Retry and saves nothing',
      () async {
        backend
          ..modelsWarm = false
          ..stayCold = true;
        await rig.connectOpenRouter();
        expect(c.step!.kind, DefaultStepKind.modelsLoading);
        expect(c.step!.model, 'example-model-a');
        expect(rig.count('POST', '/api/model/set'), 0);
        backend
          ..stayCold = false
          ..modelsWarm = true;
        await c.retryDefaultStep();
        expect(c.step!.kind, DefaultStepKind.saved);
        expect(backend.defaultModel, 'example-model-a');
      },
    );

    test('an expensive model asks first and is resent only after "Use it '
        'anyway"', () async {
      backend
        ..expensiveModel = 'example-model-a'
        ..expensiveMessage = 'Costs a lot.';
      await rig.connectOpenRouter();
      expect(c.confirmation!.message, 'Costs a lot.');
      expect(backend.defaultModel, '');
      expect(rig.count('POST', '/api/model/set'), 1);
      expect(
        rig
            .body('POST', '/api/model/set')
            .containsKey('confirm_expensive_model'),
        isFalse,
      );
      expect(await c.confirmExpensiveModel(), DefaultSetOutcome.saved);
      expect(rig.count('POST', '/api/model/set'), 2);
      expect(
        rig.body('POST', '/api/model/set')['confirm_expensive_model'],
        isTrue,
      );
      expect(c.confirmation, isNull);
      expect(c.step!.kind, DefaultStepKind.saved);
    });

    test(
      'declining the confirmation saves nothing and sends nothing more',
      () async {
        backend.expensiveModel = 'example-model-a';
        await rig.connectOpenRouter();
        c.declineExpensiveModel();
        expect(c.confirmation, isNull);
        expect(rig.count('POST', '/api/model/set'), 1);
        expect(c.step!.kind, DefaultStepKind.ask);
        expect(backend.defaultModel, '');
      },
    );

    test(
      'a failed save of the default marks the step and changes nothing',
      () async {
        rig.server.on('POST', '/api/model/set', {'detail': 'x'}, status: 500);
        await rig.connectOpenRouter();
        expect(c.step!.kind, DefaultStepKind.ask);
        expect(c.step!.failed, isTrue);
      },
    );
  });

  group('removing', () {
    Future<void> connected() async {
      backend
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey)
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      await c.load();
    }

    test('a key is removed and the list is read again', () async {
      await connected();
      final changes = c.changes;
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(result.status, RemovalStatus.removed);
      expect(result.stillConnected, isFalse);
      expect(rig.body('DELETE', '/api/env'), {'key': 'OPENROUTER_API_KEY'});
      expect(rig.entry('openrouter').connected, isFalse);
      expect(c.changes, changes + 1);
      expect(c.lastRemoval, same(result));
    });

    test('a hand-added key keeps the provider connected and is counted '
        'read-only', () async {
      backend.pool['openrouter'] = [poolEntry(label: 'spare')];
      await connected();
      expect(
        removalActionsFor(rig.entry('openrouter')).whereType<RemoveKeyAction>(),
        hasLength(1),
      );
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(result.stillConnected, isTrue);
      expect(result.stillConnectedThrough, 1);
      expect(
        rig.entry('openrouter').credentials.single.kind,
        CredentialKind.poolKey,
      );
      expect(rig.count('DELETE', '/api/credentials/pool/openrouter/1'), 0);
    });

    test('sign-in tokens in the pool are not counted as keys', () async {
      backend
        ..signedIn.add('nous')
        ..pool['nous'] = [poolEntry(source: 'device_code', authType: 'oauth')];
      await c.load();
      expect(rig.entry('nous').credentials.map((e) => e.kind), [
        CredentialKind.account,
      ]);
    });

    test('a 404 counts as already removed', () async {
      await connected();
      backend.keys.clear();
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(result.status, RemovalStatus.alreadyGone);
      expect(c.changes, 1);
    });

    test('a refusal shows Hermes reason and re-reads nothing', () async {
      await connected();
      rig.server.on('DELETE', '/api/env', {
        'detail': 'Locked by policy',
      }, status: 400);
      final reads = rig.count('GET', '/api/env');
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(result.status, RemovalStatus.refused);
      expect(result.message, 'Locked by policy');
      expect(rig.count('GET', '/api/env'), reads);
    });

    test('a lost answer re-reads and is never resent; a gone key counts '
        'as removed', () async {
      await connected();
      backend.lostRemove = LostAnswer.afterWrite;
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(rig.count('DELETE', '/api/env'), 1);
      expect(result.status, RemovalStatus.removed);
      expect(rig.entry('openrouter').connected, isFalse);
    });

    test('a lost answer that cannot be settled stays unknown', () async {
      await connected();
      backend.lostRemove = LostAnswer.beforeWrite;
      final changes = c.changes;
      final result = await c.remove(
        rig.entry('openrouter'),
        const RemoveKeyAction('OPENROUTER_API_KEY'),
      );
      expect(rig.count('DELETE', '/api/env'), 1);
      expect(result.status, RemovalStatus.unknown);
      expect(c.changes, changes);
    });

    test('sign out and delete endpoint', () async {
      backend
        ..signedIn.add('nous')
        ..endpoints.add(endpointRow('lab', name: 'Lab'));
      await c.load();
      expect(
        (await c.remove(rig.entry('nous'), const SignOutAction())).status,
        RemovalStatus.removed,
      );
      expect(rig.count('DELETE', '/api/providers/oauth/nous'), 1);
      expect(
        (await c.remove(rig.entry('lab'), const DeleteEndpointAction())).status,
        RemovalStatus.removed,
      );
      expect(rig.count('DELETE', '/api/providers/custom-endpoints/lab'), 1);
      expect(c.catalog!.byId('lab'), isNull);
    });

    test('a server command is not a removal', () async {
      await c.load();
      final result = await c.remove(
        rig.entry('openrouter'),
        const ServerCommandAction(command: 'hermes auth remove x'),
      );
      expect(result.status, RemovalStatus.refused);
      expect(rig.server.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });
  });

  group('removal actions', () {
    ProviderEntry entryOf({
      required Map<String, Object?> oauth,
      Map<String, Object?>? env,
    }) => mergeProviders(
      options: optionsBody([
        optionsRow('nous', name: 'Nous Portal', authType: 'oauth_device_code'),
      ]),
      oauth: {
        'providers': [oauth],
      },
      env: env,
    ).byId('nous')!;

    test('a signed-in account Hermes can remove offers Sign out', () {
      final entry = entryOf(
        oauth: oauthRow('nous', loggedIn: true, source: 'device_code'),
      );
      expect(removalActionsFor(entry).single, isA<SignOutAction>());
    });

    test(
      'a sign-in that is an API key maps to Remove key, not Hermes hint',
      () {
        final entry = entryOf(
          oauth: oauthRow(
            'nous',
            loggedIn: true,
            source: 'env_var',
            disconnectable: false,
            disconnectHint: 'Remove the API key from Settings → Keys instead.',
          ),
          env: {
            'NOUS_API_KEY': envRow(
              provider: 'nous',
              isSet: true,
              redacted: '«redacted:sk-n...1234»',
            ),
          },
        );
        final actions = removalActionsFor(entry);
        expect(actions.single, isA<RemoveKeyAction>());
        expect((actions.single as RemoveKeyAction).keyEnv, 'NOUS_API_KEY');
      },
    );

    test('a sign-in Hermes cannot remove shows its command', () {
      final entry = entryOf(
        oauth: oauthRow(
          'nous',
          loggedIn: true,
          source: 'file',
          disconnectable: false,
          disconnectCommand: 'hermes auth logout nous',
          disconnectHint: 'Run it on the server.',
        ),
      );
      final action = removalActionsFor(entry).single as ServerCommandAction;
      expect(action.command, 'hermes auth logout nous');
      expect(action.kind, isNull);
    });

    test('hand-added pool keys offer nothing', () {
      final entry = mergeProviders(
        options: optionsBody([
          optionsRow('openrouter', models: ['m']),
        ]),
        pool: {
          'providers': [
            {
              'provider': 'openrouter',
              'entries': [poolEntry()],
            },
          ],
        },
      ).byId('openrouter')!;
      expect(entry.credentials.single.kind, CredentialKind.poolKey);
      expect(removalActionsFor(entry), isEmpty);
    });
  });

  group('custom endpoint', () {
    test('checks, then saves the resolved address with the models found and '
        'make_default when there is no default', () async {
      await c.load();
      await c.checkEndpoint(name: 'Lab', address: 'http://localhost:8000');
      expect(c.endpointForm.phase, EndpointFormPhase.checked);
      expect(c.endpointForm.models, ['example-model-a', 'example-model-b']);
      expect(c.endpointForm.resolvedBaseUrl, 'http://localhost:8000/v1');
      expect(
        rig.server
            .requestsTo('POST', '/api/providers/custom-endpoints/validate')
            .single
            .queryParameters,
        isEmpty,
      );
      final result = await c.saveEndpoint(
        name: 'Lab',
        address: 'http://localhost:8000',
        model: 'example-model-a',
        apiKey: 'endpoint-key-0000',
      );
      expect(result, EndpointSubmit.saved);
      final sent = rig.body('POST', '/api/providers/custom-endpoints');
      expect(sent['base_url'], 'http://localhost:8000/v1');
      expect(sent['models'], ['example-model-a', 'example-model-b']);
      expect(sent['make_default'], isTrue);
      expect(sent['api_key'], 'endpoint-key-0000');
      expect(sent['name'], 'Lab');
      expect(sent['model'], 'example-model-a');
      expect(c.endpointForm.phase, EndpointFormPhase.saved);
      expect(c.step!.kind, DefaultStepKind.saved);
      expect(c.catalog!.byId('lab')!.isDefault, isTrue);
      expect(c.changes, greaterThanOrEqualTo(1));
    });

    test(
      'an address changed after the check does not use the resolved one',
      () async {
        await c.load();
        await c.checkEndpoint(name: 'Lab', address: 'http://localhost:8000');
        await c.saveEndpoint(
          name: 'Lab',
          address: 'http://localhost:9000',
          model: 'm',
        );
        expect(
          rig.body('POST', '/api/providers/custom-endpoints')['base_url'],
          'http://localhost:9000',
        );
      },
    );

    test(
      'with a default already, make_default is sent only when asked',
      () async {
        backend
          ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_oldKey)
          ..defaultProvider = 'openrouter'
          ..defaultModel = 'example-model-a';
        await c.load();
        await c.saveEndpoint(
          name: 'Lab',
          address: 'https://lab.example.com/v1',
          model: 'm',
        );
        expect(
          rig
              .body('POST', '/api/providers/custom-endpoints')
              .containsKey('make_default'),
          isFalse,
        );
        await c.saveEndpoint(
          name: 'Lab',
          address: 'https://lab.example.com/v1',
          model: 'm',
          useForNewChats: true,
        );
        expect(
          rig.body('POST', '/api/providers/custom-endpoints')['make_default'],
          isTrue,
        );
      },
    );

    test('an edit with the key untouched sends no api_key', () async {
      backend.endpoints.add(endpointRow('lab', name: 'Lab', hasKey: true));
      await c.load();
      await c.saveEndpoint(
        id: 'lab',
        name: 'Lab renamed',
        address: 'https://lab.example.com/v1',
        model: 'm',
      );
      final sent = rig.body('POST', '/api/providers/custom-endpoints');
      expect(sent.containsKey('api_key'), isFalse);
      expect(sent['id'], 'lab');
    });

    test(
      'clearing a saved key asks first and sends nothing until confirmed',
      () async {
        backend.endpoints.add(endpointRow('lab', name: 'Lab', hasKey: true));
        await c.load();
        expect(
          await c.saveEndpoint(
            id: 'lab',
            name: 'Lab',
            address: 'https://lab.example.com/v1',
            model: 'm',
            apiKey: '',
          ),
          EndpointSubmit.needsClearConfirmation,
        );
        expect(rig.count('POST', '/api/providers/custom-endpoints'), 0);
        expect(
          await c.saveEndpoint(
            id: 'lab',
            name: 'Lab',
            address: 'https://lab.example.com/v1',
            model: 'm',
            apiKey: '',
            confirmedClear: true,
          ),
          EndpointSubmit.saved,
        );
        expect(
          rig.body('POST', '/api/providers/custom-endpoints')['api_key'],
          '',
        );
      },
    );

    test('a key to a non-local http address needs a confirmation', () async {
      await c.load();
      const address = 'http://models.example.net/v1';
      expect(
        await c.saveEndpoint(
          name: 'Lab',
          address: address,
          model: 'm',
          apiKey: 'endpoint-key-0000',
        ),
        EndpointSubmit.needsCleartextConfirmation,
      );
      expect(rig.count('POST', '/api/providers/custom-endpoints'), 0);
      expect(
        await c.saveEndpoint(
          name: 'Lab',
          address: address,
          model: 'm',
          apiKey: 'endpoint-key-0000',
          confirmedCleartext: true,
        ),
        EndpointSubmit.saved,
      );
      expect(rig.count('POST', '/api/providers/custom-endpoints'), 1);
    });

    test(
      'no key, or an address local to the server, needs no confirmation',
      () async {
        await c.load();
        expect(
          await c.saveEndpoint(
            name: 'A',
            address: 'http://models.example.net/v1',
            model: 'm',
          ),
          EndpointSubmit.saved,
        );
        expect(
          await c.saveEndpoint(
            name: 'B',
            address: 'http://localhost:8000',
            model: 'm',
            apiKey: 'endpoint-key-0000',
          ),
          EndpointSubmit.saved,
        );
      },
    );

    test('endpointSendsKeyUnencrypted follows isLocalHost', () {
      for (final (address, key, result) in [
        ('http://models.example.net/v1', true, true),
        ('http://models.example.net/v1', false, false),
        ('https://models.example.net/v1', true, false),
        ('http://localhost:8000', true, false),
        ('http://192.168.1.4:8000', true, false),
        ('http://my-box.local', true, false),
        ('http://8.8.8.8', true, true),
        ('not a url', true, false),
        ('', true, false),
      ]) {
        expect(
          endpointSendsKeyUnencrypted(address, hasKey: key),
          result,
          reason: '$address $key',
        );
      }
    });

    test('a warning keeps saving possible; unreachable and failed are told '
        'apart', () async {
      await c.load();
      rig.server.on('POST', '/api/providers/custom-endpoints/validate', {
        'ok': false,
        'reachable': true,
        'message': 'No models listed.',
        'models': <String>[],
      });
      await c.checkEndpoint(name: 'Lab', address: 'https://lab.example.com');
      expect(c.endpointForm.phase, EndpointFormPhase.checked);
      expect(c.endpointForm.warning, 'No models listed.');
      rig.server.on('POST', '/api/providers/custom-endpoints/validate', {
        'ok': false,
        'reachable': false,
      });
      await c.checkEndpoint(name: 'Lab', address: 'https://lab.example.com');
      expect(c.endpointForm.phase, EndpointFormPhase.unreachable);
      rig.server.on(
        'POST',
        '/api/providers/custom-endpoints/validate',
        {},
        status: 500,
      );
      await c.checkEndpoint(name: 'Lab', address: 'https://lab.example.com');
      expect(c.endpointForm.phase, EndpointFormPhase.checkFailed);
    });

    test('missing fields send nothing', () async {
      await c.load();
      expect(
        await c.saveEndpoint(
          name: '',
          address: 'https://x.example',
          model: 'm',
        ),
        EndpointSubmit.invalid,
      );
      expect(c.endpointForm.issue, EndpointIssue.nameMissing);
      await c.saveEndpoint(name: 'A', address: 'ftp://x.example', model: 'm');
      expect(c.endpointForm.issue, EndpointIssue.addressScheme);
      await c.saveEndpoint(name: 'A', address: '', model: 'm');
      expect(c.endpointForm.issue, EndpointIssue.addressMissing);
      await c.saveEndpoint(name: 'A', address: 'https://x.example', model: ' ');
      expect(c.endpointForm.issue, EndpointIssue.modelMissing);
      expect(rig.count('POST', '/api/providers/custom-endpoints'), 0);
    });

    test(
      'a refusal shows Hermes reason; a lost answer is not resent',
      () async {
        await c.load();
        rig.server.on('POST', '/api/providers/custom-endpoints', {
          'detail': 'base_url must include scheme and host',
        }, status: 400);
        expect(
          await c.saveEndpoint(
            name: 'A',
            address: 'https://x.example',
            model: 'm',
          ),
          EndpointSubmit.refused,
        );
        expect(c.endpointForm.message, 'base_url must include scheme and host');
        rig.server.onRequest('POST', '/api/providers/custom-endpoints', (r) {
          throw DioException.connectionError(requestOptions: r, reason: 'x');
        });
        expect(
          await c.saveEndpoint(
            name: 'A',
            address: 'https://x.example',
            model: 'm',
          ),
          EndpointSubmit.unknown,
        );
        expect(rig.count('POST', '/api/providers/custom-endpoints'), 2);
        expect(c.endpointForm.phase, EndpointFormPhase.unknown);
      },
    );
  });

  group('key form state', () {
    test('primary actions by phase', () {
      const base = KeyFormState(providerId: 'p');
      expect(base.primaryAction(hasText: false), isNull);
      expect(base.primaryAction(hasText: true), KeyFormAction.save);
      expect(
        base
            .copyWith(phase: KeyFormPhase.checking)
            .primaryAction(hasText: true),
        isNull,
      );
      expect(
        base.copyWith(phase: KeyFormPhase.saved).primaryAction(hasText: true),
        isNull,
      );
      expect(base.saveVisible, isTrue);
      expect(base.copyWith(phase: KeyFormPhase.checking).busy, isTrue);
    });
  });
}

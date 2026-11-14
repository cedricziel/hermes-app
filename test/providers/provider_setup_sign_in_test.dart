import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_setup_controller.dart';
import 'package:hermes_app/src/providers/provider_sign_in.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';

import 'fake_provider_backend.dart';

const _poll = '/api/providers/oauth/nous/poll/s-1';

class _Rig {
  _Rig({TargetPlatform platform = TargetPlatform.macOS}) {
    controller = ProviderSetupController(
      repository: ProvidersRepository(backend.server.client().raw),
      profile: 'work',
      platform: platform,
      observeLifecycle: false,
    );
  }

  final backend = FakeProviderBackend();
  late final ProviderSetupController controller;

  int count(String method, String path) =>
      backend.server.requestsTo(method, path).length;

  void approve({String model = ''}) => backend.pollAnswer = {
    'session_id': 's-1',
    'status': 'approved',
    'account_email': 'ada@example.com',
    'model': model,
  };
}

void _settle(FakeAsync async) {
  for (var i = 0; i < 20; i++) {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
  }
}

void _run(
  String name,
  void Function(FakeAsync async, _Rig rig) body, {
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  test(name, () {
    fakeAsync((async) {
      final rig = _Rig(platform: platform);
      body(async, rig);
      rig.controller.dispose();
      async.flushTimers();
    });
  });
}

/// A profile whose default is a model the person chose, served by OpenRouter.
void _usableDefault(_Rig rig, [String model = 'example-model-b']) => rig.backend
  ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact('sk-o-test-4f2a')
  ..defaultProvider = 'openrouter'
  ..defaultModel = model;

void _signIn(FakeAsync async, _Rig rig) {
  rig.controller.load();
  _settle(async);
  rig.controller.startSignIn('nous');
  _settle(async);
  async.elapse(const Duration(seconds: 5));
  _settle(async);
}

void main() {
  _run('starts for the shown profile and lists a pending sign-in', (
    async,
    rig,
  ) {
    rig.controller.load();
    _settle(async);
    final signIn = rig.controller.startSignIn('nous');
    _settle(async);
    expect(signIn.phase, SignInPhase.waiting);
    expect(signIn.profile, 'work');
    expect(signIn.userCode, 'ABCD-1234');
    expect(rig.controller.pendingSignIns, [signIn]);
    expect(rig.controller.signInFor('nous'), same(signIn));
    // Continue reopens the same sign-in: nothing is started twice.
    expect(rig.controller.startSignIn('nous'), same(signIn));
    _settle(async);
    expect(rig.count('POST', '/api/providers/oauth/nous/start'), 1);
  });

  _run('Nous that moved the default itself: shown as changed, nothing saved', (
    async,
    rig,
  ) {
    _usableDefault(rig, 'example-free-model');
    rig.backend.approvalMovesDefaultTo = 'example-nous-model';
    rig.approve(model: 'example-nous-model');
    _signIn(async, rig);
    final step = rig.controller.step!;
    expect(step.kind, DefaultStepKind.saved);
    expect(step.movedByHermes, isTrue);
    expect(step.model, 'example-nous-model');
    expect(rig.count('POST', '/api/model/set'), 0);
    expect(rig.controller.signInFor('nous')!.accountEmail, 'ada@example.com');
    expect(rig.controller.signInFor('nous')!.userCode, isNull);
  });

  _run('Nous poll that names the unchanged default is ignored: the normal '
      'step with Keep follows', (async, rig) {
    _usableDefault(rig, 'example-model-b');
    // The plain poller echoes whatever the config already carries.
    rig.approve(model: 'example-model-b');
    _signIn(async, rig);
    final step = rig.controller.step!;
    expect(step.kind, DefaultStepKind.ask);
    expect(step.movedByHermes, isFalse);
    expect(step.model, 'example-nous-model');
    expect(step.currentModel, 'example-model-b');
    expect(rig.count('POST', '/api/model/set'), 0);
    expect(rig.backend.defaultModel, 'example-model-b');
  });

  _run('a poll that names another model changes nothing when the re-read '
      'default is the same', (async, rig) {
    _usableDefault(rig, 'example-model-b');
    rig.approve(model: 'something-else-entirely');
    _signIn(async, rig);
    expect(rig.controller.step!.kind, DefaultStepKind.ask);
    expect(rig.controller.step!.movedByHermes, isFalse);
  });

  _run('Nous cleared the default: choose a model, nothing saved', (async, rig) {
    _usableDefault(rig, 'example-free-model');
    rig.backend.approvalClearsDefault = true;
    rig.approve();
    _signIn(async, rig);
    expect(rig.controller.step!.kind, DefaultStepKind.choose);
    expect(rig.count('POST', '/api/model/set'), 0);
  });

  _run('a profile with no default gets the recommended model at once', (
    async,
    rig,
  ) {
    rig.approve();
    _signIn(async, rig);
    expect(rig.controller.step!.kind, DefaultStepKind.saved);
    expect(rig.controller.step!.model, 'example-nous-model');
    expect(rig.backend.defaultProvider, 'nous');
    expect(rig.controller.changes, greaterThanOrEqualTo(2));
  });

  _run('Stop cancels on the server and the row goes away', (async, rig) {
    rig.controller.load();
    _settle(async);
    rig.controller.startSignIn('nous');
    _settle(async);
    rig.controller.cancelSignIn('nous');
    _settle(async);
    expect(rig.count('DELETE', '/api/providers/oauth/sessions/s-1'), 1);
    expect(rig.controller.pendingSignIns, isEmpty);
    expect(rig.controller.signInFor('nous')!.phase, SignInPhase.cancelled);
    rig.controller.dismissSignIn('nous');
    expect(rig.controller.signInFor('nous'), isNull);
    async.elapse(const Duration(minutes: 2));
    _settle(async);
    expect(rig.count('GET', _poll), 0);
  });

  test('closing the controller stops polling without cancelling', () {
    fakeAsync((async) {
      final rig = _Rig();
      rig.controller.load();
      _settle(async);
      rig.controller.startSignIn('nous');
      _settle(async);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.count('GET', _poll), 1);
      rig.controller.dispose();
      async.elapse(const Duration(minutes: 5));
      _settle(async);
      expect(rig.count('GET', _poll), 1);
      expect(rig.count('DELETE', '/api/providers/oauth/sessions/s-1'), 0);
    });
  });

  _run('a sign-in keeps following the profile it was started for', (
    async,
    rig,
  ) {
    rig.controller.load();
    _settle(async);
    final signIn = rig.controller.startSignIn('nous');
    _settle(async);
    rig.controller.bind('home');
    _settle(async);
    expect(rig.controller.signInFor('nous'), isNull);
    expect(rig.controller.pendingSignIns, isEmpty);
    rig.approve();
    async.elapse(const Duration(seconds: 5));
    _settle(async);
    expect(signIn.phase, SignInPhase.approved);
    expect(signIn.profile, 'work');
    expect(
      rig.backend.server
          .requestsTo('GET', _poll)
          .every((r) => r.queryParameters['profile'] == 'work'),
      isTrue,
    );
    // The shown profile is not touched by the other one's approval.
    expect(rig.controller.step, isNull);
  });

  _run('the controller forwards the lifecycle to its sign-ins', (async, rig) {
    rig.controller.load();
    _settle(async);
    rig.controller.startSignIn('nous');
    _settle(async);
    rig.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    async.elapse(const Duration(minutes: 1));
    _settle(async);
    expect(rig.count('GET', _poll), 0);
    rig.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    _settle(async);
    expect(rig.count('GET', _poll), 1);
  }, platform: TargetPlatform.iOS);

  _run('a start Hermes refuses can be checked again: the snapshot is read', (
    async,
    rig,
  ) {
    rig.backend.server.on('POST', '/api/providers/oauth/nous/start', {
      'detail': 'Nous Portal is already signed in.',
    }, status: 400);
    rig.controller.load();
    _settle(async);
    final signIn = rig.controller.startSignIn('nous');
    _settle(async);
    expect(signIn.phase, SignInPhase.startRefused);
    expect(signIn.message, 'Nous Portal is already signed in.');
    rig.backend.signedIn.add('nous');
    final reads = rig.count('GET', '/api/providers/oauth');
    bool? connected;
    rig.controller.checkAgain('nous').then((v) => connected = v);
    _settle(async);
    expect(connected, isTrue);
    expect(rig.count('GET', '/api/providers/oauth'), reads + 1);
    // Sign in again starts a new session.
    rig.controller.startSignIn('nous');
    _settle(async);
    expect(rig.count('POST', '/api/providers/oauth/nous/start'), 2);
  });
}

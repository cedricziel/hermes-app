import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_sign_in.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';

const _start = '/api/providers/oauth/nous/start';
const _poll = '/api/providers/oauth/nous/poll/s-1';
const _cancel = '/api/providers/oauth/sessions/s-1';

Map<String, Object?> _session({
  int interval = 5,
  int expiresIn = 900,
  String url = 'https://portal.example.com/device?code=ABCD-1234',
}) => {
  'session_id': 's-1',
  'flow': 'device_code',
  'user_code': 'ABCD-1234',
  'verification_url': url,
  'expires_in': expiresIn,
  'poll_interval': interval,
};

Map<String, Object?> _pending() => {'session_id': 's-1', 'status': 'pending'};

class _Rig {
  _Rig({TargetPlatform platform = TargetPlatform.macOS}) {
    repository = ProvidersRepository(
      server.client().raw,
      telemetry: ConnectionTelemetry(tracer: tracer),
    );
    signIn = ProviderSignIn(
      repository: repository,
      profile: 'work',
      providerId: 'nous',
      platform: platform,
      onEnded: ended.add,
    );
  }

  final server = FakeHermesServer();
  final tracer = RecordingTracer();
  final ended = <ProviderSignIn>[];
  late final ProvidersRepository repository;
  late final ProviderSignIn signIn;

  int get polls => server.requestsTo('GET', _poll).length;
  int get cancels => server.requestsTo('DELETE', _cancel).length;

  void answer(Object? body, {int status = 200}) =>
      server.on('GET', _poll, body, status: status);
}

/// Lets every pending future of the fake client finish.
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
  Map<String, Object?>? session,
}) {
  test(name, () {
    fakeAsync((async) {
      final rig = _Rig(platform: platform);
      rig.server
        ..on('POST', _start, session ?? _session())
        ..on('DELETE', _cancel, {'ok': true});
      rig.answer(_pending());
      body(async, rig);
      rig.signIn.dispose();
      async.flushTimers();
    });
  });
}

void main() {
  group('starting', () {
    _run('shows the code and waits', (async, rig) {
      rig.signIn.start();
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.waiting);
      expect(rig.signIn.userCode, 'ABCD-1234');
      expect(rig.signIn.verificationLink?.host, 'portal.example.com');
      expect(rig.server.requestsTo('POST', _start).single.queryParameters, {
        'profile': 'work',
      });
      expect(rig.polls, 0);
    });

    test('javascript: address is not openable but the code stays', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.server
          ..on('POST', _start, _session(url: 'javascript:alert(1)'))
          ..on('GET', _poll, _pending());
        rig.signIn.start();
        _settle(async);
        expect(rig.signIn.userCode, 'ABCD-1234');
        expect(rig.signIn.verificationLink, isNull);
        rig.signIn.dispose();
      });
    });

    test('a refused start carries Hermes sentence and can start again', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.server.on('POST', _start, {
          'detail': 'Nous Portal is already signed in.',
        }, status: 400);
        rig.signIn.start();
        _settle(async);
        expect(rig.signIn.phase, SignInPhase.startRefused);
        expect(rig.signIn.message, 'Nous Portal is already signed in.');
        expect(rig.signIn.userCode, isNull);
        expect(rig.ended, [rig.signIn]);
        rig.server.on('POST', _start, _session());
        rig.signIn.start();
        _settle(async);
        expect(rig.signIn.phase, SignInPhase.waiting);
        expect(rig.signIn.message, isNull);
        rig.signIn.dispose();
      });
    });

    test('a start that gets no answer fails', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.server.onRequest('POST', _start, (request) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        });
        rig.signIn.start();
        _settle(async);
        expect(rig.signIn.phase, SignInPhase.startFailed);
        rig.signIn.dispose();
      });
    });
  });

  group('polling', () {
    for (final (asked, used) in [(1, 2), (0, 5), (5, 5), (7, 7), (60, 10)]) {
      _run('interval $asked s is used as $used s', (async, rig) {
        rig.signIn.start();
        _settle(async);
        async.elapse(Duration(seconds: used) - const Duration(seconds: 1));
        _settle(async);
        expect(rig.polls, 0);
        async.elapse(const Duration(seconds: 1));
        _settle(async);
        expect(rig.polls, 1);
        async.elapse(Duration(seconds: used));
        _settle(async);
        expect(rig.polls, 2);
      }, session: _session(interval: asked));
    }

    _run('approved ends it, drops the code and tells the owner', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.answer({
        'session_id': 's-1',
        'status': 'approved',
        'account_email': 'ada@example.com',
        'model': 'whatever-model',
      });
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.approved);
      expect(rig.signIn.accountEmail, 'ada@example.com');
      expect(rig.signIn.userCode, isNull);
      expect(rig.signIn.verificationLink, isNull);
      expect(rig.ended, [rig.signIn]);
      async.elapse(const Duration(minutes: 1));
      _settle(async);
      expect(rig.polls, 1);
    });

    _run('account email is absent when the poll sends none', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.answer({'session_id': 's-1', 'status': 'approved'});
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.signIn.accountEmail, isNull);
    });

    for (final (body, status, phase, message) in [
      ({'status': 'denied'}, 200, SignInPhase.denied, null),
      ({'status': 'expired'}, 200, SignInPhase.expired, null),
      ({'detail': 'gone'}, 404, SignInPhase.expired, null),
      (
        {'status': 'error', 'error_message': 'Provider said no'},
        200,
        SignInPhase.failed,
        'Provider said no',
      ),
      ({'status': 'error', 'error_message': ''}, 200, SignInPhase.failed, null),
    ]) {
      _run('ends as $phase for $body ($status)', (async, rig) {
        rig.signIn.start();
        _settle(async);
        rig.answer(body, status: status);
        async.elapse(const Duration(seconds: 5));
        _settle(async);
        expect(rig.signIn.phase, phase);
        expect(rig.signIn.message, message);
        expect(rig.signIn.userCode, isNull);
        expect(rig.cancels, 0);
        async.elapse(const Duration(minutes: 5));
        _settle(async);
        expect(rig.polls, 1);
      });
    }

    _run('two failed polls say it is still waiting, and keep the code', (
      async,
      rig,
    ) {
      rig.signIn.start();
      _settle(async);
      rig.answer({'detail': 'down'}, status: 500);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.signIn.offline, isFalse);
      // The failure skips one tick, so the next look is two ticks later.
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.polls, 1);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.polls, 2);
      expect(rig.signIn.offline, isTrue);
      expect(rig.signIn.phase, SignInPhase.waiting);
      expect(rig.signIn.userCode, 'ABCD-1234');
      // Backing off further, then recovering.
      rig.answer(_pending());
      async.elapse(const Duration(seconds: 60));
      _settle(async);
      expect(rig.signIn.offline, isFalse);
      expect(rig.signIn.phase, SignInPhase.waiting);
    });

    _run('lifetime plus 30 s counts as expired and cancels the session', (
      async,
      rig,
    ) {
      rig.signIn.start();
      _settle(async);
      rig.answer({'detail': 'down'}, status: 500);
      async.elapse(const Duration(seconds: 119));
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.waiting);
      async.elapse(const Duration(seconds: 1));
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.expired);
      expect(rig.cancels, 1);
      expect(rig.signIn.userCode, isNull);
    }, session: _session(expiresIn: 90));
  });

  group('ending', () {
    _run('cancel sends the delete and stops polling', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.signIn.cancel();
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.cancelled);
      expect(rig.cancels, 1);
      expect(rig.server.requestsTo('DELETE', _cancel).single.queryParameters, {
        'profile': 'work',
      });
      async.elapse(const Duration(minutes: 5));
      _settle(async);
      expect(rig.polls, 0);
    });

    _run('closing the owner stops polling without cancelling', (async, rig) {
      rig.signIn.start();
      _settle(async);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.polls, 1);
      rig.signIn.dispose();
      async.elapse(const Duration(minutes: 5));
      _settle(async);
      expect(rig.polls, 1);
      expect(rig.cancels, 0);
      expect(rig.ended, isEmpty);
    });
  });

  group('lifecycle', () {
    _run('a phone pauses in the background and polls at once on return', (
      async,
      rig,
    ) {
      rig.signIn.start();
      _settle(async);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.polls, 1);
      rig.signIn.appLifecycle(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 1));
      _settle(async);
      expect(rig.polls, 1);
      rig.signIn.appLifecycle(AppLifecycleState.resumed);
      _settle(async);
      expect(rig.polls, 2);
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      expect(rig.polls, 3);
    }, platform: TargetPlatform.iOS);

    _run('inactive counts as background on Android', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.signIn.appLifecycle(AppLifecycleState.inactive);
      async.elapse(const Duration(seconds: 30));
      _settle(async);
      expect(rig.polls, 0);
      rig.signIn.appLifecycle(AppLifecycleState.resumed);
      _settle(async);
      expect(rig.polls, 1);
    }, platform: TargetPlatform.android);

    _run('an approval during the background shows on return', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.signIn.appLifecycle(AppLifecycleState.paused);
      rig.answer({'session_id': 's-1', 'status': 'approved'});
      async.elapse(const Duration(minutes: 1));
      rig.signIn.appLifecycle(AppLifecycleState.resumed);
      _settle(async);
      expect(rig.signIn.phase, SignInPhase.approved);
    }, platform: TargetPlatform.iOS);

    _run(
      'a return after the code lifetime expires it',
      (async, rig) {
        rig.signIn.start();
        _settle(async);
        rig.signIn.appLifecycle(AppLifecycleState.paused);
        async.elapse(const Duration(minutes: 5));
        _settle(async);
        expect(rig.signIn.phase, SignInPhase.expired);
        expect(rig.cancels, 1);
      },
      platform: TargetPlatform.iOS,
      session: _session(expiresIn: 60),
    );

    _run('a desktop keeps polling in the background', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.signIn.appLifecycle(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 15));
      _settle(async);
      expect(rig.polls, 3);
      rig.signIn.appLifecycle(AppLifecycleState.resumed);
      _settle(async);
      expect(rig.polls, 3);
    });
  });

  group('telemetry', () {
    _run('the span carries the outcome and a polls bucket only', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.answer({'session_id': 's-1', 'status': 'approved'});
      async.elapse(const Duration(seconds: 5));
      _settle(async);
      final span = rig.tracer.spans.singleWhere(
        (s) => s.name == 'providers.signin',
      );
      expect(span.attributes, {'outcome': 'approved', 'polls': '1'});
      expect(span.ended, isTrue);
    });

    _run('cancelled, abandoned and failed starts are told apart', (async, rig) {
      rig.signIn.start();
      _settle(async);
      rig.signIn.cancel();
      _settle(async);
      expect(rig.tracer.spans.single.attributes['outcome'], 'cancelled');
    });

    test('closing a pending sign-in is abandoned', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.server
          ..on('POST', _start, _session())
          ..on('GET', _poll, _pending());
        rig.signIn.start();
        _settle(async);
        rig.signIn.dispose();
        expect(rig.tracer.spans.single.attributes, {
          'outcome': 'abandoned',
          'polls': '0',
        });
      });
    });

    test('a refused start is a failed sign-in', () {
      fakeAsync((async) {
        final rig = _Rig();
        rig.server.on('POST', _start, {'detail': 'no'}, status: 400);
        rig.signIn.start();
        _settle(async);
        expect(rig.tracer.spans.single.attributes, {
          'outcome': 'failed',
          'polls': '0',
        });
        rig.signIn.dispose();
      });
    });
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/computer_use_controller.dart';
import 'package:hermes_app/src/tools/tools_action_follower.dart';
import 'package:hermes_app/src/tools/tools_controller.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

const _status = '/api/tools/computer-use/status';
const _grant = '/api/tools/computer-use/permissions/grant';
const _log = '/api/actions/computer-use-grant/status';

Map<String, Object?> _cu({
  bool? screen = false,
  bool? ready = false,
  bool grantable = true,
  bool installed = true,
}) => {
  ...computerUseFixture,
  'screen_recording': screen,
  'accessibility': true,
  'ready': ready,
  'can_grant': grantable,
  'installed': installed,
  'error': 'driver says: SECRET-ERROR',
  'checks': [
    {'label': 'Driver', 'status': 'ok', 'message': 'SECRET-CHECK'},
  ],
};

Map<String, Object?> _action({
  required bool running,
  int? exit,
  int? pid = 5,
  List<String> lines = const [],
}) => {
  'name': 'computer-use-grant',
  'running': running,
  'exit_code': exit,
  'pid': pid,
  'lines': lines,
};

/// Moves the fake clock and lets every answer land. Dio schedules
/// zero-length timers between its steps, so they are run too.
void _advance(FakeAsync async, [Duration by = Duration.zero]) {
  async
    ..elapse(by)
    ..flushMicrotasks();
  for (var i = 0; i < 20; i++) {
    async
      ..elapse(Duration.zero)
      ..flushMicrotasks();
  }
}

R _settle<R>(FakeAsync async, Future<R> future) {
  R? value;
  var done = false;
  unawaited(
    future.then((v) {
      value = v;
      done = true;
    }),
  );
  _advance(async);
  expect(done, isTrue, reason: 'the call did not finish');
  return value as R;
}

void main() {
  late FakeHermesServer server;
  late ComputerUseController controller;
  late RecordingTracer tracer;
  late List<String> events;
  late int asked;
  var answer = true;
  Future<bool> Function()? confirm;

  const poll = kToolsActionInterval;

  ComputerUseController build() => ComputerUseController(
    toolsRepository(server),
    confirmGrant: () {
      asked++;
      return confirm?.call() ?? Future.value(answer);
    },
    checkTimeout: const Duration(seconds: 10),
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      events: (name, [attributes = const {}]) =>
          events.add('$name $attributes'),
    ),
  );

  int polls() => server.requestsTo('GET', _log).length;

  /// A controller with the status loaded, inside [async]'s zone.
  void open(FakeAsync async) {
    controller = build();
    _settle(async, controller.load());
  }

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', _status, _cu())
      ..on('POST', _grant, {
        'ok': true,
        'pid': 5,
        'name': 'computer-use-grant',
      });
    tracer = RecordingTracer();
    events = [];
    asked = 0;
    answer = true;
    confirm = null;
  });

  tearDown(() => controller.dispose());

  test('reads the status and derives the grant offer from the model', () {
    fakeAsync((async) {
      open(async);

      expect(controller.loadState, ToolsLoadState.ready);
      expect(controller.status!.platform, 'darwin');
      expect(controller.canOfferGrant, isTrue);
    });
  });

  test('no grant is offered when nothing is known to be missing', () {
    fakeAsync((async) {
      open(async);
      server.on('GET', _status, _cu(screen: true, ready: true));
      _settle(async, controller.load());
      expect(controller.canOfferGrant, isFalse);

      server.on('GET', _status, _cu(screen: null, installed: false));
      _settle(async, controller.load());
      expect(controller.canOfferGrant, isFalse);

      server.on('GET', _status, _cu(grantable: false));
      _settle(async, controller.load());
      expect(controller.canOfferGrant, isFalse);
      _settle(async, controller.grant());
      expect(asked, 0);
      expect(server.requestsTo('POST', _grant), isEmpty);
    });
  });

  test('404 and 405 hide the section', () {
    fakeAsync((async) {
      open(async);
      server.on('GET', _status, {'detail': 'x'}, status: 404);
      _settle(async, controller.load());
      expect(controller.loadState, ToolsLoadState.unsupported);

      server.on('GET', _status, {'detail': 'x'}, status: 405);
      _settle(async, controller.load());
      expect(controller.loadState, ToolsLoadState.unsupported);
    });
  });

  test('a failed read keeps the last status', () {
    fakeAsync((async) {
      open(async);
      server.on('GET', _status, {'detail': 'x'}, status: 500);

      _settle(async, controller.load());

      expect(controller.loadState, ToolsLoadState.failed);
      expect(controller.status, isNotNull);
    });
  });

  group('grant', () {
    test('nothing is sent until the confirmation says yes', () {
      fakeAsync((async) {
        open(async);
        final gate = Completer<bool>();
        confirm = () => gate.future;
        server.on('GET', _log, _action(running: false, exit: 0));

        final granting = controller.grant();
        _advance(async);
        expect(asked, 1);
        expect(server.requestsTo('POST', _grant), isEmpty);
        expect(controller.canOfferGrant, isFalse, reason: 'one at a time');

        gate.complete(true);
        _settle(async, granting);
        _advance(async, poll);
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
        expect(server.requestsTo('POST', _grant), hasLength(1));
      });
    });

    test('declining sends nothing', () {
      fakeAsync((async) {
        open(async);
        answer = false;

        _settle(async, controller.grant());

        expect(server.requestsTo('POST', _grant), isEmpty);
        expect(controller.grantPhase, ComputerUseGrantPhase.idle);
        expect(controller.canOfferGrant, isTrue);
        expect(
          tracer.spans.where((s) => s.attributes['action'] == 'grant'),
          isEmpty,
        );
      });
    });

    test('a confirmation that throws counts as no', () {
      fakeAsync((async) {
        open(async);
        confirm = () async => throw StateError('dialog');

        _settle(async, controller.grant());

        expect(server.requestsTo('POST', _grant), isEmpty);
      });
    });

    test('a profile switch or dispose while the question is open sends '
        'nothing', () {
      fakeAsync((async) {
        open(async);
        final gate = Completer<bool>();
        confirm = () => gate.future;
        final granting = controller.grant();
        _advance(async);
        controller.switchProfile(toolsRepository(server, profile: 'home'));
        gate.complete(true);
        _settle(async, granting);
        expect(server.requestsTo('POST', _grant), isEmpty);

        final second = Completer<bool>();
        confirm = () => second.future;
        _settle(async, controller.load());
        final again = controller.grant();
        _advance(async);
        controller.dispose();
        second.complete(true);
        _settle(async, again);
        expect(server.requestsTo('POST', _grant), isEmpty);
      });
    });

    test('a status read during the question that removes the need sends '
        'nothing', () {
      fakeAsync((async) {
        open(async);
        final gate = Completer<bool>();
        confirm = () => gate.future;
        final granting = controller.grant();
        _advance(async);
        server.on('GET', _status, _cu(screen: true, ready: true));
        _settle(async, controller.load());
        gate.complete(true);
        _settle(async, granting);

        expect(server.requestsTo('POST', _grant), isEmpty);
        expect(controller.grantPhase, ComputerUseGrantPhase.idle);
      });
    });

    test('follows the log, then re-reads the status: the result is the '
        're-read, not the log', () {
      fakeAsync((async) {
        var n = 0;
        server.onRequest('GET', _log, (_) {
          n++;
          return (
            status: 200,
            body: n < 3
                ? _action(running: true, lines: ['waiting for the window'])
                : _action(running: false, exit: 1, lines: ['log says failed']),
          );
        });
        var reads = 0;
        server.onRequest('GET', _status, (_) {
          reads++;
          return (
            status: 200,
            body: reads == 1 ? _cu() : _cu(screen: true, ready: true),
          );
        });
        open(async);

        _settle(async, controller.grant());
        expect(controller.grantPhase, ComputerUseGrantPhase.running);
        _advance(async, poll * 2);

        // The exit code was 1, yet the re-read is what says the result.
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
        expect(controller.status!.screenRecording, isTrue);
        expect(controller.status!.ready, isTrue);
        expect(controller.grantLines, ['log says failed']);
      });
    });

    test('an earlier run\'s finished log does not end a grant whose start '
        'gave no pid', () {
      fakeAsync((async) {
        server
          ..on('POST', _grant, {'ok': true})
          ..on('GET', _log, _action(running: false, exit: 0, pid: 99));
        open(async);

        _settle(async, controller.grant());

        // Unknown, not success: the status is read, and says what it says.
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
        expect(controller.status!.screenRecording, isFalse);
        expect(controller.canOfferGrant, isTrue);
        expect(controller.grantLines, isEmpty);
      });
    });

    test('a finished log without a pid is not the grant\'s own', () {
      fakeAsync((async) {
        server.on('GET', _log, _action(running: false, exit: 0, pid: null));
        open(async);

        _settle(async, controller.grant());

        // The follower ended it as unknown: one read of the log, then the
        // status read.
        expect(polls(), 1);
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
      });
    });

    test('a re-read that fails after the end is unconfirmed and keeps the '
        'loaded status and state', () {
      fakeAsync((async) {
        server.on('GET', _log, _action(running: false, exit: 0));
        var reads = 0;
        server.onRequest('GET', _status, (_) {
          reads++;
          return reads == 1
              ? (status: 200, body: _cu())
              : (status: 500, body: {'detail': 'x'});
        });
        open(async);

        _settle(async, controller.grant());

        expect(controller.grantPhase, ComputerUseGrantPhase.unconfirmed);
        expect(controller.status, isNotNull);
        expect(controller.loadState, ToolsLoadState.ready);
      });
    });

    test('a re-read that hangs ends unconfirmed after the check timeout', () {
      fakeAsync((async) {
        server.on('GET', _log, _action(running: false, exit: 0));
        open(async);
        final hang = Completer<void>();
        server.onRequest('GET', _status, (_) async {
          await hang.future;
          return (status: 200, body: _cu(screen: true));
        });

        _settle(async, controller.grant());
        expect(controller.grantPhase, ComputerUseGrantPhase.checking);
        _advance(async, const Duration(seconds: 9));
        expect(controller.grantPhase, ComputerUseGrantPhase.checking);
        _advance(async, const Duration(seconds: 2));

        expect(controller.grantPhase, ComputerUseGrantPhase.unconfirmed);
        expect(controller.loadState, ToolsLoadState.ready);
        hang.complete();
      });
    });

    test('no end within the patience still re-reads', () {
      fakeAsync((async) {
        open(async);
        server.on('GET', _log, _action(running: true));

        _settle(async, controller.grant());
        _advance(async, kToolsActionPatience);

        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
      });
    });

    test('failed reads of the log are said, backed off, and give up after '
        'three; checkAgain resumes', () {
      fakeAsync((async) {
        open(async);
        server.onRequest(
          'GET',
          _log,
          (_) => (status: 502, body: {'detail': 'x'}),
        );

        _settle(async, controller.grant());
        expect(controller.followFailing, isTrue);
        expect(controller.grantBusy, isTrue);
        _advance(async, poll);
        expect(polls(), 2);
        _advance(async, poll * 2);

        expect(polls(), 3);
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
        expect(controller.followFailing, isFalse);
        expect(controller.followLost, isTrue);

        server.on('GET', _log, _action(running: false, exit: 0));
        controller.checkAgain();
        _advance(async);

        expect(controller.followLost, isFalse);
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
      });
    });

    test('a non-macOS server refuses with Hermes\' text', () {
      fakeAsync((async) {
        open(async);
        server.on('POST', _grant, {
          'detail': 'Computer Use permission grants are a macOS concept.',
        }, status: 400);

        _settle(async, controller.grant());

        expect(controller.grantPhase, ComputerUseGrantPhase.refused);
        expect(controller.refusalDetail, contains('macOS concept'));
        expect(polls(), 0);
      });
    });

    test('a failure is not retried', () {
      fakeAsync((async) {
        open(async);
        server.on('POST', _grant, {'detail': 'x'}, status: 500);

        _settle(async, controller.grant());
        _advance(async, const Duration(minutes: 1));

        expect(controller.grantPhase, ComputerUseGrantPhase.failed);
        expect(server.requestsTo('POST', _grant), hasLength(1));
      });
    });

    test('a lost answer keeps the grant busy and follows read-only, never '
        'resending', () {
      fakeAsync((async) {
        open(async);
        server.onRequest('POST', _grant, (r) {
          throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: r,
          );
        });
        server.on('GET', _log, _action(running: true, pid: 9));

        _settle(async, controller.grant());

        expect(controller.grantBusy, isTrue);
        expect(controller.canOfferGrant, isFalse);
        _settle(async, controller.grant());
        expect(server.requestsTo('POST', _grant), hasLength(1));

        server.on('GET', _log, _action(running: false, exit: 0, pid: 9));
        _advance(async, poll);
        expect(controller.grantPhase, ComputerUseGrantPhase.finished);
        expect(server.requestsTo('POST', _grant), hasLength(1));
      });
    });

    test('a second grant while one runs is not sent', () {
      fakeAsync((async) {
        open(async);
        server.on('GET', _log, _action(running: true));
        _settle(async, controller.grant());

        _settle(async, controller.grant());

        expect(server.requestsTo('POST', _grant), hasLength(1));
        expect(asked, 1);
      });
    });

    test('a profile switch stops following', () {
      fakeAsync((async) {
        open(async);
        server.on('GET', _log, _action(running: true));
        _settle(async, controller.grant());

        controller.switchProfile(toolsRepository(server, profile: 'home'));
        final seen = polls();
        _advance(async, const Duration(minutes: 1));

        expect(polls(), seen);
        expect(controller.grantPhase, ComputerUseGrantPhase.idle);
        expect(controller.status, isNull);
      });
    });

    test('dispose stops following', () {
      fakeAsync((async) {
        open(async);
        server.on('GET', _log, _action(running: true));
        _settle(async, controller.grant());
        controller.dispose();
        final seen = polls();
        _advance(async, const Duration(minutes: 1));

        expect(polls(), seen);
      });
    });
  });

  test('spans carry the action and the outcome, never error or checks', () {
    fakeAsync((async) {
      server.on(
        'GET',
        _log,
        _action(running: false, exit: 0, lines: ['LOGLINE']),
      );
      open(async);
      _settle(async, controller.grant());

      final actions = {
        for (final s in tracer.spans.where(
          (s) => s.name == 'tools.computer_use',
        ))
          s.attributes['action']: s.attributes['outcome'],
      };
      expect(actions, {'status': 'ok', 'grant': 'ok'});
      expect(tracer.spans.every((s) => s.ended), isTrue);
      final recorded = [
        for (final s in tracer.spans) '${s.name} ${s.attributes}',
        ...events,
      ].join('\n');
      for (final leak in ['SECRET-ERROR', 'SECRET-CHECK', 'LOGLINE', 'work']) {
        expect(recorded, isNot(contains(leak)));
      }
    });
  });
}

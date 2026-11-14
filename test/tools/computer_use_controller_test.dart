import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/computer_use_controller.dart';
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

void main() {
  late FakeHermesServer server;
  late ComputerUseController controller;
  late RecordingTracer tracer;
  late List<String> events;
  late int asked;
  var answer = true;

  ComputerUseController build({
    Duration patience = const Duration(seconds: 5),
  }) => ComputerUseController(
    toolsRepository(server),
    confirmGrant: () async {
      asked++;
      return answer;
    },
    interval: const Duration(milliseconds: 10),
    patience: patience,
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      events: (name, [attributes = const {}]) =>
          events.add('$name $attributes'),
    ),
  );

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'timed out waiting');
  }

  setUp(() async {
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
    controller = build();
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('reads the status and derives the grant offer from the model', () {
    expect(controller.loadState, ToolsLoadState.ready);
    expect(controller.status!.platform, 'darwin');
    expect(controller.canOfferGrant, isTrue);
  });

  test('no grant is offered when nothing is known to be missing', () async {
    server.on('GET', _status, _cu(screen: true, ready: true));
    await controller.load();
    expect(controller.canOfferGrant, isFalse);

    server.on('GET', _status, _cu(screen: null, installed: false));
    await controller.load();
    expect(controller.canOfferGrant, isFalse);

    server.on('GET', _status, _cu(grantable: false));
    await controller.load();
    expect(controller.canOfferGrant, isFalse);
    await controller.grant();
    expect(asked, 0);
    expect(server.requestsTo('POST', _grant), isEmpty);
  });

  test('404 and 405 hide the section', () async {
    server.on('GET', _status, {'detail': 'x'}, status: 404);
    await controller.load();
    expect(controller.loadState, ToolsLoadState.unsupported);

    server.on('GET', _status, {'detail': 'x'}, status: 405);
    await controller.load();
    expect(controller.loadState, ToolsLoadState.unsupported);
  });

  test('a failed read keeps the last status', () async {
    server.on('GET', _status, {'detail': 'x'}, status: 500);

    await controller.load();

    expect(controller.loadState, ToolsLoadState.failed);
    expect(controller.status, isNotNull);
  });

  group('grant', () {
    test('nothing is sent until the confirmation says yes', () async {
      final gate = Completer<bool>();
      controller.dispose();
      controller = ComputerUseController(
        toolsRepository(server),
        confirmGrant: () {
          asked++;
          return gate.future;
        },
        interval: const Duration(milliseconds: 10),
      );
      await controller.load();
      server.on('GET', _log, _action(running: false, exit: 0));

      final granting = controller.grant();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(asked, 1);
      expect(server.requestsTo('POST', _grant), isEmpty);
      expect(controller.canOfferGrant, isFalse, reason: 'one at a time');

      gate.complete(true);
      await granting;
      await until(
        () => controller.grantPhase == ComputerUseGrantPhase.finished,
      );
      expect(server.requestsTo('POST', _grant), hasLength(1));
    });

    test('declining sends nothing', () async {
      answer = false;

      await controller.grant();

      expect(server.requestsTo('POST', _grant), isEmpty);
      expect(controller.grantPhase, ComputerUseGrantPhase.idle);
      expect(controller.canOfferGrant, isTrue);
      expect(
        tracer.spans.where((s) => s.attributes['action'] == 'grant'),
        isEmpty,
      );
    });

    test('a confirmation that throws counts as no', () async {
      controller.dispose();
      controller = ComputerUseController(
        toolsRepository(server),
        confirmGrant: () async => throw StateError('dialog'),
      );
      await controller.load();

      await controller.grant();

      expect(server.requestsTo('POST', _grant), isEmpty);
    });

    test('follows the log, then re-reads the status: the result is the '
        're-read, not the log', () async {
      var polls = 0;
      server.onRequest('GET', _log, (_) {
        polls++;
        return (
          status: 200,
          body: polls < 3
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
      await controller.load();

      await controller.grant();
      await until(
        () => controller.grantPhase == ComputerUseGrantPhase.finished,
      );

      // The exit code was 1, yet the re-read is what says the result.
      expect(controller.status!.screenRecording, isTrue);
      expect(controller.status!.ready, isTrue);
      expect(controller.grantLines, ['log says failed']);
      expect(reads, greaterThanOrEqualTo(2));
    });

    test('a re-read that fails after the end is unconfirmed', () async {
      server.on('GET', _log, _action(running: false, exit: 0));
      var reads = 0;
      server.onRequest('GET', _status, (_) {
        reads++;
        return reads == 1
            ? (status: 200, body: _cu())
            : (status: 500, body: {'detail': 'x'});
      });
      await controller.load();

      await controller.grant();
      await until(
        () => controller.grantPhase == ComputerUseGrantPhase.unconfirmed,
      );

      expect(controller.status, isNotNull);
    });

    test('no end within the patience still re-reads', () async {
      controller.dispose();
      controller = build(patience: const Duration(milliseconds: 60));
      await controller.load();
      server.on('GET', _log, _action(running: true));

      await controller.grant();
      await until(
        () => controller.grantPhase == ComputerUseGrantPhase.finished,
      );
    });

    test('a non-macOS server refuses with Hermes\' text', () async {
      server.on('POST', _grant, {
        'detail': 'Computer Use permission grants are a macOS concept.',
      }, status: 400);

      await controller.grant();

      expect(controller.grantPhase, ComputerUseGrantPhase.refused);
      expect(controller.refusalDetail, contains('macOS concept'));
      expect(server.requestsTo('GET', _log), isEmpty);
    });

    test('a failure is not retried', () async {
      server.on('POST', _grant, {'detail': 'x'}, status: 500);

      await controller.grant();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.grantPhase, ComputerUseGrantPhase.failed);
      expect(server.requestsTo('POST', _grant), hasLength(1));
    });

    test('a lost answer re-reads the status and never resends', () async {
      server.onRequest('POST', _grant, (r) {
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        );
      });

      await controller.grant();

      expect(controller.grantPhase, ComputerUseGrantPhase.finished);
      expect(server.requestsTo('POST', _grant), hasLength(1));
      expect(server.requestsTo('GET', _log), isEmpty);
    });

    test('a second grant while one runs is not sent', () async {
      server.on('GET', _log, _action(running: true));
      await controller.grant();

      await controller.grant();

      expect(server.requestsTo('POST', _grant), hasLength(1));
      expect(asked, 1);
    });

    test('a profile switch stops following', () async {
      server.on('GET', _log, _action(running: true));
      await controller.grant();
      await until(() => server.requestsTo('GET', _log).isNotEmpty);

      controller.switchProfile(toolsRepository(server, profile: 'home'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final polls = server.requestsTo('GET', _log).length;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(server.requestsTo('GET', _log), hasLength(polls));
      expect(controller.grantPhase, ComputerUseGrantPhase.idle);
      expect(controller.status, isNull);
    });

    test('dispose stops following', () async {
      server.on('GET', _log, _action(running: true));
      await controller.grant();
      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final polls = server.requestsTo('GET', _log).length;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(server.requestsTo('GET', _log), hasLength(polls));
    });
  });

  test(
    'spans carry the action and the outcome, never error or checks',
    () async {
      server.on(
        'GET',
        _log,
        _action(running: false, exit: 0, lines: ['LOGLINE']),
      );
      await controller.grant();
      await until(
        () => controller.grantPhase == ComputerUseGrantPhase.finished,
      );

      final actions = {
        for (final s in tracer.spans.where(
          (s) => s.name == 'tools.computer_use',
        ))
          s.attributes['action']: s.attributes['outcome'],
      };
      expect(actions, {'status': 'ok', 'grant': 'ok'});
      final recorded = [
        for (final s in tracer.spans) '${s.name} ${s.attributes}',
        ...events,
      ].join('\n');
      for (final leak in ['SECRET-ERROR', 'SECRET-CHECK', 'LOGLINE', 'work']) {
        expect(recorded, isNot(contains(leak)));
      }
    },
  );
}

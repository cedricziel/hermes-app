import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/terminal_backends_controller.dart';
import 'package:hermes_app/src/tools/tools_controller.dart';
import 'package:hermes_app/src/tools/tools_write.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

const _list = '/api/tools/terminal/backends';
const _put = '/api/tools/terminal/backend';

Map<String, Object?> _backends(String active) => {
  'active': active,
  'backends': [
    for (final b in backendsFixture['backends']! as List)
      {...(b as Map<String, Object?>), 'active': b['name'] == active},
  ],
};

void main() {
  late FakeHermesServer server;
  late TerminalBackendsController controller;
  late RecordingTracer tracer;
  late List<String> events;
  late int asked;
  var answer = true;

  TerminalBackendsController build() => TerminalBackendsController(
    toolsRepository(server),
    confirmLocal: () async {
      asked++;
      return answer;
    },
    checkTimeout: const Duration(milliseconds: 200),
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      events: (name, [attributes = const {}]) =>
          events.add('$name $attributes'),
    ),
  );

  Iterable<Object?> puts() =>
      server.requestsTo('PUT', _put).map((r) => jsonDecode(r.data as String));

  void lose() => server.onRequest('PUT', _put, (r) {
    throw DioException.receiveTimeout(
      timeout: const Duration(seconds: 1),
      requestOptions: r,
    );
  });

  setUp(() async {
    // The fixture's active backend is local; start from docker so Local is a
    // pick.
    server = FakeHermesServer()..on('GET', _list, _backends('docker'));
    tracer = RecordingTracer();
    events = [];
    asked = 0;
    answer = true;
    controller = build();
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('reads the backends and flags an active one that needs setup', () {
    expect(controller.loadState, ToolsLoadState.ready);
    expect(controller.backends.map((b) => b.name), ['local', 'docker']);
    expect(controller.active, 'docker');
    expect(controller.activeNeedsSetup, isTrue);
  });

  test('404 and 405 hide the section', () async {
    server.on('GET', _list, {'detail': 'x'}, status: 404);
    await controller.load();
    expect(controller.loadState, ToolsLoadState.unsupported);

    server.on('GET', _list, {'detail': 'x'}, status: 405);
    await controller.load();
    expect(controller.loadState, ToolsLoadState.unsupported);
  });

  test('a profile that is gone is its own state', () async {
    server.on('GET', _list, {
      'detail': "Profile 'work' does not exist",
    }, status: 404);

    await controller.load();

    expect(controller.loadState, ToolsLoadState.profileGone);
  });

  test('a failed read keeps the last backends', () async {
    server.on('GET', _list, {'detail': 'x'}, status: 500);

    await controller.load();

    expect(controller.loadState, ToolsLoadState.failed);
    expect(controller.backends, hasLength(2));
  });

  group('Local', () {
    test('nothing is sent until the confirmation says yes', () async {
      final gate = Completer<bool>();
      controller = TerminalBackendsController(
        toolsRepository(server),
        confirmLocal: () {
          asked++;
          return gate.future;
        },
      );
      await controller.load();
      server
        ..on('PUT', _put, {'ok': true, 'backend': 'local'})
        ..on('GET', _list, _backends('local'));

      final picking = controller.pick('local');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(asked, 1);
      expect(puts(), isEmpty);

      gate.complete(true);
      await picking;
      expect(puts().single, containsPair('backend', 'local'));
      expect(controller.active, 'local');
    });

    test('declining sends nothing and changes nothing', () async {
      answer = false;

      await controller.pick('local');

      expect(asked, 1);
      expect(puts(), isEmpty);
      expect(controller.pickState, ToolsWriteState.idle);
      expect(controller.active, 'docker');
      expect(tracer.spans, isEmpty);
    });

    test('a confirmation that throws counts as no', () async {
      controller = TerminalBackendsController(
        toolsRepository(server),
        confirmLocal: () async => throw StateError('dialog'),
      );
      await controller.load();

      await controller.pick('local');

      expect(puts(), isEmpty);
    });

    test(
      'a switch of profile while the question is open sends nothing',
      () async {
        final gate = Completer<bool>();
        controller = TerminalBackendsController(
          toolsRepository(server),
          confirmLocal: () => gate.future,
        );
        await controller.load();
        final picking = controller.pick('local');
        controller.switchProfile(toolsRepository(server, profile: 'home'));
        gate.complete(true);
        await picking;

        expect(puts(), isEmpty);
      },
    );

    test(
      'picking the backend that is already active asks and sends nothing',
      () async {
        server.on('GET', _list, _backends('local'));
        await controller.load();

        await controller.pick('local');

        expect(asked, 0);
        expect(puts(), isEmpty);
      },
    );
  });

  group('a backend other than Local', () {
    test('is sent without a question, even when it needs setup', () async {
      server
        ..on('PUT', _put, {'ok': true, 'backend': 'docker'})
        ..on('GET', _list, _backends('docker'));
      server.on('GET', _list, _backends('local'));
      await controller.load();

      await controller.pick('docker');

      expect(asked, 0);
      expect(puts().single, containsPair('backend', 'docker'));
      expect(controller.pickState, ToolsWriteState.idle);
    });

    test('a name Hermes did not list is never sent', () async {
      await controller.pick('invented');

      expect(puts(), isEmpty);
    });

    test('a refusal holds Hermes\' text', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      server.on('PUT', _put, {'detail': 'Unknown backend'}, status: 400);

      await controller.pick('docker');

      expect(controller.pickState, ToolsWriteState.refused);
      expect(controller.refusalDetail, 'Unknown backend');
      expect(controller.active, 'local');
    });

    test('a failure is not retried', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      server.on('PUT', _put, {'detail': 'x'}, status: 500);

      await controller.pick('docker');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.pickState, ToolsWriteState.failed);
      expect(puts(), hasLength(1));
    });

    test('a lost answer is checked by a re-read and never resent', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      lose();
      server.on('GET', _list, _backends('docker'));

      await controller.pick('docker');

      expect(controller.pickState, ToolsWriteState.idle);
      expect(controller.active, 'docker');
      expect(puts(), hasLength(1));
    });

    test('a lost answer with no change is not applied', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      lose();

      await controller.pick('docker');

      expect(controller.pickState, ToolsWriteState.notApplied);
      expect(puts(), hasLength(1));
    });

    test('a lost answer with a hanging re-read ends unconfirmed', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      lose();
      final hang = Completer<void>();
      server.onRequest('GET', _list, (_) async {
        await hang.future;
        return (status: 200, body: _backends('docker'));
      });

      await controller.pick('docker');

      expect(controller.pickState, ToolsWriteState.unconfirmed);
      hang.complete();
    });

    test('one write at a time', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      final gate = Completer<void>();
      server.onRequest('PUT', _put, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });

      final first = controller.pick('docker');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.pick('local');
      gate.complete();
      await first;

      expect(puts(), hasLength(1));
      expect(asked, 0);
    });

    test('a late answer after a profile switch is dropped', () async {
      server.on('GET', _list, _backends('local'));
      await controller.load();
      final gate = Completer<void>();
      server.onRequest('PUT', _put, (_) async {
        await gate.future;
        return (status: 200, body: {'ok': true});
      });
      final pending = controller.pick('docker');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.switchProfile(toolsRepository(server, profile: 'home'));
      gate.complete();
      await pending;

      expect(controller.pickState, ToolsWriteState.idle);
      expect(controller.backends, isEmpty);
    });
  });

  test('the span carries the outcome only', () async {
    server.on('GET', _list, _backends('local'));
    await controller.load();
    server.on('PUT', _put, {'detail': 'Docker is /secret/path'}, status: 400);

    await controller.pick('docker');

    final span = tracer.spans.singleWhere(
      (s) => s.name == 'tools.terminal_backend',
    );
    expect(span.attributes['outcome'], 'refused');
    expect(span.ended, isTrue);
    final recorded = [
      for (final s in tracer.spans) '${s.name} ${s.attributes}',
      ...events,
    ].join('\n');
    expect(recorded, isNot(contains('docker')));
    expect(recorded, isNot(contains('/secret/path')));
    expect(recorded, isNot(contains('work')));
  });
}

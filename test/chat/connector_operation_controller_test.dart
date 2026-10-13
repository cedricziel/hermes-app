import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/connector_operation_controller.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';

import 'connector_fixtures.dart';

void main() {
  late ActivityRpcServer server;
  late ConnectorOperationController controller;
  late Object attachment;
  setUp(() {
    server = ActivityRpcServer();
    attachment = Object();
    controller = ConnectorOperationController(
      now: () => DateTime.utc(2030),
      openBrowser: (_) async => true,
    );
    controller.bind(
      attachment,
      profile: 'private-profile',
      respond: (params) => server.client.request('connection.respond', params),
    );
    controller.accept(
      ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
      attachment: attachment,
    );
  });
  tearDown(() async {
    controller.dispose();
    await server.close();
  });
  test('late request metadata updates listeners without rolling back visible progress', () {
    var changed = 0;
    controller.addListener(() => changed++);
    controller.accept(
      ConnectorOperationSnapshot.fromRequest(
        connectionRequestFixture,
        runtimeId: 'runtime-a',
      )!,
      attachment: attachment,
    );
    expect(changed, 1);
    expect(controller.operations.single.seq, 4);
    expect(controller.operations.single.toolCallId, 'synthetic-tool');
    expect(controller.operations.single.timeoutSeconds, 60);
  });

  test('skip uses exact owner/profile and skipped-only result without optimistic state', () async {
    final operation = controller.operations.single;
    final request = controller.skip(
      operation,
      operation.targets.single.name,
      attachment: attachment,
    );
    await pumpEventQueue();
    expect(server.requests.single['params'], {
      'owner': {'type': 'session', 'session_id': 'runtime-a'},
      'op_id': 'synthetic-operation',
      'profile': 'private-profile',
      'result': {
        'targets': [
          {'name': 'synthetic-connector', 'status': 'skipped'},
        ],
      },
    });
    await controller.skip(
      operation,
      operation.targets.single.name,
      attachment: attachment,
    );
    expect(server.requests, hasLength(1));
    server.answer(0, {'status': 'ok', 'settled': false});
    await request;
    expect(controller.operations.single.targets.single.state, 'initiated');
  });
  test(
    'continue uses explicit settled_by without supplying credentials',
    () async {
      final request = controller.continueOperation(
        controller.operations.single,
        attachment: attachment,
      );
      await pumpEventQueue();
      expect((server.requests.single['params'] as Map)['result'], {
        'settled_by': 'continue',
        'targets': [],
      });
      server.refuse(0, 4002);
      await request;
      expect(controller.operations.single.settled, isFalse);
      expect(controller.errorFor(controller.operations.single.key), isNotNull);
    },
  );
  test(
    'deadline and unknown target kind disable unsupported actions',
    () async {
      final unknown = ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'seq': 5,
        'targets': [
          {
            'name': 'unknown',
            'kind': 'future',
            'action': 'connect',
            'state': 'pending',
          },
        ],
      })!;
      controller.accept(unknown, attachment: attachment);
      expect(controller.canSkip(unknown.key, 'unknown'), isFalse);
      await controller.skip(unknown, 'unknown', attachment: attachment);
      final past = ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'seq': 6,
        'deadline_at': 1893455999.0,
      })!;
      controller.accept(past, attachment: attachment);
      expect(controller.awaitingFinalStatus(past.key), isTrue);
      await controller.continueOperation(past, attachment: attachment);
      expect(server.requests, isEmpty);
    },
  );
  test('browser opening never marks a target connected and unsafe URL stays unavailable', () async {
    final operation = controller.operations.single;
    await controller.openTarget(
      operation,
      'synthetic-connector',
      attachment: attachment,
    );
    expect(controller.operations.single.targets.single.state, 'initiated');
    final unsafe = ConnectorOperationSnapshot.fromUpdate({
      ...connectionUpdateFixture,
      'seq': 5,
      'targets': [
        {
          'name': 'synthetic-connector',
          'kind': 'connector',
          'action': 'authorize',
          'state': 'initiated',
          'connect_url': 'https://user:token@unsafe.invalid',
        },
      ],
    })!;
    controller.accept(unsafe, attachment: attachment);
    expect(controller.canOpen(unsafe.key, 'synthetic-connector'), isFalse);
  });
  test('credential installation remains unsupported while Skip never transmits env', () async {
    final operation = ConnectorOperationSnapshot.fromUpdate({
      ...connectionUpdateFixture,
      'seq': 5,
      'targets': [
        {
          'name': 'needs-env',
          'kind': 'mcp',
          'action': 'install',
          'state': 'pending',
          'required_env': [
            {
              'name': 'TOKEN',
              'required': true,
              'secret': true,
              'default': 'PRIVATE-DEFAULT-TOKEN',
            },
          ],
        },
      ],
    })!;
    controller.accept(operation, attachment: attachment);
    expect(controller.canOpen(operation.key, 'needs-env'), isFalse);
    final request = controller.skip(
      controller.operations.single,
      'needs-env',
      attachment: attachment,
    );
    await pumpEventQueue();
    expect(
      server.requests.single.toString(),
      isNot(contains('PRIVATE-DEFAULT-TOKEN')),
    );
    expect((server.requests.single['params'] as Map)['result'], {
      'targets': [
        {'name': 'needs-env', 'status': 'skipped'},
      ],
    });
    server.answer(0, {'status': 'ok', 'settled': false});
    await request;
  });

  test('scope replacement rejects a late RPC outcome', () async {
    final operation = controller.operations.single;
    final request = controller.skip(
      operation,
      'synthetic-connector',
      attachment: attachment,
    );
    await pumpEventQueue();
    controller.bind(
      Object(),
      respond: (params) => server.client.request('connection.respond', params),
    );
    server.answer(0, {'status': 'ok', 'settled': true});
    await request;
    expect(controller.operations, isEmpty);
  });
  test(
    'connector outcomes exclude payloads and telemetry failures stay non-fatal',
    () async {
      controller.dispose();
      final exported = <String>[];
      controller = ConnectorOperationController(
        now: () => DateTime.utc(2030),
        events: (name, [attributes = const {}]) {
          exported.add('$name $attributes');
          throw StateError('Telemetry unavailable');
        },
      );
      controller.bind(
        attachment,
        profile: 'private-profile',
        respond: (params) =>
            server.client.request('connection.respond', params),
      );
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
        attachment: attachment,
      );
      final operation = controller.operations.single;
      final request = controller.skip(
        operation,
        'synthetic-connector',
        attachment: attachment,
      );
      await pumpEventQueue();
      server.answer(0, {'status': 'ok', 'settled': false});
      await request;
      final serialized = exported.join(' ');
      expect(serialized, isNot(contains('private-profile')));
      expect(serialized, isNot(contains('connect.invalid')));
      expect(serialized, isNot(contains('synthetic-operation')));
      expect(serialized, isNot(contains('synthetic-connector')));
      expect(controller.operations, hasLength(1));
    },
  );
  test('a stale card cannot submit after scope replacement reuses operation identity', () async {
    final previous = controller.operations.single;
    final next = Object();
    controller.bind(
      next,
      profile: 'other-profile',
      respond: (params) => server.client.request('connection.respond', params),
    );
    controller.accept(
      ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
      attachment: next,
    );
    expect(
      controller.canSkip(
        controller.operations.single.key,
        'synthetic-connector',
      ),
      isTrue,
    );
    await controller.skip(
      previous,
      'synthetic-connector',
      attachment: attachment,
    );
    expect(server.requests, isEmpty);
  });
  test(
    'confirmed RPC settlement cannot reopen from a delayed earlier transition',
    () async {
      final operation = controller.operations.single;
      final request = controller.continueOperation(
        operation,
        attachment: attachment,
      );
      await pumpEventQueue();
      server.answer(0, {'status': 'ok', 'settled': true});
      await request;
      expect(controller.operations.single.settled, isTrue);
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 5,
          'settled': false,
        })!,
        attachment: attachment,
      );
      expect(controller.operations.single.settled, isTrue);
      expect(
        controller.canSkip(
          controller.operations.single.key,
          'synthetic-connector',
        ),
        isFalse,
      );
    },
  );
  test(
    'account updates stay read-only without known profile ownership',
    () async {
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'owner': {'type': 'account'},
        })!,
        attachment: attachment,
      );
      final account = controller.operations.last;
      expect(controller.canRespond(account.key), isFalse);
      expect(controller.canOpen(account.key, 'synthetic-connector'), isFalse);
      await controller.continueOperation(account, attachment: attachment);
      expect(server.requests, isEmpty);
    },
  );
  test(
    'a card replaced by a newer snapshot cannot submit its old target',
    () async {
      final old = controller.operations.single;
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 5,
        })!,
        attachment: attachment,
      );
      await controller.skip(old, 'synthetic-connector', attachment: attachment);
      expect(server.requests, isEmpty);
    },
  );
  test('lost responder disables responses and updates listeners', () {
    var changes = 0;
    controller.addListener(() => changes++);
    controller.bind(attachment, profile: 'private-profile');
    expect(controller.canRespond(controller.operations.single.key), isFalse);
    expect(changes, 1);
  });

  for (final replaceProfile in [false, true]) {
    test(
      'pending listener ${replaceProfile ? 'profile replacement' : 'signout'} prevents connector dispatch',
      () async {
        final operation = controller.operations.single;
        var retired = false;
        controller.addListener(() {
          if (retired || !controller.pendingFor(operation.key)) return;
          retired = true;
          controller.bind(
            replaceProfile ? Object() : null,
            profile: replaceProfile ? 'replacement-profile' : null,
            respond: replaceProfile
                ? (params) =>
                      server.client.request('connection.respond', params)
                : null,
          );
        });

        final request = controller.skip(
          operation,
          'synthetic-connector',
          attachment: attachment,
        );
        await pumpEventQueue();
        if (server.requests.isNotEmpty) {
          server.answer(0, {'status': 'ok', 'settled': false});
        }
        await request;

        expect(retired, isTrue);
        expect(server.requests, isEmpty);
      },
    );
  }

  test('a newer snapshot during pending notification aborts dispatch and releases the key', () async {
    final operation = controller.operations.single;
    var replaced = false;
    controller.addListener(() {
      if (replaced || !controller.pendingFor(operation.key)) return;
      replaced = true;
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 5,
        })!,
        attachment: attachment,
      );
    });

    final request = controller.skip(
      operation,
      'synthetic-connector',
      attachment: attachment,
    );
    await pumpEventQueue();
    if (server.requests.isNotEmpty) {
      server.answer(0, {'status': 'ok', 'settled': false});
    }
    await request;

    expect(server.requests, isEmpty);
    expect(controller.operations.single.seq, 5);
    expect(controller.pendingFor(operation.key), isFalse);
    expect(controller.canSkip(operation.key, 'synthetic-connector'), isTrue);
  });

  test(
    'an old browser failure cannot annotate a replacement operation snapshot',
    () async {
      controller.dispose();
      final opened = Completer<bool>();
      controller = ConnectorOperationController(
        now: () => DateTime.utc(2030),
        openBrowser: (_) => opened.future,
      )..bind(attachment, profile: 'private-profile');
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
        attachment: attachment,
      );
      final old = controller.operations.single;
      final opening = controller.openTarget(
        old,
        'synthetic-connector',
        attachment: attachment,
      );
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 5,
        })!,
        attachment: attachment,
      );
      opened.complete(false);
      await opening;

      expect(controller.operations.single.seq, 5);
      expect(controller.errorFor(old.key), isNull);
    },
  );
  test('missing profile authority keeps session snapshots read-only without retaining browser URLs', () {
    controller.bind(
      attachment,
      respond: (params) => server.client.request('connection.respond', params),
    );
    controller.accept(
      ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
      attachment: attachment,
    );
    final operation = controller.operations.single;
    expect(controller.canRespond(operation.key), isFalse);
    expect(controller.canOpen(operation.key, 'synthetic-connector'), isFalse);
    expect(operation.targets.single.connectUrl, isNull);
  });
  test('telemetry-triggered retirement cannot resume reduction on a cleared operation', () {
    controller.dispose();
    var retire = true;
    controller = ConnectorOperationController(
      now: () => DateTime.utc(2030),
      events: (_, [attributes = const {}]) {
        if (retire) {
          retire = false;
          controller.bind(null);
        }
      },
    );
    controller.bind(
      attachment,
      profile: 'private-profile',
      respond: (params) => server.client.request('connection.respond', params),
    );
    expect(
      () => controller.accept(
        ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
        attachment: attachment,
      ),
      returnsNormally,
    );
    expect(controller.operations, isEmpty);
  });
}

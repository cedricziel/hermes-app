import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/group_room_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import '../group_protocol/groups_repository_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'visible polling backs off idle, stops hidden and resumes at cursor',
    (tester) async {
      var logs = 0;
      final repo = HermesGroupsRepository(
        (method, params) async => switch (method) {
          'groups.capabilities' => fixtures.capabilities(),
          'groups.state' => {'room': fixtures.room()},
          'groups.log' =>
            (++logs > 0) ? {...fixtures.page([], 0), 'latest_seq': 0} : {},
          _ => throw StateError(method),
        },
        interactionContractVerified: true,
      );
      final controller = GroupRoomController(
        repo,
        GroupRoom.fromJson(fixtures.room()),
      );
      controller.setVisible(true);
      await tester.pump();
      expect(logs, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(logs, 2);
      await tester.pump(const Duration(seconds: 4));
      expect(logs, 2);
      controller.setResumed(false);
      await tester.pump(const Duration(seconds: 60));
      expect(logs, 2);
      controller.setResumed(true);
      await tester.pump();
      expect(logs, 3);
      controller.dispose();
      await tester.pump(const Duration(seconds: 60));
      expect(logs, 3);
    },
  );
  test('replay drains pages and hidden stale state cannot overwrite', () async {
    final delayed = Completer<Map<String, Object?>>();
    var stateCalls = 0;
    final cursors = <int>[];
    final repo = HermesGroupsRepository((method, params) async {
      if (method == 'groups.capabilities') return fixtures.capabilities();
      if (method == 'groups.state') {
        if (++stateCalls == 2) return delayed.future;
        return {'room': fixtures.room()};
      }
      cursors.add(params['since_seq'] as int);
      return cursors.length == 1
          ? fixtures.page([fixtures.event(1)], 1, more: true)
          : fixtures.page([fixtures.event(2)], 2);
    });
    final controller = GroupRoomController(
      repo,
      GroupRoom.fromJson(fixtures.room()),
    );
    await controller.refresh();
    expect(cursors, [0, 1]);
    expect(controller.events.length, 2);
    controller.draft = 'Retain this draft';
    final stale = controller.refresh();
    controller.setVisible(false);
    delayed.complete({
      'room': {...fixtures.room(), 'name': 'Stale name'},
    });
    await stale;
    expect(controller.room.name, 'Discussion');
    expect(controller.draft, 'Retain this draft');
    controller.dispose();
  });
  test(
    'ambiguous send reconciles without resend and keeps edited draft',
    () async {
      final sent = Completer<Map<String, Object?>>();
      String? operation;
      var sends = 0;
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return fixtures.capabilities();
        if (method == 'groups.state') return {'room': fixtures.room()};
        if (method == 'groups.send') {
          sends++;
          operation = params['event_id'] as String;
          return sent.future;
        }
        return operation == null
            ? {...fixtures.page([], 0), 'latest_seq': 0}
            : {
                ...fixtures.page([
                  fixtures.event(1, id: serverUserEventId(operation!)),
                ], 1),
                'latest_seq': 1,
              };
      }, interactionContractVerified: true);
      final controller = GroupRoomController(
        repo,
        GroupRoom.fromJson(fixtures.room()),
      );
      await controller.refresh();
      controller.draft = '@unknown hello';
      final sending = controller.send();
      controller.draft = 'New draft';
      sent.completeError(const GatewayConnectionClosed());
      await sending;
      controller.reconnect();
      await controller.refresh();
      expect(sends, 1);
      expect(controller.draft, 'New draft');
      expect(controller.canRetrySend, isFalse);
      controller.dispose();
    },
  );
  test(
    'failed retry reconciliation keeps the original send identity',
    () async {
      String? operationId;
      var sends = 0;
      var failLog = false;
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return fixtures.capabilities();
        if (method == 'groups.state') return {'room': fixtures.room()};
        if (method == 'groups.send') {
          sends++;
          operationId = params['event_id'] as String;
          throw const GatewayConnectionClosed();
        }
        if (method == 'groups.log') {
          if (failLog) throw const GatewayRpcException(500, 'Log unavailable');
          return operationId == null
              ? {...fixtures.page([], 0), 'latest_seq': 0}
              : fixtures.page([
                  fixtures.event(1, id: serverUserEventId(operationId!)),
                ], 1);
        }
        throw StateError(method);
      }, interactionContractVerified: true);
      final controller = GroupRoomController(
        repo,
        GroupRoom.fromJson(fixtures.room()),
      );
      await controller.refresh();
      controller.draft = 'Keep this message';
      failLog = true;
      await controller.send();
      expect(controller.canRetrySend, isTrue);
      await controller.send(retry: true);
      expect(controller.canRetrySend, isTrue);
      expect(sends, 1);
      failLog = false;
      await controller.send(retry: true);
      expect(sends, 1);
      expect(controller.canRetrySend, isFalse);
      expect(controller.draft, isEmpty);
      controller.dispose();
    },
  );

  for (final rotation in [
    (gateway: 'gateway', epoch: 2),
    (gateway: 'replacement-gateway', epoch: 1),
  ]) {
    test(
      'authority ${rotation.gateway}/${rotation.epoch} recovers history and an ambiguous send',
      () async {
        var gateway = 'gateway';
        var epoch = 1;
        var failLog = false;
        String? operationId;
        var sends = 0;
        final cursors = <int>[];
        final repo = HermesGroupsRepository((method, params) async {
          if (method == 'groups.capabilities') return fixtures.capabilities();
          if (method == 'groups.state') {
            return {
              'room': {
                ...fixtures.room(),
                'authority_gateway_id': gateway,
                'authority_epoch': epoch,
              },
            };
          }
          if (method == 'groups.send') {
            sends++;
            operationId = params['event_id'] as String;
            throw const GatewayConnectionClosed();
          }
          if (method == 'groups.log') {
            if (failLog) throw const GatewayConnectionClosed();
            cursors.add(params['since_seq'] as int);
            return {
              ...fixtures.page([
                fixtures.event(1),
                if (operationId != null)
                  fixtures.event(2, id: serverUserEventId(operationId!)),
              ], operationId == null ? 1 : 2),
              'authority': {'gateway_id': gateway, 'epoch': epoch},
            };
          }
          throw StateError(method);
        }, interactionContractVerified: true);
        final controller = GroupRoomController(
          repo,
          GroupRoom.fromJson(fixtures.room()),
        );
        addTearDown(controller.dispose);
        await controller.refresh();
        controller.draft = 'Keep this message';
        failLog = true;
        await controller.send();
        expect(controller.canRetrySend, isTrue);

        gateway = rotation.gateway;
        epoch = rotation.epoch;
        failLog = false;
        await controller.refresh();
        await controller.send(retry: true);

        expect(controller.failure, isNull);
        expect(controller.room.authorityGatewayId, rotation.gateway);
        expect(controller.room.authorityEpoch, rotation.epoch);
        expect(cursors.take(2), [0, 0]);
        expect(controller.events.map((event) => event.eventId), [
          'event-1',
          serverUserEventId(operationId!),
        ]);
        expect(controller.canRetrySend, isFalse);
        expect(controller.draft, isEmpty);
        expect(sends, 1);
      },
    );
  }

  test(
    'topic labels follow first-seen order after replay and rotation',
    () async {
      var epoch = 1;
      var log = [
        {
          ...fixtures.event(1),
          'payload': {'thread_id': 'second'},
        },
        {
          ...fixtures.event(2),
          'payload': {'thread_id': 'first'},
        },
        {
          ...fixtures.event(3),
          'payload': {'thread_id': 'second'},
        },
      ];
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return fixtures.capabilities();
        if (method == 'groups.state') {
          return {
            'room': {...fixtures.room(), 'authority_epoch': epoch},
          };
        }
        if (method == 'groups.log') {
          return {
            ...fixtures.page(log, log.length),
            'latest_seq': log.length,
            'authority': {'gateway_id': 'gateway', 'epoch': epoch},
          };
        }
        throw StateError(method);
      });
      final controller = GroupRoomController(
        repo,
        GroupRoom.fromJson(fixtures.room()),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.labelForThread('second'), 'Topic 1');
      expect(controller.labelForThread('first'), 'Topic 2');
      expect(controller.labelForThread('new'), 'New topic');

      log.add({
        ...fixtures.event(4),
        'payload': {'thread_id': 'new'},
      });
      await controller.refresh();
      expect(controller.labelForThread('second'), 'Topic 1');
      expect(controller.labelForThread('new'), 'Topic 3');

      epoch = 2;
      log = [
        {
          ...fixtures.event(1),
          'payload': {'thread_id': 'first'},
        },
        {
          ...fixtures.event(2),
          'payload': {'thread_id': 'second'},
        },
        {
          ...fixtures.event(3),
          'payload': {'thread_id': 'new'},
        },
        {
          ...fixtures.event(4),
          'payload': {'thread_id': 'first'},
        },
      ];
      await controller.refresh();
      expect(controller.failure, isNull);
      expect(controller.labelForThread('first'), 'Topic 1');
      expect(controller.labelForThread('second'), 'Topic 2');
      expect(controller.labelForThread('new'), 'Topic 3');
    },
  );

  test(
    'stale approval is discarded and cannot be sent after state refresh',
    () async {
      final actionJson = {
        'kind': 'approval',
        'task_id': 'task',
        'member_id': 'one',
        'request_id': 'request',
        'execution_generation': 2,
      };
      var actions = [actionJson];
      var approvalCalls = 0;
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return fixtures.capabilities();
        if (method == 'groups.state') {
          return {
            'room': fixtures.room(),
            'driver_status': {
              'running': true,
              'working': false,
              'blocked': actions.isNotEmpty,
              'counts': {},
              'pending_actions': actions,
              'peer_routes': [],
            },
          };
        }
        if (method == 'groups.approve') {
          approvalCalls++;
          return {'approved': true};
        }
        return {...fixtures.page([], 0), 'latest_seq': 0};
      }, interactionContractVerified: true);
      final controller = GroupRoomController(
        repo,
        GroupRoom.fromJson(fixtures.room()),
      );
      await controller.refresh();
      final stale = controller.state!.pendingActions.single;
      actions = [];
      await controller.approve(stale, GroupApprovalChoice.once);
      expect(approvalCalls, 0);
      expect(controller.state!.pendingActions, isEmpty);
      expect(controller.failure!.kind, GroupFailureKind.stale);
      controller.dispose();
    },
  );
}

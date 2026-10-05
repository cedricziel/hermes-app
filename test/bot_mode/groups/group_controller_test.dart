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

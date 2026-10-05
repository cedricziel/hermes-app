import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

Map<String, Object?> capabilities({bool driver = true}) => {
  'protocol_version': 2,
  'driver': driver,
  'persistent_process': true,
  'authority_gateway_id': 'gateway',
  'features': ['idempotent_send', 'monotonic_log'],
  'methods': HermesGroupsRepository.requiredMethods.toList(),
  'max_log_limit': 2,
};
Map<String, Object?> member(String id) => {
  'member_id': id,
  'profile': id,
  'handle': id,
};
Map<String, Object?> room({String id = 'room'}) => {
  'room_id': id,
  'name': 'Discussion',
  'members': [member('one'), member('two')],
  'authority_gateway_id': 'gateway',
  'authority_epoch': 1,
  'revision': 1,
  'created_at': 1.0,
  'updated_at': 1.0,
  'latest_seq': 0,
};
Map<String, Object?> event(
  int seq, {
  String? id,
  String kind = 'message.user',
}) => {
  'room_id': 'room',
  'seq': seq,
  'event_id': id ?? 'event-$seq',
  'kind': kind,
  'actor': {'kind': 'user', 'id': 'user'},
  'payload': {'text': 'hello'},
  'created_at': 1.0,
};
Map<String, Object?> page(
  List<Map<String, Object?>> events,
  int cursor, {
  bool more = false,
}) => {
  'events': events,
  'cursor': cursor,
  'latest_seq': 2,
  'has_more': more,
  'authority': {'gateway_id': 'gateway', 'epoch': 1},
};
void main() {
  test('protocol, driver, permission and offline distinctions', () async {
    Future<GroupsProbe> probe(Map<String, Object?> data) =>
        HermesGroupsRepository((_, _) async => data).probe();
    expect(
      (await probe(capabilities())).availability,
      GroupsAvailability.ready,
    );
    expect(
      (await probe(capabilities(driver: false))).availability,
      GroupsAvailability.driverUnavailable,
    );
    expect(
      (await probe({...capabilities(), 'protocol_version': 1})).availability,
      GroupsAvailability.unsupported,
    );
    expect(
      (await probe({...capabilities(), 'methods': []})).availability,
      GroupsAvailability.unsupported,
    );
    expect(
      (await probe({...capabilities(), 'features': []})).availability,
      GroupsAvailability.unsupported,
    );
    for (final item in [
      (kGatewayMethodNotFound, GroupsAvailability.unsupported),
      (403, GroupsAvailability.unauthorized),
    ]) {
      final result = await HermesGroupsRepository(
        (_, _) async => throw GatewayRpcException(item.$1, 'no'),
      ).probe();
      expect(result.availability, item.$2);
    }
    expect(
      (await HermesGroupsRepository(
        (_, _) async => throw const GatewayConnectionClosed(),
      ).probe()).availability,
      GroupsAvailability.offline,
    );
  });
  test('strict identities and additive events', () {
    expect(
      () => GroupRoom.fromJson({...room(), 'room_id': 12}),
      throwsFormatException,
    );
    expect(
      () => GroupEvent.fromJson({...event(1), 'seq': '1'}),
      throwsFormatException,
    );
    final unknown = GroupEvent.fromJson(event(1, kind: 'future.kind'));
    expect(unknown.kind, 'future.kind');
    expect(unknown.transcriptText, isNull);
    expect(unknown.payload['text'], 'hello');
  });
  test(
    'requests retain exact operation identities and frozen local roster',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repo = HermesGroupsRepository((method, params) async {
        calls.add((method, params));
        return switch (method) {
          'groups.capabilities' => capabilities(),
          'groups.list' => {
            'rooms': [room()],
            'next_offset': 10,
          },
          'groups.create' || 'groups.rename' => {'room': room()},
          'groups.send' => {
            'event': event(1, id: serverUserEventId('send-id')),
            'client_event_id': 'send-id',
            'accepted': true,
            'driver_started': true,
          },
          'groups.stop' => {'cancelled': 2},
          'groups.disband' => {
            'tombstone': {
              'room_id': 'room',
              'disbanded_at': 2.0,
              'idempotent': false,
            },
          },
          _ => throw StateError(method),
        };
      }, interactionContractVerified: true);
      await repo.probe();
      expect((await repo.list(limit: 10, offset: 0)).nextOffset, 10);
      final members = [
        'one',
        'two',
      ].map((id) => GroupMember.fromJson(member(id))).toList();
      final created = await repo.create(
        name: 'Discussion',
        members: members,
        operationId: 'room',
      );
      expect(() => created.members.clear(), throwsUnsupportedError);
      expect(
        () => repo.create(
          name: 'Bad',
          members: [members.first],
          operationId: 'bad',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.create(
          name: 'Bad',
          members: [members.first, members.first],
          operationId: 'bad',
        ),
        throwsArgumentError,
      );
      await repo.send(
        'room',
        text: 'hello',
        threadId: 'thread',
        operationId: 'send-id',
      );
      expect(calls.last.$2, {
        'room_id': 'room',
        'event_id': 'send-id',
        'payload': {'text': 'hello', 'thread_id': 'thread'},
      });
      await repo.rename('room', name: 'New', operationId: 'rename-id');
      expect(calls.last.$2['event_id'], 'rename-id');
      expect(await repo.stop('room', operationId: 'cancel-id'), 2);
      expect(calls.last.$2['cancel_id'], 'cancel-id');
      expect(
        (await repo.disband('room', operationId: 'disband-id')).roomId,
        'room',
      );
    },
  );
  test(
    'unverified interactive compatibility gates execution, retains reads',
    () async {
      final repo = HermesGroupsRepository(
        (method, _) async =>
            method == 'groups.capabilities' ? capabilities() : {'rooms': []},
      );
      await repo.probe();
      expect(await repo.list(), isA<GroupRoomPage>());
      expect(
        () => repo.send('room', text: 'hi', threadId: 't', operationId: 'id'),
        throwsStateError,
      );
      expect(repo.executionUnavailableReason, contains('clarify'));
    },
  );
  test('unverified execution rejects Allow once but permits Deny', () async {
    final action = GroupPendingAction.fromJson({
      'kind': 'approval',
      'task_id': 'task',
      'member_id': 'one',
      'request_id': 'request',
      'execution_generation': 2,
    });
    final approvals = <Map<String, Object?>>[];
    final repo = HermesGroupsRepository((method, params) async {
      if (method == 'groups.capabilities') return capabilities();
      if (method == 'groups.state') {
        return {
          'room': room(),
          'driver_status': {
            'running': true,
            'working': false,
            'blocked': true,
            'counts': <String, int>{},
            'pending_actions': [
              {
                'kind': 'approval',
                'task_id': 'task',
                'member_id': 'one',
                'request_id': 'request',
                'execution_generation': 2,
              },
            ],
            'peer_routes': <Object>[],
          },
        };
      }
      if (method == 'groups.approve') {
        approvals.add(params);
        return {'approved': true};
      }
      throw StateError(method);
    });
    await repo.probe();
    await expectLater(
      repo.approve('room', action, GroupApprovalChoice.once),
      throwsStateError,
    );
    expect(approvals, isEmpty);
    expect(
      await repo.approve('room', action, GroupApprovalChoice.deny),
      isTrue,
    );
    expect(approvals.single['choice'], 'deny');
  });
  test(
    'multi-page replay deduplicates and reconciles hashed lost receipt',
    () async {
      var reads = 0;
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return capabilities();
        expect(params['limit'], 2);
        return reads++ == 0
            ? page([event(1)], 1, more: true)
            : page([event(1), event(2, id: serverUserEventId('abc'))], 2);
      });
      await repo.probe();
      final replay = GroupReplay(repo, GroupRoom.fromJson(room()));
      expect(await replay.reconcile('abc'), isTrue);
      expect(replay.cursor, 2);
      expect(replay.events.length, 2);
      expect(
        serverUserEventId('abc'),
        'user:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    },
  );
  test(
    'malformed/authority pages are atomic and stale replies ignored',
    () async {
      final response = Completer<Map<String, Object?>>();
      final repo = HermesGroupsRepository((_, _) => response.future);
      final replay = GroupReplay(repo, GroupRoom.fromJson(room()));
      final pending = replay.refresh();
      replay.invalidate();
      response.complete(page([event(1)], 1));
      await pending;
      expect(replay.cursor, 0);
      for (final invalid in [
        page([
          event(1),
          {...event(2), 'room_id': 'elsewhere'},
        ], 2),
        {
          ...page([event(1)], 1),
          'authority': {'gateway_id': 'other', 'epoch': 1},
        },
      ]) {
        final failing = GroupReplay(
          HermesGroupsRepository((_, _) async => invalid),
          GroupRoom.fromJson(room()),
        );
        await expectLater(failing.refresh(), throwsFormatException);
        expect(failing.cursor, 0);
        expect(failing.events, isEmpty);
      }
    },
  );
  test(
    'approvals refresh exact coordinates and refuse stale/retry actions',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      var generation = 1;
      final repo = HermesGroupsRepository((method, params) async {
        calls.add((method, params));
        if (method == 'groups.capabilities') return capabilities();
        if (method == 'groups.approve') return {'approved': true, 'result': {}};
        if (method == 'groups.retry') {
          return {
            'retried': false,
            'task': {
              'room_id': 'room',
              'task_id': 'task',
              'thread_id': 'thread',
              'turn_id': 'turn',
              'status': 'deferred',
              'execution_generation': 1,
              'cancel_generation': 0,
            },
          };
        }
        return {
          'room': room(),
          'driver_status': {
            'running': true,
            'working': false,
            'blocked': true,
            'counts': {},
            'peer_routes': [],
            'pending_actions': [
              {
                'kind': 'approval',
                'member_id': 'one',
                'task_id': 'task',
                'execution_generation': generation,
                'request_id': 'request',
              },
              {'kind': 'retry', 'task_id': 'task'},
            ],
          },
        };
      }, interactionContractVerified: true);
      await repo.probe();
      final state = await repo.state('room');
      final approval = state.pendingActions.first;
      await repo.approve('room', approval, GroupApprovalChoice.once);
      expect(calls.last.$2, {
        'room_id': 'room',
        'member_id': 'one',
        'task_id': 'task',
        'execution_generation': 1,
        'request_id': 'request',
        'choice': 'once',
      });
      generation = 2;
      await expectLater(
        repo.approve('room', approval, GroupApprovalChoice.deny),
        throwsStateError,
      );
      expect(
        (await repo.retry('room', state.pendingActions.last)).retried,
        isFalse,
      );
      await expectLater(
        repo.retry(
          'room',
          GroupPendingAction.fromJson({'kind': 'retry', 'task_id': 'absent'}),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'accepted send with lost receipt reconciles before explicit retry',
    () async {
      var sends = 0;
      final repo = HermesGroupsRepository((method, params) async {
        if (method == 'groups.capabilities') return capabilities();
        if (method == 'groups.send') {
          sends++;
          throw const GatewayConnectionClosed();
        }
        return page([event(1, id: serverUserEventId('lost'))], 1);
      }, interactionContractVerified: true);
      await repo.probe();
      final pending = GroupSendOperation(
        GroupReplay(repo, GroupRoom.fromJson(room())),
        text: 'Hello',
        threadId: 'thread',
        operationId: 'lost',
      );
      await expectLater(
        pending.submit(),
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await expectLater(pending.submit(), throwsStateError);
      expect(await pending.reconcile(), isTrue);
      expect(await pending.submit(), isNull);
      expect(sends, 1);
    },
  );
}

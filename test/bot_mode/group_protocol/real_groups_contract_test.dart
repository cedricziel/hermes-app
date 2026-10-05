import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart' show ProfileCreate;
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

/// Transport-only conformance against a throwaway home. This does not certify
/// clarify/sudo/secret parity; production execution remains gated until those
/// actual profile interactions have a visible backend refusal/action contract.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  test(
    'isolated hosted durable send, reconnect replay, stop and disband',
    () async {
      final dio = Dio(BaseOptions(baseUrl: url!));
      final api = HermesApiClient(dio);
      final sessionToken = await api.fetchSessionToken();
      expect(
        sessionToken,
        isNotNull,
        reason: 'Isolated dashboard session token',
      );
      dio.options.headers['X-Hermes-Session-Token'] = sessionToken;
      final status = await dio.get<Map<String, dynamic>>('/api/status');
      final expectedHome = Directory(
        '${Directory.current.path}/.dart_tool/hermes-dev/home',
      ).absolute.path;
      expect(
        status.data!['hermes_home'],
        expectedHome,
        reason: 'Never mutate a real Hermes home',
      );
      final connect = hermesGatewayConnect(
        baseUrl: url,
        authRequired: false,
        api: api,
      );
      var channel = await connect();
      var rpc = GatewayRpcClient(channel);
      final profiles = <String>[];
      final roomId = groupOperationId();
      GroupRoom? created;
      try {
        var repo = HermesGroupsRepository(
          (method, params) =>
              rpc.request(method, params).timeout(const Duration(seconds: 15)),
          interactionContractVerified: true,
        );
        final probe = await repo.probe();
        expect(probe.availability, GroupsAvailability.ready);
        for (var index = 0; index < 2; index++) {
          final profile =
              'groups-contract-${DateTime.now().microsecondsSinceEpoch}-$index';
          await api.raw.createProfileEndpointApiProfilesPost(
            profileCreate: ProfileCreate(name: profile, noSkills: true),
          );
          profiles.add(profile);
        }
        created = await repo.create(
          name: 'Contract check',
          operationId: roomId,
          members: profiles
              .map(
                (id) => GroupMember.fromJson({
                  'member_id': id,
                  'profile': id,
                  'handle': id,
                }),
              )
              .toList(),
        );
        final operationId = groupOperationId();
        final sent = await repo.send(
          roomId,
          text: 'Transport contract check',
          threadId: 'contract-thread',
          operationId: operationId,
        );
        expect(sent.accepted, isTrue);
        final duplicate = await repo.send(
          roomId,
          text: 'Transport contract check',
          threadId: 'contract-thread',
          operationId: operationId,
        );
        expect(duplicate.event.eventId, sent.event.eventId);
        expect(duplicate.event.seq, sent.event.seq);
        await channel.sink.close();
        channel = await connect();
        rpc = GatewayRpcClient(channel);
        repo = HermesGroupsRepository(
          (method, params) =>
              rpc.request(method, params).timeout(const Duration(seconds: 15)),
          interactionContractVerified: true,
        );
        await repo.probe();
        final replay = GroupReplay(repo, created);
        expect(await replay.reconcile(operationId), isTrue);
        expect(
          replay.events.where((e) => e.eventId == sent.event.eventId).length,
          1,
        );
        final state = await repo.state(roomId);
        expect(state.driverStatus, isNotNull);
        for (final pending in state.pendingActions.where(
          (a) => a.kind == 'approval',
        )) {
          expect(
            await repo.approve(roomId, pending, GroupApprovalChoice.deny),
            isTrue,
          );
        }
        expect(
          await repo.stop(roomId, operationId: groupOperationId()),
          greaterThanOrEqualTo(0),
        );
        final tombstone = await repo.disband(
          roomId,
          operationId: groupOperationId(),
        );
        expect(tombstone.roomId, roomId);
        created = null;
      } finally {
        if (created != null) {
          try {
            await rpc.request('groups.stop', {
              'room_id': roomId,
              'cancel_id': groupOperationId(),
            });
          } on Object {
            /* cleanup is attempted even after contract failure */
          }
        }
        await channel.sink.close();
        for (final profile in profiles) {
          await api.raw.deleteProfileEndpointApiProfilesNameDelete(
            name: profile,
          );
        }
        dio.close();
      }
    },
    skip: url == null
        ? 'Set HERMES_DEV_URL to the isolated dev backend'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

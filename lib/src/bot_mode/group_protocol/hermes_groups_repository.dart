import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../chat/gateway/gateway_rpc_client.dart';

/// Inject the authenticated shared gateway request method, retaining its tracing.
typedef GroupsRpc = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params,
);

String groupOperationId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String serverUserEventId(String operationId) =>
    'user:${sha256.convert(utf8.encode(operationId))}';
Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected object');
  }
  return Map<String, Object?>.from(value);
}

String _string(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _int(Map<String, Object?> data, String key, {int minimum = 0}) {
  final value = data[key];
  if (value is! int || value < minimum) throw FormatException('Invalid $key');
  return value;
}

bool _bool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}

DateTime _time(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid $key');
  }
  return DateTime.fromMillisecondsSinceEpoch(
    (value * 1000).round(),
    isUtc: true,
  );
}

List<Object?> _list(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! List) throw FormatException('Invalid $key');
  return value.cast<Object?>();
}

class GroupMember {
  GroupMember.fromJson(Map<String, Object?> data)
    : memberId = _string(data, 'member_id'),
      profile = _string(data, 'profile'),
      handle = _string(data, 'handle'),
      displayName = data['display_name'] == null
          ? null
          : _string(data, 'display_name'),
      target = data['target'] == null
          ? null
          : Map.unmodifiable(_map(data['target']));
  final String memberId, profile, handle;
  final String? displayName;
  final Map<String, Object?>? target;
  bool get isLocal =>
      target == null ||
      (target!['kind'] == 'local' && target!['profile'] == profile);
  Map<String, Object?> toJson() => {
    'member_id': memberId,
    'profile': profile,
    'handle': handle,
    if (displayName != null) 'display_name': displayName,
  };
}

class GroupRoom {
  GroupRoom.fromJson(Map<String, Object?> data)
    : roomId = _string(data, 'room_id'),
      name = _string(data, 'name'),
      members = List.unmodifiable(
        _list(data, 'members').map((v) => GroupMember.fromJson(_map(v))),
      ),
      authorityGatewayId = _string(data, 'authority_gateway_id'),
      authorityEpoch = _int(data, 'authority_epoch', minimum: 1),
      revision = _int(data, 'revision', minimum: 1),
      createdAt = _time(data, 'created_at'),
      updatedAt = _time(data, 'updated_at'),
      latestSeq = data['latest_seq'] == null ? null : _int(data, 'latest_seq'),
      disbandedAt = data['disbanded_at'] == null
          ? null
          : _time(data, 'disbanded_at');
  final String roomId, name, authorityGatewayId;
  final List<GroupMember> members;
  final int authorityEpoch, revision;
  final int? latestSeq;
  final DateTime createdAt, updatedAt;
  final DateTime? disbandedAt;
}

class GroupEvent {
  GroupEvent.fromJson(Map<String, Object?> data)
    : roomId = _string(data, 'room_id'),
      seq = _int(data, 'seq', minimum: 1),
      eventId = _string(data, 'event_id'),
      kind = _string(data, 'kind'),
      actorKind = _string(_map(data['actor']), 'kind'),
      actorId = _string(_map(data['actor']), 'id'),
      payload = Map.unmodifiable(_map(data['payload'])),
      createdAt = _time(data, 'created_at'),
      authorityEpoch = data['authority_epoch'] == null
          ? null
          : _int(data, 'authority_epoch', minimum: 1);
  final String roomId, eventId, kind, actorKind, actorId;
  final int seq;
  final int? authorityEpoch;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  String? get transcriptText =>
      {'message.user', 'message.assistant'}.contains(kind) &&
          payload['text'] is String
      ? payload['text'] as String
      : null;
}

enum GroupsAvailability {
  ready,
  driverUnavailable,
  unsupported,
  unauthorized,
  offline,
  malformed,
}

class GroupsCapabilities {
  GroupsCapabilities.fromJson(Map<String, Object?> data)
    : protocolVersion = _int(data, 'protocol_version'),
      driver = _bool(data, 'driver'),
      persistentProcess = _bool(data, 'persistent_process'),
      authorityGatewayId = _string(data, 'authority_gateway_id'),
      maxLogLimit = _int(data, 'max_log_limit', minimum: 1),
      features = Set.unmodifiable(
        _list(data, 'features').map((v) => _string({'v': v}, 'v')),
      ),
      methods = Set.unmodifiable(
        _list(data, 'methods').map((v) => _string({'v': v}, 'v')),
      );
  final int protocolVersion, maxLogLimit;
  final bool driver, persistentProcess;
  final String authorityGatewayId;
  final Set<String> features, methods;
  bool get supported =>
      protocolVersion == 2 &&
      methods.containsAll(HermesGroupsRepository.requiredMethods) &&
      features.containsAll({'idempotent_send', 'monotonic_log'});
}

class GroupsProbe {
  const GroupsProbe(this.availability, [this.capabilities]);
  final GroupsAvailability availability;
  final GroupsCapabilities? capabilities;
}

class GroupRoomPage {
  GroupRoomPage.fromJson(Map<String, Object?> data)
    : rooms = List.unmodifiable(
        _list(data, 'rooms').map((v) => GroupRoom.fromJson(_map(v))),
      ),
      nextOffset = data['next_offset'] == null
          ? null
          : _int(data, 'next_offset');
  final List<GroupRoom> rooms;
  final int? nextOffset;
}

class GroupSendReceipt {
  GroupSendReceipt.fromJson(Map<String, Object?> data)
    : event = GroupEvent.fromJson(_map(data['event'])),
      accepted = _bool(data, 'accepted'),
      driverStarted = _bool(data, 'driver_started'),
      clientEventId = data['client_event_id'] == null
          ? null
          : _string(data, 'client_event_id');
  final GroupEvent event;
  final bool accepted, driverStarted;
  final String? clientEventId;
}

class GroupTombstone {
  GroupTombstone.fromJson(Map<String, Object?> data)
    : roomId = _string(data, 'room_id'),
      disbandedAt = _time(data, 'disbanded_at'),
      idempotent = _bool(data, 'idempotent'),
      event = data['event'] == null
          ? null
          : GroupEvent.fromJson(_map(data['event'])),
      historyExpired = data['history_expired'] == null
          ? false
          : _bool(data, 'history_expired');
  final String roomId;
  final DateTime disbandedAt;
  final bool idempotent, historyExpired;
  final GroupEvent? event;
}

class GroupPendingAction {
  GroupPendingAction.fromJson(Map<String, Object?> data)
    : kind = _string(data, 'kind'),
      taskId = _string(data, 'task_id'),
      memberId = data['kind'] == 'approval' ? _string(data, 'member_id') : null,
      requestId = data['kind'] == 'approval'
          ? _string(data, 'request_id')
          : null,
      executionGeneration = data['kind'] == 'approval'
          ? _int(data, 'execution_generation', minimum: 1)
          : null,
      details = Map.unmodifiable(data);
  final Map<String, Object?> details;
  final String kind, taskId;
  final String? memberId, requestId;
  final int? executionGeneration;
  bool matches(GroupPendingAction other) =>
      kind == other.kind &&
      taskId == other.taskId &&
      memberId == other.memberId &&
      requestId == other.requestId &&
      executionGeneration == other.executionGeneration;
}

class GroupState {
  GroupState.fromJson(Map<String, Object?> data)
    : room = GroupRoom.fromJson(_map(data['room'])),
      driverStatus = data['driver_status'] == null
          ? null
          : GroupDriverStatus.fromJson(_map(data['driver_status']));
  final GroupRoom room;
  final GroupDriverStatus? driverStatus;
  List<GroupPendingAction> get pendingActions =>
      driverStatus?.pendingActions ?? const [];
}

class GroupDriverStatus {
  GroupDriverStatus.fromJson(Map<String, Object?> data)
    : running = _bool(data, 'running'),
      working = _bool(data, 'working'),
      blocked = _bool(data, 'blocked'),
      counts = Map.unmodifiable(
        _map(data['counts'])
            .map((key, value) => MapEntry(key, _int({'v': value}, 'v'))),
      ),
      pendingActions = List.unmodifiable(
        _list(
          data,
          'pending_actions',
        ).map((v) => GroupPendingAction.fromJson(_map(v))),
      ),
      peerRoutes = List.unmodifiable(
        _list(
          data,
          'peer_routes',
        ).map((v) => Map<String, Object?>.unmodifiable(_map(v))),
      );
  final bool running, working, blocked;
  final Map<String, int> counts;
  final List<GroupPendingAction> pendingActions;
  final List<Map<String, Object?>> peerRoutes;
}

enum GroupApprovalChoice { once, deny }

class GroupTaskReceipt {
  GroupTaskReceipt.fromJson(Map<String, Object?> data)
    : roomId = _string(data, 'room_id'),
      taskId = _string(data, 'task_id'),
      threadId = _string(data, 'thread_id'),
      turnId = _string(data, 'turn_id'),
      status = _string(data, 'status'),
      executionGeneration = _int(data, 'execution_generation'),
      cancelGeneration = _int(data, 'cancel_generation');
  final String roomId, taskId, threadId, turnId, status;
  final int executionGeneration, cancelGeneration;
}

class GroupRetryReceipt {
  GroupRetryReceipt.fromJson(Map<String, Object?> data)
    : retried = _bool(data, 'retried'),
      task = GroupTaskReceipt.fromJson(_map(data['task']));
  final bool retried;
  final GroupTaskReceipt task;
}

class HermesGroupsRepository {
  HermesGroupsRepository(this._request);
  final GroupsRpc _request;
  GroupsProbe? _probe;
  static const requiredMethods = {
    'groups.list',
    'groups.create',
    'groups.send',
    'groups.rename',
    'groups.stop',
    'groups.disband',
    'groups.log',
    'groups.state',
    'groups.approve',
    'groups.retry',
  };
  String? get executionUnavailableReason {
    if (_probe?.availability != GroupsAvailability.ready) {
      return 'Hosted group execution requires protocol 2 and a ready server driver.';
    }
    return null;
  }

  void _execution() {
    final reason = executionUnavailableReason;
    if (reason != null) throw StateError(reason);
  }

  Future<GroupsProbe> probe() async {
    try {
      final capabilities = GroupsCapabilities.fromJson(
        await _request('groups.capabilities', {}),
      );
      return _probe = GroupsProbe(
        !capabilities.supported
            ? GroupsAvailability.unsupported
            : !capabilities.driver
            ? GroupsAvailability.driverUnavailable
            : GroupsAvailability.ready,
        capabilities,
      );
    } on GatewayRpcException catch (error) {
      return _probe = GroupsProbe(
        error.code == kGatewayMethodNotFound
            ? GroupsAvailability.unsupported
            : {401, 403, 4401, 4403}.contains(error.code)
            ? GroupsAvailability.unauthorized
            : GroupsAvailability.offline,
      );
    } on FormatException {
      return _probe = const GroupsProbe(GroupsAvailability.malformed);
    } on Object {
      return _probe = const GroupsProbe(GroupsAvailability.offline);
    }
  }

  Future<GroupRoomPage> list({int? limit, int? offset}) async =>
      GroupRoomPage.fromJson(
        await _request('groups.list', {'limit': ?limit, 'offset': ?offset}),
      );
  Future<GroupRoom> create({
    required String name,
    required List<GroupMember> members,
    required String operationId,
  }) {
    _execution();
    if (members.length < 2 ||
        members.length > 6 ||
        members.any((v) => !v.isLocal) ||
        ['memberId', 'profile', 'handle'].any(
          (field) =>
              members
                  .map(
                    (v) => (switch (field) {
                      'memberId' => v.memberId,
                      'profile' => v.profile,
                      _ => v.handle,
                    }).toLowerCase(),
                  )
                  .toSet()
                  .length !=
              members.length,
        ) ||
        members.any(
          (v) => {'all', 'everyone'}.contains(v.handle.toLowerCase()),
        )) {
      throw ArgumentError(
        'A frozen roster needs 2–6 unique local members and handles.',
      );
    }
    _string({'id': operationId}, 'id');
    _string({'name': name}, 'name');
    return _request('groups.create', {
      'room_id': operationId,
      'name': name,
      'members': members.map((v) => v.toJson()).toList(),
    }).then((data) => GroupRoom.fromJson(_map(data['room'])));
  }

  Future<GroupSendReceipt> send(
    String roomId, {
    required String text,
    required String threadId,
    required String operationId,
  }) {
    _execution();
    for (final value in [roomId, text, threadId, operationId]) {
      _string({'v': value}, 'v');
    }
    return _request('groups.send', {
      'room_id': roomId,
      'event_id': operationId,
      'payload': {'text': text, 'thread_id': threadId},
    }).then((data) {
      final receipt = GroupSendReceipt.fromJson(data);
      if (receipt.event.roomId != roomId ||
          receipt.event.eventId != serverUserEventId(operationId) ||
          (receipt.clientEventId != null &&
              receipt.clientEventId != operationId)) {
        throw const FormatException('Send receipt identity changed');
      }
      return receipt;
    });
  }

  Future<GroupRoom> rename(
    String roomId, {
    required String name,
    required String operationId,
  }) async => GroupRoom.fromJson(
    _map(
      (await _request('groups.rename', {
        'room_id': roomId,
        'name': name,
        'event_id': operationId,
      }))['room'],
    ),
  );
  Future<int> stop(String roomId, {required String operationId}) async => _int(
    await _request('groups.stop', {
      'room_id': roomId,
      'cancel_id': operationId,
    }),
    'cancelled',
  );
  Future<GroupTombstone> disband(
    String roomId, {
    required String operationId,
  }) async => GroupTombstone.fromJson(
    _map(
      (await _request('groups.disband', {
        'room_id': roomId,
        'cancel_id': operationId,
      }))['tombstone'],
    ),
  );
  Future<GroupState> state(String roomId) async {
    final result = GroupState.fromJson(
      await _request('groups.state', {'room_id': roomId}),
    );
    if (result.room.roomId != roomId) {
      throw const FormatException('State room identity changed');
    }
    return result;
  }

  Future<Map<String, Object?>> log(String roomId, int cursor) =>
      _request('groups.log', {
        'room_id': roomId,
        'since_seq': cursor,
        'limit': min(100, _probe?.capabilities?.maxLogLimit ?? 100),
      });
  Future<bool> approve(
    String roomId,
    GroupPendingAction action,
    GroupApprovalChoice choice,
  ) async {
    if (choice == GroupApprovalChoice.once) _execution();
    if (action.kind != 'approval' ||
        !(await state(roomId)).pendingActions.any(action.matches)) {
      throw StateError('Approval is no longer pending');
    }
    return _bool(
      await _request('groups.approve', {
        'room_id': roomId,
        'member_id': action.memberId,
        'task_id': action.taskId,
        'execution_generation': action.executionGeneration,
        'request_id': action.requestId,
        'choice': choice.name,
      }),
      'approved',
    );
  }

  Future<GroupRetryReceipt> retry(
    String roomId,
    GroupPendingAction action,
  ) async {
    _execution();
    if (action.kind != 'retry' ||
        !(await state(roomId)).pendingActions.any(action.matches)) {
      throw StateError('Task has no advertised retry action');
    }
    final result = GroupRetryReceipt.fromJson(
      await _request('groups.retry', {
        'room_id': roomId,
        'task_id': action.taskId,
      }),
    );
    if (result.task.roomId != roomId || result.task.taskId != action.taskId) {
      throw const FormatException('Retry receipt identity changed');
    }
    return result;
  }
}

/// One mounted room's incorporated cursor. The UI invalidates on room/server change.
class GroupReplay {
  GroupReplay(this.repository, this.room);
  final HermesGroupsRepository repository;
  final GroupRoom room;
  final _events = <int, GroupEvent>{};
  final _ids = <String, int>{};
  int cursor = 0;
  int _generation = 0;
  Future<void>? _refreshing;
  List<GroupEvent> get events => List.unmodifiable(_events.values);
  void invalidate() => _generation++;
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    final generation = _generation;
    while (true) {
      final data = await repository.log(room.roomId, cursor);
      if (generation != _generation) return;
      final authority = _map(data['authority']);
      if (_string(authority, 'gateway_id') != room.authorityGatewayId ||
          _int(authority, 'epoch', minimum: 1) != room.authorityEpoch) {
        throw const FormatException(
          'Room authority changed; refresh room state',
        );
      }
      final pageCursor = _int(data, 'cursor');
      final latest = _int(data, 'latest_seq');
      final more = _bool(data, 'has_more');
      final parsed = _list(
        data,
        'events',
      ).map((v) => GroupEvent.fromJson(_map(v))).toList();
      final additions = <int, GroupEvent>{};
      final addedIds = <String, int>{};
      var lastSeq = 0;
      for (final event in parsed) {
        if (event.roomId != room.roomId ||
            (event.authorityEpoch != null &&
                event.authorityEpoch != room.authorityEpoch) ||
            event.seq > pageCursor ||
            event.seq < lastSeq) {
          throw const FormatException('Malformed room log identity');
        }
        lastSeq = event.seq;
        final existing = _events[event.seq] ?? additions[event.seq];
        final existingSeq = _ids[event.eventId] ?? addedIds[event.eventId];
        if ((existing != null && existing.eventId != event.eventId) ||
            (existingSeq != null && existingSeq != event.seq)) {
          throw const FormatException('Conflicting event identity');
        }
        if (existing == null) {
          additions[event.seq] = event;
          addedIds[event.eventId] = event.seq;
        }
      }
      if (pageCursor < cursor ||
          pageCursor > latest ||
          (more && pageCursor <= cursor) ||
          (pageCursor > cursor &&
              (parsed.isEmpty || parsed.last.seq != pageCursor))) {
        throw const FormatException('Invalid room log cursor');
      }
      _events.addAll(additions);
      _ids.addAll(addedIds);
      cursor = pageCursor;
      if (!more) return;
    }
  }

  /// A lost send receipt is resolved before the UI offers retry with the same ID.
  Future<bool> reconcile(String operationId) async {
    await refresh();
    return _ids.containsKey(serverUserEventId(operationId));
  }
}

/// Retains one message identity through an ambiguous acknowledgement. A caller
/// must reconcile the log before offering an explicit retry.
class GroupSendOperation {
  GroupSendOperation(
    this.replay, {
    required this.text,
    required this.threadId,
    String? operationId,
  }) : operationId = operationId ?? groupOperationId();
  final GroupReplay replay;
  final String text, threadId, operationId;
  bool accepted = false;
  bool _ambiguous = false;
  bool _reconciled = false;
  Future<GroupSendReceipt?> submit() async {
    if (accepted) return null;
    if (_ambiguous && !_reconciled) {
      throw StateError('Reconcile the room log before retrying this message');
    }
    _reconciled = false;
    try {
      final receipt = await replay.repository.send(
        replay.room.roomId,
        text: text,
        threadId: threadId,
        operationId: operationId,
      );
      accepted = receipt.accepted;
      _ambiguous = false;
      return receipt;
    } on GatewayConnectionClosed {
      _ambiguous = true;
      rethrow;
    } on TimeoutException {
      _ambiguous = true;
      rethrow;
    }
  }

  Future<bool> reconcile() async {
    accepted = await replay.reconcile(operationId);
    _reconciled = true;
    return accepted;
  }
}

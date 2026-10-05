import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../chat/gateway/gateway_rpc_client.dart';
import '../group_protocol/hermes_groups_repository.dart';

enum GroupFailureKind {
  offline,
  permission,
  stale,
  invalid,
  unavailable,
  server,
}

class GroupFailure {
  const GroupFailure(this.kind, this.message);
  final GroupFailureKind kind;
  final String message;
  factory GroupFailure.from(Object error) {
    if (error is GatewayConnectionClosed || error is TimeoutException) {
      return const GroupFailure(
        GroupFailureKind.offline,
        'Connection lost. History and your draft are retained. Reconnect to check the server result.',
      );
    }
    if (error is GatewayRpcException &&
        {401, 403, 4401, 4403}.contains(error.code)) {
      return const GroupFailure(
        GroupFailureKind.permission,
        'The server did not permit this group action.',
      );
    }
    if (error is FormatException) {
      return const GroupFailure(
        GroupFailureKind.invalid,
        'The server returned an incompatible group response.',
      );
    }
    if (error is StateError) {
      final message = error.message.toString();
      return GroupFailure(
        message.startsWith('Hosted group')
            ? GroupFailureKind.unavailable
            : GroupFailureKind.stale,
        message,
      );
    }
    return const GroupFailure(
      GroupFailureKind.server,
      'The group action failed. Refresh to check its current state.',
    );
  }
}

/// One mounted room. Polling belongs to foreground visibility; the server owns
/// every member turn. Reconnection only replays and never resubmits a prompt.
class GroupRoomController extends ChangeNotifier {
  GroupRoomController(this.repository, this.room)
    : replay = GroupReplay(repository, room);
  final HermesGroupsRepository repository;
  final GroupReplay replay;
  GroupRoom room;
  GroupState? state;
  GroupFailure? failure;
  bool pending = false, loading = false, disbanded = false;
  bool _visible = false,
      _resumed = true,
      _disposed = false,
      _probeNeeded = true;
  int _generation = 0, _idle = 0;
  Timer? _timer;
  Future<void>? _refreshing;
  bool _refreshAgain = false;
  String _draft = '', _threadId = groupOperationId();
  GroupSendOperation? _send;
  List<GroupEvent> get events => replay.events;
  String get draft => _draft;
  set draft(String value) {
    _draft = value;
    _notify();
  }

  String get threadId => _threadId;
  String labelForThread(String id) {
    final ids = events
        .map((event) => event.payload['thread_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final index = ids.indexOf(id);
    return index < 0 ? 'New topic' : 'Topic ${index + 1}';
  }

  String get discussionLabel => labelForThread(_threadId);
  bool get active => _visible && _resumed && !_disposed && !disbanded;
  bool get canRetrySend => _send != null && !pending;
  String? get unavailableReason => repository.executionUnavailableReason;
  List<GroupMember> get mentionMembers {
    final handles = <String, int>{};
    for (final member in room.members) {
      handles.update(
        member.handle.toLowerCase(),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    return room.members
        .where(
          (m) =>
              handles[m.handle.toLowerCase()] == 1 &&
              !{'all', 'everyone'}.contains(m.handle.toLowerCase()),
        )
        .toList();
  }

  void replyTo(GroupEvent event) {
    final thread = event.payload['thread_id'];
    if (thread is String && thread.isNotEmpty) {
      _threadId = thread;
      _notify();
    }
  }

  void newTopic() {
    _threadId = groupOperationId();
    _notify();
  }

  void setVisible(bool value) {
    _visible = value;
    _activityChanged();
  }

  void setResumed(bool value) {
    _resumed = value;
    if (value) _probeNeeded = true;
    _activityChanged();
  }

  void reconnect() {
    _probeNeeded = true;
    if (active) unawaited(refresh());
  }

  void _activityChanged() {
    _timer?.cancel();
    if (!active) {
      _generation++;
      replay.invalidate();
      return;
    }
    _idle = 0;
    if (_refreshing != null) _refreshAgain = true;
    unawaited(refresh());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() {
    if (_disposed || disbanded) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() {
      _refreshing = null;
      if (_refreshAgain && active) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final previousCursor = replay.cursor;
    loading = state == null;
    _notify();
    try {
      if (_probeNeeded) {
        final probe = await repository.probe();
        if (_disposed || generation != _generation) return;
        _probeNeeded = probe.availability != GroupsAvailability.ready;
      }
      final latest = await repository.state(room.roomId);
      if (_disposed || generation != _generation || disbanded) return;
      if (latest.room.disbandedAt != null) {
        _tombstone();
        return;
      }
      await replay.refresh();
      if (_disposed || generation != _generation || disbanded) return;
      room = latest.room;
      state = latest;
      if (events.any((event) => event.kind == 'room.disbanded')) {
        _tombstone();
        return;
      }
      failure = null;
      _idle = replay.cursor == previousCursor ? (_idle + 1).clamp(0, 4) : 0;
    } on Object catch (error) {
      if (!_disposed && generation == _generation) {
        failure = GroupFailure.from(error);
      }
      _probeNeeded = true;
      _idle = (_idle + 1).clamp(0, 4);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
        _schedule();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!active) return;
    final work = state?.driverStatus;
    final seconds = work?.working == true || work?.blocked == true
        ? 2
        : (2 << _idle).clamp(2, 30);
    _timer = Timer(Duration(seconds: seconds), () => unawaited(refresh()));
  }

  Future<void> send({bool retry = false}) async {
    if (pending || disbanded || _disposed) return;
    if (_send != null && !retry) return;
    if (_send == null && _draft.trim().isEmpty) return;
    final operation = _send ??= GroupSendOperation(
      replay,
      text: _draft,
      threadId: _threadId,
    );
    pending = true;
    failure = null;
    _notify();
    try {
      if (retry) await operation.reconcile();
      if (!operation.accepted) await operation.submit();
      if (!operation.accepted) {
        throw StateError('The server has not accepted this message.');
      }
      _sent(operation);
      await refresh();
    } on GatewayConnectionClosed catch (error) {
      await _reconcile(operation, error);
    } on TimeoutException catch (error) {
      await _reconcile(operation, error);
    } on Object catch (error) {
      failure = GroupFailure.from(error);
    } finally {
      pending = false;
      _notify();
    }
  }

  Future<void> _reconcile(GroupSendOperation operation, Object error) async {
    if (_disposed || disbanded) return;
    try {
      if (await operation.reconcile()) {
        _sent(operation);
        return;
      }
    } on Object {
      /* Keep the operation for an explicit, reconciled retry. */
    }
    failure = GroupFailure.from(error);
  }

  void _sent(GroupSendOperation operation) {
    if (_draft == operation.text) _draft = '';
    _send = null;
  }

  Future<void> _action(Future<void> Function() perform) async {
    if (pending || disbanded || _disposed) return;
    pending = true;
    failure = null;
    _notify();
    try {
      await perform();
      await refresh();
    } on Object catch (error) {
      // Refresh discards approval coordinates that another client consumed.
      await refresh();
      failure = GroupFailure.from(error);
    } finally {
      pending = false;
      _notify();
    }
  }

  Future<void> stop() => _action(() async {
    await repository.stop(room.roomId, operationId: groupOperationId());
  });
  Future<void> approve(GroupPendingAction action, GroupApprovalChoice choice) =>
      _action(() async {
        await repository.approve(room.roomId, action, choice);
      });
  Future<void> retryTask(GroupPendingAction action) => _action(() async {
    await repository.retry(room.roomId, action);
  });
  Future<void> rename(String name) => _action(() async {
    room = await repository.rename(
      room.roomId,
      name: name.trim(),
      operationId: groupOperationId(),
    );
  });
  Future<void> disband() => _action(() async {
    await repository.disband(room.roomId, operationId: groupOperationId());
    _tombstone();
  });
  void _tombstone() {
    disbanded = true;
    _generation++;
    replay.invalidate();
    _timer?.cancel();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    replay.invalidate();
    _timer?.cancel();
    super.dispose();
  }
}

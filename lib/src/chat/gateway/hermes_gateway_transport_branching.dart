part of 'hermes_gateway_transport.dart';

/// Stopping, undoing and branching turns.
extension _Branching on HermesGatewayTransport {
  Future<bool> _stopReply(String threadId, {String? profile}) async {
    var owner = (profile, threadId);
    var runtimeId = _runtimeOf[owner];
    if (runtimeId == null && profile == null) {
      final matches = _runtimeOf.entries
          .where((entry) => entry.key.$2 == threadId)
          .toList();
      if (matches.length == 1) {
        owner = matches.single.key;
        runtimeId = matches.single.value;
      }
    }
    // A reply that lost its connection may still be running on the server;
    // its runtime session belonged to the connection that was lost, so the
    // thread is resumed first.
    final lost = runtimeId == null && _lostReplies.containsKey(owner);
    runtimeId ??= _lostReplies[owner];
    if (runtimeId == null) return false;
    final lostRuntime = runtimeId;
    var client = lost ? null : _connected();
    var resolved = false;
    if (client == null) {
      // The listener may still be reconnecting after a dropped socket. Ask
      // the server which runtime session owns this stored thread before
      // concluding that the reply has already ended.
      client = await _client();
      final resumed = await _resumeForStop(
        client,
        owner,
        threadId,
        lostRuntime,
      );
      if (resumed['running'] != true && !_continued(resumed)) return false;
      runtimeId = resumed['session_id'] as String? ?? threadId;
      resolved = true;
    }
    final live = client;
    Future<Map<String, Object?>> interrupt(String id) =>
        _call(live, 'session.interrupt', {'session_id': id});
    try {
      final result = await interrupt(runtimeId);
      return result['status'] == 'interrupted';
    } on GatewayRpcException catch (error) {
      if (error.code != _sessionNotFound) rethrow;
      if (resolved) {
        throw GatewaySessionGone(
          error.code,
          restarted: _restartedSince(live, lostRuntime),
        );
      }
      // 4001: the runtime session this app held is gone (reaped, or the server
      // restarted). Ask which runtime session the stored thread is on now: a
      // turn that runs there, or that Hermes re-runs by itself after a restart
      // (`auto_continue`), is the one to stop.
      final resumed = await _resumeForStop(live, owner, threadId, lostRuntime);
      if (resumed['running'] != true && !_continued(resumed)) {
        // Nothing runs: a restart took the turn with it, or it finished and
        // was reaped (then there is nothing to stop, and the reply is read).
        if (_restartedSince(live, lostRuntime)) {
          throw GatewaySessionGone(error.code, restarted: true);
        }
        return false;
      }
      try {
        final result = await interrupt(
          resumed['session_id'] as String? ?? threadId,
        );
        return result['status'] == 'interrupted';
      } on GatewayRpcException catch (again) {
        if (again.code != _sessionNotFound) rethrow;
        throw GatewaySessionGone(
          again.code,
          restarted: _restartedSince(live, lostRuntime),
        );
      }
    }
  }

  /// Whether a `session.resume` answer says Hermes re-runs the interrupted turn
  /// by itself.
  bool _continued(Map<String, Object?> resumed) =>
      resumed['auto_continue'] != null && resumed['auto_continue'] != false;

  /// The `session.resume` a stop makes to find the runtime session of the
  /// thread. A final refusal is an answer to the stop: the reply is not on the
  /// server.
  Future<Map<String, Object?>> _resumeForStop(
    GatewayRpcClient client,
    _ThreadOwner owner,
    String threadId,
    String lostRuntime,
  ) async {
    try {
      return await _call(client, 'session.resume', {
        'session_id': threadId,
        'profile': ?owner.$1,
        'source': gatewaySessionSource,
      });
    } on GatewayRpcException catch (error) {
      if (isFinalResumeRefusal(error)) {
        throw GatewaySessionGone(
          error.code,
          restarted: _restartedSince(client, lostRuntime),
        );
      }
      rethrow;
    }
  }

  Future<int?> _undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) async {
    final client = await _client();
    final runtimeId = await _commandRuntime(client, threadId, profile);
    Future<int> undo({required bool withIntent}) async {
      final result = await _call(client, 'session.undo', {
        'session_id': runtimeId,
        if (withIntent) 'intent': retry ? 'retry' : 'undo',
      });
      return (result['removed'] as num?)?.toInt() ?? 0;
    }

    try {
      return await undo(withIntent: true);
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) return null;
      // A gateway older than `intent` rejects the field; it undoes the same
      // turn without it.
      if (error.code == kGatewayInvalidParams &&
          error.message.contains('intent')) {
        return undo(withIntent: false);
      }
      rethrow;
    }
  }

  Future<BranchedThread?> _branchThread(
    String threadId, {
    String? profile,
    int dropTurns = 0,
  }) async {
    final client = await _client();
    final runtimeId = await _commandRuntime(client, threadId, profile);
    Map<String, Object?>? result;
    // `session.branch_whole` does not send the copied transcript back; a
    // gateway older than it has `session.branch` only.
    for (final method in const ['session.branch_whole', 'session.branch']) {
      try {
        result = await _call(client, method, {'session_id': runtimeId});
        break;
      } on GatewayRpcException catch (error) {
        if (error.code != kGatewayMethodNotFound) rethrow;
      }
    }
    if (result == null) return null;
    final storedId = result['stored_session_id'];
    final branchRuntime = result['session_id'];
    if (storedId is! String || storedId.isEmpty || branchRuntime is! String) {
      throw const FormatException('session.branch answered without an id');
    }
    final branch = BranchedThread(storedId);
    // Hermes branches a whole conversation (its `count` counts rows the app
    // cannot tell apart); the branch is cut back a prompt at a time, by the
    // same rule that takes back a turn for Try again.
    try {
      for (var turn = 0; turn < dropTurns; turn++) {
        final Map<String, Object?> undone;
        try {
          undone = await _call(client, 'session.undo', {
            'session_id': branchRuntime,
          });
        } on Object catch (error) {
          throw BranchIncomplete(branch, error);
        }
        // Fewer prompts than counted: the copy no longer ends where asked.
        if (((undone['removed'] as num?)?.toInt() ?? 0) == 0) {
          throw BranchIncomplete(
            branch,
            StateError('nothing left to take back'),
          );
        }
      }
    } finally {
      // Nothing here follows the copy's live session; opening the branch
      // resumes it from its stored row.
      unawaited(
        _call(client, 'session.close', {
          'session_id': branchRuntime,
        }).then((_) {}, onError: (Object _) {}),
      );
    }
    return branch;
  }
}

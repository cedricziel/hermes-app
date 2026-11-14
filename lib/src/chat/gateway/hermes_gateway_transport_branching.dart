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
    if (runtimeId == null) return false;
    var client = _connected();
    if (client == null) {
      // The listener may still be reconnecting after a dropped socket. Ask
      // the server which runtime session owns this stored thread before
      // concluding that the reply has already ended.
      client = await _client();
      final resumed = await _call(client, 'session.resume', {
        'session_id': threadId,
        'profile': ?owner.$1,
        'source': gatewaySessionSource,
      });
      if (resumed['running'] != true) return false;
      runtimeId = resumed['session_id'] as String? ?? threadId;
    }
    final result = await _call(client, 'session.interrupt', {
      'session_id': runtimeId,
    });
    return result['status'] == 'interrupted';
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

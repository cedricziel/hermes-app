part of 'hermes_gateway_transport.dart';

/// Turn bookkeeping: telemetry, the silence probe, model switch, re-keying.
extension _Turns on HermesGatewayTransport {
  /// Logs the event [name], and never lets the logger break the transport.
  void _record(String name, Map<String, Object> attributes) {
    try {
      _events(name, attributes);
    } on Object {
      // Telemetry must not take a reply down with it.
    }
  }

  /// Logs that a reply ended: [via] is what ended it. A completion is the
  /// normal end; an idle report is one the reply settled on without a
  /// completion, and [errored] says an `error` event came before it.
  void _turnSettled(ChatEvent ended, {required bool errored}) =>
      _record('gateway.turn_settled', {
        'via': ended is ReplyCompleted
            ? 'complete'
            : errored
            ? 'error_event'
            : 'session_info',
      });

  /// Logs the end of a turn that finished while the app was disconnected, from
  /// the [events] the reconnect handed over: its completion, or the idle report
  /// that stands in for one. Nothing is logged when they hold neither.
  ///
  /// [events] are what the reply was shown, and the reply settles on either
  /// kind whatever the grace of [settles] says: that grace only guards a
  /// stale report on a live connection, before the reply is shown anything.
  /// [errored] is set when the reply saw an `error` event before the drop.
  void _reportSettled(Iterable<ChatEvent> events, {bool errored = false}) {
    ChatEvent? ending;
    for (final event in events) {
      errored = errored || event is ReplyErrored;
      if (event is ReplyCompleted ||
          event is SessionInfo && event.running == false) {
        ending = event;
      }
    }
    if (ending != null) _turnSettled(ending, errored: errored);
  }

  /// Logs that Hermes sent a frame of type [type] that the app shows nothing
  /// for, once per type on the connection. Only the type is logged. [on] is
  /// the connection's record, when the caller holds it.
  void _reportUnmapped(
    String type, {
    bool serverRequest = false,
    UnmappedEvents? on,
  }) {
    final reported = (on ?? _unmapped).admit(type);
    if (reported == null) return;
    _record('gateway.event_unmapped', {
      'event.type': reported,
      if (serverRequest) 'server_request': true,
    });
  }

  /// Moves the session [runtimeId] from [previous] to [next], sending only
  /// what changed. Both are scoped to the session, never written to the
  /// profile's config: `--session` says so for the model, and without it
  /// Hermes refuses the unnamed `custom` provider. The user picked [next]
  /// themselves, so a model Hermes would ask to confirm as expensive is
  /// confirmed.
  Future<void> _switchModel(
    GatewayRpcClient client,
    String runtimeId,
    ModelChoice? previous,
    ModelChoice next,
  ) async {
    if (previous == null || !previous.sameModel(next)) {
      await _call(client, 'config.set', {
        'session_id': runtimeId,
        'key': 'model',
        'value': '${next.modelId} --provider ${next.providerId} --session',
        'confirm_expensive_model': true,
      });
    }
    final effort = next.effort;
    if (effort != null && effort != previous?.effort) {
      await _call(client, 'config.set', {
        'session_id': runtimeId,
        'key': 'reasoning',
        'value': effort,
      });
    }
  }

  /// Moves what is kept for the thread [from] to [to], after compression gave
  /// the thread a new stored id: the runtime session of its reply, its model,
  /// and the watch parked for its follow-ups.
  void _rekey(_ThreadOwner from, _ThreadOwner to) {
    if (from == to) return;
    if (_ownedBindings.remove(from) case final binding?) {
      _ownedBindings[to] = binding;
    }
    if (_runtimeOf.remove(from) case final runtimeId?) {
      _runtimeOf[to] = runtimeId;
    }
    if (_modelOf.remove(from) case final model?) _modelOf[to] = model;
    if (_settledEarly.remove(from)) _settledEarly.add(to);
    if (_idle.remove(from) case final watch?) {
      final displaced = _idle[to];
      _idle[to] = watch;
      if (displaced != null) unawaited(displaced.close());
    }
  }

  /// Whether the server still lists [storedId] as running. An answer that
  /// cannot be read counts as running: a refused `session.active_list` says
  /// nothing about the turn, and a dead socket ends its watch on its own, which
  /// sends the reply down the reconnect path.
  Future<bool> _stillRunning(GatewayRpcClient client, String storedId) async {
    try {
      final statuses = _statusesOf(
        await _call(client, 'session.active_list', {}),
      );
      final status = statuses[storedId];
      return status != null && _liveStatuses.contains(status);
    } on GatewayRpcException {
      return true;
    } on GatewayConnectionClosed {
      return true;
    }
  }

  /// Waits for the next frame of [watch], and is false once the watch ended.
  ///
  /// A reply silent for [silenceProbe] is asked about: only the server can say
  /// whether the turn still runs, so it is given up on (as broken) only when
  /// the server no longer lists [storedId] as running.
  Future<bool> _advance(_Watch watch, String storedId) async {
    final pending = watch.events.moveNext();
    while (true) {
      try {
        return await pending.timeout(silenceProbe);
      } on TimeoutException {
        if (await _stillRunning(watch.client, storedId)) continue;
        _record('gateway.turn_settled', {'via': 'silence_probe'});
        throw const GatewayConnectionClosed();
      }
    }
  }

  void _beginReply(String runtimeId, _ThreadOwner owner) {
    _replying.update(runtimeId, (count) => count + 1, ifAbsent: () => 1);
    _runtimeOf[owner] = runtimeId;
  }

  void _endReply(String runtimeId, _ThreadOwner owner) {
    _replying.update(runtimeId, (count) => count - 1);
    if (_replying[runtimeId] == 0) {
      _replying.remove(runtimeId);
      if (_runtimeOf[owner] == runtimeId) _runtimeOf.remove(owner);
    }
  }
}

/// The stored id the thread was given while the app was disconnected: the
/// last one a `session.info` of [ended] reports other than [current]. The
/// events of a turn that ended meanwhile are only shown, never read by the
/// loop that follows a live turn, so the rotation is found here.
String? _rotatedIn(Iterable<_Incoming> ended, String current) {
  String? rotated;
  for (final (event, _) in ended) {
    if (event is SessionInfo) {
      final id = event.storedSessionId;
      if (id != null && id.isNotEmpty) rotated = id;
    }
  }
  return rotated == current ? null : rotated;
}

part of 'hermes_gateway_transport.dart';

/// Follow-up turns: parked watches, picking a running turn up, and the relay.
extension _FollowUps on HermesGatewayTransport {
  Stream<ChatEvent> _followUps(String threadId, {String? profile}) {
    final owner = (profile, threadId);
    var watch = _idle[owner];
    if (watch != null && watch.isDead) {
      // The socket closed while the thread was idle and everything the watch
      // held was read: nothing arrives on it any more, so the thread is
      // picked up on a fresh one.
      unawaited(_idle.remove(owner)?.close());
      watch = null;
    }
    if (watch != null) {
      final follow = _Follow(watch);
      final out = StreamController<ChatEvent>();
      out.onListen = () => unawaited(_relay(follow, owner, out));
      out.onCancel = () => _stopFollowing(follow);
      return out.stream;
    }
    // A turn may have started in another client without a local watcher.
    final out = StreamController<ChatEvent>();
    out.onListen = () => unawaited(_pickUp(owner, out));
    return out.stream;
  }

  /// Keeps [watch] as the listener of [owner]'s session between turns.
  Future<void> _park(_ThreadOwner owner, _Watch watch) async {
    final displaced = _idle.remove(owner);
    _idle[owner] = watch;
    _notifyOwned(owner, watch);
    watch.release();
    await displaced?.close();
  }

  /// Ends [follow]: a reconnect under way stops, and the watch that is current
  /// now, which may not be the one the stream began with, is closed. It is
  /// found by identity, since compression may have re-keyed the thread.
  Future<void> _stopFollowing(_Follow follow) {
    follow.cancelled = true;
    _idle.removeWhere((_, parked) => parked == follow.watch);
    return follow.watch.close();
  }

  Future<void> _pickUp(
    _ThreadOwner owner,
    StreamController<ChatEvent> out,
  ) async {
    var canceled = false;
    out.onCancel = () => canceled = true;
    // Nothing is replayed for a turn this app never followed, so the reply
    // starts from the snapshot the resume answer carries. One attempt: this
    // runs when a thread opens, which must not wait on a server that is down.
    final mine = <String>{};
    final resumed = await _reattach(
      owner,
      runtimeId: null,
      shown: mine,
      drops: 0,
      maxAttempts: 1,
      cancelled: () => canceled || out.isClosed,
    );
    final watch = resumed.watch;
    if (_reclaimOf(resumed.ended) case final reclaim?) {
      resumed.discard();
      out.add(reclaim);
      await out.close();
      return;
    }
    if (canceled || out.isClosed) {
      resumed.discard();
      return;
    }
    if (watch == null) {
      final idle = resumed.idle;
      if (idle != null) await _park(owner, idle);
      for (final (event, serverRequest) in resumed.ended) {
        _track(event, resumed.runtimeId, mine, serverRequest: serverRequest);
        out.add(event);
        // The prompt's reply came in whole, so there is no turn left to skip.
        if (event is ReplyCompleted) _settledEarly.remove(owner);
      }
      _forgetRequests(mine);
      if (idle == null || canceled || out.isClosed) {
        await out.close();
        return;
      }
      // The turn is over, but the session goes on: what Hermes chains next
      // reaches this stream through the idle watch. A thread with no turn to
      // report has nothing to follow yet.
      final follow = _Follow(idle);
      out.onCancel = () => _stopFollowing(follow);
      await _relay(follow, owner, out);
      return;
    }
    if (_idle.remove(owner) case final previous?) {
      await previous.close();
    }
    if (canceled || out.isClosed) {
      await watch.close();
      return;
    }
    _idle[owner] = watch;
    _notifyOwned(owner, watch);
    final follow = _Follow(watch);
    out.onCancel = () => _stopFollowing(follow);
    out.add(const ReplyStarted());
    await _relay(follow, owner, out, initiallyReplying: true);
  }

  Future<void> _relay(
    _Follow follow,
    _ThreadOwner owner,
    StreamController<ChatEvent> out, {
    bool initiallyReplying = false,
  }) async {
    follow.watch.hold();
    var key = owner;
    var runtimeId = follow.watch.runtimeId;
    var replying = initiallyReplying;
    if (replying) _beginReply(runtimeId, key);
    final mine = <String>{};
    final drops = _Reconnects();
    var errored = false;
    void forward(_Incoming incoming) {
      final (event, serverRequest) = incoming;
      if (event is SessionInfo) {
        final rotated = event.storedSessionId;
        if (rotated != null && rotated.isNotEmpty && rotated != key.$2) {
          final next = (key.$1, rotated);
          _rekey(key, next);
          key = next;
        }
      }
      if (event is ReplyStarted && replying) {
        // A resumed running turn can replay its start. Forwarding that
        // would create a second pending bubble with no completion.
        return;
      }
      if (!replying && opensTurn(event)) {
        replying = true;
        _beginReply(runtimeId, key);
      }
      _track(event, runtimeId, mine, serverRequest: serverRequest);
      if (out.isClosed) return;
      out.add(event);
      errored = errored || event is ReplyErrored;
      // A turn that settles without a completion is over all the same: the
      // next turn's start must not be taken for a replay of this one.
      if (replying &&
          (event is ReplyCompleted ||
              event is SessionInfo && event.running == false)) {
        if (!_settledEarly.remove(key)) {
          _turnSettled(event, errored: errored);
        }
        errored = false;
        replying = false;
        drops.reset();
        _forgetRequests(mine);
        _endReply(runtimeId, key);
      }
    }

    try {
      while (true) {
        while (true) {
          final bool more;
          try {
            // A turn under way is probed when it goes quiet; between turns a
            // quiet session is just idle.
            more = replying
                ? await _advance(follow.watch, key.$2)
                : await follow.watch.events.moveNext();
          } on GatewayConnectionClosed {
            if (!out.isClosed) out.addError(const GatewayConnectionClosed());
            return;
          }
          if (!more) break;
          drops.frame(clock.now());
          final incoming = follow.watch.events.current;
          if (incoming == null) continue;
          forward(incoming);
          if (incoming.$1 is SessionReclaimed) return;
          if (out.isClosed) return;
        }
        // Idle between turns: nothing is running to pick back up, so the
        // connection dropping just ends the stream quietly. So does a watch
        // the transport closed itself (another send took the session over).
        if (!replying || follow.cancelled || out.isClosed) return;
        if (follow.watch.closedByUs) return;
        final made = drops.dropped();
        if (made >= _maxReplyReconnects) {
          out.addError(const GatewayConnectionClosed());
          return;
        }
        drops.attempt();
        final resumed = await _reattach(
          key,
          runtimeId: runtimeId,
          shown: mine,
          drops: made,
          cancelled: () => follow.cancelled || out.isClosed,
        );
        final previous = follow.watch;
        await previous.close();
        if (follow.cancelled || out.isClosed) {
          resumed.discard();
          return;
        }
        _endReply(runtimeId, key);
        _moveRequests(mine, runtimeId, resumed.runtimeId);
        runtimeId = resumed.runtimeId;
        _beginReply(runtimeId, key);
        if (_reclaimOf(resumed.ended) case final reclaim?) {
          resumed.discard();
          out.add(reclaim);
          return;
        }
        final live = resumed.watch;
        if (live == null) {
          if (_rotatedIn(resumed.ended, key.$2) case final rotated?) {
            final next = (key.$1, rotated);
            _rekey(key, next);
            key = next;
          }
          final idle = resumed.idle;
          if (idle != null) await _park(key, idle);
          for (final (event, serverRequest) in resumed.ended) {
            if (out.isClosed) return;
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            out.add(event);
          }
          if (resumed.giveUp && !out.isClosed) {
            out.addError(const GatewayConnectionClosed());
          }
          if (idle == null || out.isClosed || follow.cancelled) return;
          // The turn is over, but the session goes on: the idle watch carries
          // whatever Hermes chains next, to this same stream.
          replying = false;
          drops.reset();
          _forgetRequests(mine);
          _endReply(runtimeId, key);
          follow.watch = idle;
          continue;
        }
        _idle.updateAll((_, parked) => parked == previous ? live : parked);
        follow.watch = live;
        drops.reconnected(clock.now());
      }
    } finally {
      _forgetRequests(mine);
      if (replying) _endReply(runtimeId, key);
      // The watch is closed below, so it must not stay parked for the next
      // follow-up stream to find dead. By identity: a send that took the
      // session over has parked its own.
      _idle.removeWhere((_, parked) => parked == follow.watch);
      if (!out.isClosed) unawaited(out.close());
      await follow.watch.close();
    }
  }

  /// Starts listening to the events and requests of [runtimeId]. The
  /// [injected] events, already decided by a reconnect, come first; then the
  /// [buffered] frames of any session, filtered to it, and the live frames.
  /// A live event at or below [startAt] (by default what the ledger holds for
  /// this connection's epoch), or what the watch already showed, is dropped,
  /// so one the replay already handed over is not shown twice.
  _Watch _watch(
    GatewayRpcClient client,
    String runtimeId, {
    String? profile,
    required String storedId,
    Object? resumeToken,
    Map<String, Object?>? resumeSnapshot,
    List<Object> buffered = const [],
    List<_Incoming> injected = const [],
    Set<String> shown = const {},
    int? startAt,
    bool record = false,
  }) {
    final inbox = StreamController<_Incoming?>();
    final owner = (profile, storedId);
    _establishOwned(owner, client, runtimeId);
    final watch = _Watch(runtimeId, client, inbox, record: record);
    var controlGeneration = 0;
    var reclaimed = false;
    void note(ChatEvent event) {
      if (event is SessionControlUpdated) controlGeneration++;
      if (event is SessionReclaimed) {
        watch.reclaimed = event;
        reclaimed = true;
        _loseOwned(client, runtimeId, retired: true);
        _awaiting.removeWhere((_, request) => request.sessionId == runtimeId);
      }
    }

    for (final incoming in injected) {
      note(incoming.$1);
      watch.push(incoming);
      if (reclaimed) break;
    }
    // The ledger is the transport's: it feeds the next replay. Whether this
    // watch has shown a live event is its own matter, so two watches on one
    // runtime session each get every frame.
    var seen = startAt ?? _ledger.resumeFrom(runtimeId, client.epoch);
    // A request the reply showed before the drop may come again from the new
    // socket; a copy, so the reply's own set stays the reply's.
    final requests = {...shown};
    void deliver(Object frame) {
      final String sid;
      switch (frame) {
        case GatewayEvent event:
          sid = _eventRuntime(event);
        case GatewayServerRequest request:
          sid = request.sessionId;
        default:
          return;
      }
      if (sid != runtimeId || reclaimed) return;
      // A frame that shows nothing, or a replayed duplicate, still counts as
      // a sign of life for the silence probe, so it is sent as a null.
      if (frame is GatewayServerRequest && !requests.add(frame.id)) {
        watch.push(null);
        return;
      }
      if (frame is GatewayEvent) {
        final seq = frame.sessionId == runtimeId ? frame.seq : null;
        if (seq != null) {
          _ledger.observe(runtimeId, seq, epoch: client.epoch);
          if (seq <= seen) {
            watch.push(null);
            return;
          }
          seen = seq;
        }
      }
      final incoming = _incomingOf(frame, runtimeId, client: client);
      if (incoming != null) note(incoming.$1);
      watch.push(incoming);
    }

    buffered.forEach(deliver);
    watch._sources = [
      client.events.listen(
        deliver,
        onDone: () {
          _loseOwned(client, runtimeId);
          unawaited(inbox.close());
        },
      ),
      client.serverRequests.listen(deliver),
    ];
    if (reclaimed) return watch;
    final generation = controlGeneration;
    unawaited(() async {
      try {
        final result = await client
            .request('session.control.read', {
              'session_id': runtimeId,
              'profile': ?profile,
            })
            .timeout(requestTimeout);
        final control = SessionControlSnapshot.decode(result['control']);
        if (watch.closedByUs ||
            client.isClosed ||
            inbox.isClosed ||
            reclaimed ||
            generation != controlGeneration ||
            generation != 0) {
          return;
        }
        watch.push(
          control == null
              ? (SessionControlUnavailable(runtimeId), false)
              : (SessionControlUpdated(control, runtimeId: runtimeId), false),
        );
      } on GatewayRpcException {
        if (!watch.closedByUs &&
            !client.isClosed &&
            !inbox.isClosed &&
            !reclaimed &&
            generation == controlGeneration &&
            generation == 0) {
          watch.push((SessionControlUnavailable(runtimeId), false));
        }
      } on Object {
        if (!watch.closedByUs &&
            !client.isClosed &&
            generation == controlGeneration) {
          _record('gateway.visibility_outcome', {
            'feature': 'session_state',
            'outcome': 'unavailable',
          });
        }
        return;
      }
    }());
    _notifyOwned(
      owner,
      watch,
      resumeToken: resumeToken,
      resumeSnapshot: resumeSnapshot,
    );
    return watch;
  }
}

/// The status of each session in a `session.active_list` answer, by key.
Map<String, String> _statusesOf(Map<String, Object?> result) {
  final statuses = <String, String>{};
  if (result['sessions'] case final List<Object?> rows) {
    for (final row in rows) {
      if (row
          case {'session_key': final String key, 'status': final String status}
          when key.isNotEmpty) {
        statuses[key] = status;
      }
    }
  }
  return statuses;
}

String _eventRuntime(GatewayEvent event) =>
    event.type == 'session.reclaimed' && event.payload['session_id'] is String
    ? event.payload['session_id'] as String
    : event.sessionId;

SessionReclaimed? _reclaimOf(List<_Incoming> incoming) =>
    incoming.map((item) => item.$1).whereType<SessionReclaimed>().firstOrNull;

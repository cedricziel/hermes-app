part of 'hermes_gateway_transport.dart';

/// Reconnecting a reply after a drop: resume, replay and what the reply missed.
extension _Reconnect on HermesGatewayTransport {
  /// Reconnects [owner] after a drop and resumes its runtime session, so a
  /// turn still running there is watched again, and the events it sent while
  /// the socket was down are replayed.
  ///
  /// [runtimeId] is the session the reply was on, or null when this app never
  /// followed it (a turn another client started); then nothing is replayed,
  /// since the server's ring may hold turns this app already showed. [shown]
  /// holds the request ids the reply has shown, so none is shown twice. [drops]
  /// counts the reconnects this reply already made, so the backoff keeps
  /// growing when a resumed turn drops again at once.
  ///
  /// Each attempt after the very first waits [reconnectDelay] before it. Up to
  /// [maxAttempts] failed attempts, or 60 s from the drop, give up (see
  /// [_Resumed.giveUp]). [cancelled] is asked between attempts and after each
  /// step of one: once it holds, nothing more is tried and nothing is merged.
  Future<_Resumed> _reattach(
    _ThreadOwner owner, {
    required String? runtimeId,
    required Set<String> shown,
    required int drops,
    required bool Function() cancelled,
    int maxAttempts = _maxReconnectAttempts,
  }) async {
    final budget = Completer<void>();
    final timer = Timer(_reconnectBudget, () {
      if (!budget.isCompleted) budget.complete();
    });
    bool stop() => budget.isCompleted || _closed || cancelled();
    // Attempts that got as far as opening a socket, for telemetry.
    var tried = 0;
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (stop()) break;
        final index = attempt + drops;
        if (index > 0) {
          await _within(
            _sleep(reconnectDelay(index, _random)),
            budget.future,
            (_) {},
          );
        }
        if (stop()) break;
        tried = attempt + 1;
        final resumed = await _within(
          _resumeOnce(owner, runtimeId, shown, stop),
          budget.future,
          (resumed) => resumed?.discard(),
        );
        if (resumed != null) {
          if (!cancelled()) {
            if (runtimeId != null) _reportReconnect(tried, resumed);
            return resumed;
          }
          resumed.discard();
          break;
        }
      }
      final failed = _Resumed(
        runtimeId: runtimeId ?? owner.$2,
        giveUp: true,
        outcome: 'failed',
      );
      if (runtimeId != null && !cancelled()) _reportReconnect(tried, failed);
      return failed;
    } finally {
      timer.cancel();
    }
  }

  /// Logs how a reconnect of a reply on screen went, after [attempt] tries.
  void _reportReconnect(int attempt, _Resumed resumed) =>
      _record('gateway.reconnect', {
        'attempt': attempt,
        'outcome': resumed.outcome,
        'replayed_count': resumed.replayedCount,
        'truncated': resumed.truncated,
        'epoch_changed': resumed.epochChanged,
      });

  /// One reconnect attempt: opens a socket, resumes the session, and works out
  /// what the reply missed. Null when the attempt failed and may be retried.
  Future<_Resumed?> _resumeOnce(
    _ThreadOwner owner,
    String? previous,
    Set<String> shown,
    bool Function() stop,
  ) async {
    final GatewayRpcClient client;
    try {
      client = await _client();
    } on Object {
      return null;
    }
    if (stop()) return null;
    // Listening starts before the resume is sent, so the frames the gateway
    // pushes ahead of its answer are kept rather than dropped.
    final tap = _Tap(client);
    final Map<String, Object?> resumed;
    Object? usageResumeToken;
    try {
      usageResumeToken = _beginResume(owner);
      resumed = await _call(client, 'session.resume', {
        'session_id': owner.$2,
        'profile': ?owner.$1,
        'source': gatewaySessionSource,
      });
    } on Object {
      tap.close();
      return null;
    }
    if (stop()) {
      tap.close();
      return null;
    }
    final answeredAt = tap.count;
    final id = resumed['session_id'];
    final runtimeId = id is String && id.isNotEmpty ? id : previous ?? owner.$2;
    // The ring only replays what this app saw of this session when the
    // session is the one the reply was on, and only from a seq this app
    // holds: from none, `last_seen: 0` would hand over the whole ring.
    final replay =
        previous != null &&
        runtimeId == previous &&
        _ledger.hasWatermark(runtimeId);
    Map<String, Object?>? since;
    if (replay) {
      try {
        since = await _call(client, 'session.events.since', {
          'session_id': runtimeId,
          'last_seen': _ledger.lastSeen(runtimeId),
        });
      } on GatewayRpcException catch (error) {
        // A gateway that predates the replay cannot fill the gap, so the
        // reply is rebuilt from the resume answer instead.
        if (error.code != kGatewayMethodNotFound) {
          tap.close();
          return null;
        }
      } on Object {
        tap.close();
        return null;
      }
    }
    // An attempt the budget or the consumer gave up on must not move the
    // watermark or park a watch.
    if (stop()) {
      tap.close();
      return null;
    }
    // Read before the merge below, which forgets the epoch it finds stale.
    final truncated = since?['truncated'] == true;
    final replayEpoch = since?['epoch'];
    final recordedEpoch = _ledger.epochOf(runtimeId);
    final epochChanged =
        recordedEpoch != null &&
        replayEpoch is String &&
        replayEpoch != recordedEpoch;
    // Nothing below awaits before the watch, so no frame is lost between the
    // release and the subscription.
    final frames = tap.release();
    for (final frame in frames) {
      if (frame is GatewayEvent && _eventRuntime(frame) == runtimeId) {
        final reclaim = mapGatewayEvent(frame);
        if (reclaim is SessionReclaimed) {
          return _Resumed(
            runtimeId: runtimeId,
            ended: [(reclaim, false)],
            outcome: 'reclaimed',
          );
        }
      }
    }
    final before = _ofSession(frames.take(answeredAt), runtimeId).toList();
    final after = _ofSession(frames.skip(answeredAt), runtimeId).toList();
    final openRows = [resumed['open_requests'], since?['open_requests']];
    final snapshot = _inflightText(resumed['inflight']);

    final epoch = client.epoch;
    final discardWarnings =
        previous != null &&
        (since == null || truncated || epochChanged || runtimeId != previous);
    if (resumed['running'] != true) {
      final ended = <_Incoming>[
        if (discardWarnings) (const WarningScopeDiscarded(), false),
      ];
      // What the session said after the completion: a turn Hermes chained.
      final next = <_Incoming>[];
      var completed = false;
      var merged = false;
      var outcome = 'ended';
      var replayedCount = 0;
      if (since != null) {
        final decision = _ledger.merge(
          sid: runtimeId,
          result: since,
          parked: _eventsOf(frames, runtimeId),
        );
        if (decision case Deliver(:final events)) {
          merged = true;
          replayedCount = events.length;
          for (final event in events) {
            final incoming = _incomingOf(event, runtimeId, client: client);
            if (incoming == null) continue;
            (completed ? next : ended).add(incoming);
            completed = completed || incoming.$1 is ReplyCompleted;
          }
        }
      }
      ReplyCompleted? stored;
      if (!completed) {
        // No completion was replayed, so the stored reply ends the turn. A
        // reply on screen is refetched; a turn picked up with none has nothing
        // to refetch, and ends quietly when it has no stored reply either. The
        // refetch comes first: the completion must stay the reply's last
        // event. A replayed error is the reason the turn failed, so it is
        // shown, and the settle that follows lets the reply fail with it.
        stored = _storedReply(resumed);
        final onScreen = previous != null;
        final errored = ended.any((incoming) => incoming.$1 is ReplyErrored);
        // After the events: a request binds to the tool call it was raised
        // in, which the replay has to have started first.
        _openRequests(ended, openRows, runtimeId, shown);
        if (onScreen) {
          ended.add((const ThreadNeedsRefetch(), false));
          outcome = 'rest_refetch';
        }
        if (stored != null) {
          ended.add((stored, false));
        } else if (errored) {
          ended.add((const SessionInfo(running: false), false));
        }
        if (stored == null && !errored && onScreen) {
          return _Resumed(
            runtimeId: runtimeId,
            ended: ended,
            giveUp: true,
            outcome: 'failed',
            replayedCount: replayedCount,
            truncated: truncated,
            epochChanged: epochChanged,
          );
        }
        // Frames the replay did not cover (the merge counts them itself).
        if (!merged) {
          next.addAll(
            _parked(after, runtimeId, shown, epoch: epoch, client: client),
          );
        }
      }
      // The session goes on being listened to: Hermes may chain another turn.
      return _Resumed(
        runtimeId: runtimeId,
        ended: ended,
        idle: _watch(
          client,
          runtimeId,
          profile: owner.$1,
          storedId: owner.$2,
          resumeToken: usageResumeToken,
          resumeSnapshot: _resumeSnapshot(resumed, runtimeId: runtimeId),
          injected: next,
          shown: shown,
        ),
        outcome: outcome,
        replayedCount: replayedCount,
        truncated: truncated,
        epochChanged: epochChanged,
      );
    }

    final injected = <_Incoming>[
      if (discardWarnings) (const WarningScopeDiscarded(), false),
    ];
    var replayedCount = 0;
    final decision = since == null
        ? const Refetch()
        : _ledger.merge(
            sid: runtimeId,
            result: since,
            parked: _eventsOf(frames, runtimeId),
          );
    if (decision case Deliver(:final events)) {
      replayedCount = events.length;
      injected.addAll(
        _inArrivalOrder(events, frames, runtimeId, shown, client),
      );
      _openRequests(injected, openRows, runtimeId, shown);
    } else {
      // The replay cannot be trusted, so the snapshot replaces the text. Its
      // leading deltas that it already holds are not shown again. With no
      // snapshot to rebuild a reply on screen from (a replay refused as
      // truncated or from another epoch, another runtime session, no seq to
      // replay from, or a gateway without the replay), the gap is one only
      // the stored thread can fill.
      if (snapshot != null) {
        injected.add((ReplyRebuilt(snapshot), false));
      } else if (previous != null) {
        injected.add((const ThreadNeedsRefetch(), false));
      }
      final dropped = snapshot == null ? 0 : _heldBySnapshot(before, snapshot);
      injected.addAll(
        _parked(
          before,
          runtimeId,
          shown,
          epoch: epoch,
          dropped: dropped,
          client: client,
        ),
      );
      injected.addAll(
        _parked(after, runtimeId, shown, epoch: epoch, client: client),
      );
      _openRequests(injected, openRows, runtimeId, shown);
    }
    return _Resumed(
      runtimeId: runtimeId,
      watch: _watch(
        client,
        runtimeId,
        profile: owner.$1,
        storedId: owner.$2,
        resumeToken: usageResumeToken,
        resumeSnapshot: _resumeSnapshot(resumed, runtimeId: runtimeId),
        injected: injected,
        shown: shown,
      ),
      outcome: decision is Deliver ? 'replayed' : 'rest_refetch',
      replayedCount: replayedCount,
      truncated: truncated,
      epochChanged: epochChanged,
    );
  }

  /// The [delivered] events of a replay as chat events, in the order the
  /// session sent them: the replayed ones first, then each live event and
  /// server request where its frame sits among the [frames] parked during the
  /// reconnect. A replayed event the parked frames also hold, by seq, takes
  /// that frame's place. A request already in [shown] is not shown again.
  List<_Incoming> _inArrivalOrder(
    List<GatewayEvent> delivered,
    List<Object> frames,
    String sid,
    Set<String> shown,
    GatewayRpcClient client,
  ) {
    final parked = Set<Object>.identity()..addAll(frames);
    final frameSeqs = {
      for (final frame in frames)
        if (frame is GatewayEvent &&
            frame.sessionId == sid &&
            frame.seq != null)
          frame.seq!,
    };
    final live = Set<Object>.identity();
    final replacing = <int, GatewayEvent>{};
    final out = <_Incoming>[];
    for (final event in delivered) {
      final seq = event.seq;
      if (parked.contains(event)) {
        live.add(event);
      } else if (seq != null && frameSeqs.contains(seq)) {
        replacing[seq] = event;
      } else if (event.type == 'billing.step_up.verification') {
        _record('gateway.visibility_outcome', {
          'feature': 'billing_verification',
          'outcome': 'discarded_replay',
        });
      } else if (_incomingOf(event, sid, client: client) case final incoming?) {
        out.add(incoming);
      }
    }
    for (final frame in frames) {
      if (frame is GatewayEvent) {
        final event =
            frame.type == 'session.reclaimed' && _eventRuntime(frame) == sid
            ? frame
            : live.contains(frame)
            ? frame
            : replacing[frame.seq];
        final incoming = event == null
            ? null
            : _incomingOf(event, sid, client: client);
        if (incoming != null) out.add(incoming);
      } else if (frame is GatewayServerRequest && frame.sessionId == sid) {
        _addRequest(out, frame, shown);
      }
    }
    return out;
  }

  /// Completes with [work]'s value, or with null once [budget] completes
  /// first. A value that arrives after the budget is handed to [discard], so
  /// a connection opened for an attempt that gave up is closed.
  Future<T?> _within<T>(
    Future<T> work,
    Future<void> budget,
    void Function(T value) discard,
  ) {
    final result = Completer<T?>();
    unawaited(
      work.then(
        (value) {
          if (result.isCompleted) {
            discard(value);
          } else {
            result.complete(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    unawaited(
      budget.then((_) {
        if (!result.isCompleted) result.complete(null);
      }),
    );
    return result.future;
  }

  /// The reply a finished turn left as the session's last message, if any.
  ReplyCompleted? _storedReply(Map<String, Object?> resumed) {
    if (resumed['messages']
        case [..., {'role': 'assistant', 'text': final String text}]
        when text.isNotEmpty) {
      return ReplyCompleted(text);
    }
    return null;
  }

  /// The frames [parked] while a reconnect was in flight, as events to show.
  /// Each event is observed on the ledger, so a later replay does not hand it
  /// again. The first [dropped] frames are observed but not shown.
  List<_Incoming> _parked(
    List<Object> parked,
    String sid,
    Set<String> shown, {
    required String? epoch,
    required GatewayRpcClient client,
    int dropped = 0,
  }) {
    final out = <_Incoming>[];
    for (var i = 0; i < parked.length; i++) {
      final frame = parked[i];
      if (frame is GatewayEvent) {
        final fresh =
            frame.sessionId != sid ||
            _ledger.observe(sid, frame.seq, epoch: epoch);
        if (!fresh || i < dropped) continue;
        final incoming = _incomingOf(frame, sid, client: client);
        if (incoming != null) out.add(incoming);
      } else if (frame is GatewayServerRequest) {
        _addRequest(out, frame, shown);
      }
    }
    return out;
  }

  /// The chat event a frame of [runtimeId] shows, or null when it shows
  /// nothing. Server requests are mapped as they arrive from the server.
  _Incoming? _incomingOf(
    Object frame,
    String runtimeId, {
    required GatewayRpcClient client,
  }) {
    switch (frame) {
      case GatewayEvent event when _eventRuntime(event) == runtimeId:
        final shown = mapGatewayEvent(event, connection: client);
        if (shown == null) _reportUnmapped(event.type);
        return shown == null ? null : (shown, false);
      case GatewayServerRequest request when request.sessionId == runtimeId:
        final shown = handledServerRequests.contains(request.method)
            ? _fromServerRequest(request)
            : null;
        return shown == null ? null : (shown, true);
      default:
        return null;
    }
  }
}

/// The frames of [sid]: its events and its server requests, in order.
Iterable<Object> _ofSession(Iterable<Object> frames, String sid) =>
    frames.where(
      (frame) => switch (frame) {
        GatewayEvent event => _eventRuntime(event) == sid,
        GatewayServerRequest request => request.sessionId == sid,
        _ => false,
      },
    );

List<GatewayEvent> _eventsOf(List<Object> frames, String sid) => [
  for (final frame in frames)
    if (frame is GatewayEvent && frame.sessionId == sid) frame,
];

/// The assistant text of a resume answer's `inflight` snapshot, if any.
String? _inflightText(Object? inflight) {
  if (inflight case {'assistant': final String text}) return text;
  return null;
}

/// How many leading deltas of [before] the snapshot already holds: the
/// shortest run from the start whose joined text ends [snapshot]. The run
/// stops at the first frame that is not a delta.
///
/// Only the text can say whether the snapshot holds a delta, so the guess
/// errs towards a duplicate over a hole: a run counts only with at least
/// [_minHeldRun] characters besides whitespace. A shorter one ("." after a
/// snapshot ending in "end.") is as likely a new delta that happens to
/// match, and dropping it loses text; shown twice, it is a blemish the
/// completion's full text corrects.
int _heldBySnapshot(List<Object> before, String snapshot) {
  final joined = StringBuffer();
  var count = 0;
  for (final frame in before) {
    if (frame is! GatewayEvent || frame.type != 'message.delta') break;
    count++;
    final text = frame.payload['text'];
    joined.write(text is String ? text : '');
    final run = joined.toString();
    final solid = run.replaceAll(RegExp(r'\s'), '').length;
    if (solid >= _minHeldRun && snapshot.endsWith(run)) {
      return count;
    }
  }
  return 0;
}

part of 'hermes_gateway_transport.dart';

/// Sending a prompt and following its reply to the end.
extension _Sending on HermesGatewayTransport {
  Stream<ChatEvent> _send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
    WorkspaceChoice? workspace,
    Future<void> Function()? beforeSubmit,
    Future<void> Function()? onNotSubmitted,
    bool Function()? queueDispatchAllowed,
  }) {
    _promptAccepted = false;
    final stopped = CancelFlag();
    final step = _SendStep();
    return CancelAwareStream(
      _sendReply(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: model,
        queued: queued,
        workspace: workspace,
        stopped: stopped,
        step: step,
        beforeSubmit: beforeSubmit,
        onNotSubmitted: onNotSubmitted,
        queueDispatchAllowed: queueDispatchAllowed,
      ).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) {
            _sendFailed(step.name, error, newThread: threadId == null);
            sink.addError(error, stackTrace);
          },
        ),
      ),
      stopped,
    );
  }

  /// Logs that a send failed at [step], with what kind of error ended it:
  /// never its message, which can quote the prompt.
  void _sendFailed(String step, Object error, {required bool newThread}) =>
      _record('gateway.send_failed', {
        'step': step,
        'new_thread': newThread,
        ...switch (error) {
          GatewayConnectionClosed() => {'cause': 'closed'},
          GatewayRpcException(:final code) => {
            'cause': 'rejected',
            'code': code,
          },
          ProfileUnavailableException() => {'cause': 'profile'},
          TimeoutException() => {'cause': 'timeout'},
          _ => {'cause': 'other', 'error_type': '${error.runtimeType}'},
        },
      });

  /// `session.create`, with the picked folder as `cwd` and `cwd_explicit`.
  /// A server whose contract predates the flag answers `4000` naming it; the
  /// create is then sent once more without the flag ([onRetry]), and the
  /// folder it reports is compared with the pick afterwards. A create that
  /// carries no folder is sent as it always was.
  Future<Map<String, Object?>> _createSession(
    GatewayRpcClient client,
    Map<String, Object?> params,
    WorkspaceChoice? workspace,
    void Function() onRetry,
  ) async {
    if (workspace == null) return _call(client, 'session.create', params);
    try {
      return await _call(client, 'session.create', {
        ...params,
        'cwd': workspace.path,
        'cwd_explicit': true,
      });
    } on GatewayRpcException catch (error) {
      if (error.code != 4000 || !error.message.contains('cwd_explicit')) {
        rethrow;
      }
      onRetry();
      return _call(client, 'session.create', {
        ...params,
        'cwd': workspace.path,
      });
    }
  }

  /// Where Hermes started the new session, from its `info`, or null when it
  /// said nothing about a folder.
  static WorkspaceBound? _workspaceBound(
    Map<String, Object?> session,
    bool retriedWithoutExplicit,
  ) {
    final info = session['info'];
    if (info is! Map) return null;
    final cwd = info['cwd'];
    if (cwd is! String || cwd.trim().isEmpty) return null;
    final branch = info['branch'];
    final project = info['project'];
    final name = project is Map ? project['name'] : null;
    final fields = project is Map ? project : const <Object?, Object?>{};
    final projectId = fields['id'];
    final primaryPath = fields['primary_path'];
    final root = info['git_repo_root'];
    return WorkspaceBound(
      cwd: cwd,
      gitRepoRoot: root is String && root.trim().isNotEmpty ? root : null,
      branch: branch is String && branch.trim().isNotEmpty ? branch : null,
      project: name is String && name.trim().isNotEmpty
          ? WorkspaceProjectRef(
              name: name,
              id: projectId is String ? projectId : null,
              primaryPath: primaryPath is String ? primaryPath : null,
            )
          : null,
      retriedWithoutExplicit: retriedWithoutExplicit,
    );
  }

  Stream<ChatEvent> _sendReply({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
    WorkspaceChoice? workspace,
    required CancelFlag stopped,
    required _SendStep step,
    Future<void> Function()? beforeSubmit,
    Future<void> Function()? onNotSubmitted,
    bool Function()? queueDispatchAllowed,
  }) async* {
    final scope = <String, Object?>{
      'profile': ?profile,
      'source': gatewaySessionSource,
    };
    // Nothing is submitted until the prompt is, so a socket that will not
    // open, or a session call it never answers, is tried again on a new one.
    // Hermes stores a session only on its first prompt: a create that did
    // arrive leaves nothing behind.
    late GatewayRpcClient client;
    late ReplayLedger before;
    late _Tap tap;
    late Map<String, Object?> session;
    var retriedWithoutExplicit = false;
    Object? usageResumeToken;
    for (var attempt = 0; ; attempt++) {
      if (attempt > 0) await _sleep(reconnectDelay(attempt, _random));
      if (stopped.value) return;
      // Each attempt decides on its own whether the flag was dropped.
      retriedWithoutExplicit = false;
      step.name = 'connect';
      try {
        client = await _client();
        step.name = 'open';
        // Listening starts before the resume is sent, so a frame the gateway
        // pushes ahead of its answer is kept for this session.
        // What the ledger held before this send's first frame: a frame the
        // tap buffers may already have been observed by a watch that was
        // listening.
        before = _ledger.snapshot();
        tap = _Tap(client);
        try {
          usageResumeToken = threadId == null
              ? null
              : _beginResume((profile, threadId));
          session = threadId == null
              ? await _createSession(
                  client,
                  {
                    ...scope,
                    if (model != null) ...{
                      'model': model.modelId,
                      'provider': model.providerId,
                      'reasoning_effort': ?model.effort,
                    },
                  },
                  workspace,
                  () => retriedWithoutExplicit = true,
                )
              : await _call(client, 'session.resume', {
                  'session_id': threadId,
                  ...scope,
                });
        } on GatewayRpcException catch (error) {
          tap.close();
          if (error.code == kGatewayProfileUnavailable) {
            throw const ProfileUnavailableException();
          }
          rethrow;
        } on Object {
          tap.close();
          rethrow;
        }
        break;
      } on Object catch (error) {
        final answered =
            error is GatewayRpcException ||
            error is ProfileUnavailableException;
        if (answered || _closed || attempt + 1 >= _sendOpenAttempts) rethrow;
      }
    }
    var runtimeId = '';
    var storedId = '';
    var owner = (profile, '');
    late _Watch watch;
    var released = false;
    // After resuming a session whose last turn was cut off, Hermes runs a turn
    // of its own ahead of this send's prompt.
    final autoContinue =
        session['auto_continue'] != null && session['auto_continue'] != false;
    try {
      runtimeId = session['session_id'] as String;
      storedId = threadId ?? session['stored_session_id'] as String;
      owner = (profile, storedId);
      _establishOwned(owner, client, runtimeId);
      _settledEarly.remove(owner);
      await _idle.remove(owner)?.close();
      // A relay may have re-keyed its watch after compression before the
      // caller knew the new id: the runtime session is the same all the same.
      for (final key in [
        for (final e in _idle.entries)
          if (e.value.runtimeId == runtimeId) e.key,
      ]) {
        await _idle.remove(key)?.close();
      }
      if (model != null) {
        if (threadId != null) {
          await _switchModel(client, runtimeId, _modelOf[owner], model);
        }
        _modelOf[owner] = model;
      }
      _beginReply(runtimeId, owner);
      watch = _watch(
        client,
        runtimeId,
        profile: profile,
        storedId: storedId,
        resumeToken: usageResumeToken,
        resumeSnapshot: _resumeSnapshot(session, runtimeId: runtimeId),
        buffered: tap.release(),
        startAt: before.resumeFrom(runtimeId, client.epoch),
        record: autoContinue,
      );
      released = true;
    } finally {
      if (!released) tap.close();
    }
    final mine = <String>{};
    var parked = false;
    final drops = _Reconnects();
    // Whether the turn has begun. A report that the session is idle only ends
    // the reply once it has, or once the grace has passed (see [settles]).
    var started = false;
    var errored = false;
    // Whether the send shows that Hermes is finishing a turn of its own.
    var finishing = false;
    // The requests of that turn the send passed on, which are withdrawn when
    // the turn ends.
    final passed = <String>{};
    // The same for a clarify question that arrived as an event: it is not a
    // request the transport answers, so [mine] does not hold it.
    final passedAsked = <String>{};
    // Takes the requests passed through so far off the send, for the
    // withdrawal that tells the reply nobody can answer them any more.
    InputRequestsCancelled? takeWithdrawn() {
      if (passed.isEmpty && passedAsked.isEmpty) return null;
      final withdrawn = InputRequestsCancelled([...passed, ...passedAsked]);
      _track(withdrawn, runtimeId, mine, serverRequest: false);
      passed.clear();
      passedAsked.clear();
      return withdrawn;
    }

    // Remembers a request of that turn the send handed over, for the
    // withdrawal, and forgets one the server took back.
    void notePassed(ChatEvent event) {
      if (_requestIdOf(event) case final id?) {
        if (mine.contains(id)) {
          passed.add(id);
        } else if (event is ClarifyRequested) {
          passedAsked.add(id);
        }
      }
      passed.retainAll(mine);
      if (event is InputRequestExpired) {
        passedAsked.remove(event.requestId);
      } else if (event is InputRequestsCancelled) {
        event.requestIds.isEmpty
            ? passedAsked.clear()
            : passedAsked.removeAll(event.requestIds);
      }
    }

    var submittedAt = clock.now();
    // Set when the server queued the prompt behind a turn that was running.
    _QueuedGate? gate;
    // Set when the prompt follows a turn Hermes ran on its own. That turn's
    // events are handed over as [UnsolicitedEvent]s while the prompt waits.
    _Unsolicited? unsolicited;
    // Whether any of that turn's frames were handed over, a request that opens
    // its reply included. A send that gives up then has a half-shown turn
    // behind it.
    var claimedShown = false;
    // The log of that turn's end: it is counted here, not on the follow-ups,
    // which never see it.
    var claimedReplying = false;
    var claimedErrored = false;
    void claimedFrame(ChatEvent event) {
      if (opensTurn(event)) claimedReplying = true;
      claimedErrored = claimedErrored || event is ReplyErrored;
      if (claimedReplying &&
          (event is ReplyCompleted ||
              event is SessionInfo && event.running == false)) {
        _turnSettled(event, errored: claimedErrored);
        claimedErrored = false;
        claimedReplying = false;
      }
    }

    Future<QueueSubmissionNotStarted> notSubmitted(Object error) async {
      try {
        await onNotSubmitted?.call();
      } on Object {
        // Failed restoration cannot erase proof that no prompt RPC was sent.
      }
      return error is QueueSubmissionNotStarted
          ? error
          : QueueSubmissionNotStarted(error);
    }

    try {
      if (threadId == null) {
        yield ThreadBound(storedId);
        if (_workspaceBound(session, retriedWithoutExplicit)
            case final bound?) {
          yield bound;
        }
      }
      // Images queue on the session and the next prompt takes them, so a send
      // that fails after queuing one must take them off again.
      final queuedImages = <String>[];
      final Map<String, Object?> submit;
      try {
        if (watch.reclaimed case final reclaim?) {
          yield reclaim;
          return;
        }
        step.name = 'attach';
        final references = await _attach(
          client,
          runtimeId,
          attachments,
          queuedImages,
          reclaimed: () => watch.reclaimed != null,
        );
        if (watch.reclaimed case final reclaim?) {
          yield reclaim;
          return;
        }
        final submissionBinding = beforeSubmit == null
            ? null
            : ownedSessionFor(owner.$2, profile: owner.$1);
        var dispatchDenied = false;
        bool authorizeSubmission() {
          var allowed =
              !stopped.value &&
              watch.reclaimed == null &&
              submissionBinding != null &&
              identical(submissionBinding.connection, client) &&
              submissionBinding.runtimeId == runtimeId &&
              ownedSessionFor(owner.$2, profile: owner.$1) == submissionBinding;
          if (allowed) {
            try {
              allowed = queueDispatchAllowed?.call() ?? true;
            } on Object {
              allowed = false;
            }
          }
          if (!allowed) dispatchDenied = true;
          return allowed;
        }

        if (beforeSubmit != null) {
          step.name = 'commit';
          try {
            await beforeSubmit();
            if (stopped.value) throw StateError('Queued submission canceled');
            if (watch.reclaimed != null) {
              throw StateError('Queued session reclaimed');
            }
          } on Object catch (error) {
            throw await notSubmitted(error);
          }
        }
        step.name = 'submit';
        submittedAt = clock.now();
        try {
          submit = await _call(client, 'prompt.submit', {
            'session_id': runtimeId,
            'text': [text, ...references].where((s) => s.isNotEmpty).join('\n'),
            if (queued) 'queued': true,
          }, authorize: beforeSubmit == null ? null : authorizeSubmission);
        } on Object catch (error) {
          if (dispatchDenied) throw await notSubmitted(error);
          rethrow;
        }
      } on Object catch (error) {
        if (watch.reclaimed case final reclaim?) {
          yield reclaim;
          return;
        }
        await _detach(client, runtimeId, queuedImages);
        if (stopped.value && error is QueueSubmissionNotStarted) return;
        rethrow;
      }
      step.name = 'reply';
      _promptAccepted = true;
      // What the session sent before it answered. A turn of Hermes' own in it
      // ends before the prompt's reply starts.
      final earlier = watch.stopRecording();
      if (submit['user_row_id'] case final int userRowId) {
        yield PromptAcknowledged(
          userRowId,
          runtimeId: runtimeId,
          connection: client,
        );
      }
      if (beforeSubmit != null) {
        final status = submit['status'];
        if (status is String &&
            PromptAccepted.allowedStatuses.contains(status)) {
          yield PromptAccepted(status);
        }
      }
      if (const {'redirected', 'steered'}.contains(submit['status'])) {
        // The server folded the prompt into the turn already running, whose
        // reply streams on in its own send. This one has nothing to wait for,
        // but the running turn's frames go on arriving: the watch is parked
        // for the follow-ups, which carry them.
        final displaced = _idle.remove(owner);
        _idle[owner] = watch;
        _notifyOwned(owner, watch);
        watch.release();
        parked = true;
        await displaced?.close();
        yield const PromptFolded();
        return;
      }
      if (submit['status'] == 'queued') {
        if (autoContinue) {
          unsolicited = _Unsolicited();
        } else {
          gate = _QueuedGate();
        }
      } else if (autoContinue) {
        // Answered as idle, so a turn that is already over in what came before
        // the answer is Hermes' own. One that has only begun is the prompt's:
        // the answer can trail the first frames of its reply.
        final probe = _Unsolicited();
        for (final arrived in earlier) {
          if (arrived != null) probe.claims(arrived.$1);
        }
        if (probe.ended) {
          // Over before the answer: what it recorded is history, not a turn
          // to finish, so nothing of it is shown or can be answered.
          unsolicited = _Unsolicited(live: false);
        }
      }
      while (true) {
        while (true) {
          final bool more;
          try {
            more = await _advance(watch, storedId);
          } on GatewayConnectionClosed {
            // The probe ended the reply as broken: no turn is being finished.
            if (finishing) yield const ReplyStatus('');
            if (takeWithdrawn() case final withdrawn?) {
              yield UnsolicitedEvent(withdrawn);
            }
            // The turn handed over is not carried on: the thread is read again.
            if (claimedShown) yield const ThreadNeedsRefetch();
            rethrow;
          }
          if (!more) break;
          drops.frame(clock.now());
          final incoming = watch.events.current;
          if (incoming == null) continue;
          final (event, serverRequest) = incoming;
          if (event is SessionReclaimed) {
            yield event;
            return;
          }
          final claimant = unsolicited;
          final claimed = claimant != null && claimant.claims(event);
          // A request of a turn that was over before the submit was answered
          // is not shown, so it must not stay answerable either.
          final history =
              claimed && !claimant.live && _Unsolicited.isInputRequest(event);
          if (!history) {
            _track(event, runtimeId, mine, serverRequest: serverRequest);
          }
          if (event is SessionInfo) {
            final rotated = event.storedSessionId;
            if (rotated != null && rotated.isNotEmpty && rotated != storedId) {
              // Compression moved the thread to a new stored session.
              final next = (profile, rotated);
              _rekey(owner, next);
              owner = next;
              storedId = rotated;
            }
          }
          if (claimed) {
            final passes = claimant.live && _Unsolicited.isInputRequest(event);
            if (passes) {
              // Held back, the request could not be answered while the turn
              // waits on it, and the queued prompt would wait behind that.
              claimedShown = true;
              yield UnsolicitedEvent(event);
              notePassed(event);
            } else if (!_Unsolicited.isInputRequest(event)) {
              // What a turn that is over asked is not shown: nobody can
              // answer it any more.
              claimedShown = true;
              yield UnsolicitedEvent(event);
              claimedFrame(event);
            }
            if (claimant.live) {
              if (!finishing && !claimant.ended) {
                finishing = true;
                yield const ReplyStatus(_finishingInterruptedTurn);
              } else if (finishing && claimant.ended) {
                finishing = false;
                yield const ReplyStatus('');
              }
            }
            // Nobody can answer what the turn asked once it is over.
            if (claimant.ended) {
              if (takeWithdrawn() case final withdrawn?) {
                yield UnsolicitedEvent(withdrawn);
              }
            }
            // The turn's end starts the prompt's clock, as a running turn's
            // does for a queued one.
            if (claimant.ended) submittedAt = clock.now();
            continue;
          }
          final wasEnded = gate?.ended ?? true;
          final admittedNow = gate == null ? [event] : gate.admit(event);
          // The running turn's end starts the queued turn's clock: an idle
          // report right after it is stale, however long that turn took.
          if (!wasEnded && gate!.ended) submittedAt = clock.now();
          for (final admitted in admittedNow) {
            started = started || beginsTurn(admitted);
            errored = errored || admitted is ReplyErrored;
            final idle = admitted is SessionInfo && admitted.running == false;
            final settled =
                idle &&
                settles(
                  started: started,
                  submittedAt: submittedAt,
                  now: clock.now(),
                );
            // A report that does not settle the reply may still carry the
            // thread's new stored id, which the controller follows.
            final ChatEvent? shown;
            if (idle && !settled) {
              final stored = admitted.storedSessionId;
              shown = stored == null
                  ? null
                  : SessionInfo(storedSessionId: stored);
            } else {
              shown = admitted;
            }
            if (shown != null) yield shown;
            if (shown is ReplyCompleted || settled) {
              _turnSettled(admitted, errored: errored);
              // The session goes on listening: Hermes may chain another turn.
              final displaced = _idle.remove(owner);
              _idle[owner] = watch;
              _notifyOwned(owner, watch);
              watch.release();
              parked = true;
              await displaced?.close();
              return;
            }
          }
        }
        // The connection died before the turn finished. Hermes keeps running
        // it, so pick it back up on a fresh connection rather than failing a
        // reply that is still on its way.
        if (stopped.value) return;
        final made = drops.dropped();
        if (made >= _maxReplyReconnects) {
          if (finishing) yield const ReplyStatus('');
          if (takeWithdrawn() case final withdrawn?) {
            yield UnsolicitedEvent(withdrawn);
          }
          if (claimedShown) yield const ThreadNeedsRefetch();
          throw const GatewayConnectionClosed();
        }
        drops.attempt();
        final resumed = await _reattach(
          owner,
          runtimeId: runtimeId,
          shown: mine,
          drops: made,
          cancelled: () => stopped.value,
        );
        await watch.close();
        if (stopped.value) {
          resumed.discard();
          return;
        }
        _endReply(runtimeId, owner);
        _moveRequests(mine, runtimeId, resumed.runtimeId);
        runtimeId = resumed.runtimeId;
        _beginReply(runtimeId, owner);
        if (_reclaimOf(resumed.ended) case final reclaim?) {
          resumed.discard();
          yield reclaim;
          return;
        }
        final live = resumed.watch;
        if (live == null) {
          if (finishing) {
            finishing = false;
            yield const ReplyStatus('');
          }
          // A prompt queued behind a running turn keeps the gate across the
          // drop: what the replay holds of the turn ahead of it is not this
          // reply's. The same goes for a turn of Hermes' own: what the replay
          // holds of it is handed over ahead of the prompt's.
          final gating = gate != null && !gate.ended;
          final own = <_Incoming>[];
          final claimedNow = <_Incoming>[];
          for (final incoming in resumed.ended) {
            if (unsolicited != null && unsolicited.claims(incoming.$1)) {
              claimedNow.add(incoming);
            } else {
              own.add(incoming);
            }
          }
          // A turn that ended in the replay asks nothing of the user any more:
          // what it raised is not shown, and what the send showed is withdrawn.
          final claimedOver = unsolicited?.ended ?? false;
          if (_rotatedIn(resumed.ended, storedId) case final rotated?) {
            final next = (profile, rotated);
            _rekey(owner, next);
            owner = next;
            storedId = rotated;
          }
          if (resumed.idle case final idle?) await _park(owner, idle);
          for (final (event, serverRequest) in claimedNow) {
            final ask = _Unsolicited.isInputRequest(event);
            if (ask && claimedOver) continue;
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            claimedShown = true;
            if (ask) {
              notePassed(event);
            } else {
              claimedFrame(event);
            }
            yield UnsolicitedEvent(event);
          }
          // When the replay ends the reply with nothing of its own, the idle
          // report settles it and the refetch the gate asks for reads the
          // thread.
          final holding = gating || claimedShown;
          var completed = false;
          final yielded = <ChatEvent>[];
          for (final (event, serverRequest) in own) {
            _track(event, runtimeId, mine, serverRequest: serverRequest);
            for (final admitted in gating ? gate.admit(event) : [event]) {
              completed = completed || admitted is ReplyCompleted;
              yielded.add(admitted);
              yield admitted;
            }
          }
          // The session is idle, so nothing the claimed turn asked is open,
          // whether or not the replay held its end.
          if (takeWithdrawn() case final withdrawn?) {
            yield UnsolicitedEvent(withdrawn);
          }
          if (holding && !completed && !resumed.giveUp) {
            yielded.add(const SessionInfo(running: false));
            yield const SessionInfo(running: false);
            // The prompt's own turn is still to come on the follow-ups; it
            // is the reply settled here, so its end is not counted again. A
            // replay that could not be trusted says nothing of that turn.
            if (!resumed.truncated && !resumed.epochChanged) {
              _settledEarly.add(owner);
            }
          }
          if (resumed.giveUp) {
            if (claimedShown &&
                !yielded.any((event) => event is ThreadNeedsRefetch)) {
              yield const ThreadNeedsRefetch();
            }
            throw const GatewayConnectionClosed();
          }
          _reportSettled(yielded, errored: errored);
          return;
        }
        watch = live;
        drops.reconnected(clock.now());
        // The server reported the resumed session running, so its turn began,
        // unless that turn is still the one a queued prompt waits behind.
        if (gate?.ended ?? true) started = true;
      }
    } finally {
      _forgetRequests(mine);
      _endReply(runtimeId, owner);
      if (!parked) await watch.close();
    }
  }
}

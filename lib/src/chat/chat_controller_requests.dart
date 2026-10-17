part of 'chat_controller.dart';

/// Approval, clarification, vault answers, and interrupt queue holds.
extension _ChatControllerRequests on ChatController {
  ChatMessage? _replyAwaiting(ChatThread thread, String requestId) {
    for (final message in thread.messages.reversed) {
      if (message.inputRequests.any((r) => r.requestId == requestId)) {
        return message;
      }
    }
    return null;
  }

  Future<bool?> _answerWhileActive(Future<bool> Function() call) async {
    if (!active) return null;
    final epoch = _activityEpoch;
    try {
      final result = await call();
      return _currentActivity(epoch) ? result : null;
    } on Object {
      if (!_currentActivity(epoch)) return null;
      rethrow;
    }
  }

  Future<void> _answerApprovalImpl(
    ChatThread thread,
    String requestId,
    String choice,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final accepted = await _answerWhileActive(
      () => transport.answerApproval(requestId, choice),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordApproval(reply, requestId, choice)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  _Hold _holdOf(ChatThread thread) => _holds[thread] ?? _Hold.none;

  void _setHold(ChatThread thread, _Hold hold) {
    if (hold == _Hold.none) {
      _holds.remove(thread);
    } else {
      _holds[thread] = hold;
    }
  }

  bool _interruptInFlight(ChatThread thread) => (_interrupts[thread] ?? 0) > 0;

  /// Settles the hold of [thread] when its turn ends, and tells whether the
  /// queue may go on. A stopped or failed turn ([halted]) pauses it, and while
  /// an interrupt is still in flight the pause outlasts the turn, so that
  /// interrupt's answer cannot release it. [idleOnly]: the turn ended on an
  /// idle report, not a completion, so a stop asked for may still be what ended
  /// it and its answer decides.
  bool _turnEnded(
    ChatThread thread, {
    bool halted = false,
    bool idleOnly = false,
  }) {
    final ready = _finishTurnHold(thread, halted: halted, idleOnly: idleOnly);
    ready ? _queueTurnReady.add(thread) : _queueTurnReady.remove(thread);
    return ready;
  }

  bool _finishTurnHold(
    ChatThread thread, {
    bool halted = false,
    bool idleOnly = false,
  }) {
    if (_suspendedQueues.contains(thread)) return false;
    final afterwards = _interruptInFlight(thread) ? _Hold.paused : _Hold.none;
    if (halted) {
      _setHold(thread, afterwards);
      return false;
    }
    switch (_holdOf(thread)) {
      case _Hold.none:
        return true;
      case _Hold.paused || _Hold.stopping:
        _setHold(thread, afterwards);
        return false;
      case _Hold.asked || _Hold.askedEnded:
        if (idleOnly) {
          _setHold(thread, _Hold.askedEnded);
          return false;
        }
        // A completion that is not a stop answers the question: the turn
        // finished by itself.
        _setHold(thread, _Hold.none);
        return true;
    }
  }

  /// Ends one interrupt of [thread]. True while others are still in flight.
  bool _endInterrupt(ChatThread thread) {
    final left = (_interrupts[thread] ?? 1) - 1;
    if (left > 0) {
      _interrupts[thread] = left;
    } else {
      _interrupts.remove(thread);
    }
    return left > 0;
  }

  Future<void> _stopReplyImpl(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (!active) return;
    final epoch = _activityEpoch;
    _finishQueueBinding(thread, false);
    final pending = [
      for (final reply in thread.messages)
        if (reply.isPending) reply,
    ];
    final generation = _generations[thread] ?? 0;
    _interrupts.update(thread, (n) => n + 1, ifAbsent: () => 1);
    if (thread.isReplying && _holdOf(thread) == _Hold.none) {
      _setHold(thread, _Hold.asked);
    }
    try {
      final stopped = await transport?.stopReply(thread.id, profile: _profile);
      if (!_currentActivity(epoch)) return;
      if ((_generations[thread] ?? 0) != generation) return;
      final others = _endInterrupt(thread);
      final hold = _holdOf(thread);
      if (stopped == true) {
        // The turn is going to end stopped. If it ended already, this answer
        // only releases what its end left.
        _setHold(thread, switch (hold) {
          _Hold.asked => _Hold.stopping,
          _Hold.askedEnded ||
          _Hold.paused => others ? _Hold.paused : _Hold.none,
          _ => hold,
        });
        return;
      }
      if (stopped != false) {
        _setHold(thread, others ? hold : _Hold.none);
        return;
      }
      final stale = [
        for (final reply in pending)
          if (reply.isPending && thread.messages.contains(reply)) reply,
      ];
      if (stale.isNotEmpty) {
        // The server has no turn left to interrupt. A completion was missed by
        // this listener, so release the stale pending reply and composer.
        _setHold(
          thread,
          others || hold == _Hold.stopping || hold == _Hold.paused
              ? _Hold.paused
              : _Hold.none,
        );
        for (final reply in stale) {
          _updateReply(
            thread,
            reply,
            () =>
                applyReplyEvent(reply, const ReplyCompleted('', stopped: true)),
          );
        }
        liveActivities?.onEvent(
          thread,
          const ReplyCompleted('', stopped: true),
        );
        _watchSource?.drop(thread);
        return;
      }
      // Nothing was running: the turn ended on its own. Only the stop that
      // held the queue lets it go on, and only when no other is in flight.
      if (others) return;
      switch (hold) {
        case _Hold.asked || _Hold.askedEnded:
          _setHold(thread, _Hold.none);
          _drainQueue(thread);
        case _Hold.paused:
          _setHold(thread, _Hold.none);
        default:
          break;
      }
    } on Object {
      if (!_currentActivity(epoch)) return;
      // The stop of an earlier reply failing is of no use to say.
      if ((_generations[thread] ?? 0) != generation) return;
      final others = _endInterrupt(thread);
      if (!others) {
        // The interrupt did not get through, so it decides nothing: the queue
        // goes on with the turn's own end.
        switch (_holdOf(thread)) {
          case _Hold.asked:
            _setHold(thread, _Hold.none);
            _awaitSettle(thread);
          case _Hold.askedEnded:
            _setHold(thread, _Hold.none);
            _drainQueue(thread);
          case _Hold.paused:
            _setHold(thread, _Hold.none);
          default:
            break;
        }
      }
      report(_couldNotStop);
    }
  }

  Future<void> _skipUnsupportedImpl(
    ChatThread thread,
    String requestId,
    UnsupportedKind kind,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final accepted = await _answerWhileActive(
      () => transport.skipUnsupported(requestId, kind),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordSkipped(reply, requestId)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> _answerVaultRequestImpl(
    ChatThread thread,
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final declined = identifier.isEmpty && password.isEmpty && code.isEmpty;
    final accepted = await _answerWhileActive(
      () => transport.answerVault(
        requestId,
        kind,
        identifier: identifier,
        password: password,
        code: code,
      ),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? declined
                ? recordVaultDeclined(reply, requestId)
                : recordVaultAnswered(reply, requestId, identifier: identifier)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> _answerClarifyImpl(
    ChatThread thread,
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final request = reply.inputRequests.firstWhere(
      (r) => r.requestId == requestId,
    );
    if (request is! ClarifyRequest) return;

    final epoch = _activityEpoch;
    bool? accepted = true;
    if (answers.isEmpty) {
      accepted = await _answerWhileActive(
        () => transport.answerClarify(requestId, const []),
      );
    } else {
      for (final q in request.questions) {
        if (!_currentActivity(epoch) ||
            _sessionStates[thread]?.reclaimedReason != null) {
          return;
        }
        accepted = await _answerWhileActive(
          () => transport.answerClarify(
            requestId,
            answers[q.qid] ?? const [],
            questionId: request.batch ? q.qid : null,
            multiSelect: q.multiSelect,
          ),
        );
        if (accepted != true) break;
      }
    }
    if (accepted == null || !_currentActivity(epoch)) return;
    _updateReply(
      thread,
      reply,
      () => accepted!
          ? recordClarifyAnswers(reply, requestId, answers)
          : expireInputRequests(reply, requestId: requestId),
    );
  }
}

/// Why a thread's queue is held while an interrupt is in flight.
enum _Hold {
  none,

  /// The user asked to stop; the answer or the turn's end decides.
  asked,

  /// The turn ended on an idle report while a stop was still unanswered.
  askedEnded,

  /// The server confirmed the interrupt: the turn's end pauses the queue.
  stopping,

  /// The turn ended stopped or failed while an interrupt was in flight.
  paused,
}

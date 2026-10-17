part of 'chat_controller.dart';

/// Follow-up turns and mapping streamed events into chat messages.
extension _ChatControllerStreaming on ChatController {
  /// The prompt [reply] answers: the user message before it, which the turn
  /// Hermes ran ahead of it goes in front of. The server stores it there too.
  ChatMessage _promptOf(ChatThread thread, ChatMessage reply) {
    final at = thread.messages.indexOf(reply);
    final user = thread.messages
        .take(at < 0 ? thread.messages.length : at)
        .toList()
        .lastIndexWhere((m) => m.role == ChatRole.user);
    return user < 0 ? reply : thread.messages[user];
  }

  /// An event of the turn Hermes ran on its own ahead of the prompt that
  /// [reply] answers. It streams into a reply of its own, in front of the
  /// prompt, while [reply] keeps waiting for its turn; the turn's end closes
  /// it. The turn belongs to the send: its end does not settle the queue or
  /// touch a stop in flight.
  void _onOwnTurnEvent(
    ChatThread thread,
    ChatMessage reply,
    _OwnTurn own,
    ChatEvent event,
    String? profile,
  ) {
    if (_onMoaEvent(thread, own.open, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    // The transport takes an idle report for the turn's end only once the turn
    // has begun; so does this. An approval alone does not begin it.
    if (beginsTurn(event)) own.began = true;
    final asks =
        event is ApprovalRequested ||
        event is ClarifyRequested ||
        event is VaultRequested ||
        event is UnsupportedRequested;
    if (own.open == null &&
        (opensTurn(event) ||
            asks ||
            // A snapshot of a turn already running, and a failure before any
            // frame of it, are the turn's too.
            (event is ReplyRebuilt || event is ReplyErrored) &&
                own.last == null)) {
      own.open = own.last = _insertReply(
        thread,
        before: _promptOf(thread, reply),
      );
    }
    final open = own.open;
    if (open == null) {
      // Nothing of the turn is on screen to carry it.
      final last = own.last;
      switch (event) {
        case ReplyCompleted() when last?.settledWithoutCompletion ?? false:
          // The turn settled on an idle report; its completion comes late.
          _onReplyEvent(
            thread,
            last!,
            event,
            profile,
            announce: event.failed,
            settles: false,
          );
          last.settledWithoutCompletion = false;
        case InputRequestsCancelled() || InputRequestExpired():
          if (last != null) {
            _onReplyEvent(thread, last, event, profile, announce: false);
          }
        case ReplyErrored(:final message):
          // The turn failed with no reply to show it; the hold of the send in
          // flight is not its to end.
          if (message.isNotEmpty) report(message);
        case SessionInfo(:final storedSessionId?) when storedSessionId != '':
          _onSessionInfo(
            thread,
            SessionInfo(storedSessionId: storedSessionId),
            settle: false,
          );
        case ThreadTitled(:final title):
          _titled(thread, title);
          notifyListeners();
        case ThreadNeedsRefetch():
          _refetch.add(thread);
          _invalidateMoaReferences(thread);
        default:
          break;
      }
      return;
    }
    final idle = event is SessionInfo && event.running == false;
    if (idle && !own.began) {
      // Hermes may still wait on what the turn asked: only a re-keyed id goes
      // on.
      if (event.storedSessionId case final stored? when stored != '') {
        _onSessionInfo(
          thread,
          SessionInfo(storedSessionId: stored),
          settle: false,
        );
      }
      return;
    }
    _onReplyEvent(thread, open, event, profile, settles: false, ownTurn: true);
    if (event is ReplyCompleted || idle) own.open = null;
  }

  /// Ends the reply of the turn Hermes ran on its own when the send is over:
  /// settled when the send ended well, failed when it gave up. A failure is
  /// announced here only when the prompt's reply, which announces its own, is
  /// no longer pending to do so.
  void _closeOwnTurn(
    ChatThread thread,
    _OwnTurn own,
    String? profile, {
    required bool failed,
    required bool announceFailure,
  }) {
    final epoch = _activityEpoch;
    final open = own.open;
    own.open = null;
    if (open != null) _finishMoaTurn(thread, open);
    if (open == null || !open.isPending) return;
    _updateReply(
      thread,
      open,
      () => failed
          ? failReply(open, null)
          : applyReplyEvent(open, const SessionInfo(running: false)),
    );
    if (!_currentActivity(epoch)) return;
    if (failed && announceFailure) {
      _announce(thread, const ReplyCompleted('', failed: true), profile);
    }
  }

  /// [thread]'s turn can no longer be followed, so nothing would end what the
  /// Lock Screen and the watch show of it.
  void _abandon(ChatThread thread) {
    liveActivities?.abandon(thread);
    _watchSource?.abandon(thread);
  }

  void _stopFollowing() {
    _cancelOwnedSubscription();
    _clearBilling();
    _clearReactions();
    _clearTodo();
    _clearConnectors();
    _clearMoa();
    for (final controller in _usage.values) {
      controller.dispose();
    }
    _usage.clear();
    for (final state in _sideResults.values) {
      state.dispose();
    }
    _sideResults.clear();
    for (final state in _processOutputs.values) {
      state.clear();
    }
    _processOutputs.clear();
    _ownedBindings.clear();
    _sessionActionGenerations.clear();
    _sessionStates.clear();
    _reclaimedQueueReview.clear();
    for (final state in _warnings.values) {
      state.clear();
    }
    _warnings.clear();
    _warningGenerations.clear();
    // A turn nobody listens to any more can no longer say it ended.
    for (final thread in _threads) {
      if (_followingIds.contains(thread.id) && !_sending.containsKey(thread)) {
        _abandon(thread);
      }
    }
    for (final subscription in _following) {
      subscription.cancel();
    }
    _following.clear();
    _followingIds.clear();
  }

  /// A turn another client submitted carries no user message on the wire: the
  /// gateway streams only what the agent produced, and the prompt lives in the
  /// stored history alone. When such a turn ends here, the thread is read
  /// again so the prompt the other side sent appears in the transcript.
  void _refetchForeignTurn(ChatThread thread) {
    if (_sending.containsKey(thread)) return;
    _refetch.add(thread);
    _refetchIfIdle(thread);
  }

  /// Hermes can chain turns on its own once a reply ended (a goal that goes
  /// on, a queued prompt); each one gets a reply of its own.
  void _followUps(ChatTransport transport, ChatThread thread, String? profile) {
    _listenOwnedSessions();
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (!active || _profile != profile || !_threads.contains(thread)) return;
    final epoch = _activityEpoch;
    final threadId = thread.id;
    if (!_followingIds.add(threadId)) return;
    ChatMessage? reply;
    late final StreamSubscription<ChatEvent> subscription;
    void end([Object? error]) {
      if (!_currentActivity(epoch)) return;
      _following.remove(subscription);
      _followingIds.remove(thread.id);
      if (error != null || !_sending.containsKey(thread)) {
        _discardWarnings(thread);
      }
      if (!disposed) notifyListeners();
      final pending = reply;
      if (pending != null) _finishMoaTurn(thread, pending);
      if (pending != null && pending.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, pending, () => failReply(pending, error));
        if (!_currentActivity(epoch)) return;
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      }
    }

    subscription = transport
        .followUps(threadId, profile: profile)
        .listen(
          (event) {
            if (!_currentActivity(epoch)) return;
            if (reply == null && opensTurn(event)) {
              // A stop in flight may be aimed at the turn this opens a reply
              // for (a folded prompt's), so the hold stays.
              reply = _addPlaceholder(thread);
            }
            final current = reply;
            if (current == null) {
              _onIdleEvent(thread, event, profile);
              return;
            }
            _onReplyEvent(thread, current, event, profile);
            if (!_currentActivity(epoch)) return;
            if (event is ReplyCompleted) {
              reply = null;
              final drain = _turnEnded(
                thread,
                halted: event.failed || event.stopped,
              );
              if (drain) _awaitSettle(thread);
              _refetchForeignTurn(thread);
              unawaited(refreshActive());
            } else if (event is SessionInfo && event.running == false) {
              // The session reports the turn over without a completion. It is
              // closed all the same, so the next chained turn gets a reply of
              // its own, and the queue goes on now that the session settled.
              reply = null;
              final drain = _turnEnded(
                thread,
                halted: current.status == MessageStatus.error,
                idleOnly: true,
              );
              if (drain) _drainQueue(thread);
              _refetchForeignTurn(thread);
              unawaited(refreshActive());
            }
          },
          onError: end,
          onDone: end,
          cancelOnError: true,
        );
    _following.add(subscription);
  }

  /// An event on the follow-ups while no reply is open. It is about the
  /// thread, or a completion for the reply a turn ended without.
  void _onIdleEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (_onMoaEvent(thread, null, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    switch (event) {
      case SessionInfo(:final running):
        // The turn a stop in flight was aimed at ended with no reply open.
        if (running == false) _turnEnded(thread, idleOnly: true);
        _onSessionInfo(thread, event);
      case ThreadTitled(:final title):
        _titled(thread, title);
        notifyListeners();
      case ReviewSummarized():
        _onReviewSummary(thread, event);
      case SubagentUpdated():
        final owner = _subagentOwner(thread, event);
        if (owner == null) return;
        _updateReply(thread, owner, () => applyReplyEvent(owner, event));
      case ThreadNeedsRefetch():
        _refetch.add(thread);
        _refetchIfIdle(thread);
        _invalidateMoaReferences(thread);
      case ReplyErrored(:final message):
        // A failure with no reply open to show it, from a turn that never
        // began. It pauses the queue like any failure, and says so.
        _settleTimers.remove(thread)?.cancel();
        _turnEnded(thread, halted: true);
        if (message.isNotEmpty) report(message);
      case ReplyCompleted():
        final settled = _settledReply(thread);
        if (settled == null) return;
        // The settle announced this reply already; a failure is news.
        _onReplyEvent(thread, settled, event, profile, announce: event.failed);
        settled.settledWithoutCompletion = false;
      default:
        break;
    }
  }

  /// Puts what the background review saved under the reply it read: the
  /// latest one that has finished. The review runs after its turn, so a reply
  /// still being written ([open]) is the next turn's.
  void _onReviewSummary(
    ChatThread thread,
    ReviewSummarized event, {
    ChatMessage? open,
  }) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.assistant) continue;
      if (identical(message, open) || message.isPending) continue;
      _updateReply(thread, message, () => applyReplyEvent(message, event));
      return;
    }
  }

  /// The reply that spawned the subagent [event] names. A child delegated
  /// in the background outlives that reply, so its later frames arrive on
  /// the follow-ups, between turns or during another one.
  ChatMessage? _subagentOwner(ChatThread thread, SubagentUpdated event) {
    for (final message in thread.messages.reversed) {
      if (message.subagents.any((s) => s.id == event.subagent.id)) {
        return message;
      }
    }
    return null;
  }

  /// The reply a turn ended without its completion, which a completion
  /// arriving later belongs to. Only the thread's last assistant message can
  /// be it: once another turn started, a completion is not its.
  ChatMessage? _settledReply(ChatThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.assistant) continue;
      return message.settledWithoutCompletion ? message : null;
    }
    return null;
  }

  /// Follows the session's stored id when compression rotates it, and
  /// settles the queue when the session reports it is no longer running.
  void _onSessionInfo(
    ChatThread thread,
    SessionInfo info, {
    bool settle = true,
  }) {
    final stored = info.storedSessionId;
    if (stored != null && stored.isNotEmpty && stored != thread.id) {
      if (_bound.contains(thread)) {
        _retargetBoundThread(thread, stored);
      } else {
        _bindThread(thread, stored);
      }
    }
    if (info.running == false) _queueSettled.add(thread);
    if (info.running == true) _queueSettled.remove(thread);
    if (settle && info.running == false) _settle(thread);
  }

  /// Takes [reply] out of the transcript, for a prompt the server folded into
  /// the turn already running: no reply of its own was shown for it.
  void _removeReply(ChatThread thread, ChatMessage reply) {
    final before = chatMessageToFlyer(reply);
    thread.messages.remove(reply);
    notifyListeners();
    syncMessage(controllerFor(thread), before, const []);
  }

  /// Reads the thread again once it asked for that and no reply is pending.
  void _refetchIfIdle(ChatThread thread) {
    if (thread.isReplying || !_refetch.remove(thread)) return;
    unawaited(refreshThread(thread.id));
  }

  void _onReplyEvent(
    ChatThread thread,
    ChatMessage reply,
    ChatEvent event,
    String? profile, {
    bool announce = true,
    bool settles = true,
    bool ownTurn = false,
  }) {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return;
    if (opensTurn(event)) _beginMoaTurn(thread, reply);
    if (_onMoaEvent(thread, reply, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    if (event is ReplyCompleted ||
        event is ReplyErrored ||
        event is PromptFolded ||
        event is SessionInfo && event.running == false) {
      _finishMoaTurn(thread, reply);
    }
    var announced = event;
    switch (event) {
      case ThreadBound(:final threadId):
        _bindThread(thread, threadId);
        _syncTodo(thread, profile);
        _syncOwnedSession(thread, profile);
        _syncConnector(thread, profile);
        if (!_currentActivity(epoch)) return;
        final source = transport;
        final binding = source is OwnedSessionTransport
            ? (source as OwnedSessionTransport).ownedSessionFor(
                thread.id,
                profile: profile,
              )
            : null;
        if (binding != null && (profile?.isNotEmpty ?? false)) {
          _adoptBilling((profile, thread.id), binding);
        }
      case ThreadTitled(:final title):
        _titled(thread, title);
        notifyListeners();
      case ReplyStarted() ||
          UnsolicitedEvent() ||
          PromptAcknowledged() ||
          PromptAccepted():
      case ConnectorOperationReceived() ||
          BillingVerificationReceived() ||
          MessageReactionsUpdated() ||
          SessionAcknowledgementReported() ||
          SideResultReceived() ||
          MoaUpdated() ||
          ProcessOutputReceived() ||
          SessionUsageUpdated() ||
          ToolRiskFlagged() ||
          NoticeShown() ||
          NoticeCleared() ||
          TodoUpdated() ||
          SessionControlUpdated() ||
          SessionControlUnavailable() ||
          SessionWaitUpdated() ||
          SessionReclaimed() ||
          SessionResumeProgress() ||
          WarningScopeDiscarded():
        break;
      case PromptFolded():
        _removeReply(thread, reply);
      case SessionInfo():
        final wasPending = reply.isPending;
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
        if (!_currentActivity(epoch)) return;
        _onSessionInfo(thread, event, settle: settles);
        if (wasPending && !reply.isPending) {
          // The turn ended without a completion, which the notifications wait
          // for: tell them how it ended.
          announced = ReplyCompleted(
            reply.content,
            failed: reply.status == MessageStatus.error,
            stopped: switch (_holdOf(thread)) {
              _Hold.stopping || _Hold.paused => true,
              _ => false,
            },
          );
        }
      case ThreadNeedsRefetch():
        _refetch.add(thread);
        _invalidateMoaReferences(thread);
      case ReviewSummarized():
        _onReviewSummary(thread, event, open: reply);
      case SubagentUpdated():
        final owner = _subagentOwner(thread, event) ?? reply;
        _updateReply(thread, owner, () => applyReplyEvent(owner, event));
      case ReplyErrored() ||
          ReplyStatus() ||
          InputRequestsCancelled() ||
          ReplyRebuilt():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
      case ReplyDelta() ||
          ReplyCheckpoint() ||
          ReasoningUpdated() ||
          ToolPreparing() ||
          ToolStarted() ||
          ToolFinished() ||
          ReplyCompleted() ||
          ApprovalRequested() ||
          ClarifyRequested() ||
          VaultRequested() ||
          UnsupportedRequested() ||
          InputRequestExpired():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
        if (event case ToolStarted(:final id, :final runtimeId)) {
          _warningState(thread, runtimeId);
          final generation = _warningGeneration(thread);
          final index = reply.toolCalls.lastIndexWhere(
            (call) => call.id == id && call.runtimeId == runtimeId,
          );
          if (index >= 0) {
            _updateReply(
              thread,
              reply,
              () => reply.toolCalls = [...reply.toolCalls]
                ..[index] = reply.toolCalls[index].copyWith(
                  warningGeneration: generation,
                ),
            );
          }
          _attachRisk(thread, reply, id, runtimeId);
        }
    }
    if (!_currentActivity(epoch)) return;
    _refetchIfIdle(thread);
    _announce(thread, announced, profile, notify: announce, ownTurn: ownTurn);
  }

  void _updateReply(
    ChatThread thread,
    ChatMessage reply,
    void Function() edit,
  ) {
    if (!active) return;
    final epoch = _activityEpoch;
    final before = chatMessageToFlyer(reply);
    final wasPending = reply.isPending;
    final openBefore = _openRequestIds(reply);
    edit();
    notifyListeners();
    if (!_currentActivity(epoch)) return;
    syncMessage(controllerFor(thread), before, chatMessageToFlyer(reply));
    if (onSurfaceChange == null) return;
    final trigger = wasPending && !reply.isPending
        ? SurfaceTrigger.reply
        : _openRequestIds(reply) != openBefore
        ? SurfaceTrigger.request
        : null;
    if (trigger == null) return;
    _touched[thread] = DateTime.now();
    _reportSurface(trigger);
  }
}

/// The reply a send opened for the turn Hermes ran on its own ahead of the
/// prompt. [last] stays after the turn ended, so a withdrawal of its requests
/// still finds it.
class _OwnTurn {
  ChatMessage? open;
  ChatMessage? last;

  /// Whether a frame that begins a turn has come: before that, an idle report
  /// is not the turn's end.
  var began = false;
}

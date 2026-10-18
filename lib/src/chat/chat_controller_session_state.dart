part of 'chat_controller.dart';

/// Session lifecycle reports, recovery actions, warnings, and notices.
extension _ChatControllerSessionState on ChatController {
  bool _sessionActionCurrent(ChatThread thread, int generation) =>
      _sessionActionGenerations[thread] == generation &&
      _threads.contains(thread);

  void _invalidateSessionActions(ChatThread thread) {
    _sessionActionGenerations[thread] = ++_nextSessionActionGeneration;
    _undoing.remove(thread);
    _turnProblems.remove(thread);
  }

  ChatSessionState? _sessionStateInImpl(ChatThread thread) =>
      _sessionStates[thread];

  void _sessionDetailsOpenedImpl() => breadcrumbs('chat.visibility_action', {
    'feature': 'session_state',
    'action': 'details',
  });

  void _reopenSessionImpl(ChatThread thread) {
    if (!active || !_threads.contains(thread)) return;
    breadcrumbs('chat.visibility_action', {
      'feature': 'session_state',
      'action': 'reopen',
    });
    _invalidateSessionActions(thread);
    _sessionStates.remove(thread);
    select(thread.id);
  }

  bool _onSessionEvent(ChatThread thread, ChatEvent event, String? profile) {
    final runtime = switch (event) {
      SessionControlUpdated(:final runtimeId) => runtimeId,
      SessionControlUnavailable(:final runtimeId) => runtimeId,
      SessionWaitUpdated(:final runtimeId) => runtimeId,
      SessionReclaimed(:final runtimeId) => runtimeId,
      SessionResumeProgress(:final runtimeId) => runtimeId,
      _ => null,
    };
    if (runtime == null) return false;
    if (!active || _profile != profile || !_threads.contains(thread)) {
      return true;
    }
    if (event is SessionReclaimed &&
        thread.remote &&
        thread.id != event.storedSessionId) {
      return true;
    }
    final state = _sessionStates.putIfAbsent(thread, ChatSessionState.new);
    if (state.reclaimedReason != null && state.runtimeId == runtime) {
      return true;
    }
    if (state.runtimeId != null && state.runtimeId != runtime) {
      _invalidateSessionActions(thread);
    }
    state.adopt(runtime);
    var outcome = 'applied';
    switch (event) {
      case SessionControlUpdated(:final control):
        state.control = control;
      case SessionControlUnavailable():
        outcome = 'unavailable';
      case SessionWaitUpdated(:final kind, :final text):
        if (state.recordMemoryRecall(text) || text.isEmpty) {
          state.waits.remove(kind);
        } else {
          state.waits[kind] = text;
          if (state.waits.length > 16) {
            state.waits.remove(state.waits.keys.first);
          }
        }
      case SessionResumeProgress(:final progress):
        state.resume = progress;
      case SessionReclaimed(:final reason):
        _invalidateSessionActions(thread);
        state.reclaimedReason = reason;
        _removeMoa(thread);
        _finishQueueBinding(thread, false);
        state.waits.clear();
        _settleTimers.remove(thread)?.cancel();
        if (_queues[thread]?.isNotEmpty ?? false) {
          _reclaimedQueueReview.add(thread);
        }
        _active.remove(thread.id);
        _discardWarnings(thread);
        for (final reply in thread.messages) {
          if (reply.role != ChatRole.assistant) continue;
          _updateReply(thread, reply, () {
            expireInputRequests(reply);
            if (reply.isPending) {
              applyReplyEvent(
                reply,
                ReplyCompleted(reply.content, stopped: true),
              );
            }
          });
        }
        outcome = 'reclaimed';
      default:
        break;
    }
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'session_state',
        'outcome': outcome,
      });
    } on Object {
      return true;
    }
    return true;
  }

  List<AgentNotice> _noticesInImpl(ChatThread thread) =>
      List.unmodifiable(_warnings[thread]?.notices ?? const <AgentNotice>[]);

  void _dismissNoticeImpl(ChatThread thread, AgentNotice notice) {
    _warnings[thread]?.dismiss(notice);
    _warningAction('dismiss');
  }

  void _warningDetailsOpenedImpl() => _warningAction('details');

  void _warningAction(String action) {
    try {
      breadcrumbs('chat.visibility_action', {
        'feature': 'warnings',
        'action': action,
      });
    } on Object catch (_) {}
  }

  ChatWarningState _warningState(ChatThread thread, String runtimeId) {
    final state = _warnings.putIfAbsent(
      thread,
      () => ChatWarningState(changed: notifyListeners),
    );
    if (state.runtimeId != null && state.runtimeId != runtimeId) {
      _warningGenerations[thread] = ++_nextWarningGeneration;
    }
    state.adopt(runtimeId);
    return state;
  }

  bool _onWarning(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! NoticeShown &&
        event is! NoticeCleared &&
        event is! ToolRiskFlagged &&
        event is! WarningScopeDiscarded) {
      return false;
    }
    if (_profile != profile) return true;
    switch (event) {
      case WarningScopeDiscarded():
        _discardWarnings(thread);
        notifyListeners();
      case NoticeShown(:final notice, :final runtimeId):
        _warningState(thread, runtimeId).show(notice);
      case NoticeCleared(:final key, :final runtimeId):
        _warningState(thread, runtimeId).withdraw(key);
      case ToolRiskFlagged(:final toolId, :final risk, :final runtimeId):
        final state = _warningState(thread, runtimeId);
        final generation = _warningGeneration(thread);
        state.risks[toolId] = risk;
        if (state.risks.length > 128) {
          state.risks.remove(state.risks.keys.first);
        }
        for (final message in thread.messages) {
          if (message.toolCalls.any(
            (call) =>
                call.id == toolId &&
                call.runtimeId == runtimeId &&
                call.warningGeneration == generation,
          )) {
            _attachRisk(thread, message, toolId, runtimeId);
            break;
          }
        }
      default:
        break;
    }
    try {
      events('gateway.visibility_outcome', {
        'feature': 'warnings',
        'outcome': event is WarningScopeDiscarded ? 'discarded' : 'applied',
      });
    } on Object catch (_) {}
    return true;
  }

  void _attachRisk(
    ChatThread thread,
    ChatMessage message,
    String toolId,
    String runtimeId,
  ) {
    final state = _warnings[thread];
    if (state == null || state.runtimeId != runtimeId) return;
    final generation = _warningGeneration(thread);
    final risk = state.risks[toolId];
    if (risk == null) return;
    _updateReply(
      thread,
      message,
      () => message.toolCalls = [
        for (final call in message.toolCalls)
          call.id == toolId &&
                  call.runtimeId == runtimeId &&
                  call.warningGeneration == generation
              ? call.copyWith(outputRisk: risk)
              : call,
      ],
    );
  }
}

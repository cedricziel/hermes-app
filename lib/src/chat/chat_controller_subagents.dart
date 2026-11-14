part of 'chat_controller.dart';

/// The agents of each chat: one roster per thread, fed by the thread's
/// `subagent.*` frames and read through `subagent.list`.
extension _ChatControllerSubagents on ChatController {
  SubagentRoster? _subagentsInImpl(ChatThread thread) {
    final source = transport;
    if (!active ||
        !thread.remote ||
        !_threads.contains(thread) ||
        source is! AgentWorkTransport) {
      return null;
    }
    final existing = _subagents[thread.id];
    if (existing != null && existing.profile == _profile) {
      existing.retarget(thread.id);
      return existing;
    }
    existing?.dispose();
    final created = SubagentRoster(
      threadId: thread.id,
      profile: _profile,
      repository: SubagentRepository(
        source as AgentWorkTransport,
        telemetry: usageTelemetry,
      ),
      env: _subagentEnvironment ??= ChatRosterEnvironment(
        transport: source,
        activity: activity,
        covered: appLock == null ? null : () => appLock!.covered,
        lockChanges: appLock,
      ),
      programs: _ChatProgramCards(this),
      events: events,
    );
    return _subagents[thread.id] = created;
  }

  /// The program cards changed by a list read or a kill answer.
  void _programCardsChanged() {
    if (active) notifyListeners();
  }

  /// Gives a frame to the roster of its thread. A thread that is not a stored
  /// chat yet has no roster to give it to; its first reply's frames reach
  /// it once the chat has its id (see `ThreadBound`).
  void _feedSubagent(ChatThread thread, Subagent subagent) {
    _subagentsInImpl(thread)?.applyFrame(subagent);
  }

  void _dropSubagents(String threadId) =>
      _subagents.remove(threadId)?.dispose();

  /// A chat's stored id changed (a compression rotated it): its roster goes
  /// with it, rows and all.
  void _rekeySubagents(String from, String to) {
    final roster = _subagents.remove(from);
    if (roster == null) return;
    _subagents.remove(to)?.dispose();
    roster.retarget(to);
    _subagents[to] = roster;
  }

  /// Sign-out, profile switch, a suspended session: nothing of the old
  /// agents stays.
  void _clearSubagents() {
    for (final roster in _subagents.values) {
      roster.dispose();
    }
    _subagents.clear();
  }
}

/// A chat's program cards as the roster sees them: the session's attachment
/// on the current connection and the [ProcessOutputState] scoped to it.
class _ChatProgramCards implements ProgramCards {
  _ChatProgramCards(this._chat);
  final ChatController _chat;

  @override
  Listenable get cardChanges => _chat;

  ChatThread? _thread(String threadId) =>
      _chat._threads.where((thread) => thread.id == threadId).firstOrNull;

  @override
  Object? attachmentOf(String threadId) {
    final source = _chat.transport;
    if (!_chat.active || source is! OwnedSessionTransport) return null;
    return (source as OwnedSessionTransport).ownedSessionFor(
      threadId,
      profile: _chat._profile,
    );
  }

  @override
  ProcessOutputState? cardsFor(
    String threadId,
    Object attachment, {
    bool create = false,
  }) {
    final thread = _thread(threadId);
    if (thread == null || attachmentOf(threadId) != attachment) return null;
    if (!create) {
      final state = _chat._processOutputs[thread];
      return state != null && state.hasScope(attachment) ? state : null;
    }
    final binding = _ChatControllerSessionBinding(_chat)
        ._syncOwnedSession(thread, _chat._profile);
    if (binding == null || binding != attachment) return null;
    return _chat._processOutputs.putIfAbsent(
      thread,
      () => ProcessOutputState()..adopt(binding),
    );
  }

  @override
  void cardsChanged() => _ChatControllerSubagents(_chat)._programCardsChanged();
}

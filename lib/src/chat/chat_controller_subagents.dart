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
    // Rosters of threads a reload replaced are gone with them.
    _subagents.removeWhere((owner, roster) {
      final stale = !_threads.contains(owner);
      if (stale) roster.dispose();
      return stale;
    });
    final existing = _subagents[thread];
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
      events: events,
    );
    return _subagents[thread] = created;
  }

  /// Gives a frame to the roster of its thread. A thread that is not a stored
  /// chat yet has no roster to give it to; its first reply's frames reach
  /// it once the chat has its id (see `ThreadBound`).
  void _feedSubagent(ChatThread thread, Subagent subagent) {
    _subagentsInImpl(thread)?.applyFrame(subagent);
  }

  void _dropSubagents(ChatThread thread) =>
      _subagents.remove(thread)?.dispose();

  /// Sign-out, profile switch, a suspended session: nothing of the old
  /// agents stays.
  void _clearSubagents() {
    for (final roster in _subagents.values) {
      roster.dispose();
    }
    _subagents.clear();
  }
}

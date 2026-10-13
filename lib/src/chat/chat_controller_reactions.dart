part of 'chat_controller.dart';

extension ReactionVisibility on ChatController {
  ReactionScope _reactionScope(
    ChatThread thread,
    OwnedSessionBinding binding,
  ) => ReactionScope(
    connection: binding.connection,
    lineage: thread,
    runtimeId: binding.runtimeId,
    profile: binding.profile,
  );

  /// Reported state only while the current protected attachment owns this thread.
  ReactionState? reactionsIn(ChatThread thread) {
    final state = _reactions[thread], binding = _ownedBindings[thread];
    final source = transport;
    if (!active ||
        !_threads.contains(thread) ||
        state == null ||
        binding == null ||
        binding.profile != _profile ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final actual = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    return actual == binding && state.hasScope(_reactionScope(thread, binding))
        ? state
        : null;
  }

  /// Reactions for the exact canonical row and role under the current owner.
  List<ReportedReaction>? reactionsFor(
    ChatThread thread,
    DurableReactionRow row,
  ) {
    final state = reactionsIn(thread), binding = _ownedBindings[thread];
    return state == null || binding == null
        ? null
        : state.reactionsFor(
            _reactionScope(thread, binding),
            row.rowId,
            role: row.role,
          );
  }

  bool _reactionOwnerCurrent(
    ChatThread thread,
    OwnedSessionBinding binding,
    int epoch,
  ) {
    final source = transport;
    return _currentActivity(epoch) &&
        _threads.contains(thread) &&
        _profile == binding.profile &&
        _ownedBindings[thread] == binding &&
        source is OwnedSessionTransport &&
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: _profile,
            ) ==
            binding;
  }

  void _syncReactions(ChatThread thread, OwnedSessionBinding binding) {
    final epoch = _activityEpoch;
    if (!_reactionOwnerCurrent(thread, binding, epoch)) return;
    final state = _reactions.putIfAbsent(
      thread,
      () =>
          ReactionState(events: events, breadcrumbs: breadcrumbs)
            ..addListener(notifyListeners),
    );
    final scope = _reactionScope(thread, binding);
    if (state.hasScope(scope)) return;
    state.adopt(scope);
    if (!_reactionOwnerCurrent(thread, binding, epoch) ||
        _reactions[thread] != state) {
      return;
    }
    state.historyLoaded(scope, [
      for (final message in thread.messages) ?message.canonicalRow,
    ]);
  }

  void _reactionHistory(ChatThread thread) {
    final state = reactionsIn(thread), binding = _ownedBindings[thread];
    if (state == null || binding == null) return;
    state.historyLoaded(_reactionScope(thread, binding), [
      for (final message in thread.messages) ?message.canonicalRow,
    ]);
  }

  void _clearReactions() {
    for (final state in _reactions.values) {
      state.dispose();
    }
    _reactions.clear();
  }

  bool _onReactionEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! MessageReactionsUpdated &&
        event is! SessionAcknowledgementReported) {
      return false;
    }
    final binding = _syncOwnedSession(thread, profile),
        state = _reactions[thread];
    if (binding == null ||
        state == null ||
        !state.hasScope(_reactionScope(thread, binding))) {
      return true;
    }
    final runtimeId = event is MessageReactionsUpdated
        ? event.runtimeId
        : (event as SessionAcknowledgementReported).runtimeId;
    final connection = event is MessageReactionsUpdated
        ? event.connection
        : (event as SessionAcknowledgementReported).connection;
    if (runtimeId != binding.runtimeId ||
        !identical(connection, binding.connection)) {
      return true;
    }
    if (event is MessageReactionsUpdated) {
      state.received(_reactionScope(thread, binding), event.snapshot);
    } else if (event is SessionAcknowledgementReported) {
      state.signal(_reactionScope(thread, binding), event.acknowledgement);
    }
    return true;
  }

  bool _assignPromptReceipt(
    ChatThread thread,
    ChatMessage user,
    PromptAcknowledged receipt,
    String? profile, {
    bool inserted = true,
  }) {
    final epoch = _activityEpoch;
    if (!active ||
        _profile != profile ||
        user.role != ChatRole.user ||
        receipt.userRowId <= 0 ||
        inserted && !thread.messages.contains(user)) {
      return false;
    }
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null ||
        receipt.runtimeId != binding.runtimeId ||
        !identical(receipt.connection, binding.connection)) {
      return false;
    }
    final row = DurableReactionRow(rowId: receipt.userRowId, role: 'user');
    if (inserted) {
      _updateReply(thread, user, () => user.canonicalRow = row);
      if (!_reactionOwnerCurrent(thread, binding, epoch)) return false;
      _reactionHistory(thread);
    } else {
      user.canonicalRow = row;
    }
    return true;
  }
}

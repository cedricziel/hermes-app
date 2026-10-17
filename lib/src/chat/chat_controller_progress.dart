part of 'chat_controller.dart';

/// Turn-scoped mixture-of-agents progress and todo plans.
extension _ChatControllerProgress on ChatController {
  List<MoaProgress> _moaInImpl(ChatThread thread) {
    final source = transport;
    if (!active ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return const [];
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    if (binding == null ||
        binding.profile != _profile ||
        _moaBindings[thread] != binding) {
      return const [];
    }
    return List.unmodifiable(
      (_moaStates[thread]?.cards ?? const <MoaProgress>[]).where(
        (card) =>
            card.turn is ChatMessage && thread.messages.contains(card.turn),
      ),
    );
  }

  void _moaDetailsOpenedImpl() => breadcrumbs('chat.visibility_action', {
    'feature': 'moa',
    'action': 'details',
  });

  void _beginMoaTurn(ChatThread thread, ChatMessage reply) {
    if (!reply.isPending ||
        !_threads.contains(thread) ||
        !thread.messages.contains(reply)) {
      return;
    }
    final previous = _moaForeground[thread];
    if (identical(previous, reply)) return;
    if (previous != null) _moaStates[thread]?.finish(previous);
    _moaForeground[thread] = reply;
    _moaUnavailable.remove(thread);
    _moaStates[thread]?.beginTurn(reply);
  }

  void _finishMoaTurn(ChatThread thread, ChatMessage reply) {
    if (!identical(_moaForeground[thread], reply)) return;
    _moaForeground.remove(thread);
    _moaStates[thread]?.finish(reply);
  }

  void _removeMoa(ChatThread thread, {bool keepTurn = false}) {
    _moaStates.remove(thread)?.clear();
    _moaBindings.remove(thread);
    if (!keepTurn) {
      _moaForeground.remove(thread);
      _moaUnavailable.remove(thread);
    }
  }

  void _invalidateMoaReferences(ChatThread thread) {
    _moaUnavailable.add(thread);
    final state = _moaStates[thread];
    state?.invalidateReferences();
    if (state != null) notifyListeners();
  }

  void _clearMoa() {
    for (final state in _moaStates.values) {
      state.clear();
    }
    _moaStates.clear();
    _moaBindings.clear();
    _moaForeground.clear();
    _moaUnavailable.clear();
  }

  void _onMoaOwnership(OwnedSessionChange change, int epoch) {
    if (!_currentActivity(epoch) || change.binding.profile != _profile) return;
    final source = transport;
    if (change.connected &&
        (source is! OwnedSessionTransport ||
            (source as OwnedSessionTransport).ownedSessionFor(
                  change.threadId,
                  profile: _profile,
                ) !=
                change.binding)) {
      return;
    }
    for (final thread
        in _threads.where((thread) => thread.id == change.threadId).toList()) {
      if (change.connected &&
          _moaBindings[thread] != null &&
          _moaBindings[thread] != change.binding) {
        _removeMoa(thread, keepTurn: true);
        _moaUnavailable.add(thread);
        if (!_currentActivity(epoch)) return;
        notifyListeners();
        if (!_currentActivity(epoch)) return;
      }
      if (!change.connected && _moaBindings[thread] == change.binding) {
        _removeMoa(thread, keepTurn: !change.retired);
        if (!change.retired) _moaUnavailable.add(thread);
        if (!_currentActivity(epoch)) return;
        notifyListeners();
      }
    }
  }

  bool _onMoaEvent(
    ChatThread thread,
    ChatMessage? reply,
    ChatEvent event,
    String? profile,
  ) {
    if (event is! MoaUpdated) return false;
    final epoch = _activityEpoch;
    final source = transport;
    final binding = source is OwnedSessionTransport
        ? (source as OwnedSessionTransport).ownedSessionFor(
            thread.id,
            profile: profile,
          )
        : null;
    if (!_currentActivity(epoch) ||
        profile != _profile ||
        !_threads.contains(thread) ||
        reply == null ||
        !reply.isPending ||
        !thread.messages.contains(reply) ||
        !identical(_moaForeground[thread], reply) ||
        binding == null ||
        binding.profile != profile ||
        binding.runtimeId != event.runtimeId ||
        !identical(binding.connection, event.connection)) {
      _moaOutcome('stale', 0);
      return true;
    }
    final state = _moaStates.putIfAbsent(thread, MoaProgressState.new);
    if (_moaBindings[thread] != binding) {
      if (_moaBindings[thread] != null) _moaUnavailable.add(thread);
      _moaBindings[thread] = binding;
      state.adopt(binding);
      if (_moaUnavailable.contains(thread)) state.invalidateReferences();
    }
    final outcome = state.apply(
      event.update,
      attachment: binding,
      turn: reply,
      eventIdentity: event.identity,
    );
    _moaOutcome(outcome.name, state.cards.length);
    if (_currentActivity(epoch) &&
        _moaBindings[thread] == binding &&
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) ==
            binding) {
      notifyListeners();
    }
    return true;
  }

  void _moaOutcome(String outcome, int count) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'moa',
        'outcome': outcome,
        'count': count,
      });
    } on Object {
      /* Telemetry cannot change reference ownership. */
    }
  }

  TodoPlanState? _todoPlanInImpl(ChatThread thread) {
    final owner = (_profile, thread.id), source = transport;
    final state = _todoPlans[owner], binding = _todoBindings[owner];
    if (!active ||
        !_threads.contains(thread) ||
        state == null ||
        binding == null ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final actual = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    return actual == binding && state.hasScope(_todoScope(binding))
        ? state
        : null;
  }

  TodoScope _todoScope(OwnedSessionBinding binding) => TodoScope(
    connection: binding.connection,
    runtimeId: binding.runtimeId,
    profile: binding.profile,
  );

  TodoPlanState _adoptTodo(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    final state = _todoPlans.putIfAbsent(owner, () {
      final created = TodoPlanState(events: events, breadcrumbs: breadcrumbs);
      created.addListener(notifyListeners);
      return created;
    });
    if (_todoBindings[owner] != binding) {
      _todoBindings[owner] = binding;
      _todoLive[owner] = 0;
      _todoResumes.remove(owner);
      state.adopt(_todoScope(binding));
    }
    return state;
  }

  void _removeTodo((String?, String) owner) {
    _todoPlans.remove(owner)?.dispose();
    _todoBindings.remove(owner);
    _todoLive.remove(owner);
    _todoResumes.remove(owner);
  }

  void _clearTodo() {
    for (final state in _todoPlans.values) {
      state.dispose();
    }
    _todoPlans.clear();
    _todoBindings.clear();
    _todoLive.clear();
    _todoResumes.clear();
  }

  void _onTodoOwnership(OwnedSessionChange change, int epoch) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_todoBindings[owner] == change.binding) {
        _removeTodo(owner);
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if (source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              change.threadId,
              profile: change.binding.profile,
            ) !=
            change.binding) {
      return;
    }
    final state = _adoptTodo(owner, change.binding);
    if (!_currentActivity(epoch) ||
        _profile != owner.$1 ||
        _todoPlans[owner] != state ||
        _todoBindings[owner] != change.binding ||
        (source as OwnedSessionTransport).ownedSessionFor(
              change.threadId,
              profile: change.binding.profile,
            ) !=
            change.binding) {
      return;
    }
    final token = change.resumeToken;
    if (change.resuming) {
      if (token != null) {
        _todoResumes[owner] = (change.binding, token, _todoLive[owner] ?? 0);
      }
      return;
    }
    final pending = _todoResumes[owner];
    if (pending != null && token != null) {
      if (pending.$1 != change.binding || !identical(pending.$2, token)) return;
      _todoResumes.remove(owner);
      if (pending.$3 != _todoLive[owner]) return;
    }
    state.resumed(_todoScope(change.binding), change.resumeSnapshot);
  }

  TodoPlanState? _syncTodo(ChatThread thread, String? profile) {
    final epoch = _activityEpoch;
    final source = transport;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final owner = (profile, thread.id);
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) {
      _removeTodo(owner);
      return null;
    }
    final state = _adoptTodo(owner, binding);
    if (!_currentActivity(epoch) ||
        _profile != profile ||
        !_threads.contains(thread) ||
        _todoPlans[owner] != state ||
        _todoBindings[owner] != binding ||
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) !=
            binding) {
      return null;
    }
    return state;
  }

  bool _onTodoEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! TodoUpdated) return false;
    final state = _syncTodo(thread, profile);
    final owner = (profile, thread.id),
        binding = _todoBindings[(profile, thread.id)];
    if (state == null ||
        _todoPlans[owner] != state ||
        binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    if (state.snapshot == null ||
        event.snapshot.revision > state.snapshot!.revision) {
      _todoLive[owner] = (_todoLive[owner] ?? 0) + 1;
    }
    state.updated(_todoScope(binding), event.snapshot);
    return true;
  }
}

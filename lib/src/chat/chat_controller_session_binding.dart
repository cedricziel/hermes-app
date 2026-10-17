part of 'chat_controller.dart';

/// Owned-session bindings, usage, side results, and process output.
extension _ChatControllerSessionBinding on ChatController {
  SessionUsageController? _usageInImpl(ChatThread thread) {
    final controller = _usage[thread], binding = _ownedBindings[thread];
    if (!active ||
        controller == null ||
        binding == null ||
        binding.profile != _profile) {
      return null;
    }
    final source = transport;
    final actual = source is OwnedSessionTransport
        ? (source as OwnedSessionTransport).ownedSessionFor(
            thread.id,
            profile: _profile,
          )
        : null;
    if (actual != null && actual != binding) return null;
    return controller.hasScope(
          UsageScope(
            connection: binding.connection,
            sessionId: binding.runtimeId,
            profile: binding.profile,
          ),
        )
        ? controller
        : null;
  }

  SideResultState? _sideResultsInImpl(ChatThread thread) {
    final state = _sideResults[thread], binding = _ownedBindings[thread];
    final source = transport;
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
    return actual == binding && state.hasScope(_sideScope(binding))
        ? state
        : null;
  }

  ProcessOutputState? _processOutputsInImpl(ChatThread thread) {
    final state = _processOutputs[thread], binding = _ownedBindings[thread];
    final source = transport;
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
    return actual == binding && state.hasScope(binding) ? state : null;
  }

  void _listenOwnedSessions() {
    _listenConnectionActivity();
    final source = transport;
    if (!active ||
        source is! OwnedSessionTransport ||
        _ownedSubscription != null) {
      return;
    }
    final epoch = _activityEpoch;
    _ownedSubscription = (source as OwnedSessionTransport).ownedSessions.listen(
      (change) {
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onConnectorOwnership(change, epoch);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onBillingOwnership(change);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onTodoOwnership(change, epoch);
        _onMoaOwnership(change, epoch);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        if (!change.connected) {
          for (final entry in _ownedBindings.entries.toList()) {
            if (entry.value != change.binding) continue;
            _reactions.remove(entry.key)?.dispose();
            _sideResults.remove(entry.key)?.dispose();
            _processOutputs.remove(entry.key)?.clear();
            if (change.retired) {
              _ownedBindings.remove(entry.key);
              _usage.remove(entry.key)?.dispose();
              notifyListeners();
            } else {
              _usage[entry.key]?.disconnected();
            }
          }
          return;
        }
        final thread = _threads
            .where((thread) => thread.id == change.threadId)
            .firstOrNull;
        if (thread != null) _syncOwnedSession(thread, _profile);
      },
      onError: (Object _) {
        if (_currentActivity(epoch)) _clearOwnedState();
      },
      onDone: () {
        if (!_currentActivity(epoch)) return;
        _ownedSubscription = null;
        _clearOwnedState();
      },
    );
  }

  void _clearOwnedState() {
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
    if (!disposed) notifyListeners();
  }

  OwnedSessionBinding? _syncOwnedSession(ChatThread thread, String? profile) {
    final epoch = _activityEpoch;
    final source = transport;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) return null;
    bool current() =>
        _currentActivity(epoch) &&
        _profile == profile &&
        _threads.contains(thread) &&
        _ownedBindings[thread] == binding &&
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) ==
            binding;
    final previous = _ownedBindings[thread];
    final controller = _usage.putIfAbsent(thread, () {
      final created = SessionUsageController(
        telemetry: usageTelemetry,
        breadcrumbs: breadcrumbs,
      );
      created.addListener(notifyListeners);
      return created;
    });
    if (previous != binding) {
      _ownedBindings[thread] = binding;
      if (!current()) return null;
      _sideResults[thread]?.adopt(_sideScope(binding));
      if (!current()) return null;
      _processOutputs[thread]?.adopt(binding);
      controller.bind(
        UsageScope(
          connection: binding.connection,
          sessionId: binding.runtimeId,
          profile: binding.profile,
        ),
        (_, _) {
          if (!active ||
              _profile != profile ||
              !_threads.contains(thread) ||
              (source as OwnedSessionTransport).ownedSessionFor(
                    thread.id,
                    profile: profile,
                  ) !=
                  binding) {
            throw StateError('Usage attachment retired');
          }
          return (source as OwnedSessionTransport).readOwnedSession(
            binding,
            'session.usage',
          );
        },
      );
      if (!current()) return null;
      if (previous != null &&
          !identical(previous.connection, binding.connection) &&
          identical(selectedThread, thread)) {
        unawaited(controller.reconnected());
      }
    }
    if (!current()) return null;
    _sideResults[thread]?.adopt(_sideScope(binding));
    if (!current()) return null;
    _processOutputs[thread]?.adopt(binding);
    if (!current()) return null;
    _syncReactions(thread, binding);
    return current() ? binding : null;
  }

  SideResultScope _sideScope(OwnedSessionBinding binding) => SideResultScope(
    connection: binding.connection,
    sessionId: binding.runtimeId,
    profile: binding.profile,
  );

  bool _onSideResult(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! SideResultReceived) return false;
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final state = _sideResults.putIfAbsent(thread, () {
      final created = SideResultState(events: events, breadcrumbs: breadcrumbs)
        ..adopt(_sideScope(binding));
      created.addListener(notifyListeners);
      return created;
    });
    state.received(_sideScope(binding), event.result);
    return true;
  }

  void _processOutputDetailsOpenedImpl() => breadcrumbs(
    'chat.visibility_action',
    {'feature': 'process_output', 'action': 'details'},
  );

  bool _onProcessOutput(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! ProcessOutputReceived) return false;
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final state = _processOutputs.putIfAbsent(
      thread,
      () => ProcessOutputState()..adopt(binding),
    );
    final outcome = state.apply(event.update, attachment: binding);
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'process_output',
        'outcome': outcome.name,
        'count': 1,
      });
    } on Object {
      return true;
    }
    return true;
  }

  bool _onUsageEvent(ChatThread thread, ChatEvent event, String? profile) {
    final tick = event is SessionUsageUpdated;
    if (!tick && event is! ReplyCompleted) return false;
    final binding = _syncOwnedSession(thread, profile);
    final controller = _usage[thread];
    if (controller == null || binding == null) return tick;
    final runtime = tick
        ? event.runtimeId
        : (event as ReplyCompleted).usageRuntimeId;
    final connection = tick
        ? event.connection
        : (event as ReplyCompleted).usageConnection;
    if (runtime != binding.runtimeId ||
        !identical(connection, binding.connection)) {
      return tick;
    }
    final scope = UsageScope(
      connection: binding.connection,
      sessionId: binding.runtimeId,
      profile: binding.profile,
    );
    if (event is SessionUsageUpdated) {
      if (event.finalSnapshot) {
        controller.complete(
          scope,
          event.malformed ? const <String, Object?>{} : event.snapshot,
        );
      } else {
        controller.tick(scope, event.snapshot);
      }
    } else if (event is ReplyCompleted) {
      controller.complete(
        scope,
        event.usageMalformed ? const <String, Object?>{} : event.usage,
      );
    }
    return tick;
  }

  int _warningGeneration(ChatThread thread) =>
      _warningGenerations.putIfAbsent(thread, () => ++_nextWarningGeneration);

  void _discardWarnings(ChatThread thread) {
    _warnings.remove(thread)?.clear();
    _warningGenerations[thread] = ++_nextWarningGeneration;
  }

  int _sessionActionGeneration(ChatThread thread) => _sessionActionGenerations
      .putIfAbsent(thread, () => ++_nextSessionActionGeneration);
}

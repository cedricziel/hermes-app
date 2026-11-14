part of 'chat_controller.dart';

/// The tools whose calls write files, for "checkpoints are off, and this chat
/// edited files". A call that carried a diff counts too.
const _editTools = {'write_file', 'patch', 'edit_file', 'apply_patch'};

/// What one chat holds of the checkpoint and context features: its two
/// controllers, the usage they read, the send hold of a full restore and the
/// outcome lines. Kept by thread id within a profile, so a re-read thread list
/// keeps a restore in flight and its result.
class _ThreadActions {
  _ThreadActions(this.threadId, this.profile);

  /// Follows the thread when compression gives it a new stored id.
  String threadId;
  final String? profile;
  CheckpointsController? checkpoints;
  ContextController? context;

  /// The usage controller [context] reads, listened to while it is the
  /// thread's.
  SessionUsageController? usage;
  VoidCallback? usageListener;

  /// The runtime the controllers are bound to, null for none.
  OwnedSessionBinding? binding;
  VoidCallback? outcomeListener;

  /// The last outcome each controller was seen with, so one settled outcome
  /// adds one line.
  Object? seenRestore, seenCompress;
  final outcomes = <TranscriptOutcome>[];

  bool sendHeld = false;

  /// How many prompts held the text of the last quote when it was taken.
  int quoteTextCount = 0;

  /// A prompt was queued while Send was held, so the queue goes on once the
  /// hold ends. A queue that was already paused stays paused.
  bool drainAfterHold = false;

  /// A removed prompt for a composer that was not showing this chat.
  String? handBack;
  bool disposed = false;
}

/// The checkpoint and context controllers of each chat: created when first
/// asked for, bound to the runtime the chat owns, fed the usage the Session
/// usage card holds, and dropped with the thread, the profile or the session.
extension _ChatControllerCheckpoints on ChatController {
  CheckpointsController? _checkpointsInImpl(ChatThread thread) =>
      transport is CheckpointsTransport
      ? _ensureActions(thread)?.checkpoints
      : null;

  ContextController? _contextInImpl(ChatThread thread) =>
      transport is ContextTransport ? _ensureActions(thread)?.context : null;

  bool _sendHeldInImpl(ChatThread thread) =>
      _actionsOf(thread)?.sendHeld ?? false;

  List<TranscriptOutcome> _outcomeLinesInImpl(ChatThread thread) {
    final actions = _actionsOf(thread);
    if (!active || actions == null || !_threads.contains(thread)) {
      return const [];
    }
    return List.unmodifiable(actions.outcomes);
  }

  /// [thread]'s flyer messages with its outcome lines among them, for every
  /// full rewrite of its message list, so a re-read keeps them.
  List<Message> _flyerOf(ChatThread thread) =>
      withOutcomeLines(chatThreadToFlyer(thread), _outcomeLinesInImpl(thread));

  /// Whether a full restore holds [thread]'s queue; if it does and a prompt
  /// waits, the queue goes on once the hold ends.
  bool _deferForHold(ChatThread thread) {
    final actions = _actionsOf(thread);
    if (actions == null || !actions.sendHeld) return false;
    if (_queues[thread]?.isNotEmpty ?? false) actions.drainAfterHold = true;
    return true;
  }

  /// Whether Send is held for [thread] by a full restore.
  bool _actionHolds(ChatThread? thread) =>
      thread != null && (_actionsOf(thread)?.sendHeld ?? false);

  _ThreadActions? _actionsOf(ChatThread thread) {
    final actions = _threadActions[thread.id];
    return actions != null && actions.profile == _profile ? actions : null;
  }

  ChatThread? _threadOf(_ThreadActions actions) {
    if (actions.disposed || actions.profile != _profile) return null;
    for (final thread in _threads) {
      if (thread.id == actions.threadId) return thread;
    }
    return null;
  }

  _ThreadActions? _ensureActions(ChatThread thread) {
    final source = transport;
    if (!active ||
        !thread.remote ||
        // By id: a sheet opened earlier holds the object a re-read replaced.
        !_threads.any((t) => t.id == thread.id) ||
        (source is! CheckpointsTransport && source is! ContextTransport)) {
      return null;
    }
    final existing = _threadActions[thread.id];
    if (existing != null && existing.profile == _profile) return existing;
    if (existing != null) _disposeActions(existing);
    final actions = _threadActions[thread.id] = _ThreadActions(
      thread.id,
      _profile,
    );
    final bridge = _bridgeFor(actions);
    final telemetry = ActionTelemetry(
      telemetry: usageTelemetry,
      breadcrumbs: breadcrumbs,
    );
    final locked = appLock?.covered ?? false;
    if (source is CheckpointsTransport) {
      actions.checkpoints = CheckpointsController(
        transport: source as CheckpointsTransport,
        bridge: bridge,
        telemetry: telemetry,
      )..setLocked(locked);
    }
    if (source is ContextTransport) {
      actions.context = ContextController(
        transport: source as ContextTransport,
        bridge: bridge,
        telemetry: telemetry,
      )..setLocked(locked);
    }
    _syncActions(thread);
    // Listened to only once bound, so creating them while a screen builds
    // notifies nobody.
    final listener = actions.outcomeListener = () => _outcomeChanged(actions);
    actions.checkpoints?.addListener(listener);
    actions.context?.addListener(listener);
    return actions;
  }

  ChatActionBridge _bridgeFor(_ThreadActions actions) => ChatActionBridge(
    isReplying: () {
      final thread = _threadOf(actions);
      return thread != null &&
          (thread.isReplying ||
              _sending.containsKey(thread) ||
              // A Retry or Edit is taking back a turn, a queued prompt is
              // being sent, or a full restore holds Send: the server could
              // rewind a second turn or lose the one in flight.
              _undoing.containsKey(thread) ||
              _retrying.contains(thread) ||
              // A turn of another client runs in this chat.
              _active.contains(thread.id) ||
              _queueDispatching.contains(thread) ||
              _actionHolds(thread) ||
              thread.messages.any((m) => m.awaitingInput));
    },
    refetchChat: () async {
      final thread = _threadOf(actions);
      if (thread == null) throw StateError('The chat is gone');
      await _ChatControllerHistory(this)
          ._refreshThreadImpl(thread.id, strict: true);
    },
    refreshUsage: () async {
      final thread = _threadOf(actions);
      if (thread == null) return;
      await usageIn(thread)?.refresh();
    },
    holdSend: (held) => _holdSend(actions, held),
    lastPrompt: () {
      final thread = _threadOf(actions);
      if (thread == null) return null;
      for (final message in thread.messages.reversed) {
        if (!_countsAsPrompt(message)) continue;
        final text = message.submittedText ?? message.content;
        if (text.isEmpty) return null;
        actions.quoteTextCount = thread.messages
            .where(
              (m) =>
                  _countsAsPrompt(m) && (m.submittedText ?? m.content) == text,
            )
            .length;
        return PromptQuote(messageId: message.id, text: text);
      }
      return null;
    },
    chatHolds: (quote) {
      final thread = _threadOf(actions);
      if (thread == null) throw StateError('The chat is gone');
      if (thread.messages.any((m) => m.id == quote.messageId)) return true;
      // A prompt sent in this visit has a local id that the re-read replaces.
      // It still counts as held when no prompt with its text was lost: the
      // same text only counts as many times as it was there before.
      var now = 0;
      for (final m in thread.messages) {
        if (_countsAsPrompt(m) &&
            (m.submittedText ?? m.content) == quote.text) {
          now++;
        }
      }
      return now >= actions.quoteTextCount;
    },
    handBackToComposer: (text) => _handBack(actions, text),
    hasEditToolCall: () {
      final thread = _threadOf(actions);
      if (thread == null) return false;
      return thread.messages.any(
        (m) => m.toolCalls.any(
          (call) => _editTools.contains(call.name) || call.diff.isNotEmpty,
        ),
      );
    },
    reestablishSession: () async {
      final thread = _threadOf(actions);
      final source = transport;
      if (thread == null || source == null || !active) return;
      final epoch = _activityEpoch;
      await source.checkConnection();
      final current = _threadOf(actions);
      if (_currentActivity(epoch) && current != null) _pickUp(current);
    },
  );

  /// A prompt the user wrote, by the rule turns are counted with: not a
  /// failed one, not a row Hermes typed, and not a command run in this visit.
  bool _countsAsPrompt(ChatMessage m) =>
      m.isPrompt &&
      m.status != MessageStatus.error &&
      (!m.id.contains('-local-') ||
          m.submittedText != null ||
          !m.content.startsWith('/'));

  /// Binds [thread]'s controllers to the runtime it owns now, or to none,
  /// and hands the context controller the usage it reads.
  void _syncActions(ChatThread thread) {
    final actions = _actionsOf(thread);
    if (actions == null || actions.disposed) return;
    final source = transport;
    final binding =
        _ownedBindings[thread] ??
        (source is OwnedSessionTransport
            ? (source as OwnedSessionTransport).ownedSessionFor(
                thread.id,
                profile: _profile,
              )
            : null);
    actions.binding = binding;
    final scope = ActionScope(
      threadId: thread.id,
      profile: _profile,
      binding: binding,
    );
    final checkpoints = actions.checkpoints, context = actions.context;
    checkpoints?.bind(scope);
    context?.bind(scope);
    // The same runtime answers again after a drop: bind is a no-op then.
    if (binding != null) {
      if (checkpoints?.notUpToDate ?? false) {
        unawaited(checkpoints!.reconnected());
      }
      if (context?.notUpToDate ?? false) unawaited(context!.reconnected());
    }
    _syncActionUsage(actions, _usage[thread]);
  }

  /// Listens to [usage] in place of the one before; its changes reach the
  /// context controller through the listener, so nothing is pushed twice.
  void _syncActionUsage(_ThreadActions actions, SessionUsageController? usage) {
    if (identical(actions.usage, usage)) return;
    final listener = actions.usageListener;
    if (listener != null) actions.usage?.removeListener(listener);
    actions.usage = usage;
    if (usage != null) {
      final next = actions.usageListener ??= () {
        if (!actions.disposed) {
          actions.context?.updateUsage(actions.usage?.snapshot);
        }
      };
      usage.addListener(next);
    }
    actions.context?.updateUsage(usage?.snapshot);
  }

  /// The chats bound to [change]'s runtime lost it: a dropped connection
  /// leaves what they show not up to date, with actions off until it is back;
  /// a retired runtime binds them again to what they own now, maybe nothing.
  void _actionsOwnershipLost(OwnedSessionChange change) {
    for (final actions in _threadActions.values.toList()) {
      if (actions.disposed || actions.binding != change.binding) continue;
      final thread = _threadOf(actions);
      if (change.retired && thread != null) {
        _syncActions(thread);
      } else {
        actions.checkpoints?.disconnected();
        actions.context?.disconnected();
      }
    }
  }

  /// A turn of [thread] ended: a file count read before it is no longer
  /// trusted, and what is open is read again.
  void _actionsTurnEnded(ChatThread thread) {
    final actions = _actionsOf(thread);
    if (actions == null || actions.disposed) return;
    final checkpoints = actions.checkpoints, context = actions.context;
    if (checkpoints != null) unawaited(checkpoints.turnEnded());
    if (context != null) unawaited(context.turnEnded());
  }

  /// The app left the front: every connection is going away.
  void _actionsSuspended() {
    for (final actions in _threadActions.values) {
      actions.checkpoints?.disconnected();
      actions.context?.disconnected();
    }
  }

  /// The usage controllers were all dropped (a re-read thread list, a
  /// suspension); they are listened to again once the chat owns a session.
  void _detachActionUsage() {
    for (final actions in _threadActions.values) {
      _syncActionUsage(actions, null);
    }
  }

  /// The thread list was read again: chats of another profile or no longer
  /// listed go, the others are bound again.
  void _actionsAfterLoad() {
    for (final entry in _threadActions.entries.toList()) {
      final actions = entry.value;
      final thread = _threadOf(actions);
      if (thread == null || !thread.remote) {
        _threadActions.remove(entry.key);
        _disposeActions(actions);
        continue;
      }
      _syncActions(thread);
    }
  }

  void _actionsLockChanged() {
    if (disposed) return;
    final locked = appLock?.covered ?? false;
    for (final actions in _threadActions.values) {
      actions.checkpoints?.setLocked(locked);
      actions.context?.setLocked(locked);
    }
  }

  /// Hermes compacted the conversation on its own.
  bool _onContextEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! ContextCompacted) return false;
    if (!active || _profile != profile) return true;
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null || binding.runtimeId != event.runtimeId) return true;
    final context = _actionsOf(thread)?.context;
    if (context != null) unawaited(context.compacted());
    return true;
  }

  void _holdSend(_ThreadActions actions, bool held) {
    if (actions.disposed || actions.sendHeld == held) return;
    actions.sendHeld = held;
    if (held) {
      actions.drainAfterHold = false;
      if (!disposed) notifyListeners();
      return;
    }
    final drain = actions.drainAfterHold;
    actions.drainAfterHold = false;
    if (disposed) return;
    notifyListeners();
    final thread = _threadOf(actions);
    // Whatever was queued during the hold goes on now, into the chat as it
    // is after the restore.
    if (drain && thread != null && active && _queues[thread] != null) {
      _drainQueue(thread);
    }
  }

  /// A prompt was queued for [thread] while Send was held.
  void _queuedDuringHold(ChatThread thread) {
    final actions = _actionsOf(thread);
    if (actions == null || !actions.sendHeld) return;
    if (!_queues.containsKey(thread)) actions.drainAfterHold = true;
  }

  void _handBack(_ThreadActions actions, String text) {
    if (!active || actions.disposed || text.isEmpty) return;
    if (_selectedId == actions.threadId && _threadOf(actions) != null) {
      (onHandBack ?? onDraft)?.call(text);
      return;
    }
    // The composer shows another chat: the text waits for this one.
    actions.handBack = text;
  }

  /// [id] was selected: a prompt handed back while another chat was open
  /// goes to its composer once the screen shows this chat.
  void _actionsSelected(String id) {
    final actions = _threadActions[id];
    final text = actions?.handBack;
    if (actions == null || text == null || actions.profile != _profile) {
      return;
    }
    actions.handBack = null;
    final epoch = _activityEpoch;
    scheduleMicrotask(() {
      if (_currentActivity(epoch) &&
          !actions.disposed &&
          _selectedId == actions.threadId) {
        (onHandBack ?? onDraft)?.call(text);
      } else if (!actions.disposed) {
        actions.handBack ??= text;
      }
    });
  }

  void _outcomeChanged(_ThreadActions actions) {
    if (actions.disposed) return;
    var added = false;
    final restore = actions.checkpoints?.outcome;
    if (restore == null) {
      actions.seenRestore = null;
    } else if (!identical(restore, actions.seenRestore)) {
      actions.seenRestore = restore;
      if (restore.kind == RestoreOutcomeKind.restored ||
          restore.kind == RestoreOutcomeKind.historyNotRewound) {
        actions.outcomes.add(
          TranscriptOutcome(
            kind: TranscriptOutcomeKind.restored,
            at: _clock(),
            files: restore.filesRestored,
            removedMessages: restore.historyRemoved > 0,
            lastMessageNotRemoved: restore.lastMessageNotRemoved,
          ),
        );
        added = true;
      }
    }
    final compress = actions.context?.outcome;
    if (compress == null) {
      actions.seenCompress = null;
    } else if (!identical(compress, actions.seenCompress)) {
      actions.seenCompress = compress;
      if (compress.kind == CompressOutcomeKind.compressed) {
        actions.outcomes.add(
          TranscriptOutcome(
            kind: TranscriptOutcomeKind.compressed,
            at: _clock(),
            beforeMessages: compress.beforeMessages,
            afterMessages: compress.afterMessages,
            fallbackUsed: compress.fallbackUsed,
          ),
        );
        added = true;
      }
    }
    if (!added || disposed) return;
    // One settle adds at most one line of each kind; each goes in by itself.
    _showOutcomeLines(actions);
    notifyListeners();
  }

  void _showOutcomeLines(_ThreadActions actions) {
    final thread = _threadOf(actions);
    if (thread == null || !active) return;
    final flyer = controllerFor(thread);
    for (final (index, outcome) in actions.outcomes.indexed) {
      final line = outcomeLineMessage(index, outcome);
      if (flyer.messages.any((m) => m.id == line.id)) continue;
      flyer.insertMessage(
        line,
        index: outcomeLineIndex(flyer.messages, outcome.at),
      );
    }
  }

  /// Compression gave the chat a new stored id: its controllers follow it.
  void _rekeyActions(String from, String to) {
    final actions = _threadActions[from];
    if (actions == null || from == to) return;
    _threadActions.remove(from);
    final displaced = _threadActions.remove(to);
    if (displaced != null) _disposeActions(displaced);
    actions.threadId = to;
    _threadActions[to] = actions;
    final thread = _threadOf(actions);
    if (thread != null) _syncActions(thread);
  }

  void _dropActions(ChatThread thread) {
    final actions = _threadActions[thread.id];
    if (actions == null) return;
    _threadActions.remove(thread.id);
    _disposeActions(actions);
  }

  /// Sign-out, profile switch, a closed transport: nothing is kept.
  void _clearActions() {
    final all = _threadActions.values.toList();
    _threadActions.clear();
    for (final actions in all) {
      _disposeActions(actions);
    }
  }

  void _disposeActions(_ThreadActions actions) {
    if (actions.disposed) return;
    final wasHeld = actions.sendHeld;
    actions.disposed = true;
    actions.sendHeld = false;
    actions.drainAfterHold = false;
    actions.handBack = null;
    actions.outcomes.clear();
    final listener = actions.usageListener;
    if (listener != null) actions.usage?.removeListener(listener);
    actions.usage = null;
    final outcome = actions.outcomeListener;
    if (outcome != null) {
      actions.checkpoints?.removeListener(outcome);
      actions.context?.removeListener(outcome);
    }
    actions.checkpoints?.dispose();
    actions.context?.dispose();
    // Clearing is not settling: a restore may still be running on the server,
    // so a queued prompt is not sent here. The queue stays for the user.
    if (!wasHeld || disposed) return;
    notifyListeners();
  }
}

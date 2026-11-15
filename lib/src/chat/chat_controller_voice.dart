part of 'chat_controller.dart';

/// Why a spoken turn was not sent. Each is a fixed word: the call maps it to
/// its own notice and nothing of the prompt travels with it.
enum VoiceTurnRefusal {
  /// A reply is running, a queue is about to send or one is being changed.
  busy,

  /// A queue holds prompts that no reply will send: the last turn was stopped
  /// or failed, or the queue was restored. No reply runs.
  queuePaused,

  /// The call ended, was muted or began to wait for the user meanwhile.
  noLongerWanted,

  /// The protected queue could not be read, so what it holds is unknown.
  queueRestoreFailed,

  /// The model, the branch, a folder move or a full restore does not allow a
  /// send now.
  modelOrBranchNotAllowed,

  /// The chat's profile was not confirmed while a queue is in play.
  profileNotConfirmed,

  /// The server took the session back, or the chat is gone.
  sessionReclaimed,
}

/// Why a prompt the user typed or queued left no trace in the chat. Fixed
/// codes: the screen words them.
enum ChatSendNotice {
  /// The words were exactly a stop phrase of Hermes' voice mode, which Hermes
  /// answers without running a turn, so nothing reached the agent.
  stopCommand,

  /// The same, in a chat that is not open: the words wait for that chat.
  stopCommandElsewhere,
}

/// What Hermes (or the transport) did with a spoken turn that was handed over.
enum VoiceTurnAnswer {
  /// A turn started for it.
  started,

  /// Hermes will answer it after the turn it is running.
  queued,

  /// Hermes took it into the turn it is running.
  steered,

  /// Hermes is adjusting the turn it is running to it.
  redirected,

  /// Hermes took it as its voice mode's stop phrase: no turn, no reply.
  voiceStopped,

  /// It was withdrawn before `prompt.submit` was written: nothing was sent.
  withdrawn,
}

/// A spoken turn in flight: its still-wanted check and what to tell the call.
final class _VoiceTurn {
  _VoiceTurn({
    required this.wanted,
    required this.interrupted,
    required this.onSubmitting,
    required this.onAnswer,
  });

  final bool Function() wanted;
  final bool interrupted;
  final void Function()? onSubmitting;
  final void Function(VoiceTurnAnswer)? onAnswer;

  void answer(VoiceTurnAnswer answer) {
    try {
      onAnswer?.call(answer);
    } on Object {
      // The call's own bookkeeping must not break the chat.
    }
  }
}

extension _ChatControllerVoice on ChatController {
  /// The first reason [selected] cannot take a spoken turn now, or null.
  VoiceTurnRefusal? _voiceRefusal(
    ChatThread? selected,
    bool Function() wanted,
  ) {
    if (!active || selected == null || !wanted()) {
      return VoiceTurnRefusal.noLongerWanted;
    }
    if (!modelSendAllowed) return VoiceTurnRefusal.modelOrBranchNotAllowed;
    if (_sessionStates[selected]?.reclaimedReason != null ||
        _queueUnavailable.contains(selected)) {
      return VoiceTurnRefusal.sessionReclaimed;
    }
    if (_undoing[selected] == TurnAction.branch ||
        _moveHolds(selected) ||
        _ChatControllerCheckpoints(this)._actionHolds(selected)) {
      return VoiceTurnRefusal.modelOrBranchNotAllowed;
    }
    final scoped = _profile != null && _profile!.trim().isNotEmpty;
    if (queueStore != null &&
        !scoped &&
        (selected.isReplying || _queues.containsKey(selected))) {
      return VoiceTurnRefusal.profileNotConfirmed;
    }
    if (_voiceQueueParked(selected)) return VoiceTurnRefusal.queuePaused;
    if (selected.isReplying ||
        (_queues[selected]?.isNotEmpty ?? false) ||
        _settleTimers.containsKey(selected) ||
        _enqueueing.contains(selected) ||
        _queuePreparing.contains(selected) ||
        _queueRemoving.contains(selected)) {
      return VoiceTurnRefusal.busy;
    }
    return null;
  }

  /// Whether [thread] holds queued prompts that wait for the user and nothing
  /// is about to send them: no reply, no settle wait, no change in progress.
  bool _voiceQueueParked(ChatThread thread) =>
      queuePaused(thread) &&
      !_settleTimers.containsKey(thread) &&
      !_queueDispatching.contains(thread) &&
      !_enqueueing.contains(thread) &&
      !_queuePreparing.contains(thread) &&
      !_queueRemoving.contains(thread);

  /// Whether the thread is certainly idle: no pending reply, no settle wait,
  /// and the session reported `running: false` after its last turn began.
  /// `isReplying` alone is not enough: Hermes can still be running after the
  /// message stopped being pending.
  bool _voiceSettled(ChatThread thread) =>
      !thread.isReplying &&
      !_settleTimers.containsKey(thread) &&
      _queueSettled.contains(thread);

  Future<VoiceTurnRefusal?> _submitVoiceTurnImpl(
    String text, {
    required bool Function() wanted,
    required bool interrupted,
    void Function()? onSubmitting,
    void Function(VoiceTurnAnswer)? onAnswer,
  }) async {
    final selected = selectedThread;
    var refusal = _voiceRefusal(selected, wanted);
    if (refusal != null || selected == null) return refusal;
    final scoped = _profile != null && _profile!.trim().isNotEmpty;
    if (queueStore != null &&
        scoped &&
        _bound.contains(selected) &&
        !_loadedQueues.contains(selected)) {
      // The persisted queue is not read yet, so an empty `queuedIn` says
      // nothing: wait for it, then decide.
      if (!_queuePreparing.add(selected)) return VoiceTurnRefusal.busy;
      final profile = _profile;
      final activityEpoch = _activityEpoch;
      final generation = _loadGeneration;
      final scope = queueScope?.call(selected, profile);
      try {
        final restored = scope != null && await _restoreQueue(selected);
        if (!wanted()) return VoiceTurnRefusal.noLongerWanted;
        if (!restored ||
            !_currentActivity(activityEpoch) ||
            generation != _loadGeneration ||
            profile != _profile ||
            !_threads.contains(selected) ||
            !_sameQueueOwner(queueScope?.call(selected, profile), scope)) {
          return VoiceTurnRefusal.queueRestoreFailed;
        }
      } finally {
        _queuePreparing.remove(selected);
      }
      if (!identical(selectedThread, selected)) {
        return VoiceTurnRefusal.noLongerWanted;
      }
      refusal = _voiceRefusal(selected, wanted);
      if (refusal != null) return refusal;
    }
    final voice = _VoiceTurn(
      wanted: wanted,
      interrupted: interrupted && _voiceSettled(selected),
      onSubmitting: onSubmitting,
      onAnswer: onAnswer,
    );
    // Nothing between this check and the send awaits.
    if (!wanted()) return VoiceTurnRefusal.noLongerWanted;
    return _send(selected, text, const [], voice: voice)
        ? null
        : VoiceTurnRefusal.noLongerWanted;
  }

  /// A typed or queued prompt was exactly a stop phrase: it went nowhere, so
  /// the user is told and, while that chat is open, gets the words back in
  /// the composer (under any new draft) rather than losing them.
  void _stopCommandTyped(ChatThread thread, String text) {
    final open = identical(selectedThread, thread);
    onSendNotice?.call(
      open || text.isEmpty
          ? ChatSendNotice.stopCommand
          : ChatSendNotice.stopCommandElsewhere,
    );
    if (text.isEmpty) return;
    if (open) {
      onDraft?.call(text);
    } else if (_threads.contains(thread)) {
      // Another chat's composer is not its to fill: wait for the chat.
      _stopHandBacks[_stopKey(thread.id)] = text;
    }
  }

  (String, String) _stopKey(String id) => (_profile ?? kDefaultProfile, id);

  void _rekeyStopHandBack(String from, String to) {
    final text = _stopHandBacks.remove(_stopKey(from));
    if (text != null) _stopHandBacks[_stopKey(to)] = text;
  }

  /// The selected chat has words waiting from a stop phrase: hand them over.
  void _stopHandBackSelected() {
    final id = _selectedId;
    final text = id == null ? null : _stopHandBacks.remove(_stopKey(id));
    if (text != null) onDraft?.call(text);
  }

  /// Takes a turn that was not sent, or that Hermes ended as a stop phrase,
  /// out of the thread: the prompt and its placeholder, and what sending them
  /// changed ([undo]), as if neither had been shown.
  void _dropUnsentTurn(
    ChatThread thread,
    ChatMessage prompt,
    ChatMessage reply,
    _SendUndo undo,
  ) {
    // First, so what listens to the removals sees the thread as it was.
    if (identical(_sentPrompts[thread], prompt)) {
      _sentPrompts[thread] = undo.prior;
    }
    if (undo.settled) _queueSettled.add(thread);
    // Each only while nothing else changed it meanwhile.
    if (undo.updatedAt != null && thread.updatedAt == undo.stamped) {
      thread.updatedAt = undo.updatedAt!;
    }
    if (undo.bumped != null && _generations[thread] == undo.bumped) {
      final before = undo.generation;
      before == null
          ? _generations.remove(thread)
          : _generations[thread] = before;
    }
    final settledReply = undo.settledReply;
    if (settledReply != null && thread.messages.contains(settledReply)) {
      settledReply.settledWithoutCompletion = true;
    }
    // Hermes stores a session with its first prompt: a chat bound by a create
    // whose prompt was never written is bound to an id Hermes does not know,
    // so the next send creates a session again.
    // Not while a prompt typed meanwhile waits on this binding: it goes out
    // with the id the create gave.
    if (!undo.bound &&
        (_queues[thread]?.isEmpty ?? true) &&
        !_enqueueing.contains(thread)) {
      _bound.remove(thread);
    }
    _removeReply(thread, reply);
    _removeReply(thread, prompt);
    // The words were the chat's title only because they were its first prompt.
    if (undo.appliedTitle != null &&
        thread.messages.isEmpty &&
        !thread.named &&
        thread.title == undo.appliedTitle) {
      thread.title = undo.title;
    }
  }
}

/// What sending a prompt changed in a thread, to put back when the prompt
/// turns out never to have been sent.
final class _SendUndo {
  _SendUndo({
    required this.title,
    required this.prior,
    required this.settled,
    required this.bound,
    required this.updatedAt,
    required this.generation,
    required this.settledReply,
  });

  /// The thread's title before, the one the prompt's words set (null when they
  /// set none), the prompt it had sent last, whether the session was known
  /// idle, and whether the thread was bound to a stored session.
  final String title;
  String? appliedTitle;
  final ChatMessage? prior;
  final bool settled;
  final bool bound;

  /// The thread's last activity before and the one sending stamped (null for a
  /// chat the send created), so a prompt that never went out leaves the chat
  /// where it was in the list.
  final DateTime? updatedAt;
  DateTime? stamped;

  /// The reply generation before and after the send. A request answered later
  /// is current only while it matches, so a turn that never ran must not make
  /// the answers about the turn before it stale.
  final int? generation;
  int? bumped;

  /// The reply before the prompt that settled without its completion, which
  /// the new turn was to take over.
  final ChatMessage? settledReply;
}

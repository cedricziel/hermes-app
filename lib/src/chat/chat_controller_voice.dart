part of 'chat_controller.dart';

/// Why a spoken turn was not sent. Each is a fixed word: the call maps it to
/// its own notice and nothing of the prompt travels with it.
enum VoiceTurnRefusal {
  /// A reply is running, a queue holds prompts or one is being changed.
  busy,

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

  /// The prompt the thread had sent before this one, which is again the last
  /// sent when this one is withdrawn.
  ChatMessage? prior;

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

  /// Takes a turn that was not sent, or that Hermes ended as a stop phrase,
  /// out of the thread: the prompt and its placeholder, as if neither had been
  /// shown. [prior] is the prompt the thread had sent before, which is the last
  /// sent again.
  void _dropUnsentTurn(
    ChatThread thread,
    ChatMessage prompt,
    ChatMessage reply,
    ChatMessage? prior,
  ) {
    _removeReply(thread, reply);
    _removeReply(thread, prompt);
    if (identical(_sentPrompts[thread], prompt)) _sentPrompts[thread] = prior;
  }
}

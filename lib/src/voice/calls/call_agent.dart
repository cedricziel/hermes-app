import 'dart:async';

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../chat/media/extract_media.dart';
import '../../chat/markdown_entities.dart';

/// Why a spoken turn was not sent. The reason is a fixed word: nothing of the
/// words travels with it. Whatever the reason, nothing was sent.
final class CallTurnRefused implements Exception {
  const CallTurnRefused(this.reason);
  final VoiceTurnRefusal reason;

  /// Hermes is still answering, or a queue is about to send.
  bool get busy => reason == VoiceTurnRefusal.busy;

  /// A queue holds prompts that wait for the user while no reply runs.
  bool get queuePaused => reason == VoiceTurnRefusal.queuePaused;

  /// The call moved on (End, mute, an approval waiting): nothing to say.
  bool get noLongerWanted => reason == VoiceTurnRefusal.noLongerWanted;

  /// The chat or its profile is gone: the call cannot go on.
  bool get endsCall =>
      reason == VoiceTurnRefusal.sessionReclaimed ||
      reason == VoiceTurnRefusal.profileNotConfirmed;

  /// The reason in fixed words, for telemetry.
  String get kind => switch (reason) {
    VoiceTurnRefusal.busy => 'busy',
    VoiceTurnRefusal.queuePaused => 'queue_paused',
    VoiceTurnRefusal.noLongerWanted => 'no_longer_wanted',
    VoiceTurnRefusal.queueRestoreFailed => 'queue_restore_failed',
    VoiceTurnRefusal.modelOrBranchNotAllowed => 'not_allowed',
    VoiceTurnRefusal.profileNotConfirmed => 'profile_not_confirmed',
    VoiceTurnRefusal.sessionReclaimed => 'session_reclaimed',
  };

  @override
  String toString() => 'The voice turn was not sent ($kind).';
}

/// How Hermes answered a spoken turn in a way that ends the wait for a reply:
/// it will answer after its current turn, took the words into it, or adjusts
/// it to them (the turn it is running goes on streaming), or it took them as
/// its own stop phrase.
enum CallTurnAnswer { queued, steered, redirected, voiceStopped }

abstract interface class CallAgent {
  /// Sends [text] as a spoken turn and follows its reply. [wanted] says
  /// whether the call still wants it sent (not ended, not muted, no approval
  /// waiting): it is asked right up to the moment `prompt.submit` is written.
  /// A turn that is not sent throws a [CallTurnRefused]. [interrupted] says
  /// the user cut off the previous spoken reply before this one.
  Future<void> reply(
    String text, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
    required bool Function() wanted,
    bool interrupted = false,

    /// Called just before the prompt is written, which ends the call's
    /// Sending: from then on End or mute cannot withdraw it.
    void Function()? onSubmitted,

    /// Called when Hermes answers in a way that ends the wait at once; the
    /// reply then returns without a spoken reply to wait for.
    void Function(CallTurnAnswer answer)? onAnswer,
  });
  Future<void> interrupt();

  /// Calls [listener] when a message is typed in the chat, which is not this
  /// call's own turn.
  void watchTyped(void Function() listener);

  /// Calls [listener] when Hermes took a message typed in the chat as the stop
  /// phrase of its voice mode, which ends the call.
  void watchVoiceStopped(void Function() listener);

  /// Whether the thread waits for the user (an approval, a question), whoever
  /// raised it: this call's reply, a typed one or a server-queued one.
  bool get attention;

  /// Calls [listener] whenever [attention] changes, until [dispose].
  void watchAttention(void Function(bool waiting) listener);
  void dispose();
}

/// Sends through the ordinary chat path: model, billing, ownership, tools and
/// approvals retain their existing checks. Only this call's own turn is stopped.
class ChatCallAgent implements CallAgent {
  ChatCallAgent(this.chat, {required this.onContextLost})
    : profile = chat.profile,
      _thread = chat.selectedThread {
    chat.addListener(_changed);
  }
  final ChatController chat;
  final void Function() onContextLost;
  final String? profile;
  final ChatThread? _thread;
  bool _submitting = false;
  bool _disposed = false;

  /// Set by [interrupt]: whatever this call sends from then on is withdrawn.
  bool _stopped = false;
  void Function()? _typed;
  void Function(ChatThread)? _voiceStopped;
  ChatMessage? _knownPrompt;
  Completer<void>? _reply;
  String? _messageID;
  void Function(String)? _text;
  void Function(bool)? _attention;
  String _spoken = '';
  void Function(bool)? _watcher;
  bool _lastAttention = false;

  /// The prompt this call's turn sent, which its reply follows.
  ChatMessage? _prompt;
  ChatMessage? _earlierPrompt;

  @override
  bool get attention =>
      _thread?.messages.any((m) => m.isPending && m.awaitingInput) ?? false;

  @override
  void watchAttention(void Function(bool waiting) listener) {
    _watcher = listener;
    _lastAttention = attention;
  }

  bool get valid =>
      !_disposed &&
      chat.active &&
      chat.profile == profile &&
      identical(chat.selectedThread, _thread);

  @override
  void watchVoiceStopped(void Function() listener) {
    final previous = _voiceStopped;
    if (previous != null) chat.removeVoiceStoppedListener(previous);
    void heard(ChatThread thread) {
      // Only a prompt of the call's own chat ends it.
      if (!_disposed && valid && identical(thread, _thread)) listener();
    }

    _voiceStopped = heard;
    chat.addVoiceStoppedListener(heard);
  }

  @override
  void watchTyped(void Function() listener) {
    _typed = listener;
    _knownPrompt = _thread == null ? null : chat.lastSentPrompt(_thread);
  }

  @override
  Future<void> reply(
    String text, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
    required bool Function() wanted,
    bool interrupted = false,
    void Function()? onSubmitted,
    void Function(CallTurnAnswer answer)? onAnswer,
  }) async {
    final thread = chat.selectedThread;
    if (!valid ||
        thread == null ||
        _reply != null ||
        thread.isCanonicalBotChat) {
      throw StateError('This chat is not ready for another voice turn.');
    }
    // A running reply is busy; what a queue means (about to send, or paused
    // for the user) is for the chat to say once it has read the queue.
    if (thread.isReplying) throw const CallTurnRefused(VoiceTurnRefusal.busy);
    final done = _reply = Completer<void>();
    // Observe errors before submit's asynchronous admission checks complete.
    unawaited(
      done.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _text = onText;
    _attention = onAttention;
    _spoken = '';
    _messageID = null;
    _prompt = null;
    _stopped = false;
    _earlierPrompt = chat.lastSentPrompt(thread);
    _submitting = true;
    try {
      final refused = await chat.submitVoiceTurn(
        text,
        wanted: () => valid && !_stopped && wanted(),
        interrupted: interrupted,
        onSubmitting: onSubmitted,
        onAnswer: (answer) {
          // The prompt is taken out of the chat again, which is not a message
          // typed there: the thread's last prompt is the one before the call's.
          if (answer == VoiceTurnAnswer.withdrawn ||
              answer == VoiceTurnAnswer.voiceStopped) {
            _knownPrompt = _earlierPrompt;
          }
          switch (answer) {
            case VoiceTurnAnswer.started:
              break;
            case VoiceTurnAnswer.queued:
              _answered(done, onAnswer, CallTurnAnswer.queued);
            case VoiceTurnAnswer.steered:
              _answered(done, onAnswer, CallTurnAnswer.steered);
            case VoiceTurnAnswer.redirected:
              _answered(done, onAnswer, CallTurnAnswer.redirected);
            case VoiceTurnAnswer.voiceStopped:
              _answered(done, onAnswer, CallTurnAnswer.voiceStopped);
            case VoiceTurnAnswer.withdrawn:
              if (!done.isCompleted) {
                done.completeError(
                  const CallTurnRefused(VoiceTurnRefusal.noLongerWanted),
                );
              }
          }
        },
      );
      if (refused != null) throw CallTurnRefused(refused);
      _messageID = _replies(thread).firstOrNull?.id;
      if (!valid || _stopped) {
        if (_messageID != null && thread.isReplying && chat.active) {
          await chat.stopReply(thread);
        }
        throw StateError('Hermes could not send this voice turn.');
      }
      _submitting = false;
      _changed();
      await done.future.timeout(const Duration(minutes: 10));
    } finally {
      _submitting = false;
      if (identical(_reply, done)) {
        _reply = null;
        _text = null;
        _attention = null;
      }
    }
  }

  /// Hermes answered in a way that ends the wait: nothing of the reply is
  /// spoken, the chat shows it.
  void _answered(
    Completer<void> done,
    void Function(CallTurnAnswer)? onAnswer,
    CallTurnAnswer answer,
  ) {
    if (done.isCompleted) return;
    try {
      onAnswer?.call(answer);
    } on Object {
      // The call's own bookkeeping must not break the agent.
    }
    done.complete();
  }

  void _changed() {
    if (_disposed) return;
    if (!valid) {
      onContextLost();
      return;
    }
    _noteTyped();
    final waiting = attention;
    if (waiting != _lastAttention) {
      _lastAttention = waiting;
      _watcher?.call(waiting);
    }
    if (_submitting) return;
    final done = _reply;
    if (done == null || done.isCompleted) return;
    final thread = _thread;
    if (thread == null) return;
    final replies = _replies(thread);
    final message = _messageID == null
        ? replies.firstOrNull
        : replies.where((m) => m.id == _messageID).firstOrNull;
    if (message == null) return;
    _messageID = message.id;
    final text = decodeMarkdownEntities(
      extractMedia(
        [...message.sealedProse.map((s) => s.text), message.content].join('\n'),
        complete: !message.isPending,
      ).text,
    );
    // Seal/flush only complete sentences while streaming. This avoids speaking
    // incomplete MEDIA markers and markdown entities, and bounds TTS latency.
    var ready = text;
    if (message.isPending) {
      final ends = RegExp(r'[.!?\n](?:\s|$)').allMatches(text).toList();
      ready = ends.isEmpty ? '' : text.substring(0, ends.last.end);
    }
    if (ready.startsWith(_spoken) && ready.length > _spoken.length) {
      _text?.call(ready.substring(_spoken.length));
      _spoken = ready;
    }
    _attention?.call(message.awaitingInput);
    if (!message.isPending) {
      if (message.status == MessageStatus.error || message.stopped) {
        done.completeError(StateError('Hermes could not finish this reply.'));
      } else {
        done.complete();
      }
    }
  }

  /// A prompt the chat sent that is not this call's is a typed one (or a
  /// queued one sent now): the call hears of it, which clears `interrupted`.
  void _noteTyped() {
    final thread = _thread;
    if (thread == null) return;
    final latest = chat.lastSentPrompt(thread);
    if (identical(latest, _knownPrompt)) return;
    _knownPrompt = latest;
    if (!_submitting && !identical(latest, _prompt)) _typed?.call();
  }

  /// The replies that follow this call's prompt. History read while the turn
  /// runs goes above it, so the prompt is found by identity, not position.
  Iterable<ChatMessage> _replies(ChatThread thread) {
    final latest = chat.lastSentPrompt(thread);
    if (_prompt == null && !identical(latest, _earlierPrompt)) _prompt = latest;
    final prompt = _prompt;
    if (prompt == null) return const [];
    final at = thread.messages.indexOf(prompt);
    if (at < 0) {
      return thread.messages.where((m) => m.id == _messageID);
    }
    return thread.messages
        .skip(at + 1)
        .takeWhile((m) => m.role != ChatRole.user || m.displayKind != null)
        .where((m) => m.role == ChatRole.assistant);
  }

  @override
  Future<void> interrupt() async {
    final done = _reply;
    if (done == null) return;
    _stopped = true;
    if (!done.isCompleted) {
      done.completeError(StateError('Voice turn interrupted.'));
    }
    final thread = _thread;
    if (thread != null && _messageID != null && thread.isReplying) {
      final id = _messageID;
      bool pending() => thread.messages.any((m) => m.id == id && m.isPending);
      final settled = Completer<void>();
      void changed() {
        if (!pending() && !settled.isCompleted) settled.complete();
      }

      chat.addListener(changed);
      try {
        await chat.stopReply(thread);
        changed();
        await settled.future.timeout(const Duration(seconds: 8));
      } finally {
        chat.removeListener(changed);
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(interrupt().catchError((Object _) {}));
    _disposed = true;
    _watcher = null;
    chat.removeListener(_changed);
    if (_voiceStopped case final heard?) chat.removeVoiceStoppedListener(heard);
  }
}

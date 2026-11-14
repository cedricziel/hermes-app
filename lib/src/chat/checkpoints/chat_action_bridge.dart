import '../owned_session_transport.dart';

/// What a checkpoint or context controller is bound to: one chat, and the
/// runtime session it already owns (null when nothing here has confirmed one,
/// for example a chat opened from history).
class ActionScope {
  const ActionScope({required this.threadId, this.profile, this.binding});

  final String threadId;
  final String? profile;
  final OwnedSessionBinding? binding;

  @override
  bool operator ==(Object other) =>
      other is ActionScope &&
      other.threadId == threadId &&
      other.profile == profile &&
      other.binding == binding;

  @override
  int get hashCode => Object.hash(threadId, profile, binding);
}

/// The last prompt of the chat, as a restore's confirmation quotes it and the
/// composer gets it back. Held in memory for one operation.
class PromptQuote {
  const PromptQuote({required this.messageId, required this.text});
  final String messageId, text;
}

/// What the controllers need from the chat around them, so they stay plain
/// Dart. The chat controller supplies these when it owns the controllers.
class ChatActionBridge {
  const ChatActionBridge({
    required this.isReplying,
    required this.refetchChat,
    this.refreshUsage = _noFuture,
    this.holdSend = _noHold,
    this.lastPrompt = _noQuote,
    this.chatHolds = _noHolds,
    this.handBackToComposer = _noText,
    this.hasEditToolCall = _noEdits,
    this.moveHolds = _noEdits,
    this.reestablishSession = _noFuture,
  });

  /// A reply is running or a request is waiting.
  final bool Function() isReplying;

  /// Re-reads the chat over REST. [historyRemoved] says a full restore took
  /// history away: a failed turn whose prompt the server no longer holds is
  /// then gone with it, not kept for a Retry.
  final Future<void> Function({bool historyRemoved}) refetchChat;
  final Future<void> Function() refreshUsage;

  /// Disables Send and holds the send queue while true.
  final void Function(bool held) holdSend;

  /// The last message for which `ChatMessage.isPrompt` is true, or null.
  final PromptQuote? Function() lastPrompt;

  /// Whether the (re-read) chat still holds [quote]'s message.
  final bool Function(PromptQuote quote) chatHolds;

  /// Puts [text] in the composer, unsent, under any existing draft.
  final void Function(String text) handBackToComposer;

  /// Whether a move of the chat's working folder is being settled. Checkpoints
  /// belong to a working directory, so no restore, of one file or all, starts
  /// then.
  final bool Function() moveHolds;

  /// Whether the chat ran an edit tool call.
  final bool Function() hasEditToolCall;

  /// Re-establishes the chat's session as a send does (after 4001).
  final Future<void> Function() reestablishSession;
}

Future<void> _noFuture() async {}
void _noHold(bool held) {}
PromptQuote? _noQuote() => null;
bool _noHolds(PromptQuote quote) => false;
void _noText(String text) {}
bool _noEdits() => false;

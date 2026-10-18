import 'dart:async';

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../chat/media/extract_media.dart';
import '../../chat/markdown_entities.dart';

abstract interface class CallAgent {
  Future<void> reply(
    String text, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
  });
  Future<void> interrupt();
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
  Completer<void>? _reply;
  String? _messageID;
  void Function(String)? _text;
  void Function(bool)? _attention;
  String _spoken = '';
  int _before = 0;

  bool get valid =>
      !_disposed &&
      chat.active &&
      chat.profile == profile &&
      identical(chat.selectedThread, _thread);

  @override
  Future<void> reply(
    String text, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
  }) async {
    final thread = chat.selectedThread;
    if (!valid ||
        thread == null ||
        _reply != null ||
        !chat.modelSendAllowed ||
        thread.isReplying ||
        chat.queuedIn(thread).isNotEmpty ||
        thread.isCanonicalBotChat) {
      throw StateError('This chat is not ready for another voice turn.');
    }
    final done = _reply = Completer<void>();
    // Observe errors before submit's asynchronous admission checks complete.
    unawaited(
      done.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _text = onText;
    _attention = onAttention;
    _spoken = '';
    _messageID = null;
    _before = thread.messages.length;
    _submitting = true;
    try {
      final accepted = await chat.submit(text, const []);
      if (accepted) {
        _messageID = thread.messages
            .skip(_before)
            .where((m) => m.role == ChatRole.assistant)
            .firstOrNull
            ?.id;
      }
      if (!valid || !accepted || done.isCompleted) {
        if (accepted &&
            _messageID != null &&
            thread.isReplying &&
            chat.active) {
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

  void _changed() {
    if (_disposed) return;
    if (!valid) {
      onContextLost();
      return;
    }
    if (_submitting) return;
    final done = _reply;
    if (done == null || done.isCompleted) return;
    final messages = _thread?.messages ?? const <ChatMessage>[];
    final replies = messages
        .skip(_before)
        .where((m) => m.role == ChatRole.assistant);
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

  @override
  Future<void> interrupt() async {
    final done = _reply;
    if (done == null) return;
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
    chat.removeListener(_changed);
  }
}

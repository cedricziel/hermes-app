import 'package:characters/characters.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';

const kPreviewLength = 120;
const kReplyReadyBody = 'Reply ready';
const kReplyFailedBody = 'Reply failed';
const kApprovalBody = 'Waiting for your approval';
const kQuestionBody = 'Has a question for you';
const kNeedsYouBody = 'Waiting for you in Hermes';

/// What to tell the user about, and for which thread.
class AttentionNotification {
  const AttentionNotification({
    required this.threadId,
    required this.title,
    required this.body,
    this.profile,
  });

  final String threadId;

  /// The Hermes profile [threadId] belongs to, when it is known.
  final String? profile;
  final String title;
  final String body;
}

/// The start of [text] on one line, for a notification body.
String replyPreview(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final characters = flat.characters;
  if (characters.length <= kPreviewLength) return flat;
  return '${characters.take(kPreviewLength).toString().trimRight()}…';
}

/// The notification [event] on [thread] deserves, or null. Nothing is said
/// while the app is focused on that very thread, or while notifications are
/// off. Request notifications stay generic on purpose: the command, question
/// or secret asked for must not show on a lock screen.
AttentionNotification? attentionFor({
  required ChatEvent event,
  required ChatThread thread,
  required bool appFocused,
  required String? selectedThreadId,
  required bool enabled,
  String? profile,
}) {
  if (!enabled) return null;
  if (appFocused && selectedThreadId == thread.id) return null;
  final body = switch (event) {
    ReplyCompleted(stopped: true) => null,
    ReplyCompleted(:final text, :final failed) =>
      failed
          ? kReplyFailedBody
          : (replyPreview(text).isEmpty ? kReplyReadyBody : replyPreview(text)),
    ApprovalRequested() => kApprovalBody,
    ClarifyRequested() => kQuestionBody,
    UnsupportedRequested() => kNeedsYouBody,
    _ => null,
  };
  if (body == null) return null;
  return AttentionNotification(
    threadId: thread.id,
    title: thread.title,
    body: body,
    profile: profile,
  );
}

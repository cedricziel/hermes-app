import 'package:flutter/foundation.dart';

import 'surface_snapshot.dart';

/// Why the snapshot is rebuilt; the span's `trigger` attribute.
enum SurfaceTrigger {
  threads,
  reply,
  request,
  pause,
  appLock;

  String get slug => switch (this) {
    appLock => 'app_lock',
    _ => name,
  };
}

/// What a chat is called until the dashboard or the gateway names it; the
/// title made from the prompt is never shared.
const kUnnamedChatLabel = 'New chat';

/// A chat of the open profile, as the chat screen holds it.
@immutable
class ThreadHint {
  const ThreadHint({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.snippet,
  });

  final String id;
  final String title;
  final DateTime updatedAt;

  /// The latest message's text, when the chat is loaded.
  final String? snippet;
}

/// A request that waits for the user.
@immutable
class RequestHint {
  const RequestHint({
    required this.threadId,
    required this.threadTitle,
    required this.kind,
    required this.requestId,
    required this.seenAt,
  });

  final String threadId;
  final String threadTitle;
  final PendingKind kind;
  final String requestId;

  /// When the app first saw it; Hermes sends no creation time.
  final DateTime seenAt;
}

/// What the open chat screen knows about its profile, so a snapshot of it
/// needs no server request.
@immutable
class ChatHints {
  const ChatHints({
    this.profile,
    this.threads = const [],
    this.requests = const [],
  });

  /// The open profile; null when the server has no profiles route.
  final String? profile;
  final List<ThreadHint> threads;
  final List<RequestHint> requests;
}

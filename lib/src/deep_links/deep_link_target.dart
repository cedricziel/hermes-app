import 'package:flutter/foundation.dart';

/// A place a `hermes://` link opens.
@immutable
sealed class DeepLinkTarget {
  const DeepLinkTarget();
}

/// A chat, fetched when the loaded pages do not hold it.
final class OpenChat extends DeepLinkTarget {
  const OpenChat({this.profile, required this.threadId, this.prompt});

  /// The chat's profile; the current one when null.
  final String? profile;
  final String threadId;

  /// Text for the chat's composer. It is never sent by the link.
  final String? prompt;

  @override
  bool operator ==(Object other) =>
      other is OpenChat &&
      other.profile == profile &&
      other.threadId == threadId &&
      other.prompt == prompt;

  @override
  int get hashCode => Object.hash(profile, threadId, prompt);

  @override
  String toString() => 'OpenChat($profile, $threadId, $prompt)';
}

/// A new chat, optionally with the microphone on and the composer filled.
final class NewChat extends DeepLinkTarget {
  const NewChat({this.profile, this.dictate = false, this.prompt});

  final String? profile;
  final bool dictate;

  /// Text for the composer. It is never sent by the link.
  final String? prompt;

  @override
  bool operator ==(Object other) =>
      other is NewChat &&
      other.profile == profile &&
      other.dictate == dictate &&
      other.prompt == prompt;

  @override
  int get hashCode => Object.hash(profile, dictate, prompt);

  @override
  String toString() => 'NewChat($profile, dictate: $dictate, $prompt)';
}

/// The chat of the oldest open request.
final class OpenRequests extends DeepLinkTarget {
  const OpenRequests();

  @override
  bool operator ==(Object other) => other is OpenRequests;

  @override
  int get hashCode => (OpenRequests).hashCode;

  @override
  String toString() => 'OpenRequests()';
}

final class OpenKanban extends DeepLinkTarget {
  const OpenKanban();

  @override
  bool operator ==(Object other) => other is OpenKanban;

  @override
  int get hashCode => (OpenKanban).hashCode;

  @override
  String toString() => 'OpenKanban()';
}

/// The Schedules tab, with one job open when [jobId] is set.
final class OpenSchedules extends DeepLinkTarget {
  const OpenSchedules({this.profile, this.jobId});

  final String? profile;
  final String? jobId;

  @override
  bool operator ==(Object other) =>
      other is OpenSchedules &&
      other.profile == profile &&
      other.jobId == jobId;

  @override
  int get hashCode => Object.hash(profile, jobId);

  @override
  String toString() => 'OpenSchedules($profile, $jobId)';
}

extension DeepLinkTargetKind on DeepLinkTarget {
  /// The fixed name breadcrumbs use for this kind of link.
  String get kind => switch (this) {
    OpenChat() => 'chat',
    NewChat() => 'new',
    OpenRequests() => 'requests',
    OpenKanban() => 'kanban',
    OpenSchedules() => 'schedules',
  };
}

import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../deep_links/deep_link_target.dart';
import '../deep_links/deep_link_uri.dart';
import '../notifications/attention_policy.dart';

/// The key the snapshot is stored under in the App Group.
const kSurfaceSnapshotKey = 'hermes.surface.v1';

const kSurfaceSnapshotVersion = 1;
const kMaxRecentChats = 10;
const kMaxSnippetLength = 120;
const kMaxTitleLength = 80;

/// The profile named when the server has no profiles route.
const kDefaultProfile = 'default';

String _cut(String text, int length) {
  final characters = text.characters;
  if (characters.length <= length) return text;
  return '${characters.take(length - 1).toString().trimRight()}…';
}

String? _snippet(String? text) {
  if (text == null) return null;
  final preview = replyPreview(text);
  return preview.isEmpty ? null : _cut(preview, kMaxSnippetLength);
}

// Swift's ISO8601DateFormatter reads no fractional seconds by default.
String _time(DateTime time) {
  final utc = time.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
  ).toIso8601String().replaceFirst('.000Z', 'Z');
}

DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// One chat in [SurfaceSnapshot.recentChats].
@immutable
class RecentChat {
  RecentChat({
    required this.profile,
    required this.id,
    required String title,
    String? snippet,
    required this.updatedAt,
  }) : title = _cut(title, kMaxTitleLength),
       snippet = _snippet(snippet);

  final String profile;
  final String id;
  final String title;

  /// The start of the latest message, when the app has it.
  final String? snippet;
  final DateTime updatedAt;

  String get url =>
      deepLinkUri(OpenChat(profile: profile, threadId: id)).toString();

  RecentChat redacted() =>
      RecentChat(profile: profile, id: id, title: '', updatedAt: updatedAt);

  Map<String, Object?> toJson() => {
    'profile': profile,
    'id': id,
    'title': title,
    'snippet': ?snippet,
    'updatedAt': _time(updatedAt),
    'url': url,
  };

  static RecentChat? fromJson(Object? json) {
    if (json is! Map) return null;
    final updatedAt = _parseTime(json['updatedAt']);
    return switch ((json['profile'], json['id'], json['title'])) {
      (final String profile, final String id, final String title)
          when updatedAt != null =>
        RecentChat(
          profile: profile,
          id: id,
          title: title,
          snippet: json['snippet'] as String?,
          updatedAt: updatedAt,
        ),
      _ => null,
    };
  }
}

/// What a request waits for. Never the command, the question or the name of
/// a secret.
enum PendingKind { approval, question, input }

/// An open request of the agent, described by its chat and kind only.
@immutable
class PendingRequest {
  PendingRequest({
    required this.profile,
    required this.threadId,
    required String threadTitle,
    required this.kind,
    required this.requestId,
    required this.createdAt,
  }) : threadTitle = _cut(threadTitle, kMaxTitleLength);

  final String profile;
  final String threadId;
  final String threadTitle;
  final PendingKind kind;
  final String requestId;

  /// When the app first learned of the request; Hermes reports none.
  final DateTime createdAt;

  String get url =>
      deepLinkUri(OpenChat(profile: profile, threadId: threadId)).toString();

  PendingRequest redacted() => PendingRequest(
    profile: profile,
    threadId: threadId,
    threadTitle: '',
    kind: kind,
    requestId: requestId,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'profile': profile,
    'threadId': threadId,
    'threadTitle': threadTitle,
    'kind': kind.name,
    'requestId': requestId,
    'createdAt': _time(createdAt),
    'url': url,
  };

  static PendingRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final createdAt = _parseTime(json['createdAt']);
    final kind = PendingKind.values.asNameMap()[json['kind']];
    return switch ((
      json['profile'],
      json['threadId'],
      json['threadTitle'],
      json['requestId'],
    )) {
      (
        final String profile,
        final String threadId,
        final String title,
        final String requestId,
      )
          when createdAt != null && kind != null =>
        PendingRequest(
          profile: profile,
          threadId: threadId,
          threadTitle: title,
          kind: kind,
          requestId: requestId,
          createdAt: createdAt,
        ),
      _ => null,
    };
  }
}

@immutable
class KanbanSummary {
  const KanbanSummary({required this.blocked, required this.review});

  final int blocked;
  final int review;

  Map<String, Object?> toJson() => {'blocked': blocked, 'review': review};

  static KanbanSummary? fromJson(Object? json) => switch (json) {
    {'blocked': final int blocked, 'review': final int review} => KanbanSummary(
      blocked: blocked,
      review: review,
    ),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is KanbanSummary &&
      other.blocked == blocked &&
      other.review == review;

  @override
  int get hashCode => Object.hash(blocked, review);
}

/// The most recent scheduled run that failed.
@immutable
class FailedJob {
  const FailedJob({
    required this.profile,
    required this.jobId,
    required this.name,
    required this.at,
  });

  final String profile;
  final String jobId;
  final String name;
  final DateTime at;

  String get url =>
      deepLinkUri(OpenSchedules(profile: profile, jobId: jobId)).toString();

  FailedJob redacted() =>
      FailedJob(profile: profile, jobId: jobId, name: '', at: at);

  Map<String, Object?> toJson() => {
    'profile': profile,
    'jobId': jobId,
    'name': name,
    'at': _time(at),
    'url': url,
  };

  static FailedJob? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = _parseTime(json['at']);
    return switch ((json['profile'], json['jobId'], json['name'])) {
      (final String profile, final String jobId, final String name)
          when at != null =>
        FailedJob(profile: profile, jobId: jobId, name: name, at: at),
      _ => null,
    };
  }
}

@immutable
class ScheduleSummary {
  const ScheduleSummary({this.nextRunAt, this.nextJobName, this.lastFailed});

  final DateTime? nextRunAt;
  final String? nextJobName;
  final FailedJob? lastFailed;

  ScheduleSummary redacted() =>
      ScheduleSummary(nextRunAt: nextRunAt, lastFailed: lastFailed?.redacted());

  Map<String, Object?> toJson() => {
    'nextRunAt': nextRunAt == null ? null : _time(nextRunAt!),
    'nextJobName': nextJobName,
    'lastFailed': lastFailed?.toJson(),
  };

  static ScheduleSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    return ScheduleSummary(
      nextRunAt: _parseTime(json['nextRunAt']),
      nextJobName: json['nextJobName'] as String?,
      lastFailed: FailedJob.fromJson(json['lastFailed']),
    );
  }
}

/// What the app shares with widgets, quick actions, Spotlight and App
/// Intents: a short picture of the user's Hermes state. It holds no token,
/// server address or identity, and never the text of a request.
@immutable
class SurfaceSnapshot {
  SurfaceSnapshot({
    required this.updatedAt,
    this.signedIn = true,
    this.profile,
    this.profiles = const [],
    List<RecentChat> recentChats = const [],
    this.pending = const [],
    this.kanban,
    this.schedules,
  }) : recentChats = _newest(recentChats);

  /// What a signed-out app shares: nothing.
  SurfaceSnapshot.signedOut(DateTime updatedAt)
    : this(updatedAt: updatedAt, signedIn: false);

  final DateTime updatedAt;
  final bool signedIn;

  /// The profile the app shows.
  final String? profile;

  /// The names of the server's profiles, in its order.
  final List<String> profiles;
  final List<RecentChat> recentChats;
  final List<PendingRequest> pending;

  /// Null when the server has no Kanban plugin enabled.
  final KanbanSummary? kanban;

  /// Null when the server has no scheduled tasks.
  final ScheduleSummary? schedules;

  static List<RecentChat> _newest(List<RecentChat> chats) =>
      ([...chats]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
          .take(kMaxRecentChats)
          .toList(growable: false);

  /// Without chat titles and snippets and job names, for while App Lock is
  /// on: counts, kinds, times, ids and links stay.
  SurfaceSnapshot redacted() => SurfaceSnapshot(
    updatedAt: updatedAt,
    signedIn: signedIn,
    profile: profile,
    profiles: profiles,
    recentChats: [for (final chat in recentChats) chat.redacted()],
    pending: [for (final request in pending) request.redacted()],
    kanban: kanban,
    schedules: schedules?.redacted(),
  );

  Map<String, Object?> toJson() => {
    'version': kSurfaceSnapshotVersion,
    'updatedAt': _time(updatedAt),
    'signedIn': signedIn,
    'profile': profile,
    'profiles': profiles,
    'recentChats': [for (final chat in recentChats) chat.toJson()],
    'pending': [for (final request in pending) request.toJson()],
    'kanban': kanban?.toJson(),
    'schedules': schedules?.toJson(),
  };

  String encode() => jsonEncode(toJson());

  /// Whether [other] says the same, whenever it was written.
  bool sameContent(SurfaceSnapshot other) {
    final mine = toJson()..remove('updatedAt');
    final theirs = other.toJson()..remove('updatedAt');
    return jsonEncode(mine) == jsonEncode(theirs);
  }

  /// The snapshot in [source], or null when it is missing, unreadable or
  /// from a newer version.
  static SurfaceSnapshot? fromJson(String? source) {
    if (source == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded['version'] != kSurfaceSnapshotVersion) {
      return null;
    }
    final Map<Object?, Object?> json = decoded;
    final updatedAt = _parseTime(json['updatedAt']);
    if (updatedAt == null) return null;
    List<T> rows<T>(String key, T? Function(Object?) read) => [
      for (final row in json[key] as List? ?? const []) ?read(row),
    ];
    return SurfaceSnapshot(
      updatedAt: updatedAt,
      signedIn: json['signedIn'] as bool? ?? false,
      profile: json['profile'] as String?,
      profiles: [
        for (final name in json['profiles'] as List? ?? const [])
          if (name is String) name,
      ],
      recentChats: rows('recentChats', RecentChat.fromJson),
      pending: rows('pending', PendingRequest.fromJson),
      kanban: KanbanSummary.fromJson(json['kanban']),
      schedules: ScheduleSummary.fromJson(json['schedules']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SurfaceSnapshot && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

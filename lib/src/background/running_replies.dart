import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:shared_preferences/shared_preferences.dart';

const _runningKey = 'hermes.background.running.v1';

/// How long a chat stays remembered: a reply nobody looked at for that long
/// is no longer news.
const kRunningReplyLifetime = Duration(hours: 24);

/// A chat whose reply still ran when the app moved to the background.
@immutable
class RunningReply {
  const RunningReply({
    required this.profile,
    required this.threadId,
    required this.since,
  });

  /// Null on a server without profiles.
  final String? profile;

  /// The chat's id, which is also the session key the server lists it under.
  final String threadId;

  /// When the app left.
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is RunningReply &&
      other.profile == profile &&
      other.threadId == threadId &&
      other.since == since;

  @override
  int get hashCode => Object.hash(profile, threadId, since);

  Map<String, Object?> toJson() => {
    'profile': ?profile,
    'threadId': threadId,
    'since': since.toUtc().toIso8601String(),
  };

  static RunningReply? fromJson(Object? json) {
    if (json
        case {'threadId': final String threadId, 'since': final String since}
        when threadId.isNotEmpty) {
      final at = DateTime.tryParse(since);
      final profile = (json as Map)['profile'];
      if (at == null || (profile != null && profile is! String)) return null;
      return RunningReply(
        profile: profile as String?,
        threadId: threadId,
        since: at,
      );
    }
    return null;
  }
}

/// The chats whose reply was running when the app left the front, which a
/// background run checks. The chat screen writes it when the app is paused and
/// empties it when the app returns; the background run removes what it
/// announced. Only ids and times are stored.
class RunningReplies {
  RunningReplies({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Writes run one after another, so that a pause followed at once by a
  /// resume ends empty.
  Future<void> _tail = Future.value();

  /// The remembered chats; unreadable storage reads as none.
  Future<List<RunningReply>> read() async {
    try {
      final raw = await _prefs.getString(_runningKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final row in decoded) ?RunningReply.fromJson(row)];
    } on Object {
      return const [];
    }
  }

  /// Remembers exactly [replies]; none forgets everything.
  Future<void> replace(List<RunningReply> replies) =>
      _queue(() => _save(replies));

  Future<void> clear() => replace(const []);

  /// Forgets [gone] and keeps the rest as it is stored now.
  Future<void> forget(Iterable<RunningReply> gone) => _queue(() async {
    final dropped = {for (final reply in gone) (reply.profile, reply.threadId)};
    await _save([
      for (final reply in await read())
        if (!dropped.contains((reply.profile, reply.threadId))) reply,
    ]);
  });

  Future<void> _save(List<RunningReply> replies) => replies.isEmpty
      ? _prefs.remove(_runningKey)
      : _prefs.setString(
          _runningKey,
          jsonEncode([for (final reply in replies) reply.toJson()]),
        );

  Future<void> _queue(Future<void> Function() write) {
    final done = _tail.then((_) => write());
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }
}

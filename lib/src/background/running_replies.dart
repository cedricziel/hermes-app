import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:shared_preferences/shared_preferences.dart';

const _runningKey = 'hermes.background.running.v1';
const _announcedKey = 'hermes.background.replied.v1';

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
    this.fromAsk = false,
  });

  /// Null on a server without profiles.
  final String? profile;

  /// The chat's id, which is also the session key the server lists it under.
  final String threadId;

  /// When the app left, or when the ask was handed to the background.
  final DateTime since;

  /// An "Ask Hermes" turn that outlived its answer, not a chat the app was
  /// showing: the chat screen's pauses and returns leave it alone.
  final bool fromAsk;

  @override
  bool operator ==(Object other) =>
      other is RunningReply &&
      other.profile == profile &&
      other.threadId == threadId &&
      other.since == since &&
      other.fromAsk == fromAsk;

  @override
  int get hashCode => Object.hash(profile, threadId, since, fromAsk);

  Map<String, Object?> toJson() => {
    'profile': ?profile,
    'threadId': threadId,
    'since': since.toUtc().toIso8601String(),
    if (fromAsk) 'ask': true,
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
        fromAsk: json['ask'] == true,
      );
    }
    return null;
  }
}

/// The chats whose reply was running when the app left the front, which a
/// background run checks, and the ones it announced. The chat screen writes
/// the first when the app is paused and empties it when the app returns; the
/// background run removes what it handled. Only ids and times are stored.
class RunningReplies {
  RunningReplies({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Writes run one after another, so that a pause followed at once by a
  /// resume ends empty.
  Future<void> _tail = Future.value();

  /// The remembered chats; unreadable storage reads as none.
  Future<List<RunningReply>> read() => _read(_runningKey);

  /// Remembers [replies] as the chats the app was showing, keeping the
  /// entries an ask added ([add]) that [replies] does not name.
  Future<void> replace(List<RunningReply> replies) => _queue(() async {
    final named = {
      for (final reply in replies) (reply.profile, reply.threadId),
    };
    final before = await _read(_runningKey);
    await _save(_runningKey, [
      for (final reply in before)
        if (reply.fromAsk && !named.contains((reply.profile, reply.threadId)))
          reply,
      ...replies,
    ]);
  });

  /// Remembers [reply], replacing an entry for the same chat.
  Future<void> add(RunningReply reply) => _queue(() async {
    await _save(_runningKey, [
      for (final known in await _read(_runningKey))
        if (known.profile != reply.profile || known.threadId != reply.threadId)
          known,
      reply,
    ]);
  });

  /// Forgets what the chat screen remembered: the app is in front. The entries
  /// of asks stay, since that chat may never have been on screen and the next
  /// pause would not add it again; the background check drops an ended turn,
  /// and an entry expires after [kRunningReplyLifetime].
  Future<void> clear() => _queue(() async {
    await _save(_runningKey, [
      for (final reply in await _read(_runningKey))
        if (reply.fromAsk) reply,
    ]);
  });

  /// Forgets everything, the entries of asks included: nobody is signed in.
  Future<void> clearAll() => _queue(() => _save(_runningKey, const []));

  /// Forgets [gone] and keeps the rest as it is stored now.
  Future<void> forget(Iterable<RunningReply> gone) =>
      _remove(_runningKey, gone);

  /// Records that a background run told the user about [replies], so that
  /// the app, replaying the same ending when it returns, does not tell again.
  Future<void> markAnnounced(Iterable<RunningReply> replies) =>
      _queue(() async {
        final known = await _read(_announcedKey);
        final added = {
          for (final reply in replies) (reply.profile, reply.threadId),
        };
        await _save(_announcedKey, [
          for (final reply in known)
            if (!added.contains((reply.profile, reply.threadId))) reply,
          ...replies,
        ]);
      });

  Future<List<RunningReply>> readAnnounced() => _read(_announcedKey);

  /// Whether a background run announced the reply of [threadId]; the record
  /// is consumed by the answer.
  Future<bool> takeAnnounced(String? profile, String threadId) async {
    var found = false;
    await _queue(() async {
      final known = await _read(_announcedKey);
      final kept = [
        for (final reply in known)
          if (reply.profile != profile || reply.threadId != threadId) reply,
      ];
      found = kept.length != known.length;
      if (found) await _save(_announcedKey, kept);
    });
    return found;
  }

  Future<void> clearAnnounced() => _queue(() => _save(_announcedKey, const []));

  Future<List<RunningReply>> _read(String key) async {
    try {
      final raw = await _prefs.getString(key);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final row in decoded) ?RunningReply.fromJson(row)];
    } on Object {
      return const [];
    }
  }

  Future<void> _remove(String key, Iterable<RunningReply> gone) =>
      _queue(() async {
        final dropped = {
          for (final reply in gone) (reply.profile, reply.threadId),
        };
        await _save(key, [
          for (final reply in await _read(key))
            if (!dropped.contains((reply.profile, reply.threadId))) reply,
        ]);
      });

  Future<void> _save(String key, List<RunningReply> replies) => replies.isEmpty
      ? _prefs.remove(key)
      : _prefs.setString(
          key,
          jsonEncode([for (final reply in replies) reply.toJson()]),
        );

  Future<void> _queue(Future<void> Function() write) {
    final done = _tail.then((_) => write());
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:shared_preferences/shared_preferences.dart';

const _recordKey = 'hermes.agent_messages.baseline.v1';

/// The start time of the newest delivery already dealt with, for each profile
/// name (`default` for the default profile), kept on the device so that the
/// app in front and the background runs announce a message only once.
///
/// Like `ScheduleBaseline` it belongs to an account (`accountKeyFor`): one
/// saved under another server or user reads as none.
class AgentMessageRecord {
  AgentMessageRecord({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// What the last look of [account] saw, or null when there was none, it is
  /// another account's or it cannot be read: the next look then only records.
  Future<Map<String, double>?> read(String account) async {
    try {
      final raw = await _prefs.getString(_recordKey);
      if (raw == null) return null;
      return _decode(raw, account);
    } on Object {
      return null;
    }
  }

  static Map<String, double>? _decode(String raw, String account) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['account'] != account) return null;
    final profiles = decoded['profiles'];
    if (profiles is! Map) return null;
    return {
      for (final MapEntry(:key, :value) in profiles.entries)
        if (key is String && value is num) key: value.toDouble(),
    };
  }

  /// Saves [record] as [account]'s; throws when storing fails, so a caller
  /// can announce nothing rather than the same message at every look.
  Future<void> write(String account, Map<String, double> record) =>
      _prefs.setString(
        _recordKey,
        jsonEncode({'account': account, 'profiles': record}),
      );

  /// The conditional writes of this instance in turn, so that two looks
  /// cannot both find the record as they read it and both save.
  Future<void> _tail = Future.value();

  /// Saves [next] as [account]'s only if the stored record still is what the
  /// look read as [expected] (null for none), and says whether it did. When it
  /// did not, another look owns the messages [next] stands for. A profile
  /// never moves back: the stored value wins when it is higher. Throws when
  /// the record cannot be read or saved.
  ///
  /// The check and the write are not atomic with another isolate's; this
  /// narrows the window the lookups of a long text read leave open.
  Future<bool> writeIfCurrent(
    String account,
    Map<String, double> next, {
    required Map<String, double>? expected,
  }) {
    final done = _tail.then((_) async {
      final stored = await _readChecked(account);
      if (stored == null ? expected != null : !mapEquals(stored, expected)) {
        return false;
      }
      await write(account, {
        for (final MapEntry(:key, :value) in next.entries)
          key: stored != null && (stored[key] ?? value) > value
              ? stored[key]!
              : value,
      });
      return true;
    });
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<Map<String, double>?> _readChecked(String account) async {
    final raw = await _prefs.getString(_recordKey);
    if (raw == null) return null;
    try {
      return _decode(raw, account);
    } on Object {
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_recordKey);
}

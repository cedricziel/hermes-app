import 'dart:convert';

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
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['account'] != account) return null;
      final profiles = decoded['profiles'];
      if (profiles is! Map) return null;
      return {
        for (final MapEntry(:key, :value) in profiles.entries)
          if (key is String && value is num) key: value.toDouble(),
      };
    } on Object {
      return null;
    }
  }

  /// Saves [record] as [account]'s; throws when storing fails, so a caller
  /// can announce nothing rather than the same message at every look.
  Future<void> write(String account, Map<String, double> record) =>
      _prefs.setString(
        _recordKey,
        jsonEncode({'account': account, 'profiles': record}),
      );

  Future<void> clear() => _prefs.remove(_recordKey);
}

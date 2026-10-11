import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _baselineKey = 'hermes.schedules.baseline.v1';

/// The last run time seen for each job (by job key), kept on the device so
/// that the app in front and the background runs never announce one run twice.
///
/// Every baseline belongs to an account (`accountKeyFor`): one saved under
/// another server or user reads as none, so it can never outlive a change of
/// server or sign-in.
class ScheduleBaseline {
  ScheduleBaseline({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// What the last look of [account] saw, or null when there was none, it is
  /// another account's or it cannot be read: the next look then only records
  /// the run times.
  Future<Map<String, DateTime>?> read(String account) async {
    try {
      final raw = await _prefs.getString(_baselineKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['account'] != account) return null;
      final runs = decoded['runs'];
      if (runs is! Map) return null;
      return {
        for (final MapEntry(:key, :value) in runs.entries)
          if (key is String && value is String) key: ?DateTime.tryParse(value),
      };
    } on Object {
      return null;
    }
  }

  /// Saves [baseline] as [account]'s; throws when storing fails, so a caller
  /// can leave its announcements for a later look.
  Future<void> write(String account, Map<String, DateTime> baseline) =>
      _prefs.setString(
        _baselineKey,
        jsonEncode({
          'account': account,
          'runs': {
            for (final entry in baseline.entries)
              entry.key: entry.value.toUtc().toIso8601String(),
          },
        }),
      );

  Future<void> clear() => _prefs.remove(_baselineKey);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What a running update needs to be picked up again after the app was
/// killed: which action it started, when, and what ran before it. None of it
/// is a secret; it is deleted when the update is resolved, on sign-out and on
/// a server change.
class UpdateRunRecord {
  const UpdateRunRecord({
    required this.startedAt,
    this.actionId,
    this.versionBefore,
    this.commitBefore,
  });

  final DateTime startedAt;
  final String? actionId;
  final String? versionBefore;
  final String? commitBefore;

  Map<String, Object> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'actionId': ?actionId,
    'versionBefore': ?versionBefore,
    'commitBefore': ?commitBefore,
  };

  static UpdateRunRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['startedAt'];
    final startedAt = raw is String ? DateTime.tryParse(raw) : null;
    if (startedAt == null) return null;
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return UpdateRunRecord(
      startedAt: startedAt,
      actionId: text('actionId'),
      versionBefore: text('versionBefore'),
      commitBefore: text('commitBefore'),
    );
  }
}

/// Keeps one [UpdateRunRecord] per account (`accountKeyFor`, a hash of the
/// server and the user, never the server's address) in shared preferences, so
/// another server or user reads nothing.
class UpdateRunStore {
  UpdateRunStore({required this.accountKey, SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final String accountKey;
  final SharedPreferencesAsync _prefs;

  String get _key => 'hermes.server_care.update.v1.$accountKey';

  /// The saved record, or null when there is none or it cannot be read.
  Future<UpdateRunRecord?> read() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return null;
      return UpdateRunRecord.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  /// A write that fails only means the update is not resumed after a
  /// relaunch.
  Future<void> write(UpdateRunRecord record) async {
    try {
      await _prefs.setString(_key, jsonEncode(record.toJson()));
    } on Object {
      return;
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } on Object {
      return;
    }
  }
}

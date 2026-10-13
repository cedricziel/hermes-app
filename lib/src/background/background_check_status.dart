import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum BackgroundCheckOutcome {
  incomplete,
  completed,
  partial,
  locked,
  unreachable,
  signedOut,
}

class BackgroundCheckStatus {
  const BackgroundCheckStatus({
    required this.attemptedAt,
    required this.outcome,
    this.completedAt,
  });
  final DateTime attemptedAt;
  final DateTime? completedAt;
  final BackgroundCheckOutcome outcome;
  Map<String, Object?> toJson() => {
    'version': 1,
    'attempted': attemptedAt.toUtc().millisecondsSinceEpoch,
    'completed': completedAt?.toUtc().millisecondsSinceEpoch,
    'outcome': outcome.name,
  };
  factory BackgroundCheckStatus.fromJson(Map<String, dynamic> value) {
    if (value['version'] != 1) {
      throw const FormatException();
    }
    return BackgroundCheckStatus(
      attemptedAt: DateTime.fromMillisecondsSinceEpoch(
        value['attempted'] as int,
        isUtc: true,
      ),
      completedAt: value['completed'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              value['completed'] as int,
              isUtc: true,
            ),
      outcome: BackgroundCheckOutcome.values.byName(value['outcome'] as String),
    );
  }
}

class BackgroundCheckAttempt {
  const BackgroundCheckAttempt(
    this.account,
    this.generation,
    this.id,
    this.status,
  );
  final String account;
  final String generation;
  final String id;
  final BackgroundCheckStatus status;
}

class BackgroundCheckStore {
  BackgroundCheckStore({
    SharedPreferencesAsync? prefs,
    DateTime Function()? now,
  }) : _prefs = prefs ?? SharedPreferencesAsync(),
       _now = now ?? DateTime.now;
  final SharedPreferencesAsync _prefs;
  final DateTime Function() _now;
  bool _retired = false;
  static const _prefix = 'hermes.background.check.v1.';
  static const _active = '${_prefix}active';
  String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  String _latest(String generation) => '$_prefix$generation.latest';
  String _record(String id) => '$_prefix$id.record';
  Future<Map<String, dynamic>?> _identity() async {
    final raw = await _prefs.getString(_active);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<bool> _current(String account, String generation) async {
    if (_retired) return false;
    final identity = await _identity();
    return !_retired &&
        identity?['account'] == account &&
        identity?['generation'] == generation;
  }

  Future<void> activate(String account) async {
    try {
      if (!_retired && (await _identity())?['account'] == account) {
        return;
      }
      await clear();
      await _prefs.setString(
        _active,
        jsonEncode({'account': account, 'generation': _id()}),
      );
      _retired = false;
    } on Object {
      // Status persistence must never affect authentication or refresh work.
    }
  }

  Future<void> clear() async {
    _retired = true;
    try {
      await _prefs.remove(_active);
      for (final key in await _prefs.getKeys()) {
        if (key.startsWith(_prefix)) {
          await _prefs.remove(key);
        }
      }
    } on Object {
      // Status persistence must never affect authentication or refresh work.
    }
  }

  Future<BackgroundCheckStatus?> read(String account) async {
    if (_retired) return null;
    try {
      final identity = await _identity();
      if (identity?['account'] != account) {
        return null;
      }
      final generation = identity!['generation'] as String;
      final id = await _prefs.getString(_latest(generation));
      if (id == null) {
        return null;
      }
      final raw = await _prefs.getString(_record(id));
      if (raw == null || !await _current(account, generation)) {
        return null;
      }
      return BackgroundCheckStatus.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<BackgroundCheckAttempt?> begin() async {
    if (_retired) return null;
    try {
      final identity = await _identity();
      if (identity == null) {
        return null;
      }
      final account = identity['account'] as String;
      final generation = identity['generation'] as String;
      final previous = await read(account);
      final previousId = await _prefs.getString(_latest(generation));
      final id = _id();
      final status = BackgroundCheckStatus(
        attemptedAt: _now(),
        completedAt: previous?.completedAt,
        outcome: BackgroundCheckOutcome.incomplete,
      );
      await _prefs.setString(_record(id), jsonEncode(status.toJson()));
      if (!await _current(account, generation)) {
        await _prefs.remove(_record(id));
        return null;
      }
      await _prefs.setString(_latest(generation), id);
      if (!await _current(account, generation)) {
        await _prefs.remove(_latest(generation));
        await _prefs.remove(_record(id));
        return null;
      }
      if (previousId != null) {
        await _prefs.remove(_record(previousId));
      }
      return BackgroundCheckAttempt(account, generation, id, status);
    } on Object {
      return null;
    }
  }

  Future<void> finish(
    BackgroundCheckAttempt? attempt,
    BackgroundCheckOutcome outcome,
  ) async {
    if (attempt == null) {
      return;
    }
    try {
      if (!await _current(attempt.account, attempt.generation) ||
          await _prefs.getString(_latest(attempt.generation)) != attempt.id) {
        return;
      }
      // Completion writes its own record; stale writers cannot replace the latest pointer.
      await _prefs.setString(
        _record(attempt.id),
        jsonEncode(
          BackgroundCheckStatus(
            attemptedAt: attempt.status.attemptedAt,
            completedAt: outcome == BackgroundCheckOutcome.completed
                ? _now()
                : attempt.status.completedAt,
            outcome: outcome,
          ).toJson(),
        ),
      );
      if (!await _current(attempt.account, attempt.generation) ||
          await _prefs.getString(_latest(attempt.generation)) != attempt.id) {
        await _prefs.remove(_record(attempt.id));
      }
    } on Object {
      // Status persistence must never affect authentication or refresh work.
    }
  }
}

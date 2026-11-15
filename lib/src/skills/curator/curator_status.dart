import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../server_care/json_read.dart';

/// What `GET /api/curator` says about the last run.
enum CuratorLastRun {
  /// `last_run_at` is null: no pass and no first check yet.
  never,

  /// `last_run_at` is a time.
  at,

  /// The field is missing or is not a time.
  unknown,
}

/// The answer of `GET /api/curator?profile=`, parsed leniently.
///
/// The route declares no response schema. A field that is missing or of
/// another type reads as null (or [CuratorLastRun.unknown]) and the rest is
/// used. Nothing here throws. The route sends nothing else (no summary, no
/// counts, no report), so this holds nothing else.
class CuratorStatus {
  const CuratorStatus({
    this.enabled,
    this.paused,
    this.intervalHours,
    this.lastRun = CuratorLastRun.unknown,
    this.lastRunAt,
    this.minIdleHours,
    this.staleAfterDays,
    this.archiveAfterDays,
  });

  /// Null when the answer has no usable object, so the caller reports an
  /// unreadable answer rather than a status of unknowns.
  static CuratorStatus? parse(Object? json) {
    final root = readMap(json);
    if (root == null) return null;
    final (lastRun, lastRunAt) = _lastRun(root);
    return CuratorStatus(
      enabled: readBool(root['enabled']),
      paused: readBool(root['paused']),
      intervalHours: _positive(_whole(root['interval_hours'])),
      lastRun: lastRun,
      lastRunAt: lastRunAt,
      minIdleHours: _nonNegative(readDouble(root['min_idle_hours'])),
      staleAfterDays: _nonNegative(_whole(root['stale_after_days'])),
      archiveAfterDays: _nonNegative(_whole(root['archive_after_days'])),
    );
  }

  /// False only when the config turns the curator off: an unreadable value
  /// counts as on, since Hermes' own default is on.
  final bool? enabled;
  final bool? paused;
  final int? intervalHours;
  final CuratorLastRun lastRun;

  /// UTC. Set with [CuratorLastRun.at]. Hermes also sets it the first time
  /// it sees a profile, without a pass.
  final DateTime? lastRunAt;
  final double? minIdleHours;
  final int? staleAfterDays;
  final int? archiveAfterDays;

  bool get isOn => enabled != false;

  static (CuratorLastRun, DateTime?) _lastRun(Map<String, dynamic> root) {
    if (!root.containsKey('last_run_at')) return (CuratorLastRun.unknown, null);
    final raw = root['last_run_at'];
    if (raw == null) return (CuratorLastRun.never, null);
    final text = raw is String ? raw.trim() : '';
    final zoned = utcTimeText(text);
    final parsed = zoned == null ? null : DateTime.tryParse(zoned);
    return parsed == null
        ? (CuratorLastRun.unknown, null)
        : (CuratorLastRun.at, parsed.toUtc());
  }

  /// [text] ready to parse as an instant: Hermes writes an offset, and a
  /// time without one is read as UTC, not as the device's local time. Null
  /// when there is no time of day (a bare date would be local midnight).
  @visibleForTesting
  static String? utcTimeText(String text) {
    if (!_hasTime.hasMatch(text)) return null;
    return _hasZone.hasMatch(text) ? text : '${text}Z';
  }

  static final _hasTime = RegExp(r'^\d{4}-\d\d-\d\d[T ]\d\d:\d\d');
  static final _hasZone = RegExp(
    r'(Z|[+-]\d\d(:?\d\d)?)$',
    caseSensitive: false,
  );

  /// The most a count of hours or days can sanely be (thousands of years).
  static const _maxWhole = 1000000;

  /// A whole number in range, as sent as an int or as a float without a
  /// fraction. 2.9 and 1e300 are not read as 2 and a saturated int.
  static int? _whole(Object? value) {
    final number = value is int
        ? value
        : (value is double &&
                  value.isFinite &&
                  value == value.truncateToDouble()
              ? value.toInt()
              : null);
    return number != null && number.abs() <= _maxWhole ? number : null;
  }

  static int? _positive(int? value) =>
      value != null && value > 0 ? value : null;

  static T? _nonNegative<T extends num>(T? value) =>
      value != null && value >= 0 ? value : null;
}

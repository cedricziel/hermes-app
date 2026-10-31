import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart';

/// Folds a burst of failed-request log records into one.
///
/// When the network drops, every request in flight fails within a few
/// milliseconds with the same `error.type` (`connectionError`), and each one
/// logs a record. The first record of an `error.type` goes through as it is;
/// further ones with that type within [window] are counted instead, and when
/// the window ends one summary record says how many there were
/// (`log.repeat_count`). Spans are not touched, so every request still has
/// its own.
///
/// Only failures that say nothing about the request itself are folded: the
/// connection ones (`connectionError`, the timeouts, `unknown`). A response
/// with an error status (`badResponse`) or a cancel always goes through, so
/// an expected 404 never hides a 500 that follows it.
class BurstDedupingLogger extends Logger {
  BurstDedupingLogger(this._inner, {this.window = const Duration(seconds: 10)});

  final Logger _inner;
  final Duration window;

  final _bursts = <String, _Burst>{};

  /// The `DioExceptionType` names a dropped network produces.
  static const _folded = {
    'connectionError',
    'connectionTimeout',
    'sendTimeout',
    'receiveTimeout',
    'unknown',
  };

  @override
  void emit(LogRecord record) {
    final type = record.attributes['error.type'];
    if (type is! String || !_folded.contains(type)) {
      _inner.emit(record);
      return;
    }
    final burst = _bursts[type];
    if (burst != null) {
      burst.repeats++;
      return;
    }
    _bursts[type] = _Burst(record);
    Timer(window, () => _end(type));
    _inner.emit(record);
  }

  void _end(String type) {
    final burst = _bursts.remove(type);
    if (burst == null || burst.repeats == 0) return;
    // Runs from a timer, outside the interceptor's guard: telemetry must
    // never break the app.
    try {
      _inner.emit(_summary(type, burst));
    } on Object {
      // Nothing to report it to.
    }
  }

  LogRecord _summary(String type, _Burst burst) {
    final first = burst.first;
    final attributes = Map<String, Object?>.of(first.attributes)
      // Each repeat had its own route, status and duration; the summary
      // keeps only what they shared.
      ..remove('http.route')
      ..remove('http.request.method')
      ..remove('http.response.status_code')
      ..remove('http.duration_ms')
      ..['log.repeat_count'] = burst.repeats
      ..['log.repeat_window_s'] = window.inSeconds;
    return LogRecord(
      body: 'HTTP requests failed: $type (${burst.repeats} more)',
      severity: first.severity,
      attributes: attributes,
      scopeName: first.scopeName,
      scopeVersion: first.scopeVersion,
    );
  }
}

class _Burst {
  _Burst(this.first);

  final LogRecord first;
  int repeats = 0;
}

import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// Records the checkpoint and context features with fixed names, outcomes,
/// flags and count buckets only. Never pass a file name, path, hash, reason,
/// message, focus, model name or server text: callers hand in enums and
/// numbers, and nothing here takes a free string from the user or server.
/// Recording never throws.
class ActionTelemetry {
  const ActionTelemetry({
    this.telemetry = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  });

  final ConnectionTelemetry telemetry;
  final Breadcrumbs breadcrumbs;

  /// 0, 1, 2–5, 6–20, 21+.
  static String bucket(int count) => switch (count) {
    <= 0 => '0',
    1 => '1',
    <= 5 => '2-5',
    <= 20 => '6-20',
    _ => '21+',
  };

  void crumb(String name, [Map<String, Object> attributes = const {}]) =>
      breadcrumbs(name, attributes);

  Span? start(String name) {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        name,
        attributes: telemetry.serverAttributes,
      ),
    );
    return span;
  }

  void finish(Span? span, Map<String, Object> attributes) {
    _quiet(() => span?.setAttributes(attributes));
    _quiet(() => span?.end());
  }

  void event(String name, Map<String, Object> attributes) =>
      _quiet(() => telemetry.events(name, attributes));

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}

/// Reports the first failure of a run of failures once, and re-arms on a
/// success.
class FailureStreak {
  var _failing = false;

  /// True for the first failure after a success (or the start).
  bool note() {
    final first = !_failing;
    _failing = true;
    return first;
  }

  void clear() => _failing = false;
}

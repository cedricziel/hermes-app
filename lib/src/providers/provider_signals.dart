import 'package:flutter_otel/flutter_otel.dart';

import '../telemetry/telemetry.dart';

/// Spans and logs of the provider flows, through the connection's telemetry.
///
/// Every attribute is a fixed name, a count, a flag or an outcome. Callers
/// pass nothing else: no key, code, provider, endpoint, model, profile or
/// Hermes message ever reaches a signal. Telemetry must never break a flow,
/// so every call is swallowed on failure.
class ProviderSignals {
  const ProviderSignals(this.telemetry);

  final ConnectionTelemetry telemetry;

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

  void end(Span? span, Map<String, Object> attributes) => _quiet(() {
    for (final e in attributes.entries) {
      span?.setAttribute(e.key, e.value);
    }
    span?.end();
  });

  void log(String name, Map<String, Object> attributes) =>
      _quiet(() => telemetry.events(name, attributes));

  /// A count as the bucket the spans record: `0`, `1`, `2-5`, `6-20`, `>20`.
  static String bucket(int count) => switch (count) {
    0 => '0',
    1 => '1',
    <= 5 => '2-5',
    <= 20 => '6-20',
    _ => '>20',
  };

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}

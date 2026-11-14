import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../telemetry/telemetry.dart';

/// Where one write that the user asked for (a pick of a provider, a model, a
/// terminal backend) is.
enum ToolsWriteState {
  idle,
  saving,

  /// The answer was lost. The state is being read again.
  checking,

  /// The answer was lost and the re-read did not finish. Nothing is sent
  /// again; the screen shows the last known state.
  unconfirmed,

  /// The answer was lost and the re-read shows the change did not land.
  notApplied,

  /// Hermes refused the value; the controller holds its own text.
  refused,
  failed,
}

/// Telemetry must never break the app.
void quietly(void Function() action) {
  try {
    action();
  } on Object {
    return;
  }
}

Span? startToolsSpan(
  ConnectionTelemetry telemetry,
  String name,
  Map<String, Object> attributes,
) {
  Span? span;
  quietly(
    () => span = telemetry.tracer?.startSpan(
      name,
      attributes: {...telemetry.serverAttributes, ...attributes},
    ),
  );
  return span;
}

/// Sets [outcome] on [span] and ends it.
void endToolsSpan(Span? span, String outcome) => quietly(() {
  span
    ?..setAttribute('outcome', outcome)
    ..end();
});

/// Ends [span] with [outcome] and logs `tools.setup_outcome` for [step].
void finishSetupStep(
  ConnectionTelemetry telemetry,
  Span? span,
  String step,
  String outcome,
) {
  quietly(() {
    span
      ?..setAttribute('outcome', outcome)
      ..end();
    telemetry.events('tools.setup_outcome', {'step': step, 'outcome': outcome});
  });
}

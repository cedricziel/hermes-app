import 'package:flutter_otel/flutter_otel.dart';

import 'safely.dart';

/// Records that something happened, with a few plain attributes.
///
/// Callers pass only fixed names and coarse values (a state, a status code, a
/// reason slug) — never a URL, host or exception message, which can carry the
/// address the user typed.
typedef TelemetryEvent = void Function(
  String name, [
  Map<String, Object> attributes,
]);

void ignoreTelemetryEvent(
  String name, [
  Map<String, Object> attributes = const {},
]) {}

/// Emits each event as an info log record.
TelemetryEvent logTelemetryEvents(Logger logger) =>
    (name, [attributes = const {}]) => safely(
      () => logger.emit(
        LogRecord(
          body: name,
          severity: LogSeverity.info,
          attributes: attributes,
        ),
      ),
    );

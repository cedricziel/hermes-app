import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry_event.dart';

import 'support/fake_logger.dart';

void main() {
  test('logs an event as an info record with its attributes', () {
    final logger = RecordingLogger();

    logTelemetryEvents(logger)('auth.state', {'state': 'ready'});

    final record = logger.records.single;
    expect(record.body, 'auth.state');
    expect(record.severity, LogSeverity.info);
    expect(record.attributes, {'state': 'ready'});
  });

  test('never throws when the logger breaks', () {
    expect(
      () => logTelemetryEvents(ThrowingLogger())('auth.state'),
      returnsNormally,
    );
  });
}

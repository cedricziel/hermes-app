import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/burst_deduping_logger.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

LogRecord _failed(String route, {String type = 'connectionError'}) => LogRecord(
  body: 'HTTP GET $route $type',
  severity: LogSeverity.error,
  attributes: {
    'hermes.version': '0.22.5',
    'http.request.method': 'GET',
    'http.route': route,
    'http.duration_ms': 12,
    'error.type': type,
  },
);

void main() {
  test('passes records without an error type through', () {
    final inner = _RecordingLogger();
    final logger = BurstDedupingLogger(inner);
    for (var i = 0; i < 3; i++) {
      logger.emit(LogRecord(body: 'HTTP GET /api/cron 200'));
    }
    expect(inner.records, hasLength(3));
  });

  test('folds a burst of one error type into the first record and a count', () {
    fakeAsync((async) {
      final inner = _RecordingLogger();
      final logger = BurstDedupingLogger(inner);

      logger
        ..emit(_failed('/api/cron'))
        ..emit(_failed('/api/dashboard'))
        ..emit(_failed('/'))
        ..emit(_failed('/api/cron', type: 'connectionTimeout'));

      expect(inner.records.map((r) => r.attributes['http.route']), [
        '/api/cron',
        '/api/cron',
      ]);

      async.elapse(const Duration(seconds: 10));

      final summary = inner.records.last;
      expect(inner.records, hasLength(3));
      expect(summary.body, 'HTTP requests failed: connectionError (2 more)');
      expect(summary.severity, LogSeverity.error);
      expect(summary.attributes['log.repeat_count'], 2);
      expect(summary.attributes['error.type'], 'connectionError');
      expect(summary.attributes['hermes.version'], '0.22.5');
      expect(summary.attributes.containsKey('http.route'), isFalse);
      expect(summary.attributes.containsKey('http.duration_ms'), isFalse);

      // A failure after the window logs again.
      logger.emit(_failed('/api/status'));
      expect(inner.records, hasLength(4));
    });
  });

  test('a lone failure logs no summary', () {
    fakeAsync((async) {
      final inner = _RecordingLogger();
      BurstDedupingLogger(inner).emit(_failed('/api/cron'));
      async.elapse(const Duration(minutes: 1));
      expect(inner.records, hasLength(1));
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';

import '../support/recording_tracer.dart';
import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

class _Logger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

/// A key typed into the real screen leaves the app once, in the body of its
/// request, and is in nothing the app records: not a span, a log record, an
/// event, a breadcrumb-like attribute, the request URL, a printed line or an
/// error.
void main() {
  for (final (label, arrange) in <(String, void Function(SetupWorld))>[
    ('a saved key', (_) {}),
    (
      'a refused key',
      (w) => w.server.on('PUT', '/api/tools/toolsets/web/env', {
        'detail': 'Unknown env var',
      }, status: 400),
    ),
    (
      'a failed key',
      (w) => w.server.on('PUT', '/api/tools/toolsets/web/env', {
        'detail': 'x',
      }, status: 500),
    ),
    (
      'a key whose answer was lost',
      (w) => w.loseAnswer('PUT', '/api/tools/toolsets/web/env'),
    ),
  ]) {
    testWidgets('$label leaves no trace of the value', (tester) async {
      final world = SetupWorld();
      arrange(world);
      final tracer = RecordingTracer();
      final logger = _Logger();
      final events = <String>[];
      final printed = <String>[];
      final dio = world.server.dio()
        ..interceptors.add(httpInterceptor(logger, tracer));
      final h = SetupHarness(tester, world)
        ..repositoryOverride = HermesToolsRepository(
          DefaultApi(dio),
          profile: 'work',
          telemetry: ConnectionTelemetry(
            tracer: tracer,
            events: (name, [attributes = const {}]) =>
                events.add('$name $attributes'),
          ),
        );
      final oldPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add('$message');

      await h.pump();
      await h.openWeb();
      await h.type(typedKey);
      await h.showKey();
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 30));
      debugPrint = oldPrint;

      // The value was sent once, in the body, and nowhere else.
      final sent = world.server.requestsTo(
        'PUT',
        '/api/tools/toolsets/web/env',
      );
      expect(sent, hasLength(1));
      expect(sent.single.data.toString(), contains(typedKey));
      expect(sent.single.uri.toString(), isNot(contains(typedKey)));

      final recorded = [
        for (final span in tracer.spans)
          '${span.name} ${span.attributes} ${span.events} ${span.statusDescription}',
        for (final record in logger.records)
          '${record.body} ${record.attributes}',
        ...events,
        ...printed,
      ].join('\n');
      expect(tracer.spans, isNotEmpty);
      expect(recorded, isNot(contains(typedKey)));
      expect(recorded, isNot(contains('SEARCHCO_API_KEY')));
      expect(tester.takeException(), isNull);
      await h.close();
    });
  }
}

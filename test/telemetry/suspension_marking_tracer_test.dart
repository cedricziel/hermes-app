import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/suspension_marking_tracer.dart';

import '../support/recording_tracer.dart';

void main() {
  test('marks a span that outlived a pause of the app', () {
    final inner = RecordingTracer();
    final suspensions = AppSuspensions.manual();
    final tracer = SuspensionMarkingTracer(inner, suspensions);

    final quick = tracer.startSpan('HTTP GET');
    quick.end();
    final long = tracer.startSpan('HTTP GET');
    suspensions.pause();
    long.end();
    final after = tracer.startSpan('HTTP GET')..end();

    expect(inner.spans.map((s) => s.attributes['app.suspended']), [
      null,
      true,
      null,
    ]);
    expect(after.name, 'HTTP GET');
  });

  test(
    'counts a pause and the return from it, not a trip through inactive',
    () {
      final suspensions = AppSuspensions.manual();
      void go(AppLifecycleState state) =>
          suspensions.didChangeAppLifecycleState(state);

      go(AppLifecycleState.inactive);
      go(AppLifecycleState.resumed);
      expect(suspensions.count, 0);

      go(AppLifecycleState.inactive);
      go(AppLifecycleState.hidden);
      go(AppLifecycleState.paused);
      expect(suspensions.count, 1);
      go(AppLifecycleState.hidden);
      go(AppLifecycleState.inactive);
      go(AppLifecycleState.resumed);
      expect(suspensions.count, 1);
    },
  );
}

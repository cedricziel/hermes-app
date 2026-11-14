import 'package:flutter/services.dart';
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
      expect(suspensions.count, 2);

      go(AppLifecycleState.inactive);
      go(AppLifecycleState.resumed);
      expect(suspensions.count, 2);
    },
  );

  test('counts a return from hidden that never paused', () {
    final suspensions = AppSuspensions.manual();
    void go(AppLifecycleState state) =>
        suspensions.didChangeAppLifecycleState(state);

    go(AppLifecycleState.inactive);
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.resumed);

    expect(suspensions.count, 1);
  });

  testWidgets('marks a span started in the background and ended after the '
      'return, through the states the binding reports', (tester) async {
    final inner = RecordingTracer();
    final suspensions = AppSuspensions.install();
    addTearDown(() => WidgetsBinding.instance.removeObserver(suspensions));
    final tracer = SuspensionMarkingTracer(inner, suspensions);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage('AppLifecycleState.paused'),
      (_) {},
    );
    final background = tracer.startSpan('HTTP GET');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage('AppLifecycleState.resumed'),
      (_) {},
    );
    background.end();

    expect(inner.spans.single.attributes['app.suspended'], isTrue);
  });
}

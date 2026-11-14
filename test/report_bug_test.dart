import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/report_bug.dart';

void main() {
  late void Function(FlutterErrorDetails)? previous;
  late List<FlutterErrorDetails> reported;

  setUp(() {
    previous = FlutterError.onError;
    reported = [];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = previous);

  test('hands an Error to the crash reporter', () {
    final bug = StateError('bug');

    reportBug(bug, StackTrace.current, 'a screen');

    expect(reported.single.exception, same(bug));
    expect(reported.single.library, 'hermes_app');
    expect(reported.single.context.toString(), 'a screen');
  });

  test('stays quiet about an Exception, which is a failed request', () {
    reportBug(const FormatException('late'), StackTrace.current, 'a screen');

    expect(reported, isEmpty);
  });
}

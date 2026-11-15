import 'package:flutter_test/flutter_test.dart';

/// Lets real I/O (a Dio request through the fake adapter, a file write) finish
/// before the test pumps frames, by waiting for [done] instead of for a fixed
/// span of wall-clock time. A fixed span expires under CPU load while the
/// work is still running, and a spinner that is still showing never settles
/// under `pumpAndSettle`.
///
/// Call it inside `tester.runAsync`. A condition that never comes true fails
/// here with [what], rather than as a `pumpAndSettle timed out` further on.
Future<void> waitForReal(
  bool Function() done, {
  required String what,
  Duration limit = const Duration(seconds: 20),
}) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > limit) fail('Gave up waiting for $what.');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

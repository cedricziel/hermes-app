import 'package:flutter_test/flutter_test.dart';

/// Gives real I/O wall-clock time until [done] holds, so a busy machine
/// fails only after [timeout] instead of after a fixed guess.
///
/// Fails with a [TestFailure] naming [reason] when [done] still does not hold
/// at the deadline, so a timeout reads as "timed out waiting for ..." and not
/// as a confusing assertion further down.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  required String reason,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (!DateTime.now().isBefore(deadline)) {
      throw TestFailure(
        'timed out waiting for $reason after ${timeout.inMilliseconds} ms',
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

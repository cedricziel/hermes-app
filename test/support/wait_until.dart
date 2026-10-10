import 'package:flutter_test/flutter_test.dart';

/// Gives real I/O wall-clock time until [done] holds, so a busy machine
/// fails only after [timeout] instead of after a fixed guess.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

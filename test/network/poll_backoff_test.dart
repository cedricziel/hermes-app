import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/network/poll_backoff.dart';

void main() {
  List<bool> ticks(PollBackoff backoff, int n) => [
    for (var i = 0; i < n; i++) backoff.tick(),
  ];

  test('looks at every tick while nothing failed', () {
    expect(ticks(PollBackoff(), 3), [true, true, true]);
  });

  test('skips 2^n - 1 ticks after n failures in a row', () {
    final backoff = PollBackoff()..failed();
    expect(ticks(backoff, 2), [false, true]);
    backoff.failed();
    expect(ticks(backoff, 4), [false, false, false, true]);
    expect(backoff.failures, 2);
  });

  test('skips at most maxSkipped ticks', () {
    final backoff = PollBackoff(maxSkipped: 3);
    for (var i = 0; i < 40; i++) {
      backoff.failed();
    }
    expect(ticks(backoff, 4), [false, false, false, true]);
  });

  test('a success or a reset ends the wait', () {
    final backoff = PollBackoff()
      ..failed()
      ..failed()
      ..succeeded();
    expect(ticks(backoff, 2), [true, true]);
    expect(backoff.failures, 0);
    backoff
      ..failed()
      ..reset();
    expect(backoff.tick(), isTrue);
  });
}

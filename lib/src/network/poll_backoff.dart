/// Spaces out the ticks of a fixed-interval poll while it keeps failing.
///
/// A poller keeps its `Timer.periodic` and asks [tick] at every tick: after
/// `n` failures in a row it skips `2^n - 1` ticks, so a 1-minute poll looks
/// again after 2, 4, 8 minutes, at most every [maxSkipped] + 1 ticks. A
/// success ([succeeded]) or a change that makes a look worth trying at once
/// ([reset], such as the app coming back to the front) ends the wait.
///
/// Ticks are counted, not wall-clock time, so a timer that fires a little
/// early never skips one tick too many.
class PollBackoff {
  PollBackoff({this.maxSkipped = 14}) : assert(maxSkipped >= 0);

  /// The most ticks skipped in a row, however many looks failed.
  final int maxSkipped;

  int _failures = 0;
  int _skip = 0;

  /// Looks that failed in a row since the last success or [reset].
  int get failures => _failures;

  /// Whether this tick should look. A skipped tick counts down the wait.
  bool tick() {
    if (_skip == 0) return true;
    _skip--;
    return false;
  }

  void succeeded() => reset();

  void failed() {
    _failures++;
    // 2^n - 1, without overflowing after many failures.
    final wait = _failures >= 31 ? maxSkipped : (1 << _failures) - 1;
    _skip = wait < maxSkipped ? wait : maxSkipped;
  }

  void reset() {
    _failures = 0;
    _skip = 0;
  }
}

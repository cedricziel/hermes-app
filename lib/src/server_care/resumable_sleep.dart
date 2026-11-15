import 'dart:async';

/// A poll's wait that a resume of the app can cut short.
///
/// A suspended app never runs the timer a poll waits for, so on resume the
/// poll reads now instead. [release] ends the wait this instance holds; it
/// touches nothing else.
class ResumableSleep {
  ResumableSleep(this._delay, {this.covered});

  final Future<void> Function(Duration) _delay;

  /// Whether App Lock covers the app: no resume is acted on then.
  final bool Function()? covered;

  Completer<void>? _wake;
  bool _owed = false;

  /// Waits [duration], or less when [wake], [resumed] or [release] ends it.
  Future<void> sleep(Duration duration) {
    final wake = _wake = Completer<void>();
    return Future.any([_delay(duration), wake.future]).whenComplete(() {
      if (identical(_wake, wake)) _wake = null;
    });
  }

  /// Ends the wait now.
  void wake() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// The app came back to the front. While App Lock covers it the wake is
  /// owed until [unlocked].
  void resumed() {
    if (covered?.call() ?? false) {
      _owed = true;
      return;
    }
    _owed = false;
    wake();
  }

  /// App Lock lifted: makes up for a resume it held back.
  void unlocked() {
    if (_owed) resumed();
  }

  /// Ends the wait the owner no longer needs.
  void release() => wake();
}

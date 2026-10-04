/// Detects the "the list has content but paints nothing" state of the chat
/// transcript, and says when to remount it.
///
/// The transcript is a `SliverAnimatedList` (via `ChatAnimatedList`). While a
/// reply streams, plain content deltas are cheap in-place updates, but every
/// structural change (an interim sealed into prose, a tool-call block
/// appearing) is a remove+insert pair. If the sliver's internal index
/// accounting ever desyncs from its painted children, layout paints nothing —
/// the blank-thread state. It heals only when the subtree is remounted, which
/// until now took a manual switch to another thread and back.
///
/// The signal available from outside the package: while the follower is glued
/// to the bottom of a non-empty list and the scroll metrics are churning
/// (streaming keeps resizing the content), the list must be building items.
/// Several churned steps in a row without a single item build mean the sliver
/// is no longer painting, and one remount recovers it. Message state lives in
/// the `InMemoryChatController` above the list, so a remount loses nothing;
/// the worst a false positive can do is one relayout flicker.
class BlankListWatchdog {
  BlankListWatchdog({
    this.quietSteps = 8,
    this.cooldown = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How many churned following-steps without an item build count as blank.
  /// A few in a row happen legitimately — the keyboard animating the composer
  /// padding resizes the viewport without touching any message — so the
  /// threshold sits well above that.
  final int quietSteps;

  /// Minimum spacing between recoveries, so one incident cannot loop.
  final Duration cooldown;

  final DateTime Function() _now;

  int _quiet = 0;
  var _hasBuiltAnItem = false;
  DateTime _lastRecovery = DateTime.fromMillisecondsSinceEpoch(0);

  /// The list built an item: it is painting.
  void onItemBuilt() {
    _hasBuiltAnItem = true;
    _quiet = 0;
  }

  /// One churned step of the metrics while following at the bottom of a
  /// non-empty list. Returns true exactly once per incident — when
  /// [quietSteps] steps passed without any item build — as the signal to
  /// remount the list.
  bool onFollowingStep() {
    if (!_hasBuiltAnItem) return false;
    if (++_quiet < quietSteps) return false;
    _quiet = 0;

    final now = _now();
    if (now.difference(_lastRecovery) < cooldown) return false;
    _lastRecovery = now;
    return true;
  }

  /// The reader scrolled away or the list emptied: stop counting until
  /// following and items resume.
  void disarm() {
    _quiet = 0;
  }
}

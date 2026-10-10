import 'package:clock/clock.dart';

/// Whether the quick panel's chat continues when the panel shows again: it
/// does within [window] of its last send or reply event, on the same
/// profile. Otherwise the panel starts empty.
class QuickPanelSession {
  QuickPanelSession({this.window = const Duration(minutes: 5)});

  final Duration window;

  ({String? profile, DateTime at})? _lastUse;

  /// The chat on [profile] was just used: a send or a reply event.
  void touch(String? profile) => _lastUse = (profile: profile, at: clock.now());

  /// Whether the chat continues for a panel shown on [profile]; forgets it
  /// when it does not.
  bool resume(String? profile) {
    final last = _lastUse;
    final continues =
        last != null &&
        last.profile == profile &&
        clock.now().difference(last.at) < window;
    if (!continues) clear();
    return continues;
  }

  /// Forgets the chat, so the next show starts empty (it moved to a window).
  void clear() => _lastUse = null;
}

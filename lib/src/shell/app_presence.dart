import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What an [AppLifecycleState] means for work that should run while the user
/// can still be told about it.
///
/// On macOS closing the last window leaves the app running, and Flutter then
/// reports `hidden` (or `inactive` while another app is in front) although
/// nothing is suspended. Only `paused` means the system stopped the app. On
/// the other platforms `hidden` and `inactive` are on the way to `paused`, so
/// they count as background there.
abstract final class AppPresence {
  /// Whether the app is running at full speed: timers and polling go on.
  /// A state not yet reported counts as in front.
  static bool foreground(AppLifecycleState? state, {TargetPlatform? platform}) {
    if (state == null || state == AppLifecycleState.resumed) return true;
    return _isMac(platform) &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.inactive);
  }

  /// Whether the user is looking at the app, so a notification is redundant.
  static bool focused(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  static bool _isMac(TargetPlatform? platform) =>
      (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;
}

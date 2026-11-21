import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether the app's content must be out of sight while the app is inactive
/// here: iOS and Android snapshot the screen for the app switcher after
/// Flutter stopped drawing. macOS, Windows and Linux take no such snapshot.
bool get blanksWhenInactiveHere =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Whether [state] is one where the app's snapshot may be taken: inactive,
/// hidden or paused.
bool isAwayState(AppLifecycleState? state) =>
    state == AppLifecycleState.inactive ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.paused;

/// Tells when the app is inactive (or hidden) on a phone, for the one piece
/// of a screen that must draw nothing readable then and cannot be wrapped in
/// a `PrivateSurface` (it is only a part of a list). [away] is always false
/// where [blanksWhenInactiveHere] is false, unless [appliesHere] says
/// otherwise (a test). It never throws and holds no content.
class AppInactiveWatcher extends ChangeNotifier with WidgetsBindingObserver {
  AppInactiveWatcher({bool? appliesHere})
    : _applies = appliesHere ?? blanksWhenInactiveHere {
    WidgetsBinding.instance.addObserver(this);
    _away = _applies && isAwayState(WidgetsBinding.instance.lifecycleState);
  }

  final bool _applies;
  late bool _away;

  /// The app is inactive or hidden and the platform takes a snapshot then.
  bool get away => _away;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = _applies && isAwayState(state);
    if (next == _away) return;
    _away = next;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

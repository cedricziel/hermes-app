import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells whether a modal route (a dialog, a sheet, a popup menu: any
/// [PopupRoute]) is on top of the navigator it observes.
///
/// Add it to `navigatorObservers`. Listeners hear of a change after the frame
/// that pushed or popped the route, since the navigator reports while it
/// builds.
class ModalRouteObserver extends NavigatorObserver with ChangeNotifier {
  final _open = <Route<dynamic>>{};
  var _disposed = false;

  /// Whether a modal route is open.
  bool get modalOpen => _open.isNotEmpty;

  void _changed(Route<dynamic>? route, {required bool added}) {
    if (route is! PopupRoute) return;
    final before = modalOpen;
    added ? _open.add(route) : _open.remove(route);
    if (before == modalOpen) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, added: true);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, added: false);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, added: false);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _changed(oldRoute, added: false);
    _changed(newRoute, added: true);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Whether a modal route (any [PopupRoute]: dialog, sheet, popup menu) is in
/// front of the screen the keyboard works on.
///
/// [observer] covers the app's root navigator. A sheet or menu pushed on a
/// nested navigator (the narrow chat layout, the activity panel; both open
/// them with `useRootNavigator: false`) never reaches the root observer, so
/// the route that holds primary focus is read as well: a modal route takes
/// focus into itself when it opens. Read live, so it needs no listener. With
/// no focus, or focus outside any route, only [observer] speaks.
bool isModalBlocking(ModalRouteObserver? observer, {FocusNode? focus}) {
  if (observer?.modalOpen ?? false) return true;
  final context = (focus ?? FocusManager.instance.primaryFocus)?.context;
  if (context == null || !context.mounted) return false;
  return ModalRoute.of(context) is PopupRoute;
}

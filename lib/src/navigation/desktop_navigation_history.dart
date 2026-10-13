import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../telemetry/breadcrumbs.dart';

@immutable
sealed class DesktopNavigationTarget {
  const DesktopNavigationTarget();
}

@immutable
final class WorkersNavigationTarget extends DesktopNavigationTarget {
  const WorkersNavigationTarget({this.boardSlug});
  final String? boardSlug;
}

typedef DesktopTargetResolver = Future<Route<void>?> Function(
  DesktopNavigationTarget target,
);

/// Replays only explicitly described pages after a guarded desktop Back.
class DesktopNavigationHistory extends NavigatorObserver with ChangeNotifier {
  DesktopNavigationHistory({
    required this.canNavigate,
    required this.resolve,
    this.breadcrumbs = Breadcrumbs.none,
  });

  final bool Function() canNavigate;
  DesktopTargetResolver resolve;
  Breadcrumbs breadcrumbs;
  final _routes = <Route<dynamic>>[];
  final _forward = <DesktopNavigationTarget>[];
  Route<dynamic>? _backRoute;
  bool _replaying = false;
  bool _resolving = false;
  bool _disposed = false;
  int _suppression = 0;
  int _revision = 0;

  Route<dynamic>? get currentRoute => _routes.lastOrNull;
  bool get canGoBack =>
      !_disposed && canNavigate() && navigator?.canPop() == true;
  bool get canGoForward =>
      !_disposed &&
      !_resolving &&
      _suppression == 0 &&
      canNavigate() &&
      _forward.isNotEmpty &&
      (currentRoute?.isFirst == true || _target(currentRoute) != null) &&
      currentRoute is PageRoute;

  DesktopNavigationTarget? _target(Route<dynamic>? route) =>
      switch (route?.settings.arguments) {
        final DesktopNavigationTarget target => target,
        _ => null,
      };

  Future<void> back() async {
    if (!canGoBack) return;
    final route = currentRoute;
    _backRoute = route;
    await navigator!.maybePop();
    if (currentRoute == route) _backRoute = null;
    breadcrumbs('nav.history.back', {
      'outcome': route?.isActive == false ? 'popped' : 'guarded',
    });
  }

  Future<void> forward() async {
    if (!canGoForward) return;
    final target = _forward.last;
    final revision = _revision;
    var consumed = false;
    _resolving = true;
    _notify();
    try {
      final route = await resolve(target);
      if (_disposed ||
          revision != _revision ||
          !canNavigate() ||
          _suppression != 0) {
        return;
      }
      _forward.removeLast();
      consumed = true;
      if (route == null) {
        breadcrumbs('nav.history.forward', {'outcome': 'unavailable'});
        return;
      }
      _replaying = true;
      try {
        unawaited(navigator!.push(route));
      } finally {
        _replaying = false;
      }
      breadcrumbs('nav.history.forward', {'outcome': 'opened'});
    } on Object {
      if (!consumed &&
          !_disposed &&
          revision == _revision &&
          canNavigate() &&
          _suppression == 0) {
        _forward.removeLast();
      }
      breadcrumbs('nav.history.forward', {'outcome': 'unavailable'});
    } finally {
      _resolving = false;
      _notify();
    }
  }

  void clear() {
    _revision++;
    _backRoute = null;
    _forward.clear();
    _notify();
  }

  /// Stops external guarded unwinds from becoming user history.
  VoidCallback suppressExternalNavigation() {
    _suppression++;
    _revision++;
    _backRoute = null;
    _notify();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _suppression--;
      _notify();
    };
  }

  /// Cancels pending resolution when a live input gate changes.
  void gateChanged() {
    _revision++;
    _backRoute = null;
    _notify();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _revision++;
    if (route is PageRoute && !_replaying) clear();
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    final target = _target(route);
    if (route is PageRoute &&
        route == _backRoute &&
        target != null &&
        _suppression == 0) {
      _forward.add(target);
      if (_forward.length > 32) _forward.removeAt(0);
      _backRoute = null;
    }
    if (route is! PageRoute && _backRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentRoute == _backRoute) _backRoute = null;
      });
    }
    _revision++;
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    clear();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index != -1) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    clear();
  }

  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _routes.clear();
    _forward.clear();
    super.dispose();
  }
}

class DesktopNavigationHistoryScope
    extends InheritedNotifier<DesktopNavigationHistory> {
  const DesktopNavigationHistoryScope({
    super.key,
    required DesktopNavigationHistory history,
    required super.child,
  }) : super(notifier: history);

  static DesktopNavigationHistory? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<DesktopNavigationHistoryScope>()
      ?.notifier;
}

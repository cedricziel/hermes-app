import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app_lock/app_lock_controller.dart';
import 'toolset_copy.dart';
import 'widgets/tools_confirmation.dart';

/// Asks the questions that come before something runs on the server: an
/// install, the Local terminal backend, the permission grant on a Mac.
///
/// One question is open at a time; asking while one is open, or while App
/// Lock covers the app, answers no. App Lock covering the app takes an open
/// question down and answers no, as does [dispose]. Cancel is the default,
/// so a question that goes away for any reason is a "no".
class ToolsAsker {
  ToolsAsker({required this.context, this.lock}) {
    lock?.addListener(_onLock);
  }

  /// The context the dialog is shown from, read when a question is asked.
  final BuildContext Function() context;
  final AppLockController? lock;
  Route<dynamic>? _route;
  NavigatorState? _navigator;
  var _disposed = false;

  Future<bool> ask(ToolsetQuestion question) async {
    if (_disposed || _route != null || (lock?.covered ?? false)) return false;
    final host = context();
    if (!host.mounted) return false;
    _navigator = Navigator.of(host, rootNavigator: true);
    final confirmed = await showToolsetConfirmation(
      host,
      question,
      onRoute: (route) => _route = route,
    );
    _route = null;
    _navigator = null;
    return confirmed && !_disposed && !(lock?.covered ?? false);
  }

  void _onLock() {
    if (lock?.covered ?? false) _takeDown();
  }

  /// Removes the open question's route, after the frame: the caller may be
  /// building or unmounting, where the navigator cannot change.
  void _takeDown() {
    final route = _route;
    final navigator = _navigator;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  void dispose() {
    if (_disposed) return;
    lock?.removeListener(_onLock);
    _takeDown();
    _disposed = true;
  }
}

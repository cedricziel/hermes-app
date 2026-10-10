import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../telemetry/breadcrumbs.dart';
import '../windows/conversation_windows.dart';
import 'global_shortcut.dart';

/// What a press of the quick panel shortcut does, in the main engine: shows
/// or hides the panel while signed in, and otherwise brings the main window
/// forward on its setup or sign-in screen.
class QuickPanelShortcut {
  QuickPanelShortcut({
    required this._shortcut,
    required this._windows,
    this._events = noopAppEventLogger,
    this._breadcrumbs = Breadcrumbs.none,
  });

  final GlobalShortcut _shortcut;
  final ConversationWindows _windows;
  final AppEventLogger _events;
  final Breadcrumbs _breadcrumbs;
  final _subscriptions = <StreamSubscription<void>>[];

  void start() {
    _subscriptions
      ..add(_shortcut.presses.listen((_) => unawaited(_pressed())))
      ..add(
        _shortcut.changes.listen(
          (set) => _events('panel.shortcut_changed', {'set': set}),
        ),
      );
  }

  Future<void> _pressed() async {
    _breadcrumbs('panel.shortcut_pressed');
    if (!await _windows.togglePanel()) await _windows.showMainWindow();
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}

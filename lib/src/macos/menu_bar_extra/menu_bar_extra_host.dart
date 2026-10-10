import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../../api/hermes_repositories.dart';
import '../../app_lock/app_lock_controller.dart';
import '../../chat/widgets/approval_card.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../windows/conversation_windows.dart';
import '../mac_app.dart';
import '../mac_window.dart';
import 'menu_bar_extra.dart';
import 'menu_bar_extra_link.dart';
import 'menu_bar_extra_settings.dart';
import 'menu_bar_tray.dart';

/// Runs the menu bar item for the whole app and gives the chat screen the
/// [MenuBarExtraLink] it connects through. It passes its child through where
/// there is no menu bar item: off macOS, in a window without the Mac chrome,
/// or without [MenuBarExtraSettings] above it.
class MenuBarExtraHost extends StatefulWidget {
  const MenuBarExtraHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.tray,
  });

  /// Gives the confirmation dialog a context under the navigator.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// The item's native side; the runner's status item unless a test supplies
  /// its own.
  final MenuBarTray? tray;

  @override
  State<MenuBarExtraHost> createState() => _MenuBarExtraHostState();
}

class _MenuBarExtraHostState extends State<MenuBarExtraHost> {
  final _link = MenuBarExtraLink();
  MenuBarExtra? _extra;

  @override
  void initState() {
    super.initState();
    if (!MenuBarExtraSettings.offered || !MacWindow.enabled) return;
    final MenuBarExtraSettings settings;
    try {
      settings = context.read<MenuBarExtraSettings>();
    } on ProviderNotFoundException {
      return;
    }
    final windows = _maybeRead<ConversationWindows?>();
    _extra = MenuBarExtra(
      tray: widget.tray ?? ChannelMenuBarTray(),
      settings: settings,
      link: _link,
      showMainWindow: () =>
          windows == null ? MacWindow.orderFront() : windows.showMainWindow(),
      focusWindow: (threadId, profile) async {
        final window = windows?.windowFor(threadId, profile);
        return window != null && await windows!.focus(window.windowId);
      },
      confirmAlways: _confirmAlways,
      lock: _maybeRead<AppLockController>(),
      quit: MacApp.terminate,
      breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      events: _events,
    );
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  AppEventLogger _events() =>
      HermesRepositories.maybeOf(context)?.telemetry.events ??
      noopAppEventLogger;

  Future<bool> _confirmAlways() async {
    final context = widget.navigatorKey.currentContext;
    return context != null && await confirmAlwaysAllow(context);
  }

  @override
  void dispose() {
    _extra?.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      InheritedProvider<MenuBarExtraLink?>.value(
        value: _extra == null ? null : _link,
        child: widget.child,
      );
}

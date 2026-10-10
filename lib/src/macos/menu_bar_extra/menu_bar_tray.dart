import 'dart:async';

import 'package:flutter/services.dart';

import 'menu_bar_extra_model.dart';
import 'menu_bar_menu.dart';

/// The menu bar item as the app sees it: what to show, and what the user did.
abstract interface class MenuBarTray {
  /// Shows the item with [state]'s icon and [items] as its menu, or removes
  /// it when not [visible]. An [urgent] update replaces a menu that is open
  /// instead of waiting for it to close: the app just locked, and the open
  /// menu still shows what the lock hides.
  Future<void> update({
    required bool visible,
    required MenuBarIconState state,
    required List<MenuBarItem> items,
    bool urgent = false,
  });

  /// The keys of the items the user picks.
  Stream<String> get selections;

  /// Fires each time the menu opens.
  Stream<void> get opened;
}

/// The runner's `NSStatusItem` (`MenuBarStatusItem`), reached over a channel.
class ChannelMenuBarTray implements MenuBarTray {
  ChannelMenuBarTray() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'selected' when call.arguments is String:
          _selections.add(call.arguments as String);
        case 'opened':
          _opened.add(null);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('hermes_app/menu_bar_extra');
  final _selections = StreamController<String>.broadcast();
  final _opened = StreamController<void>.broadcast();

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Stream<void> get opened => _opened.stream;

  @override
  Future<void> update({
    required bool visible,
    required MenuBarIconState state,
    required List<MenuBarItem> items,
    bool urgent = false,
  }) => _channel.invokeMethod<void>('update', {
    'visible': visible,
    'urgent': urgent,
    'state': state.name,
    'items': [for (final item in items) item.toJson()],
  });
}

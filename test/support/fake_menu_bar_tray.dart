import 'dart:async';

import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_model.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_menu.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_tray.dart';

typedef TrayUpdate = ({
  bool visible,
  MenuBarIconState state,
  List<MenuBarItem> items,
  bool urgent,
});

/// Stands in for the runner's status item: records what the app shows and
/// lets a test pick items and open the menu.
class FakeMenuBarTray implements MenuBarTray {
  final updates = <TrayUpdate>[];
  final _selections = StreamController<String>.broadcast(sync: true);
  final _opened = StreamController<void>.broadcast(sync: true);

  TrayUpdate get last => updates.last;

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
  }) async => updates.add((
    visible: visible,
    state: state,
    items: items,
    urgent: urgent,
  ));

  /// The titles of the top-level items, separators left out.
  List<String> get titles => [
    for (final item in last.items)
      if (!item.separator) item.title,
  ];

  /// The item titled [title], searched through the submenus.
  MenuBarItem item(String title) {
    MenuBarItem? find(List<MenuBarItem> items) {
      for (final item in items) {
        if (item.title == title) return item;
        if (item.children != null) {
          final nested = find(item.children!);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    return find(last.items) ??
        (throw StateError('No menu item "$title" in $titles'));
  }

  /// The titles of the entries in [parent]'s submenu, separators left out.
  List<String> submenuOf(String parent) => [
    for (final child in item(parent).children!)
      if (!child.separator) child.title,
  ];

  /// Picks the item titled [title] and lets the action finish.
  Future<void> pick(String title) async {
    final key = item(title).key;
    if (key == null) throw StateError('"$title" cannot be picked');
    _selections.add(key);
    await Future<void>.delayed(Duration.zero);
  }

  /// Picks by key, as the runner reports a pick, without waiting for it.
  void pickKey(String key) => _selections.add(key);

  /// Lets whatever a pick started finish.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void openMenu() => _opened.add(null);
}

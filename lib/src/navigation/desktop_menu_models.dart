import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import '../macos/mac_commands.dart';
import '../macos/menu_layout.dart';
import 'keyboard_shortcut_models.dart';
import 'keyboard_shortcuts.dart';

/// One item of a menu on the desktop menu bar. A null [onSelected] shows it
/// disabled.
@immutable
class DesktopMenuItemModel {
  const DesktopMenuItemModel({
    required this.label,
    this.chord,
    this.onSelected,
  });

  final String label;

  /// The chord shown after the label, as [desktopChordOf] writes it. Only
  /// shown: the key itself is bound by [DesktopCommandShortcuts].
  final ShortcutChord? chord;
  final VoidCallback? onSelected;
}

/// A top-level menu of the bar: [groups] are set apart by separators.
@immutable
class DesktopMenuModel {
  const DesktopMenuModel({required this.label, required this.groups});

  final String label;
  final List<List<DesktopMenuItemModel>> groups;
}

/// The menus of the desktop menu bar: File, View, Chat and Help, from the
/// Windows and Linux side of [menuLayout], each item enabled while
/// [registry] has a handler for its command.
///
/// The Hermes menu is the Mac's application menu and has no place on a bar
/// that starts with File, so its items follow File's own.
List<DesktopMenuModel> desktopMenus(
  MacCommandRegistry registry,
  AppLocalizations l10n,
) {
  DesktopMenuItemModel item(MenuEntry entry) {
    final handler = registry.handlerFor(entry.command);
    final chord = entry.shortcutOn(MenuPlatform.desktop);
    return DesktopMenuItemModel(
      label: handler?.title ?? entry.label(l10n),
      chord: chord == null ? null : desktopChordOf(chord, l10n),
      onSelected: handler?.enabled ?? false
          ? () => registry.invoke(entry.command)
          : null,
    );
  }

  List<List<DesktopMenuItemModel>> groupsOf(MenuSection section) => [
    for (final group in section.groupsOn(MenuPlatform.desktop))
      [for (final entry in group) item(entry)],
  ];

  MenuSection section(String id) => menuLayout.firstWhere((s) => s.id == id);

  return [
    DesktopMenuModel(
      label: section('file').label(l10n),
      groups: [...groupsOf(section('file')), ...groupsOf(section('hermes'))],
    ),
    for (final id in const ['view', 'chat', 'help'])
      DesktopMenuModel(
        label: section(id).label(l10n),
        groups: groupsOf(section(id)),
      ),
  ];
}

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

  /// The same menu with every item disabled.
  DesktopMenuModel inert() => DesktopMenuModel(
    label: label,
    groups: [
      for (final group in groups)
        [
          for (final item in group)
            DesktopMenuItemModel(label: item.label, chord: item.chord),
        ],
    ],
  );
}

/// Commands with a chord that the bar has no item for: F10 moves into the
/// bar, so an item for it in the bar would be a loop.
const _notInTheBar = {MacCommand.focusMenuBar};

/// The menus of the desktop menu bar: File, View, Chat and Help, from the
/// Windows and Linux side of [menuLayout], each item enabled while
/// [registry] has a handler for its command.
///
/// The Hermes menu is the Mac's application menu and has no place on a bar
/// that starts with File. As Windows and Linux apps place them, its Settings
/// and Connection Details follow File's own items, Sign Out ends File after a
/// divider, and About ends Help.
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

  MenuSection section(String id) => menuLayout.firstWhere((s) => s.id == id);

  // The entries of a section as groups, minus the commands moved elsewhere.
  List<List<DesktopMenuItemModel>> groupsOf(
    String id, {
    Set<MacCommand> without = const {},
  }) => [
    for (final group in section(id).groupsOn(MenuPlatform.desktop))
      if ([
            for (final entry in group)
              if (!without.contains(entry.command) &&
                  !_notInTheBar.contains(entry.command))
                item(entry),
          ]
          case final shown when shown.isNotEmpty)
        shown,
  ];

  DesktopMenuItemModel one(MacCommand command) => item(menuEntryOf(command)!);

  const moved = {MacCommand.about, MacCommand.signOut};
  return [
    DesktopMenuModel(
      label: section('file').label(l10n),
      groups: [
        ...groupsOf('file'),
        ...groupsOf('hermes', without: moved),
        [one(MacCommand.signOut)],
      ],
    ),
    DesktopMenuModel(
      label: section('view').label(l10n),
      groups: groupsOf('view'),
    ),
    DesktopMenuModel(
      label: section('chat').label(l10n),
      groups: groupsOf('chat'),
    ),
    DesktopMenuModel(
      label: section('help').label(l10n),
      groups: [
        ...groupsOf('help'),
        [one(MacCommand.about)],
      ],
    ),
  ];
}

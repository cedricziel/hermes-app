import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../macos/mac_commands.dart';
import '../macos/menu_layout.dart';
import 'keyboard_shortcut_models.dart';
import 'widgets/keyboard_shortcuts_view.dart';

/// Whether [platform] binds the Windows and Linux chords of [menuLayout]
/// through [DesktopCommandShortcuts]; a Mac binds its own through the menu
/// bar, and the iPad through its menus.
bool bindsDesktopChords(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.linux;

/// The menu entry of [command], or null for a command the menus do not list.
MenuEntry? menuEntryOf(MacCommand command) {
  for (final section in menuLayout) {
    for (final group in section.groups) {
      for (final entry in group) {
        if (entry.command == command) return entry;
      }
    }
  }
  return null;
}

/// [chord] as the keys a person presses on Windows and Linux, such as
/// `Ctrl`, `Shift`, `F`.
ShortcutChord desktopChordOf(SingleActivator chord, AppLocalizations l10n) =>
    ShortcutChord([
      if (chord.control) l10n.navigationKeyCtrl,
      if (chord.alt) l10n.navigationKeyAlt,
      if (chord.shift) l10n.navigationKeyShift,
      if (chord.meta) l10n.navigationKeyWin,
      _keyName(chord.trigger, l10n),
    ]);

/// [chord] as the Mac writes it: ⌃⌥⇧⌘ and then the key.
ShortcutChord macChordOf(SingleActivator chord) => ShortcutChord([
  if (chord.control) '⌃',
  if (chord.alt) '⌥',
  if (chord.shift) '⇧',
  if (chord.meta) '⌘',
  _macKeyName(chord.trigger),
]);

String _keyName(LogicalKeyboardKey key, AppLocalizations l10n) => switch (key) {
  LogicalKeyboardKey.arrowLeft => l10n.navigationKeyLeft,
  LogicalKeyboardKey.arrowRight => l10n.navigationKeyRight,
  LogicalKeyboardKey.arrowUp => l10n.navigationKeyUp,
  LogicalKeyboardKey.arrowDown => l10n.navigationKeyDown,
  LogicalKeyboardKey.backspace => l10n.navigationKeyBackspace,
  _ => _plainKeyName(key),
};

/// A key whose name is the same in every language: a letter, a function key
/// or a punctuation mark.
String _plainKeyName(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.bracketLeft => '[',
  LogicalKeyboardKey.bracketRight => ']',
  LogicalKeyboardKey.comma => ',',
  _ => key.keyLabel,
};

String _macKeyName(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.arrowLeft => '←',
  LogicalKeyboardKey.arrowRight => '→',
  LogicalKeyboardKey.arrowUp => '↑',
  LogicalKeyboardKey.arrowDown => '↓',
  LogicalKeyboardKey.backspace => '⌫',
  _ => _plainKeyName(key),
};

/// The chords of [entry] on [platform], as written there.
List<ShortcutChord> chordsOf(
  MenuEntry entry,
  MenuPlatform platform,
  AppLocalizations l10n,
) => [
  for (final chord in entry.shortcutsOn(platform))
    platform == MenuPlatform.mac
        ? macChordOf(chord)
        : desktopChordOf(chord, l10n),
];

/// Every command of [menuLayout] that has a chord on [platform], grouped as
/// the menus are. The Keyboard shortcuts page and a menu bar read the same
/// declarations, so a command is listed once.
List<ShortcutSectionModel> keyboardShortcutSections(
  AppLocalizations l10n,
  MenuPlatform platform,
) => [
  for (final section in menuLayout)
    if ([
          for (final group in section.groupsOn(platform))
            for (final entry in group)
              if (entry.shortcutsOn(platform).isNotEmpty)
                ShortcutRowModel(
                  label: _withoutEllipsis(entry.label(l10n)),
                  chords: chordsOf(entry, platform, l10n),
                ),
        ]
        case final rows when rows.isNotEmpty)
      ShortcutSectionModel(title: section.label(l10n), rows: rows),
];

String _withoutEllipsis(String label) =>
    label.endsWith('…') ? label.substring(0, label.length - 1) : label;

/// The page's platform: the Mac's keys on a Mac, Windows and Linux's
/// elsewhere.
MenuPlatform shortcutsPlatformOf(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ? MenuPlatform.mac : MenuPlatform.desktop;

const _routeName = 'keyboard-shortcuts';

/// Opens the Keyboard shortcuts page over the route in front, unless it is
/// the route in front already.
Future<void> showKeyboardShortcuts(BuildContext context) {
  final navigator = Navigator.of(context);
  var open = false;
  navigator.popUntil((route) {
    open = route.settings.name == _routeName;
    return true;
  });
  if (open) return Future.value();
  final sections = keyboardShortcutSections(
    context.l10n,
    shortcutsPlatformOf(Theme.of(context).platform),
  );
  return navigator.push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: _routeName),
      builder: (_) => KeyboardShortcutsPage(sections: sections),
    ),
  );
}

/// [label] with the first Windows or Linux chord of [command] after it, such
/// as "New chat (Ctrl+N)", for a button's tooltip. The label alone where the
/// platform binds none: a Mac button shows its chord in its own form.
String withChordHint(BuildContext context, String label, MacCommand command) {
  if (!bindsDesktopChords(Theme.of(context).platform)) return label;
  final chord = menuEntryOf(command)?.shortcutOn(MenuPlatform.desktop);
  if (chord == null) return label;
  return context.l10n.navigationChordTooltip(
    label,
    desktopChordOf(chord, context.l10n).text,
  );
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import 'mac_commands.dart';

/// A platform that shows [menuLayout]. [desktop] is Windows and Linux, which
/// bind the chords of [MenuEntry.desktopShortcuts] and have no native menu
/// bar to show them in.
enum MenuPlatform { mac, ipad, desktop }

/// One item of the app's menus, which carries out [command].
class MenuEntry {
  const MenuEntry(
    this.command,
    this.labelOf, {
    this.shortcut,
    this.desktopShortcuts = const [],
    this.platforms = _all,
    this.ipadShortcut = true,
  });

  final MacCommand command;

  /// Reads the label from the app's localizations.
  final String Function(AppLocalizations l10n) labelOf;
  final SingleActivator? shortcut;

  /// The chords Windows and Linux bind, the first one being the one a menu
  /// and a tooltip show. Not the Mac's with Ctrl for Cmd: a chord that text
  /// editing owns (Ctrl+Backspace) gets none.
  final List<SingleActivator> desktopShortcuts;
  final Set<MenuPlatform> platforms;

  /// False where [shortcut] is the Mac's and iPad keeps the key for the text
  /// field.
  final bool ipadShortcut;

  /// The label while the screen in front sets no title of its own.
  String label(AppLocalizations l10n) => labelOf(l10n);

  /// The chord [platform] binds to this item, if any.
  SingleActivator? shortcutOn(MenuPlatform platform) =>
      shortcutsOn(platform).firstOrNull;

  /// Every chord [platform] binds to this item.
  List<SingleActivator> shortcutsOn(MenuPlatform platform) =>
      switch (platform) {
        MenuPlatform.mac => [?shortcut],
        MenuPlatform.ipad => [if (ipadShortcut) ?shortcut],
        MenuPlatform.desktop => desktopShortcuts,
      };
}

/// A menu of the layout: [groups] are set apart by separators.
class MenuSection {
  const MenuSection(this.id, this.labelOf, this.groups);

  final String id;
  final String Function(AppLocalizations l10n) labelOf;
  final List<List<MenuEntry>> groups;

  String label(AppLocalizations l10n) => labelOf(l10n);

  /// [groups] as [platform] shows them, without the entries it does not offer
  /// and the groups that leave empty.
  List<List<MenuEntry>> groupsOn(MenuPlatform platform) => [
    for (final group in groups)
      if ([
            for (final entry in group)
              if (entry.platforms.contains(platform)) entry,
          ]
          case final shown when shown.isNotEmpty)
        shown,
  ];
}

const _all = {MenuPlatform.mac, MenuPlatform.ipad, MenuPlatform.desktop};
const _macOnly = {MenuPlatform.mac};
const _macAndDesktop = {MenuPlatform.mac, MenuPlatform.desktop};
const _desktopOnly = {MenuPlatform.desktop};

/// Ctrl plus [key], with the other modifiers on request.
SingleActivator ctrlActivator(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) => SingleActivator(key, control: true, shift: shift, alt: alt);

/// ⌘ plus [key], with the other modifiers on request.
SingleActivator metaActivator(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
  bool control = false,
}) =>
    SingleActivator(key, meta: true, shift: shift, alt: alt, control: control);

/// The commands of the app's menus, shared by the Mac menu bar and the iPad
/// menus. The Mac adds the items the system provides (Services, Hide, Edit,
/// Window and the like) around these.
final menuLayout = <MenuSection>[
  MenuSection('hermes', (_) => 'Hermes', [
    [MenuEntry(MacCommand.about, (l10n) => l10n.macosMenuAbout)],
    [
      MenuEntry(
        MacCommand.settings,
        (l10n) => l10n.macosMenuSettings,
        shortcut: metaActivator(LogicalKeyboardKey.comma),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.comma)],
      ),
    ],
    [
      MenuEntry(
        MacCommand.connectionDetails,
        (l10n) => l10n.macosMenuConnectionDetails,
      ),
      MenuEntry(MacCommand.signOut, (l10n) => l10n.macosMenuSignOut),
    ],
  ]),
  MenuSection('file', (l10n) => l10n.macosMenuFile, [
    [
      MenuEntry(
        MacCommand.newChat,
        (l10n) => l10n.macosMenuNewChat,
        shortcut: metaActivator(LogicalKeyboardKey.keyN),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.keyN)],
      ),
      MenuEntry(
        MacCommand.openInNewWindow,
        (l10n) => l10n.macosMenuOpenInNewWindow,
        shortcut: metaActivator(LogicalKeyboardKey.keyO, alt: true),
        platforms: _macOnly,
      ),
    ],
    [
      MenuEntry(
        MacCommand.closeWindow,
        (l10n) => l10n.macosMenuCloseWindow,
        shortcut: metaActivator(LogicalKeyboardKey.keyW),
        platforms: _macOnly,
      ),
    ],
  ]),
  MenuSection('view', (l10n) => l10n.macosMenuView, [
    [
      MenuEntry(
        MacCommand.reload,
        (l10n) => l10n.macosMenuReload,
        shortcut: metaActivator(LogicalKeyboardKey.keyR),
        desktopShortcuts: [
          ctrlActivator(LogicalKeyboardKey.keyR),
          const SingleActivator(LogicalKeyboardKey.f5),
        ],
      ),
    ],
    [
      MenuEntry(
        MacCommand.back,
        (l10n) => l10n.macosMenuBack,
        shortcut: metaActivator(LogicalKeyboardKey.bracketLeft),
        desktopShortcuts: const [
          SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
        ],
      ),
      MenuEntry(
        MacCommand.forward,
        (l10n) => l10n.macosMenuForward,
        shortcut: metaActivator(LogicalKeyboardKey.bracketRight),
        desktopShortcuts: const [
          SingleActivator(LogicalKeyboardKey.arrowRight, alt: true),
        ],
        platforms: _macAndDesktop,
      ),
      // ⌘↑ moves a text field's caret on iPad, so there the key stays with it.
      MenuEntry(
        MacCommand.enclosingFolder,
        (l10n) => l10n.macosMenuEnclosingFolder,
        shortcut: metaActivator(LogicalKeyboardKey.arrowUp),
        desktopShortcuts: const [
          SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
        ],
        ipadShortcut: false,
      ),
    ],
    [
      MenuEntry(
        MacCommand.toggleSidebar,
        (l10n) => l10n.macosMenuShowSidebar,
        shortcut: metaActivator(LogicalKeyboardKey.keyS, control: true),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.keyB)],
        platforms: _macAndDesktop,
      ),
      MenuEntry(
        MacCommand.toggleInspector,
        (l10n) => l10n.chatActivityInspectorShow,
        shortcut: metaActivator(LogicalKeyboardKey.keyI, alt: true),
        platforms: _macOnly,
      ),
      MenuEntry(
        MacCommand.showFiles,
        (l10n) => l10n.macosMenuShowFiles,
        shortcut: metaActivator(LogicalKeyboardKey.keyF, shift: true),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.keyF, shift: true)],
        platforms: _macAndDesktop,
      ),
    ],
    // Stepping through the files of a change; ⌥↑ and ⌥↓ move by paragraph in
    // an iPad text field, so there are no keys on the iPad. Windows and Linux
    // use F8 and Shift+F8.
    [
      MenuEntry(
        MacCommand.previousChange,
        (l10n) => l10n.macosMenuPreviousChange,
        shortcut: const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
        desktopShortcuts: const [SingleActivator(LogicalKeyboardKey.f8)],
        platforms: _macAndDesktop,
      ),
      MenuEntry(
        MacCommand.nextChange,
        (l10n) => l10n.macosMenuNextChange,
        shortcut: const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          alt: true,
        ),
        desktopShortcuts: const [
          SingleActivator(LogicalKeyboardKey.f8, shift: true),
        ],
        platforms: _macAndDesktop,
      ),
    ],
  ]),
  MenuSection('chat', (l10n) => l10n.macosMenuChat, [
    [
      MenuEntry(
        MacCommand.find,
        (l10n) => l10n.macosMenuFind,
        shortcut: metaActivator(LogicalKeyboardKey.keyF),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.keyF)],
      ),
    ],
    [
      MenuEntry(
        MacCommand.pinThread,
        (l10n) => l10n.macosMenuPin,
        shortcut: metaActivator(LogicalKeyboardKey.keyP, shift: true),
        desktopShortcuts: [ctrlActivator(LogicalKeyboardKey.keyP, shift: true)],
      ),
      MenuEntry(MacCommand.renameThread, (l10n) => l10n.macosMenuRename),
      // No chord: the folder button and the thread menu are the ways in.
      MenuEntry(
        MacCommand.changeFolder,
        (l10n) => l10n.macosMenuChangeFolder,
        platforms: _macOnly,
      ),
      MenuEntry(
        MacCommand.copyTranscript,
        (l10n) => l10n.macosMenuCopyTranscript,
      ),
      // No chord: a dialog follows, and the file can hold secrets.
      MenuEntry(MacCommand.exportThread, (l10n) => l10n.macosMenuExportChat),
      MenuEntry(
        MacCommand.compress,
        (l10n) => l10n.macosCompressConversation,
        platforms: _macOnly,
      ),
    ],
    [
      MenuEntry(MacCommand.archiveThread, (l10n) => l10n.macosMenuArchive),
      MenuEntry(
        MacCommand.deleteThread,
        (l10n) => l10n.macosMenuDelete,
        shortcut: metaActivator(LogicalKeyboardKey.backspace),
        // No Windows or Linux chord: Ctrl+Backspace deletes a word.
        ipadShortcut: false,
      ),
    ],
  ]),
  MenuSection('help', (l10n) => l10n.macosMenuHelp, [
    [MenuEntry(MacCommand.help, (l10n) => l10n.macosMenuHermesHelp)],
    [
      MenuEntry(
        MacCommand.keyboardShortcuts,
        (l10n) => l10n.navigationKeyboardShortcutsTitle,
        desktopShortcuts: const [SingleActivator(LogicalKeyboardKey.f1)],
        platforms: _desktopOnly,
      ),
      // Moves the keyboard into the optional menu bar; the bar registers it
      // while it is shown, so F10 is free for anything else otherwise.
      MenuEntry(
        MacCommand.focusMenuBar,
        (l10n) => l10n.navigationFocusMenuBar,
        desktopShortcuts: const [SingleActivator(LogicalKeyboardKey.f10)],
        platforms: _desktopOnly,
      ),
    ],
  ]),
];

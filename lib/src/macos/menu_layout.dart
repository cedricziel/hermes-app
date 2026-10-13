import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mac_commands.dart';

/// A platform that shows [menuLayout].
enum MenuPlatform { mac, ipad }

/// One item of the app's menus, which carries out [command].
class MenuEntry {
  const MenuEntry(
    this.command,
    this.label, {
    this.shortcut,
    this.platforms = _both,
    this.ipadShortcut = true,
  });

  final MacCommand command;

  /// The label while the screen in front sets no title of its own.
  final String label;
  final SingleActivator? shortcut;
  final Set<MenuPlatform> platforms;

  /// False where [shortcut] is the Mac's and iPad keeps the key for the text
  /// field.
  final bool ipadShortcut;

  /// The chord [platform] binds to this item, if any.
  SingleActivator? shortcutOn(MenuPlatform platform) =>
      platform == MenuPlatform.ipad && !ipadShortcut ? null : shortcut;
}

/// A menu of the layout: [groups] are set apart by separators.
class MenuSection {
  const MenuSection(this.id, this.label, this.groups);

  final String id;
  final String label;
  final List<List<MenuEntry>> groups;

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

const _both = {MenuPlatform.mac, MenuPlatform.ipad};
const _macOnly = {MenuPlatform.mac};

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
  MenuSection('hermes', 'Hermes', [
    [const MenuEntry(MacCommand.about, 'About Hermes')],
    [
      MenuEntry(
        MacCommand.settings,
        'Settings…',
        shortcut: metaActivator(LogicalKeyboardKey.comma),
      ),
    ],
    [
      const MenuEntry(MacCommand.connectionDetails, 'Connection Details'),
      const MenuEntry(MacCommand.signOut, 'Sign Out…'),
    ],
  ]),
  MenuSection('file', 'File', [
    [
      MenuEntry(
        MacCommand.newChat,
        'New Chat',
        shortcut: metaActivator(LogicalKeyboardKey.keyN),
      ),
      MenuEntry(
        MacCommand.openInNewWindow,
        'Open in New Window',
        shortcut: metaActivator(LogicalKeyboardKey.keyO, alt: true),
        platforms: _macOnly,
      ),
    ],
    [
      MenuEntry(
        MacCommand.closeWindow,
        'Close Window',
        shortcut: metaActivator(LogicalKeyboardKey.keyW),
        platforms: _macOnly,
      ),
    ],
  ]),
  MenuSection('view', 'View', [
    [
      MenuEntry(
        MacCommand.back,
        'Back',
        shortcut: metaActivator(LogicalKeyboardKey.bracketLeft),
      ),
      MenuEntry(
        MacCommand.forward,
        'Forward',
        shortcut: metaActivator(LogicalKeyboardKey.bracketRight),
        platforms: _macOnly,
      ),
    ],
    [
      MenuEntry(
        MacCommand.toggleSidebar,
        'Show Sidebar',
        shortcut: metaActivator(LogicalKeyboardKey.keyS, control: true),
        platforms: _macOnly,
      ),
      MenuEntry(
        MacCommand.toggleInspector,
        'Show Inspector',
        shortcut: metaActivator(LogicalKeyboardKey.keyI, alt: true),
        platforms: _macOnly,
      ),
    ],
  ]),
  MenuSection('chat', 'Chat', [
    [
      MenuEntry(
        MacCommand.find,
        'Find…',
        shortcut: metaActivator(LogicalKeyboardKey.keyF),
      ),
    ],
    [
      MenuEntry(
        MacCommand.pinThread,
        'Pin',
        shortcut: metaActivator(LogicalKeyboardKey.keyP, shift: true),
      ),
      const MenuEntry(MacCommand.renameThread, 'Rename…'),
      const MenuEntry(MacCommand.copyTranscript, 'Copy Transcript'),
    ],
    [
      const MenuEntry(MacCommand.archiveThread, 'Archive'),
      MenuEntry(
        MacCommand.deleteThread,
        'Delete…',
        shortcut: metaActivator(LogicalKeyboardKey.backspace),
        ipadShortcut: false,
      ),
    ],
  ]),
  MenuSection('help', 'Help', [
    [const MenuEntry(MacCommand.help, 'Hermes Help')],
  ]),
];

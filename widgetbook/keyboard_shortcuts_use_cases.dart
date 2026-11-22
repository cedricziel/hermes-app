import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/navigation/keyboard_shortcut_models.dart';
import 'package:hermes_app/src/navigation/widgets/chord_keys.dart';
import 'package:hermes_app/src/navigation/widgets/keyboard_shortcuts_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

ShortcutChord _c(String first, [String? second, String? third]) =>
    ShortcutChord([first, ?second, ?third]);

/// The commands of the Windows and Linux table, grouped as the menus are.
List<ShortcutSectionModel> _windowsAndLinux(AppLocalizations l10n) => [
  ShortcutSectionModel(
    title: l10n.macosMenuFile,
    rows: [
      ShortcutRowModel(label: l10n.macosMenuNewChat, chords: [_c('Ctrl', 'N')]),
      ShortcutRowModel(
        label: l10n.macosMenuSettings,
        chords: [_c('Ctrl', ',')],
      ),
    ],
  ),
  ShortcutSectionModel(
    title: l10n.macosMenuView,
    rows: [
      ShortcutRowModel(
        label: l10n.macosMenuReload,
        chords: [_c('Ctrl', 'R'), _c('F5')],
      ),
      ShortcutRowModel(label: l10n.macosMenuBack, chords: [_c('Alt', 'Left')]),
      ShortcutRowModel(
        label: l10n.macosMenuForward,
        chords: [_c('Alt', 'Right')],
      ),
      ShortcutRowModel(
        label: l10n.macosMenuEnclosingFolder,
        chords: [_c('Alt', 'Up')],
      ),
      ShortcutRowModel(
        label: l10n.macosMenuShowSidebar,
        chords: [_c('Ctrl', 'B')],
      ),
      ShortcutRowModel(
        label: l10n.macosMenuShowFiles,
        chords: [_c('Ctrl', 'Shift', 'F')],
      ),
      ShortcutRowModel(label: l10n.macosMenuPreviousChange, chords: [_c('F8')]),
      ShortcutRowModel(
        label: l10n.macosMenuNextChange,
        chords: [_c('Shift', 'F8')],
      ),
    ],
  ),
  ShortcutSectionModel(
    title: l10n.macosMenuChat,
    rows: [
      ShortcutRowModel(label: l10n.macosMenuFind, chords: [_c('Ctrl', 'F')]),
      ShortcutRowModel(
        label: l10n.macosMenuPin,
        chords: [_c('Ctrl', 'Shift', 'P')],
      ),
    ],
  ),
  ShortcutSectionModel(
    title: l10n.macosMenuHelp,
    rows: [
      ShortcutRowModel(
        label: l10n.navigationKeyboardShortcutsTitle,
        chords: [_c('F1')],
      ),
    ],
  ),
];

/// The same commands with the Mac's keys.
List<ShortcutSectionModel> _mac(AppLocalizations l10n) => [
  ShortcutSectionModel(
    title: l10n.macosMenuFile,
    rows: [
      ShortcutRowModel(label: l10n.macosMenuNewChat, chords: [_c('⌘', 'N')]),
      ShortcutRowModel(label: l10n.macosMenuSettings, chords: [_c('⌘', ',')]),
    ],
  ),
  ShortcutSectionModel(
    title: l10n.macosMenuView,
    rows: [
      ShortcutRowModel(label: l10n.macosMenuReload, chords: [_c('⌘', 'R')]),
      ShortcutRowModel(label: l10n.macosMenuBack, chords: [_c('⌘', '[')]),
      ShortcutRowModel(label: l10n.macosMenuForward, chords: [_c('⌘', ']')]),
      ShortcutRowModel(
        label: l10n.macosMenuEnclosingFolder,
        chords: [_c('⌘', '↑')],
      ),
      ShortcutRowModel(
        label: l10n.macosMenuShowSidebar,
        chords: [_c('⌃', '⌘', 'S')],
      ),
      ShortcutRowModel(
        label: l10n.macosMenuShowFiles,
        chords: [_c('⇧', '⌘', 'F')],
      ),
    ],
  ),
  ShortcutSectionModel(
    title: l10n.macosMenuChat,
    rows: [
      ShortcutRowModel(label: l10n.macosMenuFind, chords: [_c('⌘', 'F')]),
      ShortcutRowModel(label: l10n.macosMenuPin, chords: [_c('⇧', '⌘', 'P')]),
    ],
  ),
];

WidgetbookNode keyboardShortcutsNode() => WidgetbookFolder(
  name: 'Keyboard shortcuts',
  children: [
    WidgetbookComponent(
      name: 'KeyboardShortcutsPage',
      useCases: [
        WidgetbookUseCase(
          name: 'Windows and Linux',
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: TargetPlatform.linux),
            child: Builder(
              builder: (context) => pushed(
                KeyboardShortcutsPage(sections: _windowsAndLinux(context.l10n)),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Mac keys',
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
            child: Builder(
              builder: (context) =>
                  pushed(KeyboardShortcutsPage(sections: _mac(context.l10n))),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChordKeys',
      useCases: [
        WidgetbookUseCase(
          name: 'One and two combinations',
          builder: (_) => frame(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                ChordKeys(chords: [_c('Ctrl', 'N')]),
                ChordKeys(chords: [_c('Ctrl', 'R'), _c('F5')]),
                ChordKeys(chords: [_c('Ctrl', 'Shift', 'P')]),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);

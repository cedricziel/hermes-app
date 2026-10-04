## Why

The macOS app shows Flutter's default menu from `MainMenu.xib`: an app menu, a stock Edit menu and a Window menu. None of the app's own actions are there, so a Mac user cannot find New Chat, Find or the thread actions in the menu bar or reach them by keyboard, as the HIG expects ("every action is also in the menu bar"). The "Mac native concept" design lists the menus and their shortcuts.

## What Changes

- On macOS the app sets its own menu bar: Hermes, File, Edit, View, Chat, Window and Help, with the shortcuts from the design.
- A small command registry lets the screen in front offer handlers for menu commands. An item is disabled while no screen offers its command, and its label can follow state (Pin or Unpin).
- The chat screen offers New Chat (⌘N), Find… (⌘F, focuses the sidebar search field), and Pin/Unpin (⇧⌘P), Rename…, Copy Transcript, Archive and Delete… (⌘⌫) for the selected thread.
- The sidebar's Control-Command-S becomes the View menu's Show/Hide Sidebar item, so the chord has one owner.
- Edit items act on the focused text: Undo, Redo, Cut, Copy, Paste, Select All. Delete… deletes to the start of the line instead while a text field has focus.
- About Hermes opens the existing About dialog, Close Window closes the window, Hermes ⌘0 brings the main window to the front, Hermes Help opens the project's README.

### Non-goals

- Settings…, Open in New Window and Show Inspector stay disabled until the screens that provide them land (separate changes register them through the same registry).
- No check marks: Flutter's platform menu has no checked state.
- No Cycle Through Windows (⌘`): Flutter provides no item for it.
- Windows, Linux, Android, iOS and the web are unchanged.

### Security and privacy

None. No tokens, storage or network calls are involved; Hermes Help opens a public URL in the browser.

### Telemetry

None.

## Capabilities

### New Capabilities

- `macos-menu-bar`: the macOS menu bar, its items and shortcuts, and how they act on the screen in front.

### Modified Capabilities

None.

## Impact

- New `lib/src/macos/mac_commands.dart` (registry, `MacCommandScope`) and `lib/src/macos/mac_menu_bar.dart` (the menus).
- `lib/src/app.dart` wraps the app in the menu bar.
- `lib/src/macos/mac_sidebar.dart` drops its key handler for a command; `lib/src/chat/chat_screen.dart` registers the chat commands.
- No API, generated client, native or Xcode project change.

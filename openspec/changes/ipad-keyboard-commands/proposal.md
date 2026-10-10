# Proposal

## Why

iPadOS 26 gives every app a menu bar, and holding ⌘ shows its commands with their shortcuts. On an iPad with a keyboard, Hermes shows only the system's default menus: New Chat, Find, Pin or Settings cannot be reached from the keyboard, though the Mac app has all of them. The commands and their enablement already exist in Dart (`MacCommand`, `MacCommandScope`); they only need to reach UIKit.

## What Changes

- On iPadOS (and an iPhone with a keyboard, where holding ⌘ lists the same commands) the app adds its commands to the system menu bar with the Mac shortcuts:
  - Hermes: About Hermes; Settings… (⌘,); Connection Details, Sign Out…
  - File: New Chat (⌘N; "New Task" on Kanban, "New Schedule" on Schedules)
  - View: Back (⌘[)
  - Chat: Find… (⌘F); Pin or Unpin (⇧⌘P), Rename…, Copy Transcript; Archive, Delete…
  - Help: Hermes Help
- Items are enabled, disabled and retitled exactly as on the Mac: by the screens on view and their `MacCommandScope`s. A disabled command's shortcut is not taken, so the key reaches the app as before.
- The menu layout (labels, groups, shortcuts) is described once in Dart and used for both the Mac menu bar and the iPad menus.
- On iPad, Find… puts the cursor in the sidebar's chat search; the shell offers Settings…, Connection Details and Sign Out… on iPad too.
- The system's own Find and Format menus and New Window item are removed, since Hermes has no use for them and Find's ⌘F would clash.

Non-goals:

- No Mac-only commands on iPad: Open in New Window, Close Window, the Window menu's chat list, Show Sidebar, Show Inspector (the iPad layouts have no toggleable sidebar or inspector).
- No ⌘⌫ for Delete… on iPad: it stays the text field's "delete to line start".
- No change to the Edit menu: the system's Cut, Copy, Paste, Select All, Undo and Redo keep acting on the focused text field.
- No multiple windows (scenes) on iPad.
- No change to the macOS menu bar's content or behavior.

Security and privacy impact: None. No data leaves the app; the menu titles are fixed labels.

Observability:

- Breadcrumb `menu.command` with `command` (the enum name) and `platform` (`ipados`) when a menu item or shortcut runs a command, so a crash after a keyboard command is explained.
- Log event `ipad_menu.sync_failed` with `error.type` when the native side rejects a layout or state update, since a silently dead menu would otherwise go unnoticed.
- No span: nothing here waits on a server.

## Capabilities

### New Capabilities

- `ipad-keyboard-commands`: the iPadOS menu bar and ⌘-hold commands: which commands appear, their shortcuts, enablement from the screen in front, and how they coexist with text editing keys.

### Modified Capabilities

- `macos-menu-bar`: "Not on other platforms" now excludes iPadOS, which gets its commands from `ipad-keyboard-commands`.

## Impact

- Independent of the other changes in this rollout (wave 1).
- Dependencies: none on other changes in this rollout (wave 1), and no new package. `ipados_menu_bar` (0.6.1) was evaluated and rejected (see design.md).
- Dart: `lib/src/macos/mac_menu_bar.dart` split into a shared layout and its Mac rendering, a new `lib/src/macos/ipad_menu_bridge.dart`, iPad scopes in `app_shell.dart` and `chat_screen.dart`.
- iOS: `ios/Runner/KeyCommandMenu.swift` (channel `hermes_app/menu`), `buildMenu(with:)`, `canPerformAction(_:withSender:)` and `validate(_:)` in `AppDelegate.swift`. No Info.plist or entitlement change.
- Backend: none.

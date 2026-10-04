## 1. Command registry

- [x] 1.1 Failing tests for `MacCommandRegistry` and `MacCommandScope`: register, unregister on dispose, inner and later scopes win, priority, hidden pages, notify only on shown changes
- [x] 1.2 Implement `lib/src/macos/mac_commands.dart`

## 2. Menu bar

- [x] 2.1 Failing tests against a fake menu channel: menu structure, disabled items, selection runs the handler once, no menu off macOS, Edit items act on the focused field, ⌘⌫ guard
- [x] 2.2 Implement `MacMenuBar` and wire it into `HermesApp`, turned on in `main` on macOS

## 3. Screens

- [x] 3.1 Sidebar toggle as the View menu command, the key handler removed (test: the raw chord is left to the menu)
- [x] 3.2 Failing tests, then chat commands in `ChatScreen`: New Chat, Find…, Pin/Unpin, Rename…, Copy Transcript, Archive, Delete…

## 4. Docs and verify

- [x] 4.1 No Widgetbook use case (no Flutter widget; the menu is native), no telemetry, no skill goes stale; CLAUDE.md notes the registry
- [x] 4.2 Checked in the running macOS app: menus, shortcuts, copy/paste/undo in the composer and search field, ⌘⌫ guard

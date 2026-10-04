## Context

Flutter's `PlatformMenuBar` replaces the whole native menu, including the Edit menu from `MainMenu.xib`. On macOS a key event reaches the Flutter view first and goes to the menu's key equivalents only when the framework leaves it unhandled, so ⌘C in a text field is still handled by the text field; a menu item's callback runs when it is clicked or when no widget took the key.

## Decisions

- **Registry**: `MacCommandRegistry` maps each `MacCommand` to the handler of the winning registration: highest priority, then the latest. `MacCommandScope` registers while it is mounted and visible (`TickerMode` and `Visibility.of`, so a hidden `IndexedStack` page or covered route offers nothing). It notifies only when what the menu shows changes (enabled, title, window list), and defers that to the end of the frame when called during a build. Menu callbacks look the handler up when picked, so a screen that rebuilds with new closures does not re-send the menus.
- **Priority** exists for separate conversation windows: they run in their own engines, but only the main engine sets the menu, so a key conversation window overrides the main window's commands with priority 1 from the main isolate.
- **Edit**: no provided items exist for Undo to Select All, so the items dispatch the text intents (`UndoTextIntent`, `CopySelectionTextIntent`, `PasteTextIntent`, `SelectAllTextIntent`…) to the primary focus. They also work in a `SelectionArea`.
- **⌘⌫**: Delete… checks the focus first; inside an `EditableText` it sends `DeleteToLineBreakIntent(forward: false)` instead of deleting the chat.
- **Gate**: the menu is set only in a set-up Mac window (`MacWindow.enabled`) whose theme platform is macOS. Tests set the flag and answer the menu channel; other tests never touch it. The menus are rebuilt only when the registry notifies, because `PlatformMenuBar` resends them to the platform whenever it gets a new list.
- **Root handlers**: About, Help, Close Window (`performClose` through `macos_window_utils`) and Hermes ⌘0 (`orderFront`) are registered by the menu bar itself, so they work on every screen, including sign-in.

## Risks / Trade-offs

- A command stays available while a dialog is open above its screen (dialogs are not opaque routes). Acceptable: the actions ask before anything destructive.
- With one window, ⌘W closes it and the app quits (`applicationShouldTerminateAfterLastWindowClosed`), as before.

## Platforms

macOS only; other platforms get the registry but no menu. No entitlement, manifest or Xcode project change. Invariants touched: none.

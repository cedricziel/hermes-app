# Design

## Context

See proposal.md for motivation and specs/ipad-keyboard-commands/spec.md for behavior.

`MacMenuBar` (in `HermesApp`'s builder) always provides a `MacCommandRegistry` through `MacCommandScope.root`; only in a Mac window does it wrap the app in `PlatformMenuBar(menus: macMenus(registry))`. `MacCommandScope` registers its handlers while it is on screen (`TickerMode` and `Visibility`), the highest priority and then the latest registration wins, and the registry notifies only when what the menu shows (enabled flag, title) changes, after the frame. `PlatformMenuBar`'s default delegate talks to the `flutter/menu` channel, which only the macOS embedder implements; on iOS it does nothing.

Who registers today on iOS: `ChatScreen` (always: New Chat, Find, Pin, Rename, Copy Transcript, Archive, Delete; Open in New Window is null there), `KanbanScreen` and `SchedulesScreen` (New, retitled), `SettingsScaffold` (Back), the root (About, Help, and Mac window commands). `AppShell` registers Settings, Connection Details and Sign Out only with Mac chrome; `MacSidebar` and the Kanban inspector are Mac-only. On iOS `ChatScreen._beginSearch` focuses the Mac toolbar's field, which iOS does not build. On macOS ⌘F is the menu's Edit > Find (`MacCommand.find`); `ChatScreen` has no `HardwareKeyboard` handler, so no Flutter handler competes for any chord this change binds.

How keys reach Flutter on iOS: `FlutterViewController` overrides `pressesBegan`/`pressesEnded` and hands each press to the framework (`FlutterKeyboardManager`); a press the framework does not handle goes back up the UIKit responder chain. UIKit matches `UIKeyCommand`s of the main menu and the responder chain before it delivers the press to the first responder, and only if a target in the chain answers `canPerformAction(_:withSender:)` with true. So an enabled command's chord never reaches Flutter, and a disabled one falls through to Flutter unchanged. With a Flutter text field focused, the first responder is the engine's `FlutterTextInputView`, which implements the standard edit actions; our custom selector is unknown to it, so the search continues up to the app delegate.

## Goals / Non-Goals

**Goals:** one definition of the menus in Dart; the same enablement rules as macOS; no lost text-editing keys.

**Non-Goals:** iPad multi-window, a Flutter-drawn menu, changing the Mac menu.

## Decisions

### A small native bridge, not `ipados_menu_bar`

`ipados_menu_bar` 0.6.1 is a `PlatformMenuDelegate` for iPadOS, which would let `macMenus` run unchanged. It is a one-person project (1 GitHub star, about 80 downloads a month, nine 0.x releases in 2026) and swizzles `UIResponder.buildMenu(with:)` globally, which can break other plugins' menus. Our own bridge needs no swizzling because `FlutterAppDelegate` is a `UIResponder` that can override `buildMenu(with:)` directly, and it is about 150 lines of Swift.

### One layout in Dart, two renderings

`mac_menu_bar.dart` gains `menuLayout`: a list of `MenuSection(id, label, groups)` whose entries are `MenuEntry(command, label, shortcut, platforms)`. `macMenus(registry)` renders it to `PlatformMenu`s as today (plus the Mac-provided items and the Edit menu, which stay Mac-only), so the Mac menu is unchanged; `test/macos/mac_menu_bar_test.dart` ("sets the Mac menus in order") guards that. `IpadMenuBridge` (`ipad_menu_bridge.dart`) serializes the entries marked for iPad: `{section, label, command, input, modifiers}` once (`setLayout`), and on every registry notification `{command: [enabled, title]}` (`setState`). Shortcuts map from `SingleActivator` (`meta`→`.command`, `shift`, `alt`→`.alternate`, `control`) and the logical key's character (`[`, `,`, letters). The bridge is mounted by `MacMenuBar` when the chrome is iOS; channel errors are caught and logged.

### Native side

`ios/Runner/KeyCommandMenu.swift` keeps the layout and state. `AppDelegate`:

- `buildMenu(with:)` (main system only): removes `.find`, `.format`, `.newScene`; inserts About into `.about`, Settings… into `.preferences`, Connection Details and Sign Out… after it, New Chat at the start of `.file`, Back at the start of `.view`, a "Chat" menu after `.view`, Hermes Help into `.help`. Each item is a `UIKeyCommand(title:action:#selector(hermesCommand(_:)), input:modifierFlags:propertyList: commandName)`, or a `UICommand` without a chord.
- `canPerformAction` returns the Dart state's enabled flag for `hermesCommand(_:)`; `validate(_:)` sets the Dart title (Pin/Unpin, New Task).
- `hermesCommand(_:)` calls `invoke(command)` on the channel; Dart runs `registry.invoke` and adds the breadcrumb.
- `setState` calls `UIMenuSystem.main.setNeedsRevalidate()`; `setLayout` calls `setNeedsRebuild()`.

### iPad scopes

`AppShell` offers Settings, Connection Details and Sign Out with iOS chrome too. `ChatScreen`'s Find on iOS focuses the sidebar's `ThreadSearchView` field (a new `FocusNode` parameter) when the sidebar is on screen, and is null otherwise, so ⌘F then reaches Flutter. Delete… on iPad has no chord.

### Platforms and native changes

iOS and iPadOS; macOS output unchanged. `AppDelegate.swift`, a new `KeyCommandMenu.swift` in the Runner target (`project.pbxproj`). No Info.plist or entitlement change.

### Invariants touched

- Telemetry: the breadcrumb holds the command's enum name and a platform flag; the log event an error type. Both swallow failures.
- Auth, API layering, generated client: untouched.
- Tests: the layout and bridge with a mocked `hermes_app/menu` channel (as `test/macos/mac_menu_bar_test.dart` answers `SystemChannels.menu`); native behavior in the simulator.

### Signals

| Signal                      | Where                         | Attributes                                    |
| --------------------------- | ----------------------------- | --------------------------------------------- |
| breadcrumb `menu.command`   | `IpadMenuBridge`, on `invoke` | `command`, `platform` = `ipados`              |
| log `ipad_menu.sync_failed` | `IpadMenuBridge` catch        | `operation` (`layout`, `state`), `error.type` |

None holds user content.

## Risks / Trade-offs

- [Key command precedence is not as described: Flutter sees the press as well, or first] → task 1.1 is a spike on the iPad simulator with a hardware keyboard: bind ⌘N natively, add a Flutter `HardwareKeyboard` logger, and record which side gets the press with and without a focused text field, and when the command is disabled. If Flutter also gets it, the bridge marks the chord handled in Dart (`HardwareKeyboard` handler that swallows chords of enabled commands) so each command runs once.
- [A duplicate chord in the main menu makes UIKit log or throw] → the clashing system menus are removed first, and a Dart test asserts the iPad layout has no duplicate chord and none of ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z, ⇧⌘Z, ⌘⌫.
- [Revalidation lags a frame behind Dart] → acceptable; UIKit also asks `canPerformAction` when a chord is pressed, which reads the latest state.
- [`MacCommand` naming on iPad] → kept; renaming the enum is a refactor for another day.

## Dependencies

None on other changes in this rollout (wave 1).

## Migration Plan

Additive. Rollback removes the bridge; iPadOS falls back to its default menus.

# Tasks

One PR, `feat(macos): add a Dock menu with new chat and recent chats`, about 450 lines. No API routes change, so no OpenAPI regeneration. No Widgetbook use cases: the menu is native AppKit and has no Flutter widget.

## 1. Dart state and bridge (TDD)

- [x] 1.1 Write failing tests in `test/macos/dock_menu_controller_test.dart` for snapshot building (remote only, bot registries excluded, newest first, five at most, 40-character titles, "Untitled chat", null profile gives none), push only when the snapshot changed, and clearing when the state leaves `ready`. Implement `lib/src/macos/dock/dock_menu_controller.dart` and `dock_menu_bridge.dart` (macOS-only default like `HandoffBridge`, errors swallowed, reusing the `hermes_app/app` channel through `MacApp`, with `dockMenu` carrying the state and `dockNewChat`, `dockOpenChat` coming back).
- [x] 1.2 Write failing tests that `DockMenuGate` reports `off` while signed out or not connected, `locked` while `AppLockController.covered`, and `ready` again after unlock. Implement `DockMenuGate` and place it in `lib/src/app.dart` next to `HandoffGate`; provide the controller in `lib/main.dart`.

- [x] 1.3 Write failing tests in `test/app_lock/` that `AppLockController.unlock()` returns true after a successful confirm, false after a failed or cancelled one, and awaits an attempt already in flight instead of returning early. Change the return type to `Future<bool>`.
- [x] 1.4 Write failing tests in `test/macos/dock_menu_controller_test.dart` for the deferred New Chat: while `locked` it calls `unlock()` and runs the action only on true; a false result runs nothing; a later manual unlock does not run a cancelled action; sign-out, relock or a newer pick drops the pending one; with the lock off the action runs at once. Implement it in `DockMenuController` with the `dock.menu.deferred` breadcrumb.

## 2. Wiring to the chat

- [x] 2.1 Write failing widget tests (`test/macos/dock_menu_chat_test.dart`, `FakeHermesServer` and the fake bridge) for: a thread list change pushes the recent list; a profile switch changes it; sign-out clears it; a pick focuses an existing conversation window; a pick without a window opens the chat in the main window, including one outside the loaded page; a deleted chat reports the failure and creates nothing; New Chat starts an unsaved chat; New Chat while locked opens the chat only after the fake lock unlocks. Extract the window-or-main logic from the Handoff closure in `ChatScreen` into one method used by both, and push from `_changed`.
- [x] 2.2 Write failing tests for the `dock.menu.action` (with `deferred`) and `dock.menu.deferred` breadcrumbs and the `dock.menu.open_failed` event, asserting that no title, id or profile appears in their attributes. Add both.

## 3. Native menu

- [x] 3.1 Add the `DockMenu` class in the new `macos/Runner/DockMenu.swift` (added to the Runner target), override `applicationDockMenu(_:)` in `macos/Runner/AppDelegate.swift` and route `dockMenu` on the app channel: build the menu from the in-memory snapshot, titles as plain titles, Show Main Window native-only, build New Chat for `ready` and `locked` and chats for `ready` only, clear on any other state or a malformed argument. Cover the menu builder with XCTests in `macos/RunnerTests/RunnerTests.swift`.

## 4. Docs and verification

- [x] 4.1 Update `.claude/skills/verify-in-app/SKILL.md` with a Dock menu check on the macOS run (right-click the Dock icon: signed out, signed in, locked with New Chat then a cancelled and a successful unlock, hidden main window, chat in a conversation window), and add the Dock menu to the macOS notes in CLAUDE.md. Use an isolated Hermes home with invented chats.
- [x] 4.2 Confirm no title, id or profile name reaches telemetry, preferences or secure storage, and that no route or generated client file changed. Run `openspec validate mac-dock-menu --strict`, `dart format`, `flutter analyze`, `flutter test`, then the macOS verify-in-app loop and restore the `ios/` and `macos/` Xcode files that the build rewrites.

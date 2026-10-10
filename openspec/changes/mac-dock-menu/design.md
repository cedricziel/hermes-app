## Context

`FlutterAppDelegate` does not provide a Dock menu, so macOS shows only its default items (open windows, Options, Quit). Apple's `applicationDockMenu(_:)` is asked synchronously each time the user opens the menu. Dart cannot answer it in time, so the Swift side keeps a copy of what to show and Dart refreshes the copy.

Code this builds on, read before writing this design:

- `macos/Runner/AppDelegate.swift`: already holds `mainWindow` (kept while hidden), the `hermes_app/share` channel and `ChatHandoff`, which installs `hermes_app/handoff` on the main engine's messenger. `applicationShouldHandleReopen` already shows the hidden main window.
- `lib/src/windows/conversation_windows.dart`: `ConversationWindows.windowFor(threadId, profile)`, `focus(windowId)` and `showMainWindow()` (host `showMain`, which calls `hermes_app/window` `show`).
- `lib/src/chat/chat_screen.dart`: binds a Handoff restore closure that focuses an existing conversation window and otherwise calls `ChatController.restoreHandoff`, then `widget.onShowChat`. `_newThread()` is what File > New Chat (`MacCommand.newChat`) runs.
- `lib/src/chat/chat_open_requests.dart` and `AppShell`: `ChatOpenRequests.request(NotificationTarget)` plus `_showChat()` also opens a chat, with `fetchMissing` semantics so a chat older than the loaded pages is fetched.
- `lib/src/handoff/handoff_bridge.dart`: the pattern for a platform bridge that is a no-op off Apple platforms and swallows `PlatformException` and `MissingPluginException`.
- `lib/src/app_lock/app_lock_controller.dart`: `covered` is true while locked or not yet loaded. `unlock()` asks the device to confirm and returns nothing today; it returns early when not locked or while a prompt is already open. On macOS, `hidden` or `paused` locks the app and `resumed` calls `unlock()`, so showing the main window already starts a prompt. `AppLockGate` keeps the app mounted but offstage while covered and shows an Unlock button.

## Goals / Non-Goals

Goals: a Dock menu that works with the main window hidden or closed, never shows titles while signed out or locked, and reuses the existing chat-opening paths. Non-goals are listed in `proposal.md`.

## Decisions

### Hand-written AppKit code, no plugin

I searched pub.dev for a Dock-menu plugin. None implements `applicationDockMenu`: `macos_dock` is a visual widget, `tray_manager` and `system_tray` manage a status-bar item, and `mac_menu_bar` customizes the menu bar. The native part is about 60 lines of AppKit (`NSMenu`, `NSMenuItem`, one method channel), so this follows the "no mature plugin fits" case of CLAUDE.md. The app is sandboxed; building an `NSMenu` and activating the app need no entitlement.

### Dart pushes a snapshot; native owns the menu

Channel `hermes_app/dock_menu`, installed in `applicationDidFinishLaunching` on the main engine's messenger, like `ChatHandoff`.

- Dart to native `update`: `{state: "ready" | "locked" | "off", chats: [{id, profile, title}]}`. Only `ready` carries chats; `locked`, `off` and any malformed argument clear the stored chats. Native keeps the last value in memory only.
- Native to Dart `newChat` and `openChat` `{id, profile}`.

`applicationDockMenu` builds a fresh `NSMenu` from the stored snapshot on every call: New Chat when the state is `ready` or `locked`, the chats only when `ready`, then Show Main Window always. Show Main Window is native only (`makeKeyAndOrderFront` plus `NSApp.activate`), so it works signed out and when the Dart side is not ready. Chat items carry the id and profile as a `representedObject`; titles are used as `NSMenuItem.title` (never as a format string, no key equivalents) and cut to 40 characters on the Dart side, with an empty title shown as "Untitled chat". New Chat and chat items first show the main window, because a pick that opens the chat in the hidden main window must be seen; the conversation-window case focuses that window instead (Dart decides, see below).

A pick when the Dart handler is not installed yet cannot happen: the menu holds no chat items and no New Chat until Dart has pushed `ready` or `locked`.

### Which chats, in which order

`DockMenuController` receives the list from `ChatScreen`, which already reacts to `ChatController` changes in `_changed`. It takes `ChatController.threads` that are `remote`, not `isCanonicalBotChat` (hidden Bot Chat registries are not user chats), sorted by `updatedAt` descending, first five. Pinned chats get no priority: "recent" means recent. The profile is `ChatController.profile`; when it is null (not resolved yet) the list is empty rather than ambiguous, matching Handoff's explicit-profile rule. The controller compares the new snapshot (ids, titles, profile) with the last pushed one and calls the bridge only when it differs, so streaming tokens that bump `updatedAt` do not cause traffic.

The list follows the profile the chat screen shows, so switching profile in the sidebar changes the Dock menu. A reply that finishes moves its chat to the top.

### Eligibility: signed in, connected, unlocked

`DockMenuGate` (a widget in `app.dart`'s builder, next to `HandoffGate`) watches `AuthController.state` and `AppLockController.covered` and calls `DockMenuController.configure(state)`: `off` unless signed in and connected, `locked` when connected and covered, otherwise `ready`. Leaving `ready` drops the controller's list and pushes the new state, so a locked menu never holds titles. When `ChatScreen` disposes (sign-out removes the shell), it clears its list. Showing titles again after unlock needs the next `_changed` from the chat, so `ChatScreen` pushes once when the state flips back to `ready`. Platforms: the controller is constructed with the same macOS-only `enabled` default as `HandoffBridge`.

### Opening a chat

Picking a chat runs in `ChatScreen`, with the logic Handoff already uses, extracted into one method `_openElsewhereOrHere(threadId, profile)`:

1. If `ConversationWindows.windowFor(threadId, profile)` exists, `focus` it and stop.
2. Otherwise bring the main window forward, call `AppShell`'s show-chat callback (`onShowChat`) and `ChatController.restoreHandoff`-style loading so a chat outside the loaded page or on another profile still opens.

Using the Handoff restore rather than a plain `select` matters for the second case: the menu snapshot may be a few seconds old. Failure (chat deleted since, network) goes through the existing chat-open failure presentation and the `dock.menu.open_failed` event.

New Chat calls `_newThread()` after the same show-main step (when the app is locked, see the next section); if the key window is a conversation window, New Chat still creates the chat in the main window, as File > New Chat does from there.

### New Chat while locked: a deferred action

With app lock on and the app locked, New Chat stays in the menu. Picking it:

1. Native shows the main window and sends `newChat`, as in the unlocked case.
2. `DockMenuController.newChat(run)` sees the state is `locked`. It keeps exactly one pending action (a newer pick replaces it) and calls `AppLockController.unlock()`. The main window already shows `AppLockGate`'s lock screen, and the resume that the window brings usually starts a prompt too.
3. `unlock()` now returns `Future<bool>`: true when the app is unlocked afterwards. If a prompt is already open it awaits that attempt instead of returning early, so the pick and the resume share one prompt. Existing callers ignore the result.
4. On true, and only if the pending action is still the one that waited, the state is `ready`, and the shell is still signed in, the controller runs `run`, which is `ChatScreen`'s `_newThread()` plus `onShowChat`. On false the action is dropped.

The action is cancelled, never retried, when: the unlock fails or the user dismisses the prompt; the app locks again or the state leaves `locked`/`ready` (sign-out, change of server) before it ran; or a newer pick replaced it. A later manual unlock through the Unlock button does not run a cancelled action, so a stale click cannot start a chat minutes later. Chat items are not offered while locked, so there is nothing else to defer. If app lock is off, or not enforced because the device cannot confirm, the state is never `locked` and New Chat runs at once.

The pending action holds no user content (a closure and a flag), so it is not a privacy concern, and it is not persisted.

### Why not wait for `hermes://`

Another change owns a cross-platform URL scheme and a Dart router with open chat and new chat. This change does not depend on it. The channel actions map one-to-one onto those router intents, so replacing the two native-to-Dart calls with the router later is a small edit; this is stated here so neither side re-specifies the other.

## Platforms

macOS only: `AppDelegate.swift` and the Dart bridge. iOS, Android, Windows, Linux and watchOS get a no-op bridge. No entitlement, Info.plist, Xcode project or deployment-target change; the Swift code goes into an existing file, so no source reference is added. Conversation-window engines do not register the channel (like `ChatHandoff`), only the main engine does.

## Invariants touched

- Telemetry must never break the app: bridge calls swallow platform errors; breadcrumb and event calls use the existing safe wrappers.
- Breadcrumbs hold fixed names, flags and outcomes only: confirmed, no titles, ids, profile names or counts.
- `AppLockController` keeps its contract: the lock only hides the UI, and `unlock()` still needs the device to confirm. Its only change is the return value.
- Auth and token storage are not touched. No REST call is added, so `authController.api!.raw` and OpenAPI generation are not involved. Opening a chat reuses the existing repositories.

## Observability placement

- `dock.menu.action` breadcrumb: recorded in `ChatScreen` where the channel action is handled; attributes `action`, `window`, `deferred`.
- `dock.menu.deferred` breadcrumb: recorded by `DockMenuController` when a deferred New Chat ends; attribute `outcome` (`completed`, `cancelled`).
- `dock.menu.open_failed` log event: recorded by `DockMenuController` when the open callback reports failure; attribute `reason` (`unavailable`, `network`). No chat data.
- No span, for the reason given in `proposal.md`.

## Risks / Trade-offs

- The snapshot can be stale: a chat deleted on another device stays in the menu until the next refresh. A pick fails through the normal path. Accepted.
- Titles sit in native memory. Dropping them on lock and sign-out is the mitigation; a process memory dump by the same user is outside the threat model.
- `FlutterAppDelegate` may add its own `applicationDockMenu` in a future Flutter release; override with `super` call is not possible for an absent method, so re-check on Flutter upgrades (a test of the menu builder in Swift would catch it).
- The main window is hidden, not released, when conversation windows are open; showing it from the Dock reuses the existing `mainWindow` reference.

- A deferred New Chat on a prompt the user ignores waits until the prompt ends or the app relocks; nothing runs afterwards. Accepted.

## Migration

No stored data. Rollback removes the delegate method and the channel.

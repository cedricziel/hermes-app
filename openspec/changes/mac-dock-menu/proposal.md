## Why

On macOS the Dock icon is the quickest way back into the app. Today its menu only lists the open windows. A user who wants to start a chat or return to a recent one must bring the app forward first, find the window, and then use the sidebar. A Dock menu with New Chat, the latest chats and Show Main Window removes those steps.

## What Changes

- Add a Dock icon menu on macOS through `applicationDockMenu(_:)` in `macos/Runner/AppDelegate.swift`: **New Chat**, up to five recent chats of the current profile (most recent first), a separator, and **Show Main Window**.
- Picking a chat opens it in its conversation window if one is open, otherwise in the main window. This is the same rule Handoff restoration uses today.
- Dart pushes the menu content (a small list of titles, thread ids and the profile) to native whenever it changes, because AppKit asks for the menu synchronously and cannot wait for Dart.
- Signed out or not yet connected: the menu holds only Show Main Window, and no chat title is kept natively.
- Locked (app lock on): the menu shows New Chat and Show Main Window; recent chats are hidden. Picking New Chat brings up the main window with the unlock prompt and, after a successful unlock, opens a new chat. If the unlock fails or is dismissed, the action is cancelled.
- The native side clears its copy of the list on sign-out, change of server, app lock and when the chat screen goes away.
- `AppLockController.unlock()` returns whether the app is unlocked afterwards, so a caller can run an action only on success.

## Capabilities

### New Capabilities

- `mac-dock-menu`: the macOS Dock menu, its content rules, and how its choices reach the chat.

### Modified Capabilities

None. Conversation windows and Handoff keep their requirements; the Dock menu is another source of "open this chat" and "new chat".

## Impact

- `lib/src/app_lock/app_lock_controller.dart` (`unlock()` returns `Future<bool>`; existing callers ignore it).
- `macos/Runner/AppDelegate.swift` (the menu and a `hermes_app/dock_menu` channel); no new Swift file is required, though a `DockMenu` class in the same file keeps the delegate small.
- Dart: a `DockMenuBridge` and `DockMenuController` under `lib/src/macos/dock/`, a `DockMenuGate` beside `HandoffGate` in `lib/src/app.dart`, and a push from `ChatScreen` when its thread list changes.
- Reuse of the open-in-window-or-main logic that `ChatScreen` binds for Handoff, extracted so both callers share it.
- Widgetbook: none. The menu is native AppKit, so there is no Flutter widget to catalog.
- One PR, about 450 lines including tests.

### Non-goals

No menu on iOS, Windows or Linux (a Windows jump list and Linux desktop actions are separate work). No Dock badge, progress or bounce. No status-bar item. No pinned or favourite chats, search, or profile switching in the menu. No hosted Bot Mode group rooms or Kanban items. No new URL scheme; if the `hermes://` router lands first, the menu may call it instead of the channel, but this change does not depend on it. No actionable notification buttons.

### Security and privacy

Chat titles are user content. They leave the Dart isolate for the macOS process memory only, and are never persisted: nothing goes to preferences, secure storage, Spotlight or `NSUserActivity`. The native copy is dropped when the user signs out, changes server, or the app locks, and the menu then shows no titles. With app lock on, a locked app does not leak titles through the Dock. A locked menu still offers New Chat: it exposes no user content, and it acts only after the device confirms the person. Titles are shown only to someone who can already use the Mac session. Thread ids and the profile name stay in memory with the titles and are used only to route a click. No tokens or credentials are involved.

### Observability

- **Breadcrumbs** through `Breadcrumbs`: `dock.menu.action` with `action` (`new_chat`, `open_chat`, `show_main`), `window` (open in a conversation window or not) and `deferred` (the action waited for an unlock). They explain a later crash ("the user clicked a Dock item, then the chat failed"). Fixed names and flags only.
- **Log event**: `dock.menu.open_failed` through `AppEventLogger` when a picked chat could not be opened (the existing failure path), with only a failure kind. A click that does nothing is the failure worth counting.
- **Deferred New Chat**: a `dock.menu.deferred` breadcrumb with `outcome` (`completed`, `cancelled`). Cancelled covers a failed or dismissed unlock, a relock, sign-out and a newer pick.
- **Spans**: none. The channel call is a local, instant message, not work that takes time or crosses a network.
- Titles, thread ids, profile names and counts of chats are never attached to any signal.

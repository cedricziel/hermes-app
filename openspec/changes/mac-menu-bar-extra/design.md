## Context

`AppDelegate.swift` already keeps the main window object alive while it is hidden, because conversation windows depend on its engine, and `applicationShouldHandleReopen` shows the window again. Quitting after the last window closes is the only part missing. In Dart, being "in front" means `AppLifecycleState.resumed` in three places: `AttentionNotifier._focused` (`lib/src/notifications/attention_notifier.dart`), `ScheduleWatcher._foreground` (`lib/src/schedules/schedule_alerts.dart`) and `AppShell.didChangeAppLifecycleState` (`_schedulesController?.foreground`). When the macOS window is hidden, Flutter reports `hidden`, so `ScheduleWatcher` stops its timer. `AttentionNotifier` still posts notifications then, because `_focused` is false. `attentionFor` suppresses a notification only when the app is focused on the very thread. Running replies are `ChatThread.isReplying`, and pending requests are `ChatMessage.inputRequests`. Both are owned by `ChatController`. `ChatController.answerApproval(thread, requestId, choice)` is the chat card's path, and `ApprovalRequest.choices` lists what a request offers.

## Goals / Non-Goals

Goals: keep running windowless, keep notifying and checking schedules, and show state and approvals in the menu bar. Non-goals are listed in the proposal.

## Decisions

1. **Stay-alive in Swift.** `applicationShouldTerminateAfterLastWindowClosed` returns false. Since a hidden window never closes, AppKit never asks that, so `AppDelegate.refreshWindowless()` decides: no visible or minimised window (and the app not hidden with Cmd-H) means windowless. It runs after the main window hides and on window key, minimise, deminiaturise and close notifications. Windowless takes a `ProcessInfo` activity (`.userInitiatedAllowingIdleSystemSleep`) so App Nap leaves the timers and sockets alone, and tells Dart over `hermes_app/app` (`windowless`). Any activation with no visible window (the Dock, a tapped notification, also Cmd-Tab) shows the main window; that is intended, even if a conversation window is only minimised. `MainFlutterWindow.close()` always hides the window instead of closing it (leaving full screen first, so no empty Space stays): a real close posts `willClose`, which makes `desktop_multi_window` drop the main engine. The main window is hidden, never released, so its engine (and the gateway sockets in it) keeps running. Conversation windows are separate engines and close as before.

2. **"Windowless" is not "background" on macOS.** A new `AppPresence` (`lib/src/shell/app_presence.dart`) reports `foreground` as `resumed || (isMacOS && hidden/inactive)`, and `focused` as `resumed` only. On macOS a hidden or inactive app keeps running at full speed, so the watcher must not stop. `ScheduleWatcher` and `AppShell` read `foreground` from it. `AttentionNotifier` keeps reading `focused`, so notifications post while no window shows. That behaviour does not change; a test pins it. `paused` (the app quitting or the system suspending it) still stops the timer. On iOS and Android `foreground` equals `resumed`, so nothing changes there.
   - Alternative: an always-on timer on macOS. Rejected because the lifecycle would no longer govern the watcher at all.

3. **A small `NSStatusItem` in the runner, not `tray_manager`.** The design first chose `tray_manager`, but its 0.8.0 release is a rewrite on `nativeapi`: it compiles a C++ core through a native-assets build hook for every platform the app builds (iOS and Android included, for one Mac-only feature) and needs X11 and Xi development packages on Linux, which the Linux CI job and the `.deb` do not have. Older releases ship a Linux plugin that needs `libayatana-appindicator3-dev`. Either way the cost lands on platforms that never show the item. `MenuBarStatusItem` (about 100 lines at the end of `MainFlutterWindow.swift`) uses only `NSStatusItem` and `NSMenu`, which need no entitlement, so it works in the sandbox. It is created by the main window's engine only: a status item belongs to the app, not to a window, so conversation windows never see it. Dart talks to it over `hermes_app/menu_bar_extra`: `update` sends the icon state and the whole menu, and the runner reports `selected` (an item key) and `opened`. Adding `tray_manager` stays possible if Windows or Linux ever get a tray.

4. **Model and view split.** `MenuBarExtraModel` (pure Dart, `lib/src/macos/menu_bar_extra/menu_bar_extra_model.dart`) is built from `ChatController` (thread list, `isReplying`, open `inputRequests`). It holds `state` (idle, working, attention), `replies` (thread title and ref) and `requests` (thread ref, request id, kind, command, choices). `MenuBarExtra` (`menu_bar_extra.dart`) listens to the controller, sends the menu to the runner only when the model changes (`==`). The runner draws one of three template SF Symbols (`bubble.left`, `ellipsis.bubble`, `exclamationmark.bubble`), so the icon follows a light or dark menu bar without PNG assets. Approval titles show the command trimmed to 60 characters. The full command sits in a disabled first item of the submenu, trimmed to 300 characters. Choice labels reuse the card's label mapping (pull it out of the approval card widget into a shared function if it is inline).

5. **Scope: chats this app runs.** The model reads only threads `ChatController` holds with a live transport stream: sends from this Mac, plus `followUps`. That is exactly what the chat UI already shows live. There is no polling and no other profiles' unloaded threads. Requests in conversation-window engines are not visible to the main engine's controller. Those windows' chats are refreshed in the main window on key (existing behaviour). Accepted limit: a reply running only in a conversation window shows in that window, not in the menu. This is noted in the spec.

6. **Actions.** Open chat goes through `ChatOpenRequests` (as Kanban and Schedules do) and shows the main window via `ConversationWindows.showMainWindow` or the `AppDelegate` reopen path. If the chat already has a conversation window, that window is brought forward instead (`ConversationWindows` lookup). Approve calls `ChatController.answerApproval`, so the card updates the same way. New Chat goes through `MacCommand.newChat`, or the controller's new-thread call when no scope offers it, after showing the main window. Quit calls `NSApp.terminate` through a one-method `hermes_app/app` channel call (`terminate`) in `AppDelegate`, since the plugin has no quit API.

7. **Setting.** `MenuBarExtraSettings` (a `ChangeNotifier` on shared preferences, key `menuBarExtra.enabled`, default true) shows as a row with a switch in `settings_dialog.dart`, only on macOS. Off calls `trayManager.destroy()`.

## Platforms

macOS only. No entitlement change: the status item needs none in the sandbox. Xcode: no new file or package; `MenuBarStatusItem` lives in `MainFlutterWindow.swift` and is created next to the main window's other channels, not in the conversation-window setup. iOS, Android, Windows and Linux are unchanged: `AppPresence` equals the old check there, and `MenuBarExtra` is not built.

## Invariants touched

- Telemetry must never break the app: crumbs and logs go through `Breadcrumbs` and `AppEventLogger`, which swallow failures.
- Auth: none. A windowless app refreshes tokens on use exactly as before. Sign-out empties the controller, so the menu shows only New Chat, Show Main Window and Quit, and the icon goes idle.

## Observability

- `app.lifecycle` crumb `state: windowless`, recorded in `AppShell` when the runner reports (`MacApp.windowlessChanges`) that no window is left. Flutter's `hidden` is not used: it also fires when the window is covered, on another Space or the app is hidden.
- `menubar.opened` crumb (`replies`, `approvals`: counts) from `MenuBarExtra` on `onTrayIconMouseDown`.
- `menubar.action` crumb (`kind`, and `choice` only for approve, one of once/session/always/deny) from `MenuBarExtra.onTrayMenuItemClick`.
- `menubar.approval_answered` log (`choice`, `accepted`) from `MenuBarExtra` after `answerApproval` returns.
None of these carries a title, command, profile, server or id.

## Risks / Trade-offs

- A windowless engine keeps its sockets open and uses some power. This is the point of the feature, and Quit is always available.
- Flutter does not render while hidden, but timers and isolates run. A test cannot prove this for macOS App Nap. Task 1 adds a verify-in-app check that the watcher fires with the window closed for 3 minutes. If App Nap throttles it, the hold (`ProcessInfo.beginActivity(.userInitiatedAllowingIdleSystemSleep)`, kept while no window is on screen) is the fix. It is already in, as a precaution.
- The menu is rebuilt in full on each change. With a handful of items that is cheap, and rebuilds are limited to model changes.

## Why

On macOS, closing the last window quits Hermes (`applicationShouldTerminateAfterLastWindowClosed` returns true in `macos/Runner/AppDelegate.swift`). A reply still running, a pending approval and the one-minute schedule check all stop with it. Mac users expect an agent client to stay running in the background and show its state in the menu bar, the way mail and chat clients do.

## What Changes

- Closing the last window no longer quits the app on macOS. Cmd-Q and Hermes > Quit still do. The Dock icon stays in every state; the activation policy is never changed.
- A menu bar item (status item) is on by default. Its icon shows idle, working (a reply is running) or needs attention (an approval or another request is waiting).
- Its menu lists the running replies and pending approvals of chats this app already follows: replies sent from this Mac and follow-ups on chats it already listens to. It adds no server polling. Picking a reply opens its chat. Each approval is a submenu with its command and the choices the chat card offers. A choice is answered through the same path the card uses. The menu ends with New Chat, Show Main Window and Quit.
- A "Menu bar item" switch in Settings hides the item. The app keeps running after its last window closes even with the item hidden, and the Dock icon brings the window back.
- While no window is visible, reply and request notifications keep being posted and `ScheduleWatcher` keeps checking every minute. Today both stop when Flutter reports the app as not resumed.
- Ships in two PRs: (1) stay-alive and background notifications, (2) the menu bar item and its setting.

## Non-goals

- No accessory (Dock-less) mode and no launch at login.
- No server-side discovery of replies or approvals in chats this app does not run, and no new polling.
- No clarify, vault or secret answers from the menu. Those requests show as "needs you" rows that open the chat.
- No Windows or Linux tray icon, although the chosen plugin supports both.
- No `hermes://` URL scheme and no notification action buttons. Other changes own those. This change neither uses nor needs them.

## Capabilities

### New Capabilities
- `mac-menu-bar-extra`: background lifetime on macOS, the menu bar item, its menu and its setting.

### Modified Capabilities
None. The changed notification and schedule timing appears as requirements of the new capability.

## Impact

- `macos/Runner/AppDelegate.swift`: stay-alive.
- `lib/src/notifications/attention_notifier.dart`, `lib/src/schedules/schedule_alerts.dart`, `lib/src/shell/app_shell.dart`: what counts as "in front" on macOS.
- New `lib/src/macos/menu_bar_extra/`, with `tray_manager` as a new dependency (macOS only in use).
- `lib/src/settings/settings_dialog.dart`: the new switch, backed by shared preferences.
- Backend: none.

## Security and privacy impact

The menu shows chat titles and approval commands on screen, as the chat card already does. Nothing goes on the lock screen or into preferences except the on/off flag. No tokens are touched. Telemetry carries no titles or commands.

## Observability

- Breadcrumbs `menubar.opened` (counts: replies, approvals) and `menubar.action` (`kind`: open_chat, approve, new_chat, show_main, quit; `choice` for approvals as the fixed choice name). They explain a crash that follows a menu action.
- Breadcrumb `app.lifecycle` gains `state: windowless` when the last window closes, so a crash report shows that the app was running without a window.
- Log event `menubar.approval_answered` (`choice`, `accepted`: bool) through `AppEventLogger`. This counts approvals answered outside the chat card and catches failures.
- No spans: the menu does no slow or cross-boundary work beyond the existing approval RPC, which the gateway already traces.

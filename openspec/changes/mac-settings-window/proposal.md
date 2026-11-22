# Proposal

## Why

Audit item C4. On a Mac, Settings is not a window. `MacCommand.settings` (⌘,) calls `showSettingsDialog` (`lib/src/shell/app_shell.dart:736`), and so does the sidebar account menu (`lib/src/chat/widgets/thread_sidebar.dart:895`). That function (`lib/src/settings/settings_dialog.dart:52`) opens a grouped list through `showAppDialog` (`:90`), which on macOS pushes a `RawDialogRoute` on the root navigator (`lib/src/widgets/dialog_presentation.dart:32`). The list is a modal dialog over the main window with a scrim. Choosing a row pops it and opens the next dialog (`settings_dialog.dart:129-148`: Appearance, Notifications, Dictation, Voice calls, Spotlight, App Lock, About; Change Server calls `AuthController.changeServer`). The quick-panel shortcut row and the menu bar item switch are inline.

What a Mac user sees, and what they expect:

- Settings blocks the chat. The scrim covers the window, so the user cannot read the chat while they change a setting, for example while they pick light or dark and want to see the transcript change.
- Every row replaces the dialog, so the list closes and the user must press ⌘, again to change a second setting.
- `showSettingsDialog` has no guard against a second call while a settings dialog is open, so nothing focuses the open one.
- The Mac convention is a separate Settings window that ⌘, opens and, when open, focuses. It stays open beside the main window and closes with ⌘W.

The audit premise holds: Settings is inside the main window. It is a dialog, not a pushed page.

## What Changes

Recommended (design.md, "Options"): a separate Settings window on macOS, a second Flutter window of the kind the conversation windows already are (`desktop_multi_window`, `lib/src/windows/`). ⌘, and the account-menu "Settings…" open it or focus it if it is open. The window is a view: it holds no session, no token and no App Lock state. The settings that persist in preferences are read and written in the window; the ones the main engine owns (App Lock, notifications permission, Spotlight index, the menu bar item, Change Server) are changed by commands over the window link, answered by the main engine, which sends back a snapshot of on/off values and availability. The quick-panel shortcut's native recorder is hosted in the window itself and sets the same app-wide chord (design.md, "Quick panel shortcut").

Other platforms keep `showSettingsDialog` unchanged.

## Non-goals

- No change to what the settings are, their copy, or the dialogs for Appearance, Notifications, Dictation, Voice calls, Spotlight, App Lock and About.
- No new settings, and no search in Settings.
- No Settings window on iOS, iPadOS, Android, Windows or Linux.
- No session or token in the Settings window, and no server address or account name shown in it.
- No change to conversation windows, the quick panel or the menu bar item.

## Security and privacy impact

The window never gets a token, header, server address or identity: the snapshot holds only on/off values, enum names (theme mode, dictation engine) and availability flags. App Lock is owned by the main engine only; the window closes when the app is covered and ⌘, is off while covered (the covered app already offers no menu commands, `lib/src/app_lock/app_lock_gate.dart:34-41`). Change Server stays a command that the main engine runs, so no `AuthController` exists in the window. Nothing typed in Settings (App Lock has no typed secret here; the shortcut recorder records a chord, not text) is logged.

## Observability

- Breadcrumbs `settings.window.opened`, `settings.window.focused`, `settings.window.closed` (user steps; no attributes).
- Log event `settings.window.command_failed` through `AppEventLogger` with `command` (fixed name) and `outcome` (`timeout`, `no_owner`, `rejected`), recorded by the main engine from a failure report the Settings window sends over the link, since the window starts no telemetry: a failing bridge would otherwise look like a dead switch. No value, no setting content.
- No span: nothing here takes time or crosses the network.

## Design pass

Needed: this changes the look and the placement of Settings. Record a short "Proposed:" note in `docs/design-briefs/macos-platform-fixes.md` (added by this change). Canvas boards to ask for: the window at its default size (light, dark, German), the window with a nested dialog (Appearance), the window while the main window shows the chat, the unavailable states (no session: the main-owned rows are disabled with a line saying why; locked: the window is gone).

## Open questions for the owner

1. Is a thin bridge worth about three PRs, or is a cheaper fix enough (design.md, option D: keep the dialog, make ⌘, focus an open one, stop blocking)?
2. Should the window follow the Mac preference style (a toolbar of tabs) or stay one grouped list? The list is what exists.
3. Should Settings be reachable while signed out? Today ⌘, is off then, because `AppShell` offers it. About and Appearance do not need a session.

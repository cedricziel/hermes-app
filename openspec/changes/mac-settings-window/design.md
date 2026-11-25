# Design

Platforms: macOS only. iOS, Android, Windows and Linux keep `showSettingsDialog`. Native change: what `desktop_multi_window` already provides for conversation windows (a window id, a frame autosave name, a minimum size); the native Settings window sets `setFrameAutosaveName` as `macos/Runner/MainFlutterWindow.swift:310` does for conversation windows. One native change more: the quick-panel shortcut recorder is an `AppKitView` whose factory (`hermes_app/shortcut_recorder`) is registered on the main engine only (`macos/Runner/QuickPanelShortcut.swift:22-23`), so the Settings window's engine registers the same factory, bound to the one shared `QuickPanelShortcut`, in the window-created callback (`MainFlutterWindow.swift:99-101`); see "Quick panel shortcut" below. No entitlement or Xcode project change is planned; confirm in the spike (task 1.0).

Invariants touched: App Lock (the window never outlives a cover), auth (the window holds no session), privacy (a snapshot without identity), telemetry (fixed names only).

## Current behaviour

- Entry points: menu item `MacCommand.settings` with ⌘, (`lib/src/macos/menu_layout.dart:81-85`), handled by `AppShell` only (`lib/src/shell/app_shell.dart:736-738`), so it is dimmed while signed out; on an iPad ⌘, reaches the same handler through the iPad menu bridge. And the sidebar account menu's "Settings…", which exists only in the macOS branch of `AccountFooter` (`lib/src/chat/widgets/thread_sidebar.dart:886-895`, `MacAccountFooter`). So `showSettingsDialog` is reached only on the Mac and on the iPad; iPhone, Android, Windows and Linux have no caller of it today.
- `showSettingsDialog` (`lib/src/settings/settings_dialog.dart:52`) reads values from the providers above it (`ThemeController`, `NotificationSettings`, `DictationSettings`, `PortableCallSettings`, `SpotlightSettings`, `AppLockController`, and on a Mac `GlobalShortcut` and `MenuBarExtraSettings`) and lists them in a `GroupedDialog`. Each row pops the list and opens its own dialog (`:129-148`).
- Who owns what today:
  - Preferences only (`SharedPreferencesAsync`, with a `load()` that can run again): theme mode (`lib/src/settings/theme_controller.dart`), dictation engine, portable-call switch.
  - Main engine only: `AppLockController` (a conversation window starts no app lock, `lib/src/windows/conversation_window_app.dart:44-46`), `GlobalShortcut` (native recorder in an `AppKitView`), `MenuBarExtraHost`, the Spotlight index, notification permission, and `AuthController` (Change Server).
- Conversation windows hold no session: `windowApiClient(args.baseUrl, link.headers)` takes its auth headers from the main window per request (`conversation_window_app.dart:56`), and the main engine pushes commands such as `queue.locked` and `queue.unlocked` down the link (`lib/src/windows/desktop_conversation_windows.dart:243`, `:397`; `lib/src/windows/conversation_windows.dart:258`). The quick panel builds its own `DictationSettings` and loads it from preferences (`lib/src/quick_panel/quick_panel_app.dart:39-40`), which shows that a second engine can read preferences. There is no cross-engine change notification yet: an engine reads a preference when it starts.
- A covered app offers no menu commands (`lib/src/app_lock/app_lock_gate.dart:34-41`).

## Options

A. Separate Flutter window, view only (recommended).

- Settings opens in its own native window by the same `desktop_multi_window` path as conversation windows. It has no `AuthController`, no `AppLockController`, no `Dio`.
- Window-owned: Appearance, Dictation, Voice calls. The window builds the same controllers the quick panel does, loads them, and after a write tells the main engine to load them again (a `settings.changed` command carrying a fixed preference name).
- Main-owned: Notifications, Spotlight, App Lock, menu bar item, Change Server. The quick-panel shortcut is main-owned too, but its recorder is hosted in the window ("Quick panel shortcut" below), so it needs no command. The window shows the last snapshot the main engine sent (on, off, unavailable) and sends one command per user action (`notifications.set`, `spotlight.set`, `appLock.open`, `menuBar.set`, `server.change`). The main engine does the work and answers with a new snapshot. A dialog that needs the main engine's platform code (App Lock enrolment, the notification permission prompt) is shown by the main engine, which brings its window forward first.
- Trade-off: the most Mac-like result (⌘, and ⌘W, a window beside the chat) and no session in a second engine. The cost is a small bridge (about seven messages: the five commands above, `settings.changed` and the failure report `settings.commandFailed`, and one snapshot type) and a lifecycle to get right. A window-side copy of a main-owned controller would be cheaper to write and wrong: two App Lock states.

B. A Mac-style sheet attached to the main window.

- Flutter has no native sheet. The current dialog is the closest thing, with a scrim. It keeps the chat blocked and keeps the list-closes-on-pick behaviour. No data constraint; no Mac convention gained.

C. Keep it in the main window, non-modal: Settings as a shell destination or a pane beside the chat, like Server (`ServerSplitView`).

- No second engine and full access to controllers. It adds a sidebar row for something the Mac puts behind ⌘, and stays inside the main window. Not the convention.

D. Keep the dialog, fix its worst edges.

- ⌘, while it is open focuses it; a picked row opens on top of the list instead of replacing it; the barrier stays. The smallest change. It does not answer "a window of its own".

E. A second view in the same engine (multi-view).

- Would keep every controller in one isolate and make A's bridge unnecessary. It is not used anywhere in the app and is not assumed available in the Flutter release pinned in `.fvmrc`; the spike (task 1.0) must say whether it is. If it works, it replaces A's bridge and the rest of this design stands.

Recommendation: A, after the spike of E. If the owner would rather not pay for the bridge, D.

## Window rules

- One window. ⌘, or the account menu's "Settings…" creates it, or orders the open one front and focuses it. The frame is autosaved; the default size is about 520 x 640 content, the minimum 420 x 480; the grouped list scrolls.
- Not listed among the chats in the Window menu (it has its own "Settings" entry), not restored at launch, not handed off.
- While it is key, ⌘, is on and focuses it; commands that need a conversation (`MacCommand.newChat` and the like) are off, as with the quick panel.
- Closes at once when `AppLockController.covered` becomes true, and on sign-out, server change and session expiry. It does not reopen on unlock. Signed out, ⌘, stays off (open question 3 in the proposal).
- Only if the owner answers yes to open question 3 (Settings while signed out): main-owned rows are disabled with a line ("Sign in to change this.") while there is no session; Appearance, Dictation and Voice calls stay on; Change Server is left out of the list, because the sign-in screen in the main window already offers a server. Otherwise none of this applies, since the window cannot open signed out.
- Change Server asks nothing more than today (it runs `AuthController.changeServer`); the window closes with the connection.

## Quick panel shortcut

- The recorder is a native `AppKitView` (`lib/src/quick_panel/widgets/shortcut_recorder_row.dart:42`). KeyboardShortcuts keeps the chord in user defaults, natively and app-wide, and the main engine only learns whether one is set (`QuickPanelShortcut.swift`).
- Chosen: host the recorder in the Settings window's engine. The window-created callback registers `ShortcutRecorderFactory` on that engine's registrar with the shared `QuickPanelShortcut` instance, so recording in the window changes the same native chord, and the main engine's channel still reports the change to `GlobalShortcut`. The window's row reads "set or not" from the snapshot, like other main-owned values. This is the native change named under Platforms.
- Rejected: a `shortcut.record` command that makes the main engine show the recorder. The recorder is a view, not an action; it would have to open in the main window, behind the Settings window.

## Privacy and telemetry

- The snapshot is a closed record of booleans, enum names and flags; a test fails if a field can hold free text.
- Commands and answers carry fixed names and booleans. Raw exception text from the main side never reaches the window; the window shows one generic line, "Couldn't change this setting. Try again.", a new string (task 1.3).
- The main engine records all of them, because the Settings window starts no telemetry (as conversation windows do not, `lib/src/windows/conversation_window_app.dart:43-45`): the breadcrumbs `settings.window.opened`, `settings.window.focused` and `settings.window.closed` from `SettingsWindows` when it creates, focuses or sees the window close, with no attributes; and the log event `settings.window.command_failed` through `AppEventLogger`. The window sends the commands, so only the window sees a command time out, find no owner or come back rejected; it then reports the failure to the main engine over the link (a `settings.commandFailed` message carrying only the fixed command name and the outcome), and the main engine records the event with `command` (one of the fixed command names) and `outcome` (`timeout`, `no_owner`, `rejected`). If that report is lost too, nothing is recorded and nothing is resent. None holds a value, a preference's content, a server or an account.

## Acceptance

- Catalog: `SettingsWindowView` (plain model: sections, row values, availability) at default size, minimum size, German, largest text, light and dark, signed out, and with a failing command.
- Bridge unit tests with a fake link: a command reaches the main engine and its snapshot returns; a lost answer shows the generic line and never repeats a toggle; the window closes on cover, sign-out and server change.
- Widget test: ⌘, while the window is open focuses it and opens no second one; ⌘, while covered does nothing.
- Spec scenarios in `specs/mac-settings-window/spec.md`.
- A real run on a Mac (`verify-in-app`): open, change Appearance, see the main window follow, lock the app, see the window go. Listed under "Not verified on a device" until run.

## Design pass

Canvas "Hermes: Mac Settings window, toast, sub-pages" (private, ask its owner for access): https://claude.ai/artifact/Q36fmBuDK9Gy3jkgBF2g5R. Its "C4" row, one decision per board:

- Today, the Settings dialog over the window: a modal list with a scrim over the whole window, and a pick closes it. Replaced on the Mac.
- Proposed, the Settings window beside the main window: a separate window at 520 x 640 (minimum 420 x 480), no scrim, the existing grouped list in one scrolling column; rows keep their values and open their dialogs as today. The quick-panel recorder (28 pt, hosted in the window's engine, see "Quick panel shortcut") and the menu bar switch stay inline.
- Proposed, locked and signed out: on App Lock the window closes and unlock does not reopen it. Signed out, Command-comma stays off; if the owner answers yes to open question 3, the main-owned rows (Notifications, Quick panel, Spotlight, App Lock, Menu bar item) dim with "Sign in to change this.", Appearance, Dictation and Voice calls stay on, and Change Server is left out. Rendering showed that a disabled row dims its reason line too; the catalog pass checks its contrast and moves the reason to the section footer if it fails AA.

Still owed: the window in dark and German, at the largest text size, and with the Appearance dialog open in it (the same list as the brief's "Not yet on the canvas").

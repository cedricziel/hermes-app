## Context

Conversation windows (`lib/src/windows/`) already run a chat in a second Flutter engine on macOS: `desktop_multi_window` starts `main(["multi_window", id, args])`, `runConversationWindow` builds `ConversationWindowScreen`, `WindowAuthInterceptor` fetches headers from the main isolate (`auth.headers` on the main channel, answered in `ConversationWindows`), and `ConversationWindow` in `macos/Runner/MainFlutterWindow.swift` configures the `NSWindow` and registers a short plugin list (drop, file pickers, open_file, pasteboard, shared_preferences, url_launcher). Dictation plugins (`record`, `hermes_speech`) are left out there on purpose.

`ChatComposer` (`lib/src/chat/widgets/chat_composer.dart`) is a plain widget taking a controller, attachments, a `modelPill` widget and a `DictationView`. `ChatScreen` builds the `DictationController` and `OnDeviceSpeech`; `ConversationWindowScreen` builds a `ChatController` with a transport and the `ComposerModelPill`. `ChatProfiles.current` holds the main window's profile.

## Goals / Non-Goals

Goals: a hotkey-summoned panel that does not activate the main window, streams one chat, and hands that chat to a window. Non-goals: see proposal.

## Decisions

### 1. Host the panel in a desktop_multi_window engine, re-parented into an NSPanel

The panel reuses the conversation-window path: the main isolate creates it with `DesktopConversationWindowHost.create` and arguments marked `kind: panel`. That gives it a separate engine, `WindowAuthInterceptor`, the main channel and the window-closed bookkeeping for free.

`desktop_multi_window` creates a plain `NSWindow`. A Spotlight-style panel needs `NSPanel` with `.nonactivatingPanel`, so typing into it does not activate Hermes and raise the main window. In `setOnWindowCreatedCallback`, when the arguments say `panel`, a new `QuickPanel` class (next to `ConversationWindow`) creates an `NSPanel` subclass that returns `true` from `canBecomeKey`, sets `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`, `hidesOnDeactivate = false`, `isMovableByWindowBackground = true`, moves the plugin's `FlutterViewController` into it as `contentViewController`, and orders the plugin's original window out without closing it (closing it would make the plugin drop the engine). It resigns key on `windowDidResignKey` and tells Dart (`focus_lost`).

Alternatives considered:
- Keep the plugin's `NSWindow` and set `level = .floating`: showing it requires `NSApp.activate`, which brings the main window forward on the same Space. Rejected.
- A Swift-owned `FlutterEngine` outside `desktop_multi_window`: the panel would lose the inter-engine channel the auth and window code rely on, and need a second copy of it. Rejected.
- Render the panel in the main engine with a second `FlutterViewController`: Flutter's multi-view embedding on macOS is not stable on the channel the app ships. Rejected.

The re-parenting is the one risky step, so the first task is a spike behind a failing native check; if the plugin cannot tolerate it, the fallback is to set the panel style bits on the plugin's own window by swapping its class with `object_setClass` to the `NSPanel` subclass before it is shown. The design picks whichever works and records it in the task.

Spike result (PR A): re-parenting works, so there is no `object_setClass` fallback. `QuickPanel` lives in its own `macos/Runner/QuickPanel.swift` rather than in `MainFlutterWindow.swift`. The panel's engine starts through `ConversationWindow.attach` like any window and then calls `presentPanel` on its `hermes_app/window` channel; there `ConversationWindow` lets go of it and `QuickPanel.adopt` moves the view controller into the panel, sets the plugin's window's `contentViewController` to nil and orders it out. In a debug build against a dev backend, with TextEdit frontmost, the panel was toggled 22 times by a timer: every hide reported `shortcut` (so the panel was key each time), TextEdit stayed the frontmost app throughout, and every `panel.shown`/`panel.hidden` report came back over the main channel. The main window toggles through `togglePanel` on its own `hermes_app/window` channel, which answers false while there is no panel so Dart creates one. `closeConversation` with the panel's id and `closeConversations` close it too. Hide reasons are `escape`, `shortcut` (the shortcut pressed while the panel is key), `focus_lost` and `open_in_hermes`; anything else is recorded as `other`.

Review fixes (PR A): until the panel's engine reports its first `shown`, a press neither toggles nor creates another engine; one that has not reported in after 15 s is closed and replaced. A close that arrives before the engine presents is honoured in `presentPanel`. `QuickPanelWindow.performKeyEquivalent` keeps chords from reaching the main menu: Flutter gets them first (the field's edit chords), then ⌘W hides the panel, ⌘Q quits and every other chord does nothing. While Hermes is hidden (⌘H), showing the panel unhides the app without activating it, which also brings its other windows back, and `panelShown` is reported only when the panel is on screen. The window losing or regaining key while the panel takes or gives it back does not report a key change (`QuickPanel.switchingKey`), so the main window does not reload its chats on every toggle. The panel forwards the app's active changes to its engine, which desktop_multi_window did through the window it made.

The panel is created hidden on the first hotkey press and kept alive (ordered out, not closed) afterwards, so the chat and its gateway socket survive between presses. It is excluded from `ConversationWindowStore` persistence and from the Window menu's list (`ConversationWindowsMenu`), and closed on sign-out with the other windows.

### 2. Global shortcut: sindresorhus/KeyboardShortcuts

The shortcut is registered by the Swift package [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (3.x), not by a pub.dev plugin. Facts checked against its README:

- Sandbox: it is documented as fully sandboxed and Mac App Store compatible. It registers system-wide chords through Carbon, so no Accessibility or Input Monitoring permission is needed. Hermes is sandboxed; no entitlement changes.
- macOS minimum: 10.15 (one API needs 13). The Runner deployment target is 26.0, so this is no constraint.
- Recorder: it ships `KeyboardShortcuts.RecorderCocoa` (AppKit) and a SwiftUI `Recorder`. The recorder stores the chord, shows a clear button, and warns when the chord clashes with a system shortcut or with the app's main menu, which covers our menu bar commands without writing that check ourselves.
- Storage: the recorder persists the chord in user defaults under a `KeyboardShortcuts_` key, so it does not clash with `shared_preferences` keys (prefixed `flutter.`). Dart never reads or writes the chord.

Why not `hotkey_manager` (the pub.dev option): its last release is from May 2024, it is a thin wrapper that would still need our own recorder and conflict checks, and a global hotkey is OS plumbing that breaks across macOS releases. KeyboardShortcuts is actively maintained by an author whose apps ship it on the Mac App Store, has one small surface (a `Name`, `onKeyDown`, a recorder), and removes the Dart-side recorder, chord validation and menu-conflict code. The cost is a Swift package in the Runner instead of a pub dependency; CLAUDE.md's dependency rule prefers a mature maintained package over homegrown code, and this is one.

How it is added. The macOS app has no Podfile and Runner deployment target is 26.0, so the package goes in through Xcode's Swift Package Manager on `Runner.xcodeproj` (Add Package Dependencies, the repository URL, "Up to next major" from the current 3.x, product `KeyboardShortcuts` linked to the Runner target only; the panel engine is the same process, so nothing else links it). This edits `Runner.xcodeproj/project.pbxproj` and creates `Package.resolved` under the project's `xcshareddata/swiftpm/`; both are committed, and the package version is pinned by `Package.resolved`. CLAUDE.md warns that building rewrites tracked `ios/` and `macos/` Xcode files: stage the pbxproj and `Package.resolved` changes by name, and `git restore` any other Xcode churn. CI's macOS build resolves the package with network access; the task checks that `flutter build macos` works from a clean clone.

Wiring. `QuickPanelShortcut.swift` (Runner, main engine only) declares `KeyboardShortcuts.Name("quickPanel")` with no default, calls `KeyboardShortcuts.onKeyDown(for:)`, and forwards each press over a method channel `hermes_app/quick_panel` to the main isolate. A `GlobalShortcut` interface in `lib/src/quick_panel/global_shortcut.dart` wraps that channel so tests use a fake. The Dart side decides what a press does: show or hide the panel when a connection is ready, otherwise bring the main window forward. `GlobalShortcut` also exposes whether a shortcut is set, read through the channel (`KeyboardShortcuts.getShortcut(for:)`), for the Settings row's summary and for the `panel.shortcut_*` events.

The recorder. `RecorderCocoa` can be shown from Flutter: Flutter's macOS `AppKitView` hosts a native view from a `FlutterPlatformViewFactory` registered by the Runner under `hermes_app/shortcut_recorder`, which returns a `RecorderCocoa(for: .quickPanel)` and reports changes (set or cleared) back over the channel. Platform views are supported in the main window's engine, which is the only engine that shows Settings. The Settings row (`ShortcutRecorderRow`, Widgetbook first with a plain stand-in in place of the platform view) sizes the native control to the row's value area. If the platform view looks wrong in the grouped list or fails with the Settings dialog's route transitions, the fallback is a Flutter recorder field that reads `HardwareKeyboard`, builds a `KeyboardShortcuts.Shortcut` from the key code and modifiers and hands it to native with `KeyboardShortcuts.setShortcut(_:for:)`; chord rules and menu clash warnings would then be ours. The task starts with a spike on the platform view and records which path was used.

Only the main engine registers the shortcut and shows the recorder; the panel engine does not link the channel.

Spike result (PR A): the package resolves through Xcode SPM (3.1.0, pinned in both `Package.resolved` files: the workspace's, which `flutter build` uses, and the project's), the debug and the sandboxed release build both compile, and a chord stored under `KeyboardShortcuts_quickPanel` is read back at launch (`isSet` answers true). The recorder is the native platform view: Settings opened with `AppKitView` and raised no error. Its look in the dialog could not be checked in that session, which had no Screen Recording or Accessibility permission, so the Flutter fallback stays documented here in case it looks wrong. `GlobalShortcut` is provided app-wide (`Provider<GlobalShortcut?>`, macOS only), because the channel has one handler and both the press handling and the Settings row need it.

### 3. Profile and session reuse

On each show, the panel asks the main isolate `profile.current` (answered in `ConversationWindows` from `ChatProfiles.current`). A new chat is created with `ChatTransport.send` on that profile, so it is a normal session (`source: hermes_app`) listed in the main window's history. A `QuickPanelSession` in the panel isolate holds `{threadId, profile, lastUsed}`; `lastUsed` updates on send and on each reply event. On show, if `now - lastUsed < 5 min` and the profile is unchanged, the chat continues; otherwise the panel clears to an empty composer. The rule is pure and unit-tested with a fake clock.

### 4. Panel screen

`QuickPanelScreen` (`lib/src/quick_panel/quick_panel_screen.dart`) reuses `ChatController`, `ChatThreadView` (compact, no header) and `ChatComposer` with `ComposerModelPill` and the attachment source, the same way `ConversationWindowScreen` does. The panel is 680 pt wide; it starts at composer height and grows to at most 60% of the screen height as the reply arrives (`present`/`resize` on the window channel). Return sends (the composer's existing behaviour); Escape cancels dictation first, then hides; ⌘O, and a button, call `showInWindow` on the main channel, which opens or focuses the chat's conversation window through the existing `ConversationWindows.open`, then hides the panel and starts its next show empty. Approval and clarify cards work as in a window.

### 5. Dictation in the panel

`QuickPanel` registers `RecordPlugin` and `HermesSpeechPlugin` in addition to the conversation-window list. `hermes_speech` keeps its event sink per plugin instance, so the panel engine gets its own channel and listener and does not steal the main engine's. The panel builds its own `DictationController`, `OnDeviceSpeech` and reads `DictationSettings` from shared preferences (unrelated to the shortcut, which lives in user defaults under the package's own key). Recording stops when the panel hides. Conversation windows keep their short list.

## Platforms

macOS only. No entitlement change (`audio-input`, `network.client` already present). Xcode: no new target; one Swift package dependency on the Runner target (see decision 2). No Info.plist change.

## Invariants touched

- Auth: the panel engine holds no tokens; 401 handling stays in the main window via `WindowAuthInterceptor`.
- API layering: no new REST route; sessions come from the gateway, history through `HermesChatRepository`.
- Telemetry stays off in the panel engine (as in conversation windows); events are forwarded to the main isolate's `AppEventLogger`/`Breadcrumbs` over the main channel with fixed names only.

## Observability

- `panel.shown`, `panel.hidden {reason}`, `panel.chat {continued}`: breadcrumbs recorded in the main isolate's `ConversationWindows` when the panel reports them.
- `panel.shortcut_pressed`: breadcrumb in the main isolate when the native press arrives. `panel.shortcut_changed {set}`: `AppEventLogger` in `GlobalShortcut` (main isolate) when the recorder reports a change.
- `panel.opened_in_window`: `AppEventLogger` in the `showInWindow` handler.
None carries text, titles, profile names or ids.

## Risks / Trade-offs

- Re-parenting a plugin-owned view controller may break on a `desktop_multi_window` update. Mitigated by the spike. There is no committed native test: the check that the engine survives hide and show is the scripted timer toggle in the verify-in-app skill's quick panel section, run against a dev backend.
- The shortcut and its recorder are Swift code the Dart tests cannot reach; the Dart side is tested through a fake `GlobalShortcut`, and the native path is covered by the verify-in-app check. A Swift package makes the Runner depend on network package resolution; the pin in `Package.resolved` keeps builds reproducible.
- A chord another app has already taken may register without an error; the recorder warns only about system and menu-bar clashes. The user sees that the panel does not appear and records another chord.
- Two engines each holding an audio engine: only the key window dictates, and the panel stops recording on hide.

## Decisions left to implementation

- The panel opens on the screen with the mouse, centred horizontally, in the upper third.
- Whether the recorder is the native platform view or the Flutter fallback is settled by the spike in task 2.1 and recorded in decision 2.

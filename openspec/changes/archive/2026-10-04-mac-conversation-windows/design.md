## Context

The app runs one Flutter engine in one `NSWindow` (`MainFlutterWindow`). `AuthController` owns the session: it stores tokens in secure storage and is the only code that refreshes them; refresh tokens rotate, so two refreshers spending the same refresh token sign the user out (the 0.1.8 and 0.1.9 regressions). `ChatController` holds one profile's threads and streams replies over the dashboard websocket. CI and release builds use the stable Flutter channel (3.47 at the time of writing).

## Decision: how to get a second window

**(a) Flutter's own windowing API** (`RegularWindowController`, several views on one engine and one isolate). This would be the best fit: one `AuthController`, one set of controllers. On 3.47 stable it is not usable: the API lives in `package:flutter/src/widgets/_window*.dart`, is `@internal`, is not exported, throws `UnsupportedError` unless `isWindowingEnabled`, and the `windowing` feature flag (`enable-windowing`) is only available on the master channel (`flutter_tools` `windowingFeature`: `master: available`). Its docs say it changes "even in patch versions". Rejected: it would force release builds onto master.

**(b) `desktop_multi_window` (mixin.dev, 0.3.1, macOS/Windows/Linux, about 290 likes).** Each window is a new `FlutterViewController` with its own engine and isolate, started at `main(["multi_window", windowId, arguments])`, and `WindowMethodChannel` passes messages between engines through the plugin. Chosen, with these rules:

- **One token owner.** A conversation window builds its own `Dio`, whose only auth interceptor (`WindowAuthInterceptor`) asks the main window for headers over the `hermes_app/conversations` window channel (`auth.headers`). On a 401 it asks again once, passing the headers that were rejected; the main window's `AuthController.windowAuthHeaders` refreshes only when the rejected token is still the current one (the same stale-token rule its own interceptor uses), through the same de-duplicated `_refreshSession`. On a server without the auth gate the main window hands out the page session token instead. The secure storage plugin is not registered in sub-engines, so a conversation window cannot read tokens even by mistake.
- **Selective plugins.** `MainFlutterWindow` registers, for each new engine, only what the conversation view uses: shared preferences (theme), url_launcher, pasteboard, file selector/picker, desktop_drop, open_file. Not registered: flutter_local_notifications (it takes the notification centre delegate), flutter_secure_storage, local_auth, connectivity, device_info, package_info and macos_window_utils (its window manipulator is a process-wide static bound to the main window).
- **App-global pieces stay in the main engine.** Only the main engine sets `PlatformMenuBar`; menu commands that act on the key window are routed by the main isolate to the conversation window through its own window channel. Telemetry, notifications, the watch bridge, app lock and the share inbox start only in the main engine.
- **Native chrome per window.** The sub-window's transparent title bar, full-size content view, unified toolbar, minimum size, frame autosave and title are set in Swift on the window's own channel (`hermes_app/window`, the same name the main engine uses, so `MacWindow.startDrag` works in both).

**(c) Stop.** Not needed: (b) works on stable without touching the session rules.

## Other decisions

- **Main window lifetime.** Its `isReleasedWhenClosed` is off, so closing it hides it and its engine (the token owner) keeps running; ⌘0 or the Dock icon shows it again. Quitting stays the same: the app ends when the last window closes.
- **Registry.** `ConversationWindows` (main isolate, `ChangeNotifier`) is the list of open windows: window id, session id, profile, title, and which one is key. It opens a window (or focuses the one already open for that session and profile), removes windows the plugin reports gone, answers the windows' requests, and persists the list (server URL, profile, session id, title) to shared preferences on every change. Platform calls go through a `ConversationWindowHost` interface so tests use a fake.
- **Restoration.** Once the main window is signed in (`AppShell` mounts), the registry reopens the saved windows for the current server URL once. Frames come back through `NSWindow.setFrameAutosaveName`, keyed by server, profile and session; without a saved frame the window cascades from the main window.
- **Conversation view.** The sub-engine runs a `ChatController` for the window's profile and opens its session with `open(fetchMissing: true)`, the path notifications use. The message list and composer are the main window's `ChatThreadView`, pulled out of `chat_screen.dart`. The toolbar is a plain-model widget (`ConversationWindowToolbar`) with a Widgetbook use case.
- **Consistency.** Each engine keeps its own websocket and state. A conversation window reloads its chat (details and messages) when it becomes key, unless a reply is streaming there. The main window reloads, when it becomes key, every loaded chat that has been open in a conversation window this session, unless a reply is streaming there; a chat that is gone (archived or deleted) is dropped from its list. Rename, pin, archive and delete in a conversation window therefore show in the main window the next time it is focused.
- **Sign-out.** The registry closes every window and clears the saved list when the main window signs out or changes server.

## Risks / Trade-offs

- [One isolate per window costs memory, about one engine each] → acceptable for a handful of windows.
- [A second websocket per window] → each window opens one only while it streams; the dashboard serves several clients already (the web UI).
- [The plugin is pre-1.0 and its 0.3.0 was a rewrite] → it is small (four Swift files), the app uses only create/show/fromCurrentEngine/getAll/onWindowsChanged and the window channel; everything else is in our own Swift.
- [The main window is hidden but alive] → the token owner never goes away while conversation windows are open.
- [Theme changes made in the main window do not reach open conversation windows] → listed as a non-goal; reopening the window picks them up.

## Platforms

macOS only: new Swift in `macos/Runner/MainFlutterWindow.swift` and `AppDelegate.swift`, the plugin added to the generated registrant and the Xcode project. No entitlement change. iOS, Android, Windows and Linux: the new Dart code is never reached (the registry is null off macOS), though the plugin's Windows and Linux code is compiled into those builds.

Invariants touched: auth (the token hand-off keeps a single refresher and keeps tokens in secure storage only; the persisted window list holds no secret).

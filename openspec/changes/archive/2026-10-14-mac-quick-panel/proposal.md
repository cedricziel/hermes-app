## Why

On a Mac, asking Hermes something means finding the app, bringing its window forward and starting a chat. A global shortcut that opens a small floating prompt over whatever app is in front, with the reply streaming right there, makes quick questions cheap and leaves the user where they were.

## What Changes

- A user-recorded global keyboard shortcut (none by default) shows a floating quick panel above other windows, on the current Space and over full-screen apps, without bringing the main window forward.
- The panel holds a composer (text, attachments, dictation, model pill) and the reply streamed below it. Return sends, Escape hides the panel.
- The panel's chat is a normal saved session in the main window's current profile and shows up in the chat list like any other.
- Showing the panel again within 5 minutes of its last use continues the same chat; after that it starts empty.
- "Open in Hermes" (⌘O) moves the chat to a conversation window and hides the panel.
- Settings… gains a Quick panel row to record, change or clear the shortcut, using KeyboardShortcuts' native recorder control. The shortcut is stored per device by that package in the app's user defaults.
- The panel runs in its own engine, created through the conversation-window infrastructure, and registers the dictation plugins that conversation windows leave out.

## Capabilities

### New Capabilities

- `mac-quick-panel`: a global-shortcut prompt panel on macOS that sends to the current profile and streams the reply in place.

### Modified Capabilities

None. Chat, voice-dictation and macos-menu-bar requirements stay as they are; the panel is another place that uses them.

## Impact

- `macos/Runner/MainFlutterWindow.swift`: a panel variant of `ConversationWindow` (non-activating, floating, all Spaces) and the extra plugin registrations for it.
- `lib/src/windows/`: panel launch arguments, a `QuickPanelScreen`, and main-isolate handling of `profile.current` and "Open in Hermes".
- `lib/src/settings/settings_dialog.dart`: the shortcut row, which embeds the native recorder as a platform view.
- `macos/Runner/`: the Swift package sindresorhus/KeyboardShortcuts added to the Runner target (Xcode SPM), a small `QuickPanelShortcut.swift` that registers the shortcut and the recorder's platform view factory. No new pub.dev dependency (see design).
- Two PRs: the native panel host and shortcut first, the panel's chat second (see tasks).

Coordination: the `hermes://` deep-link router and actionable notifications are owned by other changes. This change depends on neither. A `hermes://new-chat` link could later open the panel, but that is not specified here.

### Non-goals

- No default shortcut, and no shortcut on iOS, Windows, Linux or Android.
- No profile picker in the panel; it always uses the main window's current profile.
- No chat list, search, slash-command menu beyond what `ChatComposer` already offers, or history browsing inside the panel.
- No hands-free voice mode, no screenshot or selected-text capture from the frontmost app.
- No launch-at-login or menu bar extra; the shortcut works while Hermes is running.

### Security and privacy

The panel's engine never reads tokens: like conversation windows it asks the main window for request headers through `WindowAuthInterceptor`. The shortcut (key code and modifiers) is stored in user defaults by KeyboardShortcuts; it is not a secret. The package registers the chord through Carbon, which sees only that chord, not other keystrokes, and needs no Accessibility or Input Monitoring permission. It is documented as App Sandbox and Mac App Store compatible. Dictation in the panel uses the existing microphone entitlement and keeps no recording beyond what dictation already keeps. No telemetry carries prompt text, titles or profile names.

### Observability

- Breadcrumbs `panel.shown` / `panel.hidden` (`reason`: escape, open_in_hermes, focus_lost) and `panel.chat` (`continued`: true/false), so a crash after a hotkey press is explainable.
- Log event `panel.shortcut_changed` (`set`: true/false) through `AppEventLogger` when the user records or clears the shortcut, and breadcrumb `panel.shortcut_pressed`, so "the shortcut did nothing" reports can be told apart from "it was never set".
- Log event `panel.opened_in_window` (no attributes) to count how often a panel chat moves to a window.
- No new spans: sending goes through the gateway transport, which already traces its socket.

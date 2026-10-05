## Why

Users who move between an iPhone, iPad, and Mac must find their chat again in Hermes. Apple Handoff can reopen the same saved chat using the receiving device's existing dashboard connection and credentials.

## What Changes

- Advertise the visible, saved chat through an Apple user activity identified by dashboard URL, profile, and thread ID.
- Receive activities during cold launch and while the app is running, then open the target after connection, sign-in, and app unlock.
- Ask before connecting to an incoming dashboard that differs from the configured server, or when no server is configured.
- Withdraw the activity when its chat is no longer visible, the app locks, or the connection leaves ready state.
- Keep the activity payload small and versioned, with a generic title and no transcript or credentials.

## Capabilities

### New Capabilities

- `apple-handoff`: Continue a saved chat between iOS, iPadOS, and macOS with native Apple Handoff and existing Hermes session APIs.

### Modified Capabilities

None. Existing auth, chat, and app-lock requirements remain authoritative. Handoff adds another source of chat-open requests.

## Impact

- Native integration in `ios/Runner/SceneDelegate.swift`, `ios/Runner/AppDelegate.swift`, and `macos/Runner/AppDelegate.swift`, plus activity declarations in both Runner plists.
- A Dart platform bridge and app-wide pending activity controller, wired into auth, app lock, the shell, and chat selection.
- Existing `ChatOpenRequests` and profile-aware chat restoration, using the generated REST client and gateway transport.
- Widgetbook states for the dashboard connection prompt and restoration failures, and focused tests using `FakeHermesServer`.
- One feature PR, targeting roughly 500 implementation lines. Use the existing chat restoration path and standard dialogs to keep scope bounded.

### Non-goals

Draft text, attachments, queued messages, scroll position, unsaved chats, hosted group rooms, browser Handoff, watchOS Handoff, and Android, Windows, or Linux equivalents are outside this change. Handoff does not transfer ownership of a running reply or send a prompt.

### Security and privacy

The payload exposes the dashboard address, profile name, and thread ID to Apple's Handoff mechanism. Use a generic activity title, omit credentials and chat content, and disable search and public indexing. Validate incoming identifiers and URLs before use. Each receiving device authenticates independently. Never silently switch servers or bypass app lock. Stored tokens and refresh behavior remain unchanged.

### Telemetry

None. Do not add Handoff payloads, dashboard addresses, profile names, or thread IDs to telemetry. Existing API and connection instrumentation remains unchanged.

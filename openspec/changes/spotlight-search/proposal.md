# Proposal

## Why

People remember a conversation by what it was about, not where it sits in the chat list. iOS Spotlight is where they already search for that. Hermes indexes nothing today: Handoff publishes its activity with `isEligibleForSearch = false` on purpose, so chats never show up in system search. Making recent chats findable from Spotlight, and opening them on a tap, saves opening the app and scrolling. Because chat titles and snippets can be private, it is the user's choice.

## What Changes

- A "Show chats in Spotlight" switch, off by default, on iOS: in the account menu's new "Spotlight" entry and in the Settings dialog.
- While it is on, the app adds its recent chats (the surface snapshot's, up to ten across profiles) to Spotlight with the chat's title and latest-message snippet, and keeps that set in step with each new snapshot: new chats appear, renamed ones change, chats that fall out of the recent set are removed.
- Tapping a Hermes result in Spotlight opens Hermes on that chat in its profile, also when Hermes was not running.
- Turning the switch off, signing out and changing server remove every Hermes item from Spotlight.
- The index API is generic (a domain, an id, a title, a text and a `hermes://` link per item), so a later Memory browser can add a `memory` domain without native changes.
- Handoff stays as it is (`isEligibleForSearch = false`).

Non-goals:

- No full-history index: only the chats in the snapshot, not every chat on the server, and no message bodies beyond the 120-character snippet.
- No Spotlight on macOS in this change (the native index call lives in the iOS Runner; the macOS gaps change can reuse the Dart side).
- No Siri suggestions or App Shortcuts from indexed items (`app-intents`).
- No Android equivalent (AppSearch).

Security and privacy impact: the indexed titles and snippets leave the app's sandbox for the system's Spotlight index, where any user of the unlocked device can search them, and iOS may show them in suggestions. That is why the switch is off by default and its description says so. The items are stored in a named index with complete file protection, so they are not searchable while the device is locked. The index holds no token, server address or user identity; the link holds the profile name and chat id. Everything is removed on sign-out, server change or switching off. Telemetry carries counts, domains and outcomes, never a title, snippet or id.

Observability:

- Log event `spotlight.index_failed` (`operation`, `spotlight.domain`, `error.type`) when an index call fails, so a broken index is visible.
- Log event `spotlight.opened` (`spotlight.domain`) when a result opens the app: the only way to tell whether anyone uses it.
- Breadcrumb `spotlight.toggled` (`enabled`), a user step that explains a later crash in the indexer.
- No span: the index call is local and quick, and it is not tied to a server connection, which the app's spans describe.

## Capabilities

### New Capabilities

- `spotlight-search`: the opt-in setting, what is indexed and when it is removed, opening a result, and the generic domain-based index.

### Modified Capabilities

None. Handoff's behavior is unchanged.

## Impact

- Depends on `surface-snapshot` (recent chats with snippets and URLs, its write listener, the signed-out snapshot) and `deep-links` (opening a result goes through the same path as a `hermes://` link).
- Dependency: none. A small method channel instead of a plugin (see design.md).
- Dart: a new `lib/src/spotlight/` module, the setting and its dialog, a row in the Settings dialog and the account menu, Widgetbook use cases.
- iOS: `ios/Runner/Spotlight.swift` (channel `hermes_app/spotlight`), hooks in `AppDelegate.swift` and `SceneDelegate.swift`, `CoreSpotlight` linked. No entitlement or Info.plist change.
- Backend: none.

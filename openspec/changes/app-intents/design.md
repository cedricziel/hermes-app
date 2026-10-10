# Design

## Context

See proposal.md for motivation and specs/app-intents/spec.md for behavior.

- `deep-links` (wave 1) registers the `hermes` URL scheme on the Runner, parses `hermes://chat`, `hermes://new` and the others in `lib/src/deep_links/`, and routes them through `AppShell`, including the link that cold-starts the app.
- `home-screen-widgets` creates the Swift package `ios/HermesSurfaceKit` (snapshot reader and its tests, compiled into `HermesLiveActivity`). This change extends that package; it does not create a second one.
- `surface-snapshot` (wave 1) writes `hermes.surface.v1` to `UserDefaults(suiteName: $(CUSTOM_GROUP_ID))` (Contract 2) and lets listeners subscribe to writes. Its `recentChats` rows already carry a ready-made `url`, and `profiles` lists the server's profile names. While App Lock is on, chat titles are written empty and snippets left out.
- The Runner and `HermesLiveActivity` both have the App Group. `HermesLiveActivity` is a widget extension whose `@main WidgetBundle` holds only the reply activity today. The deployment target is iOS 26 everywhere, so App Intents, `ControlWidget`, `OpenURLIntent` and `supportedModes` are all available without availability checks.
- The watch app defines its own `NewChatIntent` and `VoiceChatIntent` in another bundle. Its phrases are reused here; its file is not touched.

## Goals / Non-Goals

**Goals:**

- Every entry point ends in one `hermes://` link built the same way as Dart builds it, so the app has one way in.
- Entity queries answer from the snapshot alone: no Flutter engine, no network, so the Shortcuts editor and Control Center stay fast and work in the widget extension.
- Swift that a later macOS Runner can compile unchanged.

**Non-Goals:**

- Running Dart from an intent (that is `ask-hermes-intent`).
- A second snapshot reader. The intents use the one `home-screen-widgets` adds to `HermesSurfaceKit`, extended where they need `profiles`.

## Decisions

### Native Swift App Intents, not the `app_intents` plugin

Checked `app_intents` 0.18.0 on pub.dev (published 2026-10-02, 160 pub points, 2 likes, about 900 downloads in 30 days, pre-1.0 with 32 releases in nine months). It routes every `perform()` and entity query to a Dart handler on the running engine (it waits up to five seconds for the executor to be set), and needs its own code generator (`app_intents_codegen`) to emit the Swift types. That does not fit:

- Entity queries and controls run in the widget extension, where there is no Flutter engine at all. The plugin's model needs one.
- Our open intents need no Dart: they build a URL. Our answering intents (`ask-hermes-intent`) need Dart in a headless engine, which the plugin does not start.
- It is young and lightly used, which the project's dependency rule weighs against.

Hand-written App Intents are about 200 lines of Swift with no dependency. `intelligence` (0.2.0, February 2025) and `flutter_siri_suggestions` (2022, SiriKit donations) were also checked and are unmaintained or the wrong API.

### Extending `ios/HermesSurfaceKit`, compiled into both targets

`home-screen-widgets` creates the package following `ios/HermesWatch` (sources Xcode compiles straight into the target, tested with `swift test` on macOS) with its lenient snapshot reader. This change adds:

- To the snapshot reader: decoding of `profiles` (a missing or malformed list read as empty), if `home-screen-widgets` does not decode it already.
- `DeepLink`: the package's URL builder, added by `lock-screen-widgets` together with its fixture test against the Dart `deepLinkUri` (`Tests/Fixtures/deep_links.json`). App Intents reuse it and add no builder of their own. The snapshot's own `url` is used when present; the builder covers chats a saved shortcut names that are no longer in the snapshot and the profile-only links.
- `ChatEntity` (`AppEntity`): id `<percent-encoded profile>/<thread id>` (the shape `WatchRequestHandler` already binds a thread to its profile with), title, profile, last update. Display: the title, with the profile as subtitle when the snapshot holds more than one profile. Its `EntityStringQuery` answers `suggestedEntities` with the snapshot's recent chats, `entities(for:)` with the matching rows, and for an id not in the snapshot an entity titled "Chat" that still opens (the app fetches missing chats). `entities(matching:)` filters titles case- and diacritic-insensitively.
- `ProfileEntity` (`AppEntity`): the snapshot's `profiles`, with the current `profile` first. When `profiles` is empty (an older snapshot), it falls back to `profile` and the profiles of `recentChats`, without duplicates.
- Under App Lock the snapshot's titles are empty, so a chat entity is shown as "Chat" and title search and "Open <chat> in Hermes" match nothing; the profile list and links still work.
- `OpenChatIntent`, `NewChatIntent`, `DictateIntent`: `supportedModes = .foreground`, `perform()` returns `.result(opensIntent: OpenURLIntent(url))`. `OpenChatIntent` also conforms to `ControlConfigurationIntent` so the Open Chat control can be configured with a chat. Names are prefixed (`HermesOpenChatIntent`, …) only if the Swift compiler complains about the watch module, which it should not since the targets are separate.

The package's platforms are iOS 26 and macOS 26; it imports `AppIntents`, `Foundation` and `WidgetKit` only, no UIKit.

### Intents in both targets, the shortcuts provider in the Runner only

An intent that a control runs must be compiled into the widget extension, and an intent that opens the app must be compiled into the app. The intents and entities are therefore members of both the Runner and `HermesLiveActivity`. `HermesAppShortcuts: AppShortcutsProvider` must exist once per app and lives in a Runner-only file (`ios/Runner/HermesAppShortcuts.swift`), because a second provider in the extension would make the phrases ambiguous. `ask-hermes-intent` and `request-intents` add their shortcuts to this provider (at most 10 per app; this change uses 3).

Phrases, from the watch's set where they exist: New Chat "New \(.applicationName) chat", "Start a \(.applicationName) chat"; Dictate "Talk to \(.applicationName)", "Voice chat with \(.applicationName)", "Dictate to \(.applicationName)"; Open Chat "Open \(\.$chat) in \(.applicationName)". "Ask \(.applicationName)" is left for `ask-hermes-intent`.

### Controls in `HermesLiveActivity`

`HermesLiveActivityBundle` gains `NewChatControl`, `DictateControl` (`StaticControlConfiguration` with a `ControlWidgetButton`) and `OpenChatControl` (`AppIntentControlConfiguration` with `OpenChatIntent`, showing the chosen chat's title, or "Open Chat" before one is chosen). Reusing the existing extension avoids a new target, bundle id, provisioning profile and App Group entitlement; it already has the App Group the entity queries need. `home-screen-widgets` is expected to add its widgets to the same bundle. A new extension was rejected because each costs a fastlane signing entry and a pbxproj target for no gain.

The Lock Screen shows controls on a locked device; a control's title is fixed text, and the Open Chat control shows the chat's title. That title is the user's own choice for their Lock Screen.

### Refreshing the chat phrases

The parameterized phrase "Open \(\.$chat) in Hermes" only knows the chats iOS last asked for. After each snapshot write, Dart calls `refreshShortcuts` on a `hermes_app/intents` method channel (iOS only, errors swallowed), and the Runner calls `HermesAppShortcuts.updateAppShortcutParameters()`. The call is made from a listener the app registers on the snapshot store's write stream, so `surface-snapshot` does not need to know about intents. `ask-hermes-intent` reuses the same channel name for its own methods.

### When the user is signed out

The intents still open the app on their link; the app shows setup or sign-in, and `deep-links` drops a chat link it cannot open while signed out. Entity queries return nothing when `signedIn` is false.

### Platforms and native changes

- iOS: new Swift files in the Runner and `HermesLiveActivity` targets, three controls in the extension's bundle. No Info.plist key, entitlement or new target. `fastlane/Fastfile` is unchanged.
- macOS: none shipped; `HermesSurfaceKit` builds for macOS in `swift test`.
- Android, Windows, Linux, watchOS: none.

### Invariants touched

- Tokens and secure storage: not read. The snapshot never holds a token (Contract 2).
- Telemetry: none added; see proposal.
- API layering and the generated client: untouched; no network.
- Tests: the Swift logic is tested with `swift test` in CI's macOS job next to the watch core; the Dart channel call with a mock method channel handler.

## Risks / Trade-offs

- [`OpenURLIntent` with the app's own custom scheme] → expected to open the app and deliver the URL through the scene's `openURLContexts`, like any custom scheme. If verification shows it does not for a foreground-mode intent, `perform()` falls back to handing the URL to the `deep-links` change's Swift intake directly (the intent runs in the app process because of `supportedModes = .foreground`).
- [App Lock hides titles] → chats cannot be picked or spoken by name while App Lock is on. That is the point of App Lock; the Chat picker still lists them as "Chat" with their profile and age.
- [Snapshot is stale while the app has not run] → the picker shows the chats as of the last write. Background refresh (`background-refresh`) narrows the gap.
- [Two `AppShortcutsProvider`s, phone and watch] → they are in different bundles; Siri on the phone uses the phone's. "Talk to Hermes" on the phone dictates in the app, which matches the watch's meaning.
- [`HermesLiveActivity` grows beyond Live Activities] → the name is kept to avoid a target rename in pbxproj; the bundle's doc comment says it hosts every widget and control.

## Dependencies

- `home-screen-widgets`: creates `ios/HermesSurfaceKit` and its snapshot reader, and the widget bundle the controls join.
- `surface-snapshot`: writes the snapshot, including `profiles`.
- `deep-links`: registers `hermes://` and handles the links.

## Migration Plan

Nothing to migrate. Rollback removes the shortcuts provider and the controls; saved shortcuts that use the intents then fail with iOS's own "app no longer supports this action" message.

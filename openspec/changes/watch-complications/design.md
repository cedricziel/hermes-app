# Design

## Context

Platforms: iOS (a method on the existing watch channel) and watchOS (a new WidgetKit extension, an App Group entitlement on the watch app). Android, macOS, Windows and Linux are unaffected. Native changes: a new extension target in `ios/Runner.xcodeproj`, `ios/HermesComplication/` (Info.plist, entitlements, xcconfig, privacy manifest), an entitlements file for `HermesWatch`, and fastlane and CI entries for the new bundle ID.

## Relation to open changes

- `watch-live-activity` (open) adds a `.small` Live Activity layout so the Smart Stack mirrors a phone-sent reply. It cannot cover a turn sent from the watch (ActivityKit needs the app in front). This change covers both kinds of turn with a widget the watch owns, so the Smart Stack may show both cards for a phone-sent reply. That is acceptable: the Live Activity is richer (elapsed time), while the widget also covers watch-sent turns and outlives a dismissed activity. Neither change depends on the other.
- `live-activities` (open) defines the states a reply passes through (`ReplyActivityState`, `nextActivityState`). The complication reuses that state machine so the two never disagree about a turn; only the wording differs. It does not use the Live Activity setting: the complication is not an activity and is not gated by it.
- `apple-handoff` (open) hands a chat to another device. No interaction.
- `actionable-request-notifications` added the `waiting` answer to the watch relay. A turn that waits on an approval or question is the "waiting for you" state here. The status comes from the same events, not from the relay's `waiting` answer, so it also covers phone-sent turns.

## Decisions

### One publisher, fed from the two places that see a turn

`WatchComplicationStatus` (Dart) keeps the live turns and publishes the one worth showing. Two callers feed it, because no single existing object sees every turn:

- `ChatController._announce` receives every event of a reply sent from the phone, next to the Live Activity, and `begin` is called where the Live Activity begins.
- `WatchRequestHandler._send` sees every event of a turn sent from the watch.

`AttentionNotifier.announce` is not the place: only `ChatController` calls it, the watch handler posts through the bridge's own `announcer`, and the notification policy drops most events (working, and anything on the thread on screen).

State is `nextActivityState` from the Live Activity module, mapped to four wire states: `working`, `waiting` (approval, question, needs-you), `ready`, `failed`. A stopped reply drops the turn.

Which turn is shown: the newest waiting turn, otherwise the most recently updated one. A finished turn stays until a newer one replaces it, so the glance still says "Reply ready" for the chat. Only the newest finished turn is kept.

### Transport

`transferCurrentComplicationUserInfo` is WatchConnectivity's call for pushing a complication update to a watch app that may not be running; it wakes the watch app in the background but has a daily budget (50). The native side uses it while `isComplicationEnabled` and `remainingComplicationUserInfoTransfers > 0`, and `updateApplicationContext` otherwise (the latest value wins, not budgeted). Dart sends only when the payload changed, so streamed deltas cost nothing; a turn costs about three transfers (start, wait, end).

Payload: `{v: 1, state, updatedAt (seconds), title?, threadId?}`, or `{v: 1, state: "none"}` to clear. `title` is omitted for a chat the gateway has not named (the watch app then looks the title up in its saved chat list by thread id) and under App Lock. `threadId` is the watch's bound id (`<encoded profile>/<session id>`), omitted under App Lock and while the chat is not yet stored on the server.

### The watch app and the widget share an App Group

A widget extension is its own process and cannot read the watch app's container. The watch app stores the decoded status in the `UserDefaults` of the App Group `group.com.cedricziel.hermesApp` (the group the phone app and its extensions already use; the iOS and watchOS containers are separate on disk) and calls `WidgetCenter.reloadAllTimelines()`. The App Groups capability must be enabled on the two App IDs in the developer portal, as for the Live Activity; fastlane's `bootstrap_app` says so.

`ComplicationStatus`, its decoding, the store and the timeline plan are in `ios/HermesWatch/Core/ComplicationStatus.swift`, compiled into the Swift package (for `swift test`), the watch app and the extension. Presentation (symbols, colours, layouts) lives in the extension only.

### Timeline and relevance

`ComplicationTimeline.plan(for:now:)` returns dated entries with a relevance score for the Smart Stack:

| Status         | Relevance | Until                              |
| -------------- | --------- | ---------------------------------- |
| waiting        | 1.0       | 30 min after the update, then idle |
| working        | 0.5       | 30 min after the update, then idle |
| ready / failed | 0.8       | 10 min after the update, then 0.1  |
| ready / failed | 0.1       | 6 h after the update, then idle    |
| idle           | 0         |                                    |

Working and waiting go idle after 30 minutes without a renewal because Hermes has no push channel: a phone app that iOS suspended cannot report the end, and a stale "Working" is worse than nothing. The phone republishes only on a change, so a turn that really runs longer stops being shown after 30 minutes. This is a documented limit.

The provider returns the plan with `.atEnd`; the watch app reloads the timelines when a status arrives.

### Deep links

Circular and corner use `widgetURL(hermes-watch://voice)`; the rectangular widget uses `hermes-watch://chat?id=<bound id>&title=<title>` when the status holds a thread id, otherwise `hermes-watch://open`. The watch app handles them with `onOpenURL` and the existing `LaunchRequests` queue, which gains a `thread` case. `VoiceChatIntent` is not reused directly: a URL reaches the same screen and works in every complication family. The title in the URL stays on the watch.

### Signing and embedding

The extension is embedded in the watch app (`Embed Foundation Extensions` phase of `HermesWatch`), SDK `watchos`, with `SUPPORTED_PLATFORMS = "watchos watchsimulator"` in every configuration as for the watch app (commit ca8346d: the project-level `SUPPORTED_PLATFORMS = iphoneos` otherwise reaches the target and the archive fails). CI's platform check covers the new target. Fastlane gets the identifier in `extension_targets`, `match_identifiers` and `bootstrap_app`. Debug and Release use the same bundle ID on iOS, as for the other extensions.

## Invariants

Touches none of auth, API layering or the telemetry rules. Telemetry: breadcrumbs only, fixed names and a `via` flag; no titles or ids.

## Risks

- The extension and the App Group entitlement on the watch app need the developer portal changes before a signed build can run; unsigned and simulator builds do not.
- A paired watch is needed to see `transferCurrentComplicationUserInfo` delivered and the Smart Stack ordering. The simulator has no phone; the widget is compile-checked and screenshotted with a seeded status.
- Two Smart Stack cards for a phone-sent reply while its Live Activity runs. Acceptable, see above.

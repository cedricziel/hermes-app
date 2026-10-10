# Design

Platforms: watchOS and the Dart relay. The receivers on iOS and macOS are unchanged.

## What the receivers accept

`HandoffActivity.parse` (`lib/src/handoff/handoff_activity.dart`) takes `userInfo` with `version == 1`, string `serverUrl` (absolute http/https, no user info, query or fragment; it is canonicalised on arrival), non-blank `profile` and `threadId`, under 3000 bytes. Both Runners' `ChatHandoff` accept an activity whose type equals the first `NSUserActivityTypes` entry of their Info.plist, `$(HERMES_HANDOFF_TYPE)`. The watch publishes exactly `{version: 1, serverUrl, profile, threadId}` with `requiredUserInfoKeys` set to the same four, type from its own Info.plist.

`threadId` is the raw session id. The watch only knows the bound id (`<profile>/<session id>`), which it treats as opaque, so the phone sends the raw id next to it as `sessionId`; the watch does not take the bound id apart.

## One definition of the activity type

`HERMES_HANDOFF_TYPE` is set to the same two values in `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` (the `.dev` suffix matches the debug bundle ID). Both now include a new `ios/Flutter/HandoffType.xcconfig`, which holds the two values (`[config=Debug]` condition), and `HermesWatch.xcconfig` includes it too. A debug watch app therefore publishes the debug type, the one the debug phone app declares. The macOS configs keep their own pair; the values must match across them.

The watch target generates its Info.plist, which cannot express an array through `INFOPLIST_KEY_*`, so a small `ios/HermesWatch/Info.plist` with `NSUserActivityTypes` is merged in (`INFOPLIST_FILE` next to `GENERATE_INFOPLIST_FILE`). The watch reads the type at runtime from that array, as the Runners do.

## Where the fields come from

`WatchRequestHandler` gets a `serverUrl` callback (`HandoffActivity.server(auth.baseUrl)` in `handlerFor`). `threads` and `messages` already know the profile they used. When either is missing or blank the fields are omitted, so the watch advertises nothing rather than something the receiver would reject.

`threads` carries them per chat because the list is what the user picks from and the watch caches it (`ThreadSummary` is `Codable`; the new optional field decodes from old caches). `messages` carries them once per answer so a chat opened from a stale or partial cache gets them when the phone answers. The watch keeps the target on its conversation model, from the list row first and the messages answer after.

## Relation to open changes

- `apple-handoff`: its "No Handoff integration SHALL run on ... watchOS" and the watchOS non-goal described the phone, iPad and Mac apps only. This change adds a watch advertiser that feeds the same receivers and changes none of their rules; when `apple-handoff` is archived that sentence should read "the Android, Windows and Linux apps".
- `live-activities`: no overlap.
- `actionable-request-notifications` / `watch-complications`: no overlap. A PR changing the send path of the relay (`watch_request_handler.dart`) may be open; this change only touches the two read answers.

## Invariants

The watch holds no tokens and never calls the address; it only passes it on. Telemetry and API layering are untouched.

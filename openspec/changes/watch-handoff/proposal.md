# Proposal

## Why

A watch chat that gets long, or that needs a keyboard, is better finished on the iPhone or the Mac. The apps already continue a saved chat through Apple Handoff, but the watch advertises nothing, so the user has to find the chat again by hand.

## What Changes

- The phone adds `serverUrl`, `profile` and `sessionId` (the raw session id) to each chat of its `threads` answer. They are left out when the phone cannot name them (no canonical server address, or no active profile).
- While a chat that has them is open, the watch advertises an `NSUserActivity` of type `HERMES_HANDOFF_TYPE` carrying the existing v1 payload (`version`, `serverUrl`, `profile`, `threadId`), and withdraws it when the chat closes.
- The watch target declares that activity type in its Info.plist, from the same `HERMES_HANDOFF_TYPE` setting the iOS and macOS apps use.
- The watch spec sentence "SHALL NOT hold tokens or the server address" becomes: the watch holds no tokens and uses the address only to pass it on for Handoff.

Non-goals:

- No change to the receivers (`lib/src/handoff`): a Mac signed in to another server still declines the chat, and the connect prompt is unchanged.
- A new chat is not advertised until the list is loaded again with it, and neither is a chat the list did not give the fields for. The `messages` answer is unchanged.
- The watch never connects to the address.

## Capabilities

### Modified Capabilities

- `watch`: the relay answers carry the Handoff fields, and the watch advertises the activity.

## Impact

- `lib/src/watch/watch_request_handler.dart` and `watch_bridge.dart` (the `threads` answer), `ios/HermesWatch` (Core models, relay decode, `ConversationView`), `ios/HermesWatch/Info.plist`, `ios/Flutter/HandoffType.xcconfig`, `HermesWatch.xcconfig` and the project file.
- Security and privacy: the dashboard address and profile name now reach the watch, which keeps them in its chat cache on the watch and publishes them to Apple's Handoff mechanism, as the phone already does. No credentials, no chat text. The title stays generic.
- Observability: None. Handoff itself has no events on the phone either.

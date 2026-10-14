# Proposal

## Why

The Live Activity for a reply sent from the iPhone already reaches the Apple Watch: watchOS mirrors an iPhone's activity into the Smart Stack. Without a layout of its own, the watch shows the Dynamic Island's compact form, which is hard to read on a wrist. ActivityKit lets an activity declare a supplemental `.small` family that watchOS (and CarPlay) use instead.

## What Changes

- The `HermesLiveActivity` widget declares `.supplementalActivityFamilies([.small])` and draws a compact `.small` layout: the Hermes icon in the state's tint, the chat title, a short state word (Working, Waiting for you, Done, Failed) and, while working, the elapsed time.
- Dart does not change. The activity already stores the title, state and start time in the App Group; the extension derives the short state word from the state.
- The docs say which turns get an activity: only replies sent from the phone.

Non-goals:

- No activity for a turn sent from the watch. ActivityKit starts an activity only while the app is in front, and a watch request wakes the phone app in the background, so the phone cannot start one. Documented, not worked around.
- No new data in the activity, no interactive buttons, no push updates, no watch complication (that is `watch-complications`).
- No change to when the activity starts, updates or ends.

Security and privacy impact: None beyond the existing rule. The small layout shows the chat title, a fixed state word and the elapsed time. No reply text, command, question or secret name, and nothing new is written to the App Group.

Observability: None. A presentation-only change in the widget extension; the activity's lifecycle crumbs (`live_activity.*`) are unchanged.

## Capabilities

### Modified Capabilities

- `live-activities`: gains a requirement for the watch Smart Stack presentation. The capability itself is introduced by the open change `live-activities`, so the delta is an ADDED requirement on top of it.

## Impact

- iOS widget extension: `ios/HermesLiveActivity/HermesLiveActivity.swift`.
- watchOS: no target change. Mirroring and the `.small` family are handled by the system; the watch app is not involved.
- Backend: none.

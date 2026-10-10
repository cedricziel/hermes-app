# Design

Platforms: watchOS only. No entitlement, manifest or Xcode project change (no new file, so no `project.pbxproj` edit).

## Chips

A `QuickReplies` view in `ConversationView.swift` lists the four constant strings in a vertical stack of compact buttons, placed in the composer area above the text field. Each button calls the same `submit`-style path as the field: `model.send(text)`. `ConversationModel.send` already ignores a call while `phase` is `.sending` or `.loading`, so the same rules hold with no Core change; the chips are also `.disabled(busy)` like the field, so they look inactive. They are hidden while recording, when the composer shows "Stop and send".

Retry after a failed send keeps working: a chip text that fails is stored as `unsent`, and "Try again" resends it.

## Double tap

`.handGestureShortcut(.primaryAction)` goes on the one primary button of the composer: "Stop and send" while recording, the microphone button otherwise. Only one of them exists at a time, so the gesture has a single target. While busy the microphone button is disabled, so the gesture does nothing, as for a tap.

## Relation to open changes

- `live-activities`: no overlap. A chip send is a turn sent from the watch, which that change already excludes from Live Activities.
- `apple-handoff`: no overlap; it concerns phone, iPad and Mac.

## Invariants

None of the project invariants (auth, API layering, telemetry) is touched.

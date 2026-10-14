# Design

## Context

Platforms: iOS (the widget extension) and watchOS (rendering only, by the system). Android, macOS, Windows and Linux are unaffected. No entitlement, manifest or Xcode project change: the extension already exists and the Runner's deployment target (iOS 26) is far above `supplementalActivityFamilies` (iOS 18 / watchOS 11).

## Relation to open changes

- `live-activities` (open, unarchived) defines the activity, its states, privacy rule, stale handling and end rules. It lists "the watch's Smart Stack (the watch mirrors iPhone activities by itself; no watch-specific layout)" as a non-goal. This change reverses only that non-goal: the watch gets a layout of its own. Everything else there stands. The new requirement is an ADDED requirement of the same capability and touches no requirement of that change, so the two archive in either order.
- `apple-handoff` (open) concerns handing a chat to another Apple device; it does not involve activities. No interaction.

## Decisions

### Use `.supplementalActivityFamilies([.small])`

The only API that lets an activity carry a watch layout. With it declared, watchOS 11+ renders the `.small` content in the Smart Stack instead of the Dynamic Island's compact presentation. The content closure reads `@Environment(\.activityFamily)` and returns a `SmallView` for `.small` and the existing Lock Screen view otherwise. The modifier only adds families to the default one, so the iPhone Lock Screen is unchanged.

### Derive the short word in the extension

The shared defaults hold `state` (`working`, `approval`, `question`, `needsYou`, `ready`, `failed`) and `label` (the notification body, too long for a watch). The extension maps `state` to Working / Waiting for you / Done / Failed. No Dart change and no new App Group key, so the stored data stays as private as it is.

### The watch cannot start an activity

`Activity.request` only succeeds while the app is in the foreground. A turn sent from the watch reaches the phone as a background wake-up, so no activity can be requested for it. Hermes has no push channel, so push-to-start is not available either. This is a platform limit and is documented in CLAUDE.md and the spec.

## Invariants

Touches none of auth, API layering or telemetry. Observability: no spans, log events or breadcrumbs. The change is presentation only, and no title, id or text is recorded anywhere new.

## Risks

- Mirroring to a watch needs a physical paired watch; the simulator does not show it. The layout is compile-checked and previewed in Xcode only, and has not been seen on a watch. CarPlay uses the same `.small` layout.

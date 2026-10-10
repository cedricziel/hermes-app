# Design

## Context

See proposal.md for motivation and specs/lock-screen-widgets/spec.md for behavior.

After `home-screen-widgets`, `ios/HermesLiveActivity` uses `ios/HermesSurfaceKit` (snapshot decoding and widget models, tested with `swift test`), `SurfaceProvider` (one timeline entry per snapshot, reloaded by the app) and the Needs you widget in small and medium. Dart's `kSurfaceWidgetKinds` lists the kinds `SurfaceSnapshotStore` reloads after each write. `deep-links` handles `hermes://new?dictate=1` by opening a new chat and starting the microphone, and `hermes://requests` by opening the oldest request's chat.

WidgetKit facts that shape the design (iOS 26 deployment target, so all are available):

- Lock Screen accessory families (`accessoryCircular`, `accessoryRectangular`, `accessoryInline`) have a single tap target: `widgetURL` only, no `Link`s.
- `systemSmall` is also a single tap target; `systemMedium` supports several `Link`s. StandBy shows `systemSmall` widgets (two side by side) on iPhone.
- Accessories render in the vibrant/monochrome mode; `widgetAccentable()` and `AccessoryWidgetBackground()` give them the system look.
- On a locked device, content marked `.privacySensitive()` is redacted; a tap asks for unlock before the app opens.

## Goals / Non-Goals

**Goals:** a glanceable count and one-tap launches that never reveal a chat on the Lock Screen.

**Non-Goals:** interactive buttons (`Button(intent:)`), which need App Intents (`app-intents`).

## Decisions

### Needs you gets more families, not a second widget

`NeedsYouWidget` lists `.accessoryCircular`, `.accessoryRectangular` and `.accessoryInline` in `supportedFamilies` next to its Home Screen sizes, so the user finds one "Needs you" in the gallery. Circular: `hand.raised.fill` over the count (`Gauge`-free, plain text). Rectangular: "Hermes", the count, and the oldest request's kind label with its chat title `.privacySensitive()`, or the redacted placeholder from `home-screen-widgets` when App Lock left the title out. Inline: "N waiting in Hermes" or "Nothing waiting". The tap target is the oldest request's URL from the snapshot or `hermes://requests`, computed in `WidgetModels` (already tested there for small).

### New Chat and Dictate as two static widgets, plus a medium pair

Without App Intents a widget cannot be configured, so each launch is its own `StaticConfiguration`: `HermesNewChat` and `HermesDictate`, each `accessoryCircular` and `systemSmall`, with `widgetURL` `hermes://new` and `hermes://new?dictate=1`. The medium Quick launch (`HermesQuickLaunch`, `systemMedium`) puts two `Link`s side by side. They read the snapshot only for the signed-out state: signed out, the label reads "Sign in" and the tap opens `hermes://new` anyway, which the app turns into its sign-in screen. URLs are built by a small Swift helper in `HermesSurfaceKit` with tests that match the `deep-links` format; they are fixed strings without a profile, so the app's current profile applies.

Alternative: one Quick launch widget configurable between New Chat and Dictate. Rejected for now; `app-intents` can replace both with an `AppIntentConfiguration` later without breaking placed widgets (the kinds stay).

### Dart side

`kSurfaceWidgetKinds` gains `HermesNewChat`, `HermesDictate` and `HermesQuickLaunch`, since they read the signed-in state, so a sign-in or sign-out reloads them. Needs you is already listed.

### Platforms and native changes

iOS only (iPhone Lock Screen and StandBy, iPad Lock Screen). `project.pbxproj`: new Swift files in the `HermesLiveActivity` target. No entitlement, Info.plist, bundle ID, fastlane, Android or macOS change.

### Invariants touched

- Tokens: none read; the snapshot holds none.
- Telemetry: no new signal; the existing `widgets.installed` counts these kinds.
- API layering, generated client: untouched.
- Tests: `swift test` for the models and URL helper; a Dart test for the reload kinds.

### Signals

None added. `widgets.installed` (from `home-screen-widgets`, `WidgetUsageReporter`) reports these kinds and families with counts only.

### Dependencies

- `home-screen-widgets`: `ios/HermesSurfaceKit` (snapshot reader, widget models), `SurfaceProvider`, the Needs you widget and `kSurfaceWidgetKinds`.
- `surface-snapshot`: the snapshot, with App Lock redaction.
- `deep-links`: `hermes://new`, `hermes://new?dictate=1`, `hermes://requests`.

## Risks / Trade-offs

- [`hermes://new?dictate=1` opens to a microphone permission prompt or an unavailable recognizer] → `deep-links` falls back to a new chat with the composer focused; the widget does not know about dictation availability.
- [Dictate on a server without speech-to-text] → same fallback; the widget label stays "Dictate", accepted.
- [Users expect the circular count to update live] → it updates when the app writes the snapshot (foreground today, `background-refresh` later); the rectangular family shows no age, the Home Screen sizes show staleness.
- [StandBy night mode tints everything red] → accessory-style rendering with `widgetAccentable()`; checked in the simulator.

## Migration Plan

Additive. Rollback removes the new widgets and families; placed ones disappear on the next install.

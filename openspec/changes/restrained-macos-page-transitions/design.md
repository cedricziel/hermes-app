## Context

See proposal.md for motivation. The installed Flutter 3.47.6 SDK maps macOS to Cupertino page transitions. Route type alone therefore does not explain the reported Material motion. Main, conversation-window, and quick-panel apps all use the shared Hermes themes.

## Goals / Non-Goals

Control ordinary macOS page pushes/pops through the shared theme, including light/dark modes and Material full-screen image viewers. Keep route settings, results, observers, and dismissal guards intact. Dialogs, sheets, and non-Material routes are separate work. Material full-screen page routes, including the attachment image viewer, follow the same stationary fade; this is appropriate for a desktop viewer and avoids a mobile vertical entrance.

## Decisions

Override only the macOS builder in the framework's transition map. Use a 150 ms opacity fade in both directions with no translation or scale. Central theme policy avoids migrating each MaterialPageRoute and preserves route behavior. Explicit route replacement would be more invasive.

Return the page directly when MediaQuery reports disabled animations. This avoids page opacity changes during reduced motion; route lifecycle completion still follows the configured short duration.

Retain SDK builders for iOS, Android, Windows, and Linux, including iOS interactive Back and Android predictive Back. watchOS does not use this Dart theme. No entitlement, manifest, or Xcode project changes.

No API contracts, token storage, or telemetry invariants change. No spans, events, or breadcrumbs are added because this is a visual policy without user-content or network operations. No new widget or Widgetbook use case is needed for a route animation builder.

## Risks / Trade-offs

- A later SDK may change other platform defaults → preserve its transition map and test iOS/Android builders against the installed SDK.
- Theme overrides supplied by callers may replace this policy → production app entry points use the shared theme; tests cover both standard modes.
- Motion is subjective → verify push/pop on an isolated macOS app and cover stationary page positions, opacity, reduced motion, interruption, and return results in widget tests.

## Migration Plan

Ship the theme override in one bounded PR after tests, review, and builds. Reverting the override restores the SDK default without data migration.

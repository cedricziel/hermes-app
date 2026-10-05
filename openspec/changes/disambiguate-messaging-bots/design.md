## Context

`HermesBot` is a messaging platform, `HermesBotsRepository` reads `/api/messaging/platforms`, and the chat sidebar routes “Bots” to that settings screen. See proposal.md for the release sequence. The existing `profiles-and-bots` specification owns this behavior.

## Goals / Non-Goals

Goals: Establish distinct vocabulary in user flows and internal interfaces before adding named agents.

Non-goals: No platform configuration migration or new API behavior.

## Decisions

Use “Messaging” for navigation and “messaging platform” for generic copy. “Messaging bots” would remain technically accurate but is longer in the compact sidebar and keeps two destinations named Bots.

Rename the messaging feature directory to `lib/src/messaging/` and its types to `HermesMessagingPlatform`, `HermesMessagingRepository`, `MessagingScreen`, and `MessagingSetupScreen`; repository composition uses `messaging`, and sidebar callbacks use `onOpenMessaging`. Telegram pairing stays in the same feature with its existing name. Rename rather than add compatibility aliases because these are internal application APIs. Keep upstream route names unchanged.

Preserve all scenarios in modified requirements, changing only their messaging terminology. Widgetbook and workflow expectations must match the new screen before navigation is wired.

Platforms: iOS, Android, macOS, Windows, and Linux share these labels; watchOS has no management screen. No native entitlement, manifest, Xcode, or dependency change.

Invariants touched: Generated REST client remains the API boundary; Telegram tokens stay on the server; saved credentials remain redacted. Telemetry remains opt-in and emits no new events.

## Risks / Trade-offs

[References retain old names] → Search production code, tests, catalog, README, and CLAUDE.md; compile and run the complete suite.

[The combined capability name is historical] → Keep its path for stable delta application; clarify its Purpose when syncing the release changes.

## Migration Plan

Ship this small PR first (`refactor(messaging): distinguish platform connections from bots`). It is compatible with current servers. Rollback is an application revert; no server data changes.

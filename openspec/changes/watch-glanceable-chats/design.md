## Context

See proposal.md for motivation. Observed source: lib/src/watch/watch_request_handler.dart, ios/HermesWatch/Core/Models.swift, ChatCache.swift, ThreadListModel.swift and ThreadListView.swift.

Main Watch thread list has title/time/pin only. Surface-snapshot carries request kind and profile but forbids request details; reuse metadata without expanding that contract. Connection identity is owned by reliability.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Cross-device unread synchronization, changing server chat order or 20-thread cap, watch profile switching, continuous polling.

## Decisions

Extend threads response with activeProfile and fetchedAt, plus optional known per-thread status. Prefer already available current phone state and pending metadata; fetch session.active_list only where needed and within a bounded refresh budget. Do not derive idle from missing status. Keep the current profile list and 20-thread cap. Track seen updatedAt locally within the identity-scoped cache; first observation establishes a baseline, successful fresh message loading marks the current thread seen. This means Updated on this watch, not a cross-device unread guarantee. A cached row can retain last-known status but must label it saved. Show cached fetchedAt, not newest message time, as freshness. Old peers omit optional fields; labels fall back to unknown profile/status/time instead of fabricated values.

### Platforms and project configuration

watchOS and paired iOS only. Android, macOS, Windows, and Linux behavior remains unchanged. No new entitlement or manifest requirement is planned. New native files, if introduced, must be added to the existing Xcode target and Swift core package when portable.

### Invariants and diagnostics

Preserve secure token storage, concurrent-401 behavior, generated-client REST layering, and opt-in fail-safe telemetry. Existing Dart watch.request.started/completed events record fixed operation, authentication state, result, and duration; native watch logs record operation, numeric delivery error, and result. Expand the operation allowlist only for this change's new relay operations. No new spans are needed beyond existing timed relay work, and no UI breadcrumbs are exported. No signal contains user content, request ids, titles, profile names, tokens, audio, or server addresses.

### Native UI verification

SwiftUI is not a Flutter widget, so Widgetbook cannot host these screens. Add deterministic DemoClient/native preview fixtures before wiring screens, including loading, failure, old payload, large text, and VoiceOver states. Use the project verify-in-app throwaway backend for the iPhone relay and the watch-native-verification change for paired watch exercise. Never use production credentials, real agent commands, or inherited user data.

## Risks / Trade-offs

- Phone suspension can delay relay results. Preserve recovery/fallback controls rather than assuming completion.
- Small displays can obscure actions. Validate long content, maximum text, and VoiceOver on the smallest supported watch.
- Existing unarchived deltas overlap the main watch spec. Reconcile the named baseline before archive and apply dependent changes in order.

## Migration Plan

Depends on watch-context-identity cache invalidation. Known waiting status depends on reliable pending-turn correlation, not on inline request details. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

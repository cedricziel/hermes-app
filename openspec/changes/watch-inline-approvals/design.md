## Context

See proposal.md for motivation. Observed source: lib/src/watch/watch_request_handler.dart, lib/src/notifications/request_answers.dart, lib/src/chat/gateway/hermes_gateway_transport.dart, ios/HermesWatch/Core relay models and ConversationView.swift.

Main phone-only request requirement is stale for waiting. Reliability reconciles it; this addition explicitly permits transient approval details only after the phone's security gates. Surface-snapshot privacy remains unchanged. Request-intents already defines offered choices, confirmation, and shared answering behavior; reuse those semantics.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Secret/sudo answers, arbitrary Yes/No chat text as approval, adding or broadening approval choices, snapshot command storage.

## Decisions

Add watch relay request-details and answer operations bound to connection, profile, thread, and request identity. Reuse RequestAnswerSender readiness/App Lock checks and HermesGatewayTransport.answerOpenRequest instead of prompt.submit. Check locks again immediately before answering. Fetch current state before display and revalidate before answer; do not trust cached choices. Affirmative choices require a confirmation sheet showing full command and exact choice. Deny remains immediate. Request details remain transient; never put commands into ChatCache, surface snapshot, notifications metadata, or telemetry. Keep snapshot pending records as kind/id only. Unknown or oversized request details provide an iPhone fallback and no answer action. Cap the relay payload below its safe WatchConnectivity limit; do not silently truncate a command and then permit approval.

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

After watch-request-guidance, watch-session-privacy, watch-context-identity, and `watch-send-recovery`. Inline questions reuses this relay foundation. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

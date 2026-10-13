## Context

See proposal.md for motivation. Observed source: ios/HermesWatch/ConversationView.swift and native fixtures.

Main Requests the watch cannot answer says a send completes and closes the request socket. Current code already preserves approval/question waiting and notifications. Reliability owns that baseline reconciliation; this change adds wording to the existing waiting implementation, and requires that reconciliation before archive.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Programmatically opening notification UI, inline answers, backend cancellation.

## Decisions

This is the immediate UI-only stage. Keep the existing polling and request kind but explain notification actions accurately without claiming the watch can programmatically open a notification. Show "Answer in the Hermes notification, or open Hermes on your iPhone." Show "Leave waiting view" with "Hermes will keep waiting for your answer." The action leaves local polling; it does not cancel or deny anything. Composer remains disabled for a pending request. Inline structured handling arrives in later changes. No new relay fields are required.

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

Depends on watch-conversation-usability and `watch-send-attempt-isolation`; reconciles actionable-request-notifications before archive; inline approvals/questions supersede notification-only handling later. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

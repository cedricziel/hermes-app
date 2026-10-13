## Context

See proposal.md for motivation. Observed source: ios/HermesWatch/ConversationView.swift and Core/ConversationModel.swift.

Main Sending from the watch removes failed outgoing text and offers Try again. The implementation also keeps accepted messages after waiting failures. Replace the former with explicit visible delivery and recovery state, retaining acceptance distinctions.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Server cancellation, infinite chat history, automatic resend, cross-device draft synchronization.

## Decisions

Use stable message anchors and distinguish whether the user follows the active turn or has scrolled into history. Reveal the answer start instead of the composer for a followed turn. Keep the existing non-lazy stack because the source documents long-message height errors with a lazy stack. Model outgoing delivery explicitly: definitely not sent, acceptance unknown, accepted awaiting reply, and failed final turn. Retry must use the reliability change's identity/recovery action; Edit never reuses an old send identity and cannot become enabled until an uncertain acceptance is resolved. After Check result still reports uncertain, a separate Send again action explains duplicate risk and requires confirmation before issuing a new identity. It does not convert the original uncertain send into a definitely unsent draft. Discard removes only the local draft and never implies cancelling server work. Accepted outgoing messages stay in history. Do not introduce a second send policy in the view.

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

Depends on `watch-send-journal`, `watch-send-recovery`, and `watch-send-attempt-isolation` for delivery identity, uncertain outcomes, and recovery. Reading-position work is independent of a server upgrade. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

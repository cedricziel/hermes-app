## Context

See proposal.md for motivation. Observed source: lib/src/watch/watch_request_handler.dart, lib/src/chat/gateway/hermes_gateway_transport.dart, ios/HermesWatch/Core relay models and ConversationView.swift.

The active notification-inline-reply change submits ordinary chat prompts with queued:true; it is not a question answer path. Existing actionable-request notifications and question transport provide qid-based answering. Surface-snapshot pending entries cannot supply question text or choices and remain content-free.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Secret/sudo values, invented options, generic chat Yes/No answers, atomic all-questions backend contract.

## Decisions

Extend request-details to questions containing qid, prompt, choices, multiSelect, and batch. Empty choices identify open-ended input in ClarifyQuestion; no arbitrary text option is added to fixed choices. Single-question answers use QuestionAnswer and answerOpenRequest. Batch answers use the existing owning transport answerClarify path, which uses clarify.lock for one qid, not request.answer. Keep the owning live request context and show explicit question progress. The checked-in OpenRPC contract documents editable early locks until every question is locked; do not treat the first lock as request completion. If owning batch context cannot be restored safely, fall back to iPhone instead of submitting through a new generic answer path. Preserve completed questions and fetch current liveness before each next answer. Draft selections/text stay transient. For details unavailable after process restart, offer notification/iPhone fallback rather than inventing a question enumeration RPC. Reuse approval relay gates and bounds. Display all offered choices in a scrollable list, never silently answer a truncated list.

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

Depends on watch-inline-approvals relay foundation and watch-session-privacy, watch-context-identity, and `watch-send-recovery`. Contextual-actions delegates active questions to this structured view. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

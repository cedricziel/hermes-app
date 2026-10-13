## Context

See proposal.md for motivation. Observed source: ios/HermesWatch/VoiceRecorder.swift, ConversationView.swift, Core/ConversationModel.swift and their native fixtures.

The completed watch-quick-replies delta requires stop-and-send on double tap. This change replaces that gesture behavior with stop-and-review by default. Main watch lacks voice details; the current recorder and sendVoice path are the implementation baseline.

## Goals / Non-Goals

Goals: Use the existing phone relay and a bounded native UI change.

Non-goals: Streaming dictation, conversation voice mode, audio playback, persistent or cross-device drafts.

## Decisions

Separate transcription from command submission. Keep the transcript and temporary audio in memory for the current conversation, not preferences or cache. Add a recording termination reason so only an explicit manual stop can use fast-send. A double tap stops recording and starts transcription; in review mode it does not submit. Show elapsed time against the existing 30-second cap. A failed transcription keeps the audio for Retry or Discard. Empty speech offers record again. Explicitly leaving the conversation discards the draft and cancels transcription; late transcription cannot submit. Watch sleep or an audio interruption keeps the stopped recording available for review while the conversation remains alive. Process termination discards the draft. This bounds sensitive storage without adding draft synchronization.

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

Implement after privacy reset and attempt guards. Adopt the watch-native-verification change for interruption, sleep/wake, and late transcription. Ship as one bounded PR near 500 changed lines; keep later features in their separate changes. Optional relay additions may degrade only after the mandatory context-identity protocol handshake succeeds; incompatible identity protocol peers must follow watch-context-identity update-required behavior. Roll back the feature UI without deleting accepted messages or changing backend state.

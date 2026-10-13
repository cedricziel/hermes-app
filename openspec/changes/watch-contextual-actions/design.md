## Context

`ConversationView.swift` currently renders Continue, Yes, No, and Summarize whenever the recorder is idle, even before the first message. Its busy flag disables the same chips during real questions. The completed `watch-quick-replies` delta defines this behavior, while `watch-voice-review` replaces the stop-and-send gesture with review by default. See proposal.md for scope.

## Goals / Non-Goals

Goals: Make built-in actions fit the conversation state and route request answers through the existing structured paths.

Non-goals: Add custom favorites, synchronize configuration, infer approvals from ordinary reply text, or generate suggestions on the server.

## Decisions

Use a deterministic context selector. An empty new chat with an empty composer offers Plan my day and Explain something. These populate "Help me plan my day." and "Help me understand this topic: " respectively and focus the editable composer. No starter submits immediately. These exact initial texts are bounded product-copy choices, not a server contract. Existing composer text or a voice draft suppresses starter replacement so tapping an action cannot silently overwrite user work.

After a successful completed assistant reply, offer Continue and Summarize while idle. A tap submits the fixed text through the regular model send path, so delivery identity, failure recovery, and duplicate-risk handling remain centralized. Hide generic Yes and No. During a pending approval or question, show its structured request view and offered choices rather than ordinary follow-ups. Unknown or unsupported pending request kinds retain the phone fallback without fabricated options. Loading, sending, transcribing, recording, and unresolved delivery suppress ordinary actions.

Keep double tap from the complete watch-voice-review predecessor unchanged: idle starts recording, an explicit stop follows the selected review/fast-send mode, and automatic termination always reviews. In an editable voice review draft, the primary action remains the explicit Send control; an unrelated follow-up cannot replace it.

### Platforms and project configuration

watchOS only, using the paired iOS relay unchanged. Android, macOS, Windows, and Linux remain unchanged. No new native entitlement, manifest, dependency, or Xcode capability is needed. A new portable selector file must join the native watch target and Swift core package when introduced.

### Invariants and diagnostics

Preserve secure storage, authentication, context binding, generated-client layering, and opt-in fail-safe telemetry. No new REST or gateway operation is introduced. Existing relay events retain fixed operation, authentication state, result, and elapsed time without text, audio, titles, profile names, tokens, addresses, or identifiers. No extra spans, log events, or breadcrumbs are proposed for UI selection.

### Native UI fixtures

Add DemoClient or native SwiftUI fixtures before screen wiring for empty chat, typed draft, voice draft, completed answer, failed turn, pending approval, single and multi-select question, unsupported request, and uncertain delivery. SwiftUI cannot be hosted in Flutter Widgetbook. Exercise large text and VoiceOver with the `watch-native-verification` checklist and isolated `verify-in-app` relay setup.

## Risks / Trade-offs

- Built-in starter wording may be too broad. Insert editable drafts so users can specify the task before sending.
- A stale view can display an action after the state changes. Recheck the current model state before submission and let the existing send guard reject invalid actions.
- Concurrent spec successors can overwrite gestures. Apply and archive `watch-voice-review` before this full replacement of Quick replies and double tap.

## Migration Plan

Apply after `watch-voice-review`, `watch-conversation-usability`, `watch-inline-approvals`, and `watch-inline-questions`. Rollback restores the preceding chips without changing stored messages or request outcomes. Keep implementation in one PR near 500 lines; there is no custom configuration or migration.

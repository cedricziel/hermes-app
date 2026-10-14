## Context

`ConversationModel` keeps `unsentId` and `keptMessage` only in memory. A normal send failure can remove the outgoing message even if submission was accepted before the transport error. Existing error controls offer Try again without expressing delivery uncertainty.

Platforms: watchOS native UI and core; iOS journal capability dependency. macOS hosts Swift tests. Android, macOS product UI, Windows, and Linux are unaffected. Add protected outbox source membership to the watch target if necessary; no new entitlement or shared group.

## Goals / Non-Goals

Goal: distinguish status lookup from deliberate new submission across process lifetime.

Non-goal: redesign outgoing rows or scrolling. `watch-conversation-usability` follows this change and consumes its states.

## Decisions

Add a small protected pending-send store and explicit recovery states to core. Persist text, identity, context/revision, original profile/target, local message ID, original createdAt timestamp, and last known delivery state before transport work. Update bound thread information as valid responses arrive. Exclude the outbox from backups and use watchOS file protection. Keep tokens and raw server URLs out of outbox records; Handoff metadata remains in the existing context-scoped cache rather than duplicated here.

Keep the same ID for every Check result. A fresh launch establishes the current context and capability before status lookup. Ordinary auth restoration unavailable retains the current pending record; confirmed logout/context departure invokes privacy purge. If deletion fails, apply the privacy tombstone so retained bytes cannot be reloaded, and reject late writes for invalidated context generations. The current context/revision must match on every success before any result is accepted. Scope revisions survive ordinary phone restart and token refresh.

Use `recoveryState` pending, uncertain, or not_sent from `watch-send-journal`. Only its saved completion or the original still-owned live completion finishes the send. Suppress duplicate completion using the persisted local send identity. Do not infer delivery from a Swift error or synthesize an assistant bubble for a working placeholder. Preserve existing approval/question waits and local Stop waiting guards.

Introduce base Check result, Open chat, and confirmed Send again controls in the existing error area. Provide DemoClient fixtures and SwiftUI previews before wiring controls; Flutter Widgetbook cannot render this native watch screen. Enable uncertain Send again only after Check result was attempted in the current context. Uncertain Send again and edited-send submission show a concise confirmation explaining possible duplicate execution. Confirmation creates a fresh ID, persists its new pending record, and starts one attempt. Cancel preserves the original. Keep the old uncertain ID available until explicitly discarded or replaced so its status cannot accidentally be treated as a fresh send. Rich outgoing rows and automatic reading-position changes belong to the following usability change.

Bound outbox storage consistently with the phone journal. Keep at most 100 pending records per context; refuse new sends when full rather than deleting unresolved records. Completed or discarded records can be removed after their terminal state is persisted. Forget recovery removes the local record and asks the phone to release a detached record through a context-valid `forgetSend` relay request carrying sendId; it never cancels server work. The phone retains unexpired dispatch tombstones. A disconnected forget remains local until the phone record expires. Document actionable capacity recovery rather than permanent full-state lockout. Local Stop waiting remains local; the user can resume status lookup later with the retained ID.

Project invariants: no tokens in ordinary files, no new REST calls, and no content in diagnostics. Log local recovery actions in the watch Apple logger using fixed `action` values check_result or resend_confirmed and fixed `outcome` values only. No IDs, context, revision, text, profile, URLs, or exception messages. Existing phone request diagnostics supply boundary timing; no extra spans or breadcrumbs.

## Risks / Trade-offs

- A pending file increases watch-side private storage. Protected files, backup exclusion, purge, and tombstones limit exposure.
- The user may deliberately run a command twice after confirmation. Explicit confirmation preserves that choice while avoiding silent replay.
- A phone without the capability cannot provide safe recovery. Refuse unsafe replay and request an update.
- A completed result may be lost before the phone persists it. Keep uncertain state and offer ordinary history navigation.

## Migration plan

Implement after journal, attempt isolation, privacy, and context identity. Do not migrate unscoped legacy pending records into the current owner. Ship before conversation-usability and request-guidance changes. Keep native fixtures in the isolated verification procedure from `watch-native-verification`. Rollback must never reinterpret persisted uncertain attempts as new sends.

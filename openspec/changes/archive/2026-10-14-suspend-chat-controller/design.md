## Context

See proposal.md for motivation. ChatController already uses generations for thread loads and opens, while commands and answers often check only disposal. ThreadSearch and ThreadHousekeeping own their own asynchronous work. ChatTransport remains stable and is renewed by the session owner before activity resumes.

## Goals / Non-Goals

Provide one optional ValueListenable activity input, defaulting to active for existing callers. Keep owner verification and transport replacement outside the controller. This change does not establish retained UI safety for other route families.

## Decisions

Use an activity epoch alongside existing load/open/per-thread generations. Capture epochs before every asynchronous operation and reject stale continuations both during suspension and after recovery. A boolean check alone permits old work to mutate newly resumed state. Gate command entry before local mutation, cancel reply/follow-up/search/settle/replay resources synchronously and invalidate sidebar work.

Read the activity signal directly at entry because an earlier listener may call the controller or its sidebar helpers before the controller observes the pause. Every delivered activity notification invalidates work and suspends child resources, including when a reentrant resume hides the intermediate false value. Schedule reconciliation after notification delivery and fence it by epoch, so an earlier nested recovery cannot start another stale reload. Recheck the original epoch or generation after external callbacks and state notifications before protected requests, draft delivery, or announcements.

Check the captured activity epoch after publishing undo state and before dispatching the backend undo. Check both the captured epoch and original opening generation after inserting a fetched target and before selecting it. A synchronous pause and resume cannot turn either retired operation into fresh authorized work.

On resume reload the existing profile, validate it when profiles are available, preserve local unsent threads, and reselect/refetch the prior server thread when valid. Submitted and queued prompts are never replayed automatically. Retaining existing controllers without a reload would keep stale server state.

Recover every queued remote target absent from the first page through the existing session detail route. Remap each queue to its refreshed thread. If the target is missing or unreadable, retain the queued prompt objects in a paused local draft with the settled messages. The local draft remains unbound, so an explicit send creates a new session. If the former profile no longer exists, retain its queues as local drafts with distinct IDs. A session with the same ID on another profile must not inherit those queues.

For an unbound local conversation, capture pending replies whose send stream has already stopped when reconciliation starts. Remove only those still-pending replies when publishing recovered state. Keep the local thread object, settled messages, and queued prompts, so explicit queue submission can create a new session. A fresh send started after authorized resume remains intact while reconciliation waits. No submitted or queued prompt is sent automatically.

Resample local threads, queues, and selection immediately before publishing reconciliation. A queue or local conversation can be created while session, launch, or recovery lookups wait. Recover newly queued remote targets until all current targets are covered, then remap the current queue lists rather than earlier copies. Preserve active same-profile thread objects over stale session rows so their fresh sends remain attached. When the profile changes, queued remote targets still become unbound drafts with distinct IDs.

Track the target, prompt, and `fetchMissing` flag of an external opening until it finishes. Suspension moves that metadata into an interrupted slot, clears the pending automatic tap replay, and releases the `_opening` wait barrier. `takeInterruptedOpening()` consumes the slot only while activity is active. Recovery alone does not select that external target or deliver its draft. The session owner takes and requeues the intent only after sign-in dismissal, verified recovery, and arbitration with newer intents. A newer explicit `open()` supersedes the interrupted slot. Completion of the retired HTTP request cannot block a fresh `newThreadWhenOpened()`.

## Risks / Trade-offs

Already-dispatched requests can finish remotely. Reconciliation replaces server state and does not infer that a prompt is safe to repeat. The session owner must renew the transport before opening activity. Local composer text and files remain the mounted screen's responsibility.

The optional activity listenable does not prove account identity or dismissal. The owner must verify same-account recovery and replace the transport before setting it active. Controller tests cover retained metadata and suppressed delivery. They do not establish the owner's intent arbitration, retained UI behavior, or native notification behavior.

## Platforms and invariants

Shared Dart behavior affects iOS, Android, macOS, Windows and Linux; watchOS is indirectly affected through the phone. No native entitlement, manifest or Xcode changes. Generated API layering remains unchanged. Tests use FakeHermesServer through the generated client for repository contracts, with controllable transport streams for lifecycle behavior. No new spans, events or breadcrumbs are added; existing chat breadcrumbs contain counts, flags and outcomes only, without user content.

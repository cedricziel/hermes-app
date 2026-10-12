## Context

See proposal.md for motivation. `ComposerDictation.refresh` currently fences disposal, profile, and engine changes but lacks a suspension epoch. `DictationController.cancel` invalidates transcript settlement before awaiting microphone shutdown, but draft restoration waits for its eventual idle notification. Recorder acquisition can also finish after cancellation.

## Goals / Non-Goals

Goals: synchronous draft restoration and activity fencing, bounded cleanup of delayed acquisition, and fresh capability checks on externally authorized resume.

Non-goals: proving session ownership, changing native voice APIs, new widgets, or retaining the navigator. Platforms affected: Flutter iOS, Android, macOS, Windows, and Linux. watchOS is unaffected. No native entitlements, manifests, or Xcode files change.

## Decisions

Both composer and recording controller accept an optional `ValueListenable<bool>`; absence means active. The composer tracks refresh epochs and clears capability availability while suspended. The controller checks activity and run identity around awaits and callbacks. Its acquisition and microphone close guard prohibit a new run while the old global recorder resource is unresolved; a stale acquisition is closed before that guard is released. Merely checking activity after acquisition would allow an old completion to close a newer microphone.

Restore the original `TextEditingValue` immediately when activity closes, then let recorder shutdown proceed asynchronously. If another writer changed the field during dictation, preserve that writer's value under the existing draft rules. Waiting for microphone shutdown would expose provisional text to retention snapshots.

Resume performs support refresh only. Session ownership proof remains the external coordinator's responsibility. Existing generated-client API layering, content-free telemetry, and secure token storage invariants remain intact. Existing `voice.dictation.ended` cancellation breadcrumbs come from the controller and carry only engine, outcome, and optional path; no added spans or log events.

Settlement listeners can synchronously pause and resume activity before transcript insertion. Recheck the run after those listeners return and record a cancelled completion when it was invalidated. The existing stop-and-send helper must not treat a discarded transcript or silence result as permission to send the restored typed draft.

Lease cleanup captures the acquisition's profile and waits for that acquisition before release. A transient pause retains cleanup without sending authenticated traffic. Authorized resume flushes pending releases before a new acquisition. Controller disposal does not itself revoke credential authorization, so ordinary active disposal still releases immediately. Inactive disposal transfers pending cleanup to the session owner and removes the controller's activity listener.

The generated OpenAPI client and the local backend's `tools/stt_lease.py` specify no lease TTL. The backend keeps lease names in a process-local set until explicit release or process termination. `stt.local.unload_after_idle_seconds` controls cached model eviction separately. Permanent authorization loss therefore prevents a guaranteed remote release; cleanup must never use another owner's credentials.

## Risks / Trade-offs

- Already dispatched uploads or model installations cannot be recalled through their existing APIs → ignore late results and prevent new work while inactive.
- Slow recorder acquisition or close temporarily prevents another explicit start → keep the global resource serialized until cleanup completes.
- Full retained-route behavior depends on shell wiring → verify it separately in the integration slice.
- Inactive widget disposal requires owner-held cleanup → expose pending cleanup for the integration slice to retain and release only under the original session's authorization.

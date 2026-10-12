## Context

See proposal.md for motivation. The root queue keeps only the latest navigation callback. ShareController identifies initial delivery while listeners run, separately accumulates text/files, retains the latest quote, and consumes items only through take().

## Goals / Non-Goals

Do not consume payloads or mutate chat/composer/attachments until dismissal and lock checks permit delivery. Retain superseded payloads for a deliberate Chat entry. Keep existing standalone Chat behavior, quote formatting, and sending behavior. No new widgets or catalog cases are needed.

## Decisions

Queue a callback that reads ShareController at delivery time, rather than capturing and consuming each arrival. Several arrivals can replace the callback without losing content. If newer navigation replaces it, the inbox remains pending.

Give ChatScreen an explicit section-entry revision from the shell. Increment it on user selection of Chat, including repeated selection. On that revision, schedule guarded delivery of any pending share. The host validates the captured entry revision and invalidates recovery when later section selection or external navigation arrives, so a deferred frame cannot overtake newer intent. External notification/link selection does not count as a deliberate recovery entry. Reuse the existing host queue and mounted checks; a disposed shell leaves untaken items in the controller.

Defer initial held-share delivery until a frame gives the host a usable navigator. Mark initial-inbox notifications as launch requests so they yield to newer navigation. Place late initial items before accumulated warm items, retaining the newer waiting quote. Standalone Chat still absorbs initial items normally. Retain the existing quote behavior after delivery; its existing new-chat completion checks remain covered by quote tests.

All Flutter platforms are affected: iOS, Android, macOS, Windows, and Linux. watchOS has no shared-content path here. No native project changes. API layering and telemetry privacy invariants remain unchanged. The existing chat.share.quote breadcrumb carries only a held flag and is emitted at delivery.

## Risks / Trade-offs

- A retained payload could wait indefinitely if the user never re-enters Chat → this is the confirmed conflict policy; do not consume or silently drop it.
- Build-time navigation from section revision changes → dispatch after the frame and recheck mounted/pending state.
- Replaced callbacks or disposal could duplicate delivery → take() occurs only inside the accepted callback; integration tests assert exact payload contents and once-only delivery.

## Migration Plan

Deliver after the notification-queue change. Existing inbox formats and backend contracts require no migration. Revert the dispatch wiring to roll back.

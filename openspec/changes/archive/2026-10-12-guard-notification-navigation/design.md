## Context

The root navigation queue from #646 protects deep links. Warm notifications enter ChatScreen; launch targets are consumed separately inside ChatController while loading threads. Both currently mutate selection or publish requests before route dismissal. See proposal.md for scope.

## Goals / Non-Goals

Reuse the queue for notification work before any target is applied. Preserve standalone ChatScreen and ChatController behavior when no host queue exists. No new presentation widget or catalog use case is needed; existing editors and confirmations are unchanged.

## Decisions

Add an optional host callback that accepts deferred notification work. AppShell runs that callback only after guarded routes have closed and App Lock allows navigation. ChatScreen keeps the existing direct handler as the standalone fallback.

Add an optional launch-target callback to ChatController and use it in ChatScreen so initial notifications cannot select a chat before the host accepts them. Keep the controller's existing standalone fallback. A warm-tap flag and accepted-request generations in ChatScreen preserve newer intent. Launch work carries its origin to the host, and the queue rejects it after any earlier explicit request or cancellation. The host checks acceptance before clearing availability-held payloads. Existing controller pending-tap behavior remains.

Factor the root queue accessor and use it for notification/job work and deep links. New external requests invalidate older availability-held links/jobs, so a delayed server check cannot resurrect an older intent. Keep job availability waiting while unknown, but ignore a confirmed unavailable schedule destination. Resume the queue on unlock even when no DeepLinks provider exists.

Platforms: iOS, Android, macOS, Windows, and Linux. No watchOS or native entitlement/manifest/Xcode changes. Authentication, API layering, and generated contracts remain unchanged. The queue cannot deliver while covered or after disposal; session/profile matching remains the existing notification contract.

## Risks / Trade-offs

- Cold launch is asynchronous and can resolve after a warm tap. Test the ordering explicitly.
- Notification delivery can occur before thread loading finishes. Preserve the existing held-target path rather than inventing another loading queue.
- Availability and App Lock can change while an editor is open. Recheck them at delivery and resume only after unlock.
- Sharing remains a separate accumulator. Do not migrate or discard its payloads in this slice.

## Observability

AppShell records `nav.notification.ignored` only for confirmed unavailable schedule targets, with kind/job and reason/unavailable. Existing chat/destination breadcrumbs run on accepted delivery. No user content, spans, or new log events are added.

## Migration Plan

Add warm-tap regressions, wire the host queue, add cold-launch ordering regressions, then wire launch delivery. Verify existing no-fetch, profile, prompt, and scheduled-job tests. Merge after required checks and isolated review when CodeRabbit is limited.

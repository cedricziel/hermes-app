## Context

See proposal.md for scope. AppShell publishes deep-link chat requests synchronously, and ChatScreen immediately consumes them. Existing editors use PopScope with asynchronous discard confirmation; a successful maybePop result does not establish that the route closed.

## Goals / Non-Goals

Unwind routes serially and publish the latest link only after reaching the shell. Keep existing editor confirmations and completion behavior. This first slice does not migrate other external entry points.

## Decisions

Use a reusable navigation queue that reads the current top route, asks maybePop, and waits for that route's popped future. New requests replace the pending callback while the route remains open. Await cancellation on disposal as well, so authentication teardown cannot deliver stale work. A raw popUntil reset is rejected because it bypasses guards; maybePop without waiting is rejected because dirty-route confirmation is asynchronous.

After the stack clears, re-enter the existing deep-link availability and App Lock checks before publishing any chat request. Retain kind/cold/waited breadcrumb attributes and mark a guard-delayed request as waited. Links arriving during App Lock continue using DeepLinks' existing pending slot; a newer held link supersedes an older queued link on unlock.

Platforms: iOS, Android, macOS, Windows, and Linux. No watchOS, entitlement, manifest, or Xcode project changes. No backend contract or minimum Hermes version changes. Authentication storage and API layering remain unchanged.

## Risks / Trade-offs

- A user choosing Keep editing leaves the latest link pending until the route closes. This preserves the payload without repeatedly prompting.
- Busy routes can remain open indefinitely. Wait for explicit route completion and never force dismissal.
- Several links can arrive during a confirmation. Keep one queue worker and deliver only the latest request.
- The app can lock or a destination can disappear while waiting. Recheck those conditions at delivery.

## Observability

Existing breadcrumbs remain in AppShell's delivery handler. They contain fixed kind and boolean flags, never user content. No new span or event is required.

## Migration Plan

Add regressions, add the helper, migrate deep links, and verify existing workflows. Roll back the isolated commit if necessary. A later PR can reuse the helper for notifications and sharing.

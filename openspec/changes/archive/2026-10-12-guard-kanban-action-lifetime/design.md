## Context

See proposal.md for the motivation. `runKanbanAction` captures a `ScaffoldMessenger` before it awaits the action, then reports any failure through that messenger. A pending action can outlive the widget that supplied the context.

## Goals / Non-Goals

**Goals:** Preserve visible errors for mounted callers and suppress late snackbar presentation after disposal. Give Quick Look tests an explicit signal that its asynchronous preview reached the fake platform boundary.

**Non-Goals:** Cancel requests, change snackbar text, alter successful action behavior, add telemetry, or change native code.

## Decisions

- Check the invoking context after an action fails and before showing the snackbar. Return the existing failure result when the context has been disposed.
- In tests, expose a completion future from the fake Quick Look implementation. Await that future after a gated attachment fetch so assertions run after the action has advanced beyond download and file staging. Pump the widget after the signal to process its queued continuation.
- Keep the regression test at the widget boundary. Unmount only the caller while retaining its `ScaffoldMessenger`, then fail the pending action and assert that the action returns its normal failure result without raising a snackbar assertion.

The existing Hermes API routes and response shapes remain unchanged. The shared Flutter error handler applies to iOS, Android, macOS, Windows, and Linux; watchOS relay behavior is unchanged. No platform-specific code, entitlements, manifests, or Xcode project files change. The change adds no spans, logs, or breadcrumbs because it reports no new outcome and changes no user journey signal.

## Risks / Trade-offs

- A failure that arrives after its caller closes is no longer shown in that screen's snackbar. The screen no longer exists, and showing there would raise an assertion. The action still returns failure to its caller.

## Migration Plan

No migration is needed. Reverting the context check restores the prior failure behavior.

## Verification record

The late-error regression failed before the guard with a missing-Scaffold assertion while its messenger remained mounted. The final suite passed 15 tests, covering both typed plugin and generic errors after disposal and the Quick Look completion handshake. Scoped analysis, formatting, strict change validation, and diff checks passed. This change alters error ownership without changing presentation; no new catalog content is needed. Native interaction remains unverified.

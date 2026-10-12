## Context

The job controller owns execution independently of the status route. Closing the view sets `sheetOpen` false and dismisses only a completed job; running jobs continue. The shared macOS dialog policy from PR #674 supplies stationary motion, reduced motion, captured themes, and keyboard traversal.

## Goals / Non-Goals

Change the status route on macOS while preserving job progress, result reporting, and background execution. Keep non-macOS bottom sheets and existing Skills grouped components. Other feature migrations and authentication lifecycle changes remain separate.

## Decisions

Use the shared dialog policy for a constrained, scrollable macOS job view at every width; retain the existing mobile route and drag handle elsewhere. Reuse the job content rather than replacing the job controller or duplicating execution. Provide sufficient top padding and scrolling for long log lines, increased text scale, and small windows. Keep result cleanup in the existing completion path regardless of dismissal method.

Add catalog running/succeeded/failed/unknown states before screen wiring. Test the actual route and controller behavior through the generated HTTP client and FakeHermesServer where backend behavior is involved; direct SkillJob fixtures are sufficient for standalone content.

Platforms: macOS route presentation changes. iOS, Android, Windows, Linux, and watchOS remain unchanged. No entitlement, manifest, Xcode, dependency, or generated API change.

Project invariants: closing progress does not cancel a server job or dispatch another operation, failures and unknown results never claim success, and API calls continue through the generated client. No new telemetry is needed for this local presentation change, so no span, log event, breadcrumb, or content attribute is added.

## Risks / Trade-offs

A long log or enlarged text can overflow a centered dialog; constrain and scroll the content, then test small windows and scale. A route change could clear a running job or lose result reporting; retain controller completion semantics and regress background completion. Widget/catalog verification does not establish native device behavior; record its limits.

## Verification record

The compact Mac regression failed against the old bottom-sheet route. The final Skills job/controller/HTTP/caller suite passed 75 tests, including six new route/readability tests. Generated-client tests cover closing a running job, subsequent completion, and completed-job cleanup on macOS, iOS, and Android. Long logs at text scale 2 remain scrollable with a visible footer at 390 by 400; short status views fit their content. All 48 catalog platform/theme/viewport variants passed, scoped analysis was clean, and strict change validation passed.

The web catalog built and rendered the synthetic Mac running-job dialog. Pointer dismissal could not be confirmed in its Phone preview, where the dialog extends beyond the preview frame; compact route geometry and dismissal are covered by widget tests. Native macOS interaction remains unverified because the native control tool previously could not bind the isolated fixture reliably and stalled. The React SkillJobSheet counterpart needs a design port.

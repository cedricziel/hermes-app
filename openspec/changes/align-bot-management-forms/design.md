## Context

The bot editor writes revision-checked profile configuration and confirms expensive model changes. Group creation keeps a stable operation identity across retries and requires two to six members.

## Decisions

Reuse GroupedDialog's action footer and grouped field/value rows. Extract plain bot editing fields for catalog previews. Keep the existing member checklist, model picker, warning text, and backend writes. Wait for the editor route to finish before disposing field controllers.

Platforms: iOS, Android, macOS, Windows, Linux. No watchOS or native project changes. Auth, API layering, content privacy, and telemetry behavior remain unchanged. No new spans, events, or breadcrumbs.

## Risks

Avoid changing metadata semantics, model confirmation, or retry identity while restructuring layout. Verify those paths through existing tests and rendered workflows.

## Verification so far

Thirteen roster, group retry, and bot workflow tests passed. Sixteen editor catalog and group creation screenshot cases passed. Desktop and phone renders were inspected; formatting, analysis, and strict OpenSpec validation passed. The draft remains local until PR #627 merges.

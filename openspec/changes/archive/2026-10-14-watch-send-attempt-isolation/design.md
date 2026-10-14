## Context

`ConversationModel.send` checks `currentSend` inside the waiting loop and error branches, but not before all success mutations. Existing Swift model tests exercise waiting and retries without asserting every late result path.

Platforms: watchOS runtime and macOS Swift test host. iOS relay remains unchanged. Android, macOS product UI, Windows, and Linux are unaffected. No entitlement, manifest, or Xcode project change.

## Goals / Non-Goals

Goal: enforce one local owner of conversation mutations after each asynchronous send boundary.

Non-goal: treat cancellation of a Swift task as cancellation of server work.

## Decisions

Check the attempt token immediately after the initial request and every poll resolves, before changing metadata or messages. Keep the existing explicit Stop waiting token invalidation. Compose the attempt check with the authentication and context-generation checks from `watch-session-privacy` and `watch-context-identity`; all checks must pass before a result mutates state. Task cancellation alone is insufficient because native callbacks can still complete and the server may continue.

Add deterministic suspended-response tests in `ios/HermesWatch/Tests/HermesWatchCoreTests/ModelTests.swift`. Resolve an old response after Stop waiting, including while a newer attempt remains in progress. Test success, failed completion, waiting, and thrown errors. Assert metadata and retry buffers as well as messages and phase.

This change adds a unique requirement instead of replacing Sending from the watch. The implemented waiting behavior is described by the completed, unarchived `actionable-request-notifications` change. Reconcile that baseline before archive; preserve its independent approval requirements.

Project invariants: no authentication, API layering, or token storage changes. Observability adds no spans, log events, or breadcrumbs because existing transport diagnostics remain sufficient and the stale-state rejection is directly testable.

## Risks / Trade-offs

- Missing one mutation path would retain the race. Centralize the guard placement after awaited results and test each result kind.
- Ignoring a late reply delays visibility until history reload. This follows Stop waiting behavior and avoids attaching an old answer to a new local attempt.

## Migration plan

Ship independently before durable recovery. No wire migration. Rollback changes only local race protection.

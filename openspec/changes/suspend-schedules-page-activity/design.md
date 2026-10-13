## Context

The controller already distinguishes visible and foreground state and rejects stale list generations, but commands and auxiliary reads lack a session boundary. See proposal.md for scope. Shared Dart behavior affects iOS, Android, macOS, Windows and Linux; watchOS is unaffected. No native entitlement, manifest or Xcode change is needed.

## Goals / Non-Goals

Goals: use the existing optional activity convention and retain page context during recoverable inactivity.

Non-goals: changing session identity, wiring the retained owner, or implementing form/detail suspension and recovery beyond existing callback cancellation.

## Decisions

Use live activity checks with a separate activity epoch. Every delivered notification invalidates work, because an earlier listener can perform nested false-to-true delivery before this controller sees the false value. Checking only a cached boolean or boolean transitions would miss that suspension.

Check the epoch after awaits and notifications before dispatch or publication. Keep list request generation separate so an ordinary list refresh cannot falsely retire a command. Commands and auxiliary reads reject stale outcomes with StateError. Refresh silently drops stale work because lifecycle callbacks start it without awaiting a result.

Resume with a fresh read only after the destination has started loading. Preserve filter, scope, rows and selected key; clear optimistic pending markers, loading and queued open requests. Cancel the timer immediately and restart it only with active session, foreground app and visible destination.

API layering and auth-storage invariants remain unchanged. Existing generated repositories issue the same requests. No observability signals or user-content attributes are added.

## Risks / Trade-offs

A command already dispatched may complete on the server. The client rejects its retired outcome and fresh recovery reads server state without replaying the command.

The shell does not yet supply an activity signal. Existing widgets catch only typed suspension and capture/recheck the controller activity period around awaited callbacks, including the delayed run-history lookup. Owner integration and handling suspended command errors remain separate work; integrated verification stays pending.

## Migration Plan

The optional constructor parameter leaves existing callers active. A later owner integration supplies one captured session activity and disposes this state on explicit departure. Removing the optional parameter and its fences rolls back this component change without data migration.

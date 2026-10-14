## Context

See proposal.md. Bot roster and canonical chat resolution use the shell's authenticated gateway. The root queue protects other handoffs but offers no request revision for an asynchronous lookup.

## Goals / Non-Goals

Reuse root dismissal, App Lock, and authorization policy while preserving canonical context. This change does not replace the queue or add a general intent broker.

## Decisions

Reserve a shell-local revision when a bot request arrives. The common external-navigation helper and deep-link arrival advance that revision, including unavailable links. Clear obsolete waiting discovery/share slots and cancel older queued delivery before beginning the bot lookup. Enqueue the resolved bot action directly so completion does not become a newer arrival.

Capture the current owner generation. Require the shell's live readiness, protected authorization, captured owner, bot-open version, and root-intent revision at entry, after each shell await, and at queued delivery. Retired failures are silent. Construct and publish the existing BotChatContext only after root routes permit dismissal.

Tests drive generated REST clients over FakeHermesServer and the real gateway client over a scripted loopback WebSocket. No production injection seam or real Hermes backend is required.

Shared Dart behavior affects iOS, Android, macOS, Windows, and Linux. watchOS is unchanged. No native entitlement, manifest, or Xcode changes. Existing API layering, secure-token storage, and telemetry invariants remain. No span, log event, breadcrumb, or attribute is added; existing signals retain their fixed, non-content attributes.

## Risks / Trade-offs

Canonical operations already dispatched may finish remotely; this shell fence cannot undo them. The shell checks between its own roster and canonical operations. Full transport renewal and retained-owner integration remain separate.

Native presentation and window interaction remain unverified until isolated client verification. The focused fixtures establish route and owner behavior only.

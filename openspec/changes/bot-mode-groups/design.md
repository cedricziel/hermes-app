## Context

See `bot-mode-group-protocol/design.md` for the verified server contracts. The app has a shared shell, one ordinary chat renderer, adaptive toolbar conventions, approval cards, and Widgetbook/workflow harnesses. Hosted rooms are durable server objects, not ordinary `ChatThread` instances.

## Goals / Non-Goals

Goals: Same-server text groups, attributed messages, understandable activity and controls, and reliable mobile resume.

Non-goals: Thread-level model overrides, mutable membership, pictures, attachments, peer rooms, or legacy Desktop room migration.

## Decisions

Depend on `bot-mode-group-protocol`; retain the group's distinct controller and event projection instead of forcing its transcript into a single-profile chat transport. Reuse markdown/message bodies and existing adaptive layout, toolbar, named buttons, and approval card styles. Keep room/member IDs and server action coordinates in models; chrome displays names, never parses names back into identities.

Place rooms alongside bots in the primary Bots roster. Selecting a bot opens its canonical DM; selecting a room opens a dedicated GroupChatScreen. On desktop use the roster as a left pane; on phone navigate from roster to conversation. Create-group and room-action widgets are plain models/callbacks built in the catalog first. Limit the first creation form to room name and member checklist.

Project message events to attributed transcript rows and turn/activity events into a compact activity area. Unknown events remain safely inspectable without pretending to be member prose. Mention suggestions are restricted to the fixed roster. The room composer has no attachment button and preserves a stable discussion thread ID when replying; a fresh topic uses a new ID.

Poll `groups.log` and `groups.state` on foreground visibility, drain replay pages immediately, and back off when idle or disconnected. Stop timers on dispose and suspension. Reconnection does not resend messages. Show driver-unavailable history and preserve composer drafts; action buttons use exact server coordinates and explicit retry confirmation only for advertised indeterminate/deferred tasks. Use the current AttentionPolicy for foreground room notices only; no background-push claim.

Group approvals support once/deny. The protocol conformance gate must show unsupported interactive inputs as failure or refuse execution with a visible reason. If upstream cannot satisfy this, the affected group execution is not marked release-ready; no invented clarify/sudo/secret methods or silent toolset changes.

Platforms: iOS, Android, macOS, Windows, and Linux; watchOS group conversations are deferred. No native entitlement, manifest, Xcode project, or new dependency change.

Invariants: Managed auth, secure tokens, shared RPC ownership, bounded lifecycle polling, opt-in telemetry without content, and isolated-home verification.

## Risks / Trade-offs

[Polling adds delay] → Fast visible-room cadence and immediate replay after user actions, idle backoff, server-bound limits.

[Member names change] → Preserve frozen member IDs and handles while displaying recorded authors accurately.

[UI expands beyond 500 lines] → Reuse existing body widgets and adaptive primitives; keep protocol implementation in its dependent PR and split optional presentation additions before coding.

## Migration Plan

Implement as `feat(bots): add hosted group conversations` after `bot-mode-group-protocol`. Publish the first feature release only with messaging terminology, roster, canonical DMs, local agent messaging, hosted protocol and group UI integrated and verified. Rollback removes the app surface without deleting server rooms.

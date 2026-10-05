## Context

See `bot-mode-group-protocol/design.md` for the verified server contracts and the isolated hosted clarify reproduction. The app has a shared shell, one ordinary chat renderer, adaptive toolbar conventions, approval cards, and Widgetbook/workflow harnesses. Hosted rooms are durable server objects, not ordinary `ChatThread` instances.

## Goals / Non-Goals

Goals: Same-server text groups, attributed messages, understandable activity and controls, and reliable mobile resume.

Non-goals: Thread-level model overrides, mutable membership, pictures, attachments, peer rooms, or legacy Desktop room migration.

## Decisions

Depend on `bot-mode-group-protocol`; retain the group's distinct controller and event projection instead of forcing its transcript into a single-profile chat transport. Reuse markdown/message bodies and existing adaptive layout, toolbar, named buttons, and approval card styles. Keep room/member IDs and server action coordinates in models; chrome displays names, never parses names back into identities.

Place rooms alongside bots in the primary Bots roster. Selecting a bot opens its canonical DM; selecting a room opens a dedicated GroupChatScreen. On desktop use the roster as a left pane; on phone navigate from roster to conversation. Create-group and room-action widgets are plain models/callbacks built in the catalog first. Limit the first creation form to room name and member checklist.

Project message events to attributed transcript rows and turn/activity events into a compact activity area. Unknown events remain safely inspectable without pretending to be member prose. Mention suggestions are restricted to the fixed roster. The room composer has no attachment button and preserves a stable discussion thread ID when replying; a fresh topic uses a new ID.

Poll `groups.log` and `groups.state` on foreground visibility, drain replay pages immediately, and back off when idle or disconnected. Stop timers on dispose and suspension. Reconnection does not resend messages. Show driver-unavailable history and preserve composer drafts; action buttons use exact server coordinates and explicit retry confirmation only for advertised indeterminate/deferred tasks. Use the current AttentionPolicy for foreground room notices only; no background-push claim.

Group approvals support once/deny. Hosted clarify, sudo, and secret requests have no room action in the verified protocol; the app does not poll or attach to hidden member sessions to copy Desktop's client-driven implementation. Show a concise limitation in the creation flow and during active room work: interactive requests cannot be answered here and a member may wait; Stop ends the server task. Never present a password or secret value form. Enable creation and send for a ready protocol 2 driver with required methods and transport features. Do not silently change profile tools.

Platforms: iOS, Android, macOS, Windows, and Linux; watchOS group conversations are deferred. No native entitlement, manifest, Xcode project, or new dependency change.

Invariants: Managed auth, secure tokens, shared RPC ownership, bounded lifecycle polling, opt-in telemetry without content, and isolated-home verification.

## Risks / Trade-offs

[Polling adds delay] → Fast visible-room cadence and immediate replay after user actions, idle backoff, server-bound limits.

[Member names change] → Preserve frozen member IDs and handles while displaying recorded authors accurately.

[Member waits for an unsupported input] → Keep polling and show the limitation beside active work with Stop available; do not imply that the app can identify the hidden request from room state.

[UI complexity grows] → Reuse existing body widgets and adaptive primitives; keep the protocol implementation in its own layer within the combined PR.

## Migration Plan

Implement hosted group conversations after `bot-mode-group-protocol` in the combined Bot Mode PR. Publish the first feature release only with messaging terminology, roster, canonical DMs, local agent messaging, hosted protocol and group UI integrated and verified. Rollback removes the app surface without deleting server rooms.

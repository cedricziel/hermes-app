## Context

`ChatController` holds a single profile's threads; `ChatOpenRequests` already carries profile-aware notification targets. The transport creates/resumes runtime sessions and streams events. Its current `_reattach` does not pass owner profile, and internal stored-ID maps need owner-qualified keys for Bot Mode.

Verified source: [canonical lifecycle](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/apps/desktop/src/plugins/hermes-bots/canonical-chat.ts), [session contracts](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/tui_gateway/contracts/sessions.py), `tools/bot_mode_dm.py`, and `agent/turn_context.py`.

## Goals / Non-Goals

Goals: Preserve canonical identity and profile ownership, reuse the existing transcript renderer, and expose same-server teammate messaging.

Non-goals: A client-owned DM orchestrator, cross-server relay, routine editor, or ordinary-session behavioral changes.

## Decisions

Carry conversation kind and owner as explicit bot-open context, separate from mutable labels. Extend shared open requests rather than changing the sticky CLI default. Use profile-qualified session keys in watchers, model caches, and reattach state. Retain stored IDs for REST and runtime IDs for events; session compression can change the resolved tip without changing bot identity.

Implement lookup/create in a small canonical repository using shared RPC. Follow upstream adopt-before-create rules. Materialize with `session.title` before REST history and verify the registry if the result remains pending; failure leaves a retryable state and must not send a kickoff into a stray conversation. Do not send an automatic introductory model turn: an empty canonical chat is usable when title materialization is supported. Disable creation explicitly when this required contract cannot be confirmed.

Canonical chats are hidden from ordinary session lists by upstream `hidden`, shown through the bot roster, and remain titled `Bot Chat`. Friendly labels belong in app chrome and profile metadata. Keep archive retirement behind an explicit explanation; disable generic rename. Compaction maps `/new` and `/reset` to the supported compact action while retaining the root.

A small plain-model mention picker maps a selected profile to an unambiguous handle; the backend injects the protocol and runs `message_agent`. Canonical chats qualify; ordinary sessions and hosted member sessions do not. Preserve attribution from server display metadata and typed tool/transcript messages; never fabricate peer answers or expose delivery acknowledgement as completion.

Platforms: iOS, Android, macOS, Windows, and Linux; watchOS bot-specific navigation is deferred, and shared transport changes retain existing watch session behavior. No native or dependency changes.

Invariants: Existing auth refresh and secure storage, generated REST history client, opt-in gateway tracing, and approval/clarification handling remain mandatory. No new telemetry content.

## Risks / Trade-offs

[Duplicate canonical chats] → Exact lookup, positive-roster safeguards, serialized creation, title uniqueness conflict adoption.

[Session IDs overlap across profiles] → Owner-qualified maps and reconnect tests with duplicate stored IDs.

[Another client owns the target turn] → Surface typed busy/queued outcomes; do not retry a prompt as a new session.

## Migration Plan

Implement as `feat(bots): open durable specialist chats` after `bot-mode-roster`, targeting about 500 changed lines through reuse. No imported chat pointers or local profile files. Rollback retains valid server chats; keep this and group changes in the same first-release milestone.

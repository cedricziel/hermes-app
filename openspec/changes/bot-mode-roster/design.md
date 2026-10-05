## Context

The existing REST profile repository parses only names, descriptions, model and skill counts. Bot Mode requires the richer `profiles.list` RPC response, metadata revisions, and exact canonical previews. The installed source baseline is 0.21.4, commit `35fdb4608aa8af455d2597664cff1754a3722cd1`.

Source contracts: [profile types](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/tui_gateway/contracts/profiles_vault_complete_foreign_subagents.py), [profile handlers](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/tui_gateway/methods_profiles.py), and desktop `apps/desktop/src/plugins/hermes-bots/types.ts`.

## Goals / Non-Goals

Goals: One server-backed identity per profile, a usable primary roster, and a small editor that reuses existing profile/model controls.

Non-goals: Profile deletion/renaming, advanced skill/tool/MCP editing, custom avatar pipelines, and speculative support for older gateway writes.

## Decisions

Extract a shared authenticated gateway service around `GatewayRpcClient`, and inject a request interface into the roster repository and existing chat transport. Reuse connection, authentication, request timeouts, and tracing; repositories do not own unrelated sockets. Probe read-only contracts, re-probe on connection replacement, and distinguish unsupported methods from transient connection or permission failures.

Add `BotModeBot` as a distinct domain model keyed by server identity and canonical profile name. Preserve the entire `hermes-bots` metadata object when patching title/description. A `ui_meta` write replaces its whole top-level key, so compare-and-swap using the roster revision is required. Success requires each requested `applied` field; partial edits retain drafts. Display existing avatars only where supported, otherwise render a deterministic initial/color using a plain-model roster tile.

Fresh creation uses an explicit “Use current provider credentials” option, initially on to match upstream. The server performs mirroring; the app handles no copied secrets and never enables clone channels. Show the created profile if a second metadata save fails and retry that save, not creation. Immutable profile name appears as advanced identity information; editing title does not rename the profile.

Keep Profiles for configuration and ordinary profile selection; opening a Bot will target its owner without writing the CLI sticky default in the dependent chat change. Add Bots to shell destinations on supported servers and keep Messaging in management navigation. Start plain-model tiles and editor states in Widgetbook.

Platforms: iOS, Android, macOS, Windows, and Linux. watchOS retains ordinary conversation relay; Bot management is not exposed there. No native entitlements, manifests, Xcode projects, or dependency changes.

Invariants: Reuse managed auth and secure token storage; no hand-written REST calls or generated-client edits; opt-in telemetry excludes content; integration tests use real RPC frames and generated HTTP clients where reused.

## Risks / Trade-offs

[Metadata overwritten by another client] → Preserve unknown fields, require revisions, surface conflicts.

[Credential mirroring semantics vary] → Set the choice explicitly and verify server outcomes against an isolated home; do not claim independent OAuth credentials.

[Scope grows beyond one small PR] → Keep identity editing minimal and target about 500 changed lines; split advanced lifecycle work before implementation if necessary.

## Migration Plan

Depends on `disambiguate-messaging-bots`; implement as `feat(bots): add profile-backed specialist roster`. Follow with `bot-mode-chats`, `bot-mode-group-protocol`, and `bot-mode-groups` in the same first feature release. Existing profiles are added by explicit user action; app rollback leaves server profiles valid for Hermes Desktop and CLI.

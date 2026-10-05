## Context

The checked-in OpenAPI contains no hosted group contract. The installed source exposes typed `groups.*` through the same dashboard socket as chat. Its durable hosted driver schedules member turns independently of the viewing app. Desktop also has legacy client-driven rooms; those metadata rooms cannot be assumed to equal hosted rooms.

Source: [group contracts](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/tui_gateway/contracts/groups_bot_relay.py), [handlers](https://github.com/NousResearch/hermes-agent/blob/35fdb4608aa8af455d2597664cff1754a3722cd1/tui_gateway/methods_groups.py), and `tui_gateway/hosted_room_service.py`. The inspected hosted protocol is version 2. In an isolated Hermes 0.21.4 run, a scripted hosted member called `clarify`: for more than seven seconds `groups.state` had one running task and no pending action, `groups.log` held only the user message, and the hidden member's `session.resume` reported `status=waiting` with an open clarify request. The interaction gap was reproduced on a running backend.

## Goals / Non-Goals

Goals: Typed requests, durable replay, exact controls, and recovery independent of UI.

Non-goals: New REST endpoints, peer grants, authority takeover, legacy desktop room migration, or group orchestration in Flutter.

## Decisions

Use the shared gateway service introduced by the roster change. A small `HermesGroupsRepository` parses strict identity/cursor fields and tolerates additive event kinds by retaining unknown events without projecting them as assistant text. Typed room/member/status/event models carry server authority and exact action coordinates. Add fake RPC fixtures from the inspected contracts; this is a websocket boundary and does not require modifying OpenAPI or generated REST code.

Probe protocol version 2, required advertised methods and transport features, and driver readiness before executable group creation or send. Permit history viewing if a driver is down. Do not require remote RoomLink capability for local members. Do not advertise compatibility with protocol 1 until representative conformance tests establish equivalent behavior.

Generate and retain operation UUIDs for create/send/rename/stop. A send receipt means accepted, not completed. Resolve an ambiguous response by replaying the server event whose ID is `user:${sha256(client_event_id UTF-8).hexdigest()}`. The raw `client_event_id` appears only in a send receipt, so matching log IDs directly to the raw UUID is incorrect. Add a fixed digest fixture and an accepted-send/lost-receipt test. Bound page size to the advertised maximum and poll only while the owning UI is visible and the app resumed. A controller generation prevents old-server or old-room responses from mutating a newer selection. Store no transcript cache in preferences; reopening can replay from zero, while reconnecting a mounted room resumes its incorporated cursor.

Read pending action coordinates from `groups.state`; offer retry only for its advertised indeterminate/deferred retry actions, not every failed turn. Approvals offer once/deny because the runtime handler is narrower than its schema enum. The current hosted contract does not expose clarify, sudo, or secret requests as room actions. Do not poll hidden member sessions or call ordinary session response methods from the room UI. Keep `groups.stop` available while the driver reports work or a block, including when no pending room action explains the wait. Never disable or rewrite a user's profile tool configuration silently.

Platforms: shared Dart support for iOS, Android, macOS, Windows, and Linux; no watchOS group UI. No native configuration/dependency changes.

Invariants: Existing dashboard authorization and token refresh, opt-in tracing with method/status only, no manual generated-client edits, and no access to the user's real Hermes home during verification.

## Risks / Trade-offs

[Desktop legacy rooms differ] → List hosted rooms only; document this boundary, never adopt metadata logs automatically.

[Missing interactive input contract] → Explain before group creation and during active room work that interactive requests cannot be answered in hosted groups and may leave a member waiting. Offer Stop, and preserve ordinary DM chat's supported input surface.

[Authority changes or malformed replay] → Stop cursor advance and refresh room state; never promote authority automatically.

## Migration Plan

Implement the hosted group protocol after bot chats and before group UI in the same first release. No server schema migration. Rollback leaves hosted room records and events intact.

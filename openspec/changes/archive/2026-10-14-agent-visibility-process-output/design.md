## Context

See [proposal.md](proposal.md) for motivation. Pinned Hermes baseline `167e9fdb84248cd0fff80762dc57b6a914b6e930` defines `TerminalOutputPayload` and `TerminalClosePayload` in `tui_gateway/contracts/events.py`. `session_notifications.py::_wire_desktop_sinks` resolves the process owner to an in-memory runtime and emits output chunks or a close notification on that runtime. Close contains only a process ID; the sink does not establish an exit code or process success. Sources reviewed: lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_models.dart; lib/src/chat/widgets; lib/src/chat/gateway/gateway_replay.dart. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-process-output/spec.md](specs/agent-process-output/spec.md). No interactive terminal, shell input, process killing, file download, exit-code inference, or complete output archive.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Reuse the existing confirmed owned-session lookup and the same controller ownership subscription. Stamp each process event with the physical connection token and envelope runtime. Require current connection, runtime, profile, conversation, and protected activity before applying. Recheck after binding notifications that can retire ownership reentrantly. Retire changed buffers before observer notification. The usage getter also checks its cached scope and any divergent non-null confirmed binding, while preserving known stale counters during disconnection. Clear buffers on connection loss or replacement, runtime reclaim, profile replacement, conversation disposal, and protected activity retirement. Same-client/runtime/profile takeover preserves the buffers. Keep the existing replay ledger authoritative for chunk deduplication.
- Provide compact chat cards and explicit expandable details. Preserve reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- Keep byte accounting and text-tail truncation separate from widget layout. Process identity is scoped to the exact owned binding so a reused ID cannot combine unrelated outputs. Bound expanded text to a scrolling viewport and cap the process-card group so it cannot consume the transcript. Place omission labels after the text tail, with a card-eviction footer after the group. Native terminal privileges are unnecessary.
- Full output recovery is unavailable in the existing event payloads; no backend extension is planned.

## Platforms and invariants

Affects the Flutter app on iOS, Android, macOS, Windows, and Linux. watchOS presentation and relay payloads are unchanged. No native entitlement, manifest, or Xcode project change is needed. Existing authentication and secure token storage remain authoritative. REST refreshes, if applicable, reuse existing repositories through the generated client. Do not hand-edit packages/hermes_api or add new Dio calls.

## Observability

At the event reducer or connection invalidation consumer, log gateway.visibility_outcome through AppEventLogger using allowlisted feature and outcome values and optional count. At user details, retry, or browser actions, record chat.visibility_action through Breadcrumbs with feature and action enums. Existing gateway receive, RPC, and REST spans retain connection hermes.* attributes. Add no user text, IDs, profile names, codes, URLs, output, or reaction content. Telemetry failures remain swallowed, including errors during fallback handling.

## Risks / Trade-offs

- Event replay can repeat effects. Reuse sequence checks and capability identity; test replay and stale-result behavior.
- Optional protocol fields can be absent or malformed. Decode safely, omit unavailable details, and leave chat operational.
- This PR changes live presentation. It cannot guarantee event history that the backend does not persist. Restore only documented snapshots or existing durable transcript data.
- Shared chat model changes can conflict with adjacent proposals. Land this bounded capability independently and reconcile shared event decoding in integration review.

## Migration Plan

No persisted-data migration or backend deployment is required. Add app behavior behind safe optional decoding. Rollback removes this capability's UI and mapping while keeping the existing contract inventory classification accurate. Target one feat(chat) commit and roughly 500 implementation lines or fewer; split presentation from follow-up enhancements if this bound is exceeded.

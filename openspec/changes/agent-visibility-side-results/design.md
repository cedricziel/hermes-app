## Context

See [proposal.md](proposal.md) for motivation. Pinned backend `167e9fdb84248cd0fff80762dc57b6a914b6e930` defines `SideAgentCompletePayload` in `tui_gateway/contracts/events.py`. `methods_prompt.py::_spawn_side_agent` emits `background.complete` or `btw.complete` on the parent runtime with `task_id`, `text`, and optional `question`; failures are reported as literal text, not a typed main-turn failure. Sources reviewed: lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_controller.dart; test/chat_background_subagent_test.dart. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-side-results/spec.md](specs/agent-side-results/spec.md). No new side-agent launch UI, operating-system delivery, inferred progress, or guaranteed cold-start history.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Reuse the existing owned-session subscription and confirmed binding lookup. Each mapped side event carries its actual physical connection token and envelope runtime. Before applying, require the current connection, runtime, profile, and thread owner to match. Recheck after binding notifications that can retire activity reentrantly. Retire changed details before notifying observers of the replacement binding. The usage getter exposes only a matching scope and hides a divergent non-null confirmed binding; null ownership preserves known disconnected-stale counters. Clear details on physical connection loss or replacement, reclaim, profile replacement, thread removal, and protected activity retirement. Same-client/runtime/profile takeover keeps existing results. Reuse the existing replay ledger rather than introducing independent reconnect logic.
- Keep inspection, session-status, and notice cards in one bounded scrollable header so multiple expanded views leave the conversation and composer usable.
- Provide compact chat cards and explicit expandable details. Preserve reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- Reuse the existing unsolicited-event path and conversation ordering. Do not map side completions to ReplyCompleted. The contract has no dedicated side-result history API; disclose this limitation in the implementation review.
- Operating-system attention remains owned by mobile proposals.

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

## Context

See [proposal.md](proposal.md) for motivation. Sources reviewed: lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_models.dart; lib/src/chat/widgets; test/gateway/gateway_contract_test.dart. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-warnings/spec.md](specs/agent-warnings/spec.md). No operating-system notifications, automatic tool cancellation, secret recovery, credit purchase, or persisted warning history.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Use server, profile, stored-session, runtime, and attachment generation ownership as appropriate. Runtime IDs and opaque revisions cannot serve as global identities. Reject stale asynchronous results and reuse the existing replay ledger rather than introducing independent reconnect logic.
- Provide compact chat cards and explicit expandable details. Preserve reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- Buffer unmatched risks only within the active session, with a bounded count and cleanup at disposal. Keep keyed notices outside assistant response text; expiry must be injectable for tests. Agent/sticky notices follow explicit withdrawal because the schema does not specify an automatic turn-end rule.
- Notice persistence across cold start is unavailable in the current resume schema.

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

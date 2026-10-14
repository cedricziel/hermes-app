## Context

See [proposal.md](proposal.md) for motivation. Sources reviewed: lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_controller.dart; lib/src/chat/widgets; openspec/specs/model-settings/spec.md. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-moa-progress/spec.md](specs/agent-moa-progress/spec.md). No advisor model selection changes, inferred advisor errors, backend cancellation controls, or durable advisor archive.

## Contract evidence

The current checkout pins `71d34bad1045610252eda02ee79549436896e784`. The prepared fixture baseline is `167e9fdb84248cd0fff80762dc57b6a914b6e930`; the four MoA payload schemas are identical. Notification names are `moa.reference`, `moa.progress`, `moa.phase`, and `moa.aggregating`. None supplies a turn ID. Connection/runtime proof comes from the confirmed transport binding; foreground turn identity comes from an actual pending reply or message-start event, never from labels or advisor indices.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Use server, profile, stored-session, runtime, and attachment generation ownership as appropriate. Runtime IDs and opaque revisions cannot serve as global identities. Reject stale asynchronous results and reuse the existing replay ledger rather than introducing independent reconnect logic.
- Provide compact chat cards and explicit expandable details. Preserve reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- Reuse the existing inline expandable-card pattern but keep advisor progress distinct from subagent lifecycle because the wire identities differ. Optional index is not a stable cross-turn identifier.
- Public getters compare cached ownership with the current confirmed binding synchronously. A missing binding hides advisor state. Settlement removes the foreground marker before late events can update it. Replay uses the existing gateway sequence ledger; unsequenced distinct frames retain distinct identities.
- No dependency on model-settings changes; configuration API behavior remains unchanged.

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

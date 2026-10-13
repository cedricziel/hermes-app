## Context

See [proposal.md](proposal.md) for motivation. Sources reviewed: lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/chat_controller.dart; lib/src/schedules/schedules_controller.dart; lib/src/messaging/messaging_screen.dart; lib/src/messaging/telegram_pairing_screen.dart. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-change-invalidation/spec.md](specs/agent-change-invalidation/spec.md). No new socket solely for invalidation, continuous background execution, guaranteed signal delivery, projects or skin support, or replacing polling recovery.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Use server, profile, stored-session, runtime, and attachment generation ownership as appropriate. Runtime IDs and opaque revisions cannot serve as global identities. Reject stale asynchronous results and reuse the existing replay ledger rather than introducing independent reconnect logic.
- Preserve the existing list UI, reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Refresh read models without disturbing drafts or selections.
- Add a connection-scoped invalidation channel alongside session event delivery. Existing watches filter by runtime ID, so these broadcasts must be consumed before that filter. Reuse repositories and generated clients rather than parsing alternate REST shapes.
- Coordinates with `backend-contract-advisory-alignment`, but requires no new backend behavior.

## Platforms and invariants

Affects the Flutter app on iOS, Android, macOS, Windows, and Linux. watchOS presentation and relay payloads are unchanged. No native entitlement, manifest, or Xcode project change is needed. Existing authentication and secure token storage remain authoritative. REST refreshes, if applicable, reuse existing repositories through the generated client. Do not hand-edit packages/hermes_api or add new Dio calls.

## Observability

At the event reducer or connection invalidation consumer, log gateway.visibility_outcome through AppEventLogger using allowlisted feature and outcome values and optional count. No new breadcrumb is added for automatic invalidation; existing list retry breadcrumbs remain authoritative. Existing gateway receive, RPC, and REST spans retain connection hermes.* attributes. Add no user text, IDs, profile names, codes, URLs, output, or reaction content. Telemetry failures remain swallowed, including errors during fallback handling.

## Risks / Trade-offs

- Event replay can repeat effects. Reuse sequence checks and capability identity; test replay and stale-result behavior.
- Optional protocol fields can be absent or malformed. Decode safely, omit unavailable details, and leave chat operational.
- This PR changes live presentation. It cannot guarantee event history that the backend does not persist. Restore only documented snapshots or existing durable transcript data.
- Shared chat model changes can conflict with adjacent proposals. Land this bounded capability independently and reconcile shared event decoding in integration review.

## Migration Plan

No persisted-data migration or backend deployment is required. Add app behavior behind safe optional decoding. Rollback removes this capability's UI and mapping while keeping the existing contract inventory classification accurate. Target one feat(chat) commit and roughly 500 implementation lines or fewer; split presentation from follow-up enhancements if this bound is exceeded.


## Confirmed broadcast scope

The current contract is `71d34bad1045610252eda02ee79549436896e784`. `ChangeSignalPayload` is an object with no required fields, identical to the retained `167e9fdb` baseline. Broadcasts provide no profile or resource identity. The shared connection feed reports the actual physical client before runtime filtering; it never opens a socket to observe changes. Each destination uses its existing explicit repository profile, verified authentication owner, activity period, and a pure current-client check both before the read and before synchronous application. Unknown profile scope pauses automatic invalidation while ordinary foreground refresh remains available.

## Review layers

The signal/coalescer/authenticated-binding foundation is reviewed separately from actual destination consumers. The shared neutral raw-feed producer belongs to the connector prerequisite and is not duplicated here. The consumer layer uses pure repository reads, immutable generation-tagged snapshots, and synchronous fenced model application. Session-list reconciliation retains selected, queued, in-flight, preparing, and busy thread objects in their original namespace; only a complete list can establish absence. Queue recovery availability is updated through a synchronous marker hook, without deleting records, changing IDs, retiring watches, or draining queues.

## Queue integration

The destination layer reuses the queue controller's existing unavailable set. The read-list generation and actual explicit profile fence synchronous application. The retained-object predicate includes the public queueBusy state, so a complete list cannot remove a target during protected enqueue, preparation, dispatch, restoration, or removal. Positive exact rows and successful explicit recovery clear only the missing-target error; they do not send or rebind prompts. Storage and original-scope cleanup remain owned by the queue implementation. The optional local queueDispatchAllowed callback reaches the existing guarded request after instrumentation; it adds no backend or storage API and does not alter the raw connection feed. Admission permission stays separate from post-byte known acceptance and owner proof.

## Verification status

The prior isolated consumer regression and catalog checks are recorded in the extraction evidence. Current queue-based integration adds protected busy-target and availability-control regressions. Native destination verification is pending; no task checkbox claims it completed.

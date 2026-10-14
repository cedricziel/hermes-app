## Context

See [proposal.md](proposal.md) for motivation. Sources reviewed: lib/src/chat/gateway/gateway_rpc_client.dart; lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/widgets; lib/src/messaging/telegram_pairing_screen.dart. The event mapper drops the listed events; session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-billing-verification/spec.md](specs/agent-billing-verification/spec.md). No billing charges, automatic top-up, payment details, automatic step-up, credential collection, persistent code storage, or portal callback endpoint.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Use server, profile, stored-session, runtime, and attachment generation ownership as appropriate. Runtime IDs and opaque revisions cannot serve as global identities. Reject stale asynchronous results and reuse the existing replay ledger rather than introducing independent reconnect logic.
- Provide compact chat cards and explicit expandable details. Preserve reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- The wire event has no request identifier or expiry. Allow one app-originated step-up per session and generation; do not correlate unsolicited or competing flows by guessing. Clear transient code on App Lock and require fresh details after unlocking; do not persist it. No new native entitlement is needed.
- No backend extension. The schema does not expose discoverable method capabilities; method-not-found fallback provides runtime availability. The action grants billing scope only and never initiates a charge.

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


## Verified dispatch and lifecycle

The retained backend-source audit at `167e9fdb84248cd0fff80762dc57b6a914b6e930` registers only `billing.step_up.verification`; there is no `billing.verification` alias. `billing.step_up` is a pooled operation that can wait for minutes. The app uses the confirmed current physical client and runtime with a nonempty resolved profile. It does not resume a stored ID to obtain billing authority. The direct request uses the shared pre-send authorization guard after request instrumentation and has no generic optional-call timeout that would discard a valid long device flow. One request per confirmed binding stays in flight until the originating result or socket failure.

Billing uses the existing owned-session subscription. Pure current-binding checks hide retired state before ownership callbacks run. The card is inside the existing bounded activity list; main-turn settlement, typing, canonical prompt receipts, and the replay ledger remain authoritative. The main screen passes its existing App Lock controller. Covering the app clears code and URL immediately and rejects new details and actions, while retaining the pending barrier. Unlocking does not restore a previous code. A final valid RPC result can update the grant status while locked without retaining private verification details. Existing authenticated session activity and auxiliary-window leases remain required when integrating with current main. Live billing requires an explicitly supplied App Lock controller; without that authority it creates no module and accepts no details or actions. Auxiliary engines currently supply no proven App Lock coverage bridge, so billing stays unavailable there. Their queue visibility flag starts visible and cannot substitute for authoritative lock coverage. This policy does not change the auxiliary window UI or introduce a global lock bridge.

Replay-only verification rows must not restore a code discarded with the old connection. Current live frames parked during attachment can still supply fresh details. No correlation ID, expiry, browser callback, payment operation, or backend field is invented. The originating RPC's `ok` and `granted` booleans alone establish a grant; reported `retry_after` alone controls the retry delay.

The current checked-in schema is pinned to `71d34bad1045610252eda02ee79549436896e784` in `openrpc/HERMES_REF`. Its billing parameter/result and verification-payload fields match the retained synthetic fixtures. These checks do not claim a native run against that backend revision. Automated validation passed 149 distinct tests and scoped analysis of 25 changed Dart paths. Native verification and final authenticated auxiliary-window integration remain pending for root's rebase and verification run.

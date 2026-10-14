## Context

See [proposal.md](proposal.md) for motivation. The retained source audit at backend `167e9fdb84248cd0fff80762dc57b6a914b6e930` emits `connection.request` as a notification in `agent_callbacks.py`, not a server request. `methods_connectors.py::_connection_update` emits session updates on their owning runtime; genuine account updates broadcast globally with no profile and remove connect URLs and connection IDs. `connection.respond` resolves a captured session owner/profile-home record; account responses otherwise consult profile scope, so a broadcast cannot prove account-profile authority. Sources reviewed: lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/widgets; openrpc/hermes-gateway.openrpc.json. The checked-in schema remains pinned to `71d34bad1045610252eda02ee79549436896e784`. Native verification against that pin remains pending. Session watches filter by runtime ID. Existing replay handling already provides event sequence deduplication and attachment ownership. Listed sources identify affected code and nearby reference implementations, not mandatory changes to every file.

## Goals / Non-Goals

Use the existing Flutter chat presentation and authenticated gateway. Keep this PR bounded to the capability in [specs/agent-connector-operations/spec.md](specs/agent-connector-operations/spec.md). No credential entry, catalog installation, native desktop integration, automatic browser launch, automatic connection-success reporting, or new connector endpoints.

## Decisions

- Add typed optional event decoding and a reducer for this capability instead of treating event text as assistant prose. This preserves main-turn completion and input-request behavior.
- Session operations reuse the existing owned-session subscription and pure confirmed lookup. Require exact physical client, confirmed runtime, profile, conversation, protected activity epoch, and displayed snapshot identity. Unknown or missing profile authority is read-only, with connect URLs removed before retention and no browser/response action. Global account updates appear as explicitly connection-wide read-only activity, never as the selected conversation's operation. The neutral raw notification feed is tagged by the actual client before runtime filtering, has a pure current-token getter and ownership predicate, and uses the existing session wrapper epoch gates. It does not create or resume a connection.
- Provide compact chat cards and explicit expandable details. Both scoped and connection-wide groups join the existing shared activity panel, which remains capped at 40% of the available chat height. Preserve the current usage, Todo, Side, Process, and MoA ownership getters and delivery behavior, reduced motion, screen-reader labels, narrow layouts, and macOS presentation. Generic toast-only rendering would hide inspectable activity and cannot represent replacement or recovery.
- Retire operation controllers and cancel deadlines on connection/runtime/profile/account ownership loss, reclaim, conversation removal or retarget, and protected activity retirement. Guards also run after notification/logging callbacks that can retire scope reentrantly. Browser callbacks capture the immutable displayed snapshot and attachment; RPC dispatch rechecks authorization after request instrumentation and before sending bytes, A purpose-built pending-response proof permits the operation's own pending state while requiring the captured snapshot, responder, scope generation, eligibility, and supported action to remain current. A newer snapshot, metadata enrichment, deadline, or responder replacement during instrumentation prevents bytes and suppresses a stale refusal on the replacement card. Once admitted, an authoritative RPC settlement may arrive after the original deadline; scope retirement still prevents applying it to another owner.
- Restore only the decoded `pending_connection` projection on an existing confirmed resume. Do not retain credential defaults or complete transcripts in the ownership stream, and reject older operation seq snapshots when newer live updates exist.
- ConnectionAnswerStatus permits approved and skipped. This change sends skipped only; it does not add install approvals. Fixture the exact owner and response shape. Use url_launcher through existing external browser support and display destination host before explicit launch. No new URI callback route is required to render backend updates.
- No backend changes. Unsupported target actions remain unavailable. Keep credential/install flows out of this PR.

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


## Automated verification receipt

Actual-client regressions reproduced response bytes after same-binding snapshot replacement, deadline expiry, and responder loss during instrumentation. The pending-response proof fixes those cases; the positive control retains authoritative settlement received after an admitted response's deadline. The amended core's metadata-enrichment identity is covered by the same byte-send boundary. The real view exercises both connection-wide and scoped groups inside the shared cap at 320×360, and a replacement observer checks that restored connector activity cannot expose old usage, Todo, or Side details. Before the parent rebase, the wiring on main `e208ef64` plus the replayed connector core passed 216 distinct tests: 104 serial feature tests and 112 MoA/acknowledgement/dispatch/feed/reconnect tests. The final wiring directly based on published core `21dbf633` passed 75 narrow post-parent tests covering core listener retirement, metadata enrichment, actual-client guards, Process, and shared activity. The inherited Process long-output widget also passed independently. Concurrent combined runs stalled without an assertion failure at different inherited fixtures; the serial run completed in 17 seconds without a production patch. Full `flutter analyze --no-pub` reported no issues. Both strict OpenSpec validations passed. Native verification remains pending.

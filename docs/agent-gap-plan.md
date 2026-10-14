# App and agent gap proposals

These proposals cover the app gaps reviewed on 12 October 2026. They change the client and its development tooling only. Compact chat cards expose details on demand, and actions rely on existing Hermes contracts. Backend compatibility checks remain advisory. Restored local prompts wait for review. Learned-memory management includes inspection, editing, and deletion.

Each linked change contains its own proposal, design, acceptance scenarios, and implementation tasks, except the compatibility change, which deliberately has no delta specs because it changes tooling only. Implementation is tracked in each change's `tasks.md`.

## Implementation progress

Implementation has shipped through isolated feature checkouts and separate PRs. All 18 app-only proposals have landed through the feature PRs listed below after independent review and CI. Native verification limits remain recorded separately. Queue recovery, auxiliary-window ownership, process output, connector operations, and device verification are merged.

The final combined Reaction and resource refresh source is based on merged Billing main `d79a29f24e09d797fb872b576709241f7bef2ce8`. Reaction head `ac3efe54edb05afe85df77f87351da2903e12b12` and destination head `ecb87825f86061f9830c90b877089724e2bea8f1` produced combined tree `5634e358072cf3b81b983aa6cf967b2cdf6ec06e`. Rebasing refresh onto merged Reaction produced `f21e4e25081fc4da3f0dd0d49c62b6b86e5d2097` with the identical tree. Final feature main `2485c54a2806d1715e9bf084e0ebf402742bc8a7` retains that same tree. Its affected regression suites passed 351 tests, its Billing/Reaction/list-refresh catalogs passed 128 cases, full analysis found no issues, and strict Reaction and invalidation specs passed. Formatting checked 35 Dart files without changes. These counts are shared combined evidence, not separate totals for each PR or reruns of every earlier suite.

Bounded macOS verification of this exact combined source observed the canonical reaction badge and session acknowledgement, connector details and response dispatch, billing details and App Lock redaction, and a visible composer at 1600×688. The disposable backend recorded one completed billing request and one completed connector response. Browser and clipboard actions used counters; no real billing grant, connector connection, device authentication, or queue keychain behavior is claimed. Refresh destinations and extended replay, race, and platform scenarios were unobserved in that round. All three disposable processes stopped and the test endpoint closed.

The separately authorized fresh notification fixture built and passed source and compiled isolation checks. UI automation stalled on both its exact path and bundle identity before any permission request or post. OS acceptance and banner presentation remain unverified; no notification was created. Earlier isolated macOS checks cover bounded memory, queue recovery, usage, todo plans, and activity-card cases; they do not verify every native scenario or platform. Each change's unchecked tasks retain its extended verification limits. All changes remain limited to the app and its development tooling.

## Follow-up verification

The final authenticated macOS round used source `4e9214043d5de58927f6612b7042f0db87176dbc`, the Chat sidebar fix merged in [#756](https://github.com/cedricziel/hermes-app/pull/756). The disposable app used real synthetic password authentication, PKCE, identity verification, and WebSocket tickets, with memory-only client token storage and reviewed isolation adapters. An empty-runtime sessions hint caused one sessions read and displayed a new row while retaining the selected thread and unsent draft. Chat navigation scrolled to Profiles and Schedules. Screenshots were 1600×560 pixels; native logical bounds were unavailable.

Schedule content also refreshed, but two reads over 49.161 seconds overlapped polling, so event-only refresh and coalescing are not established. Messaging, pairing, dirty-form preservation, and extended native races remain unobserved; invalidation task 3.3 stays unchecked. Shared Schedules navigation overflowed in the short window, and an unsent draft disappeared after leaving Chat and returning; these are separate findings from draft retention during the sessions hint. Both disposable processes, all their listeners, synthetic auth files, and the empty guarded task container directory were removed. No OS notification was requested or posted.

Queue fixture cleanup and composer commit waits landed in [#750](https://github.com/cedricziel/hermes-app/pull/750), [#755](https://github.com/cedricziel/hermes-app/pull/755), and [#757](https://github.com/cedricziel/hermes-app/pull/757). Actual reconnect invalidation coverage landed in [#753](https://github.com/cedricziel/hermes-app/pull/753), followed by task reconciliation in [#752](https://github.com/cedricziel/hermes-app/pull/752). The advisory verification task is complete through [#754](https://github.com/cedricziel/hermes-app/pull/754). The project verification guide now covers authenticated ownership, current process readiness, and credential-safe logs through [#758](https://github.com/cedricziel/hermes-app/pull/758).

## Delivery tasks

- [x] Publish, independently review, and merge advisory contract alignment.
- [x] Review and ship warning cards from an isolated checkout.
- [x] Independently review and merge all app-only feature changes in dependency order.
- [x] Publish and independently review the final delivery index.
- [x] Verify bounded authenticated sessions refresh and short Chat navigation from the exact sidebar source.
- [ ] Complete the remaining platform and extended native scenarios.

## Pull requests

| Change | Pull request | State |
| --- | --- | --- |
| Advisory contract alignment | [#681](https://github.com/cedricziel/hermes-app/pull/681) | Merged after independent isolated review, required CI, and automated approval. |
| Reproducible API regeneration | [#728](https://github.com/cedricziel/hermes-app/pull/728) | Merged after independent isolated review, actual regeneration with no generated-client diff, and all CI. |
| Request alert retry | [#688](https://github.com/cedricziel/hermes-app/pull/688) | Merged after independent review, addressed automated finding, and all CI. The original native posting check stopped on denied OS permission; the authorized fresh fixture later hit a UI-binding stall before permission or posting. |
| Warning cards | [#702](https://github.com/cedricziel/hermes-app/pull/702) | Merged after independent isolated review and passing CI. Native notices, TTL, and risk labels verified; detailed native output remains unobserved. |
| Session usage | [#727](https://github.com/cedricziel/hermes-app/pull/727) | Merged after isolated review, 200 usage and gateway regressions, clean analysis, all CI, and native live/final totals. |
| Todo plans | [#729](https://github.com/cedricziel/hermes-app/pull/729) | Merged after 294 regressions, full analysis, independent source review, and all CI. Native statuses, revisions, empty plans, profile isolation, and usage coexistence verified; extended transitions remain unobserved. |
| Side results | [#731](https://github.com/cedricziel/hermes-app/pull/731) | Merged after independent review, 122 combined regressions, full analysis, and all CI. Shared activity scrolling preserves the composer in short windows; three bounded macOS rounds verified live, closed, replacement, and profile behavior. Extended cases remain unchecked. |
| Activity retirement | [#744](https://github.com/cedricziel/hermes-app/pull/744) | Merged after all CI and independently reproduced notifier failure, 69 activity regressions, independent source review, and full analysis. Side results, todo plans, and usage clear immediately during activity retirement. |
| Gateway connection and dispatch guards | [#737](https://github.com/cedricziel/hermes-app/pull/737) | Merged after independent source review, 25 real transport/client/wrapper regressions, full-analysis hooks, and all CI. Reuses the existing socket; no backend change. |
| Connector snapshot models | [#738](https://github.com/cedricziel/hermes-app/pull/738) | Merged after independent extraction review, five semantic snapshot/URL tests, full-analysis hooks, and all CI. Raw authority regression fixed before publication. |
| Advisor progress | [#736](https://github.com/cedricziel/hermes-app/pull/736) | Merged after independent review found and fixed two turn/binding ordering bugs; 60 combined regressions, full analysis, strict specs, all CI, and bounded native macOS progress/reference/settlement/profile checks passed. Extended cases remain unobserved. |
| Scoped refresh coordinator | [#740](https://github.com/cedricziel/hermes-app/pull/740) | Merged after source review, 26 coordinator/auth-binding regressions, and full-analysis hooks. Bounded rejected-read loop fixed before publication; destination wiring follows. |
| Connector controls | [#741](https://github.com/cedricziel/hermes-app/pull/741) | Merged after addressed review feedback and all CI; originally published above models after independent review, 22 controller/card regressions, 72 catalog cases, and full analysis. Three metadata regressions and two listener-retirement regressions were reproduced and fixed; the earlier control/catalog batch passed 4,704 checks. Live wiring follows. |
| Device verification controls | [#742](https://github.com/cedricziel/hermes-app/pull/742) | Merged after all CI and independent review, 25 helper/card tests and 144 post-rebase catalog checks. Live wiring follows. |
| Live connector operations | [#745](https://github.com/cedricziel/hermes-app/pull/745) | Merged after all CI and independent review, 216 earlier regressions, 75 final-parent regressions, full analysis, and strict specs. One bounded macOS round observed expanded details and response dispatch; final-card, replay, lock, and expiry cases remain unobserved. |
| Canonical reaction core | [#739](https://github.com/cedricziel/hermes-app/pull/739) | Merged after independent extraction review, 127 parser/state/card/mapper/repository regressions, full-analysis hooks, and all CI. Live receipt and event wiring follows. |
| Live reaction receipts | [#743](https://github.com/cedricziel/hermes-app/pull/743) | Merged after all CI and independent review. Prior receipt/insertion RED tests, 126 regressions, and 64 overlapping ownership cases remain separate evidence. Final combined verification with merged Billing and resource refresh passed 351 regressions, 128 shared catalog cases, full analysis, and strict specs. One bounded macOS round observed the canonical badge and acknowledgement. History, replay, popover, and extended native scenarios remain unchecked. |
| Process output | [#732](https://github.com/cedricziel/hermes-app/pull/732) | Merged after isolated review, 182 regressions, all CI, and three bounded macOS activity rounds. Extended native cases remain unchecked. |
| Queue submission proof | [#730](https://github.com/cedricziel/hermes-app/pull/730) | Merged after isolated review, reproduced instrumentation cancellation, 615 integrated regressions, full analysis, and all CI. Pre-byte denial remains distinct from uncertain delivery. |
| Queue storage access | [#733](https://github.com/cedricziel/hermes-app/pull/733) | Merged after independent isolated review, ten real-store and broker tests, full analysis, and all CI. Window coordination and recovery UI follow. |
| Queue window coordination | [#734](https://github.com/cedricziel/hermes-app/pull/734) | Merged after all CI and isolated review, 71 window/launch/host/profile regressions, and full analysis. |
| Reviewed queue recovery | [#735](https://github.com/cedricziel/hermes-app/pull/735) | Merged after all CI and isolated review, 296 regressions, full analysis, 615 current-main regressions, and native macOS cold-restart, explicit review, attachment, and uncertain-delivery checks. Other platforms and extended native cases remain unobserved. |
| Live billing verification | [#747](https://github.com/cedricziel/hermes-app/pull/747) | Merged after independent review, 310 combined tests, full analysis, strict specs, and all CI. Missing auxiliary App Lock coverage fails closed; one bounded macOS round observed details, simulated copy/browser callbacks, App Lock redaction, and the test-handler result. Extended native checks remain pending. |
| Resource refresh destinations | [#746](https://github.com/cedricziel/hermes-app/pull/746) | Merged after all CI and independent review. Prior 809 regressions and 180 catalog-union cases remain separate evidence. Final combined verification with merged Billing and Reaction passed the shared 351-regression and 128-catalog batches, full analysis, and strict specs. A later authenticated round verified sessions refresh with draft and selection retention. Cron redraw overlapped polling; messaging, pairing, coalescing, and extended native cases remain unchecked. |
| Verification guidance | [#748](https://github.com/cedricziel/hermes-app/pull/748) | Merged after all CI and delegated reflection, independent documentation review, final-newline checks, and full-analysis hooks. |
| Background status | [#726](https://github.com/cedricziel/hermes-app/pull/726) | Merged after isolated review, 103 integrated tests, analysis, and all CI; native mobile checks pending. |
| Encrypted queue store | [#723](https://github.com/cedricziel/hermes-app/pull/723) | Merged after isolated review, 27 storage tests, and all CI. Native macOS keychain persistence and backup protection verified in the isolated recovery fixture; other platforms remain unobserved. |
| Memory inspection | [#724](https://github.com/cedricziel/hermes-app/pull/724) | Merged after isolated review, 20 tests, all CI, and native list/detail/profile checks. Authentication and App Lock native transitions remain unobserved. |
| Memory editing and deletion | [#725](https://github.com/cedricziel/hermes-app/pull/725) | Merged after 38 memory tests, isolated review, native save/delete/draft/profile checks, addressed automated finding, and all CI. |
| Queue storage foundation | [#722](https://github.com/cedricziel/hermes-app/pull/722) | Merged after independent source review, analyzer, Swift parsing, and all CI builds; native macOS protection verified through recovery; other platforms remain unobserved. |
| Session state | [#721](https://github.com/cedricziel/hermes-app/pull/721) | Merged after independent review, automated approval, all CI, and 126 focused tests. Native progress, reclaim/reopen, draft retention, and paused queues verified; remaining native cases stay unchecked. |

## Suggested implementation order

Start with warnings, session state, notification retry, and advisory contract alignment. These improve existing workflows without adding new backend requirements. Queue recovery follows the durable store. Memory mutations follow inspection. Remaining live activity views can land independently after their documented prerequisites.

| Work | Proposal | Dependencies and boundaries |
| --- | --- | --- |
| Important warnings and notices | [Warnings](../openspec/changes/agent-visibility-warnings/proposal.md) | In-app risk and credit warnings; OS delivery stays with the existing notification system. |
| Running-task state and recovery | [Session state](../openspec/changes/agent-visibility-session-state/proposal.md) | Goal, loop, heartbeat, takeover, and resume progress. No unsupported control actions. |
| Backend compatibility evidence | [Advisory contract alignment](../openspec/changes/backend-contract-advisory-alignment/proposal.md) | Match committed REST and gateway provenance; retain advisory checks and free scripted tests. |
| Retrying request alerts | [Request alert retry](../openspec/changes/mobile-reliability-request-alert-retry/proposal.md) | Record announcement after OS acceptance; supersedes the pending background-refresh ordering rule. |
| Protecting queued prompts | [Durable queue store](../openspec/changes/mobile-reliability-durable-queue-store/proposal.md) | Encrypted records and attachment copies; separate local ownership from backend-accepted prompts. |
| Recovering queued prompts | [Queue recovery](../openspec/changes/mobile-reliability-queue-recovery/proposal.md) | Requires durable store. Recovery stays paused; uncertain submissions never resend automatically. |
| Explaining background delivery | [Background status](../openspec/changes/mobile-reliability-background-status/proposal.md) | Permission, availability, and last-check outcomes. No delivery-time guarantee. |
| Understanding session consumption | [Session usage](../openspec/changes/agent-inspection-session-usage/proposal.md) | Session totals and server-supplied cost. No inferred per-turn usage. |
| Inspecting learned memory | [Learned-memory inspection](../openspec/changes/agent-inspection-learned-memory/proposal.md) | Existing profile-scoped learning APIs; verify untyped response shapes with matching fixtures. |
| Editing and deleting learned memory | [Learned-memory mutations](../openspec/changes/agent-inspection-memory-mutations/proposal.md) | Requires inspection. Only memory nodes; permanent deletion and uncertain outcomes must be explicit. |
| Agent todo lists | [Todo state](../openspec/changes/agent-visibility-todo-state/proposal.md) | Verified snapshot fields and scoped resume restoration. |
| Background and side answers | [Side results](../openspec/changes/agent-visibility-side-results/proposal.md) | Keep side results distinct from the foreground reply. |
| Background process output | [Process output](../openspec/changes/agent-visibility-process-output/proposal.md) | Bound retained output. A closed terminal does not establish process success. |
| Advisor and aggregation progress | [MoA progress](../openspec/changes/agent-visibility-moa-progress/proposal.md) | Render only supported progress and reference output. |
| Connector operation progress | [Connector operations](../openspec/changes/agent-visibility-connector-operations/proposal.md) | Supported browser handoff and pending-operation recovery; no new connector APIs. |
| Device verification | [Billing verification](../openspec/changes/agent-visibility-billing-verification/proposal.md) | Existing verification flow only. Returning from a browser does not prove success. |
| Keeping lists current | [Change invalidation](../openspec/changes/agent-visibility-change-invalidation/proposal.md) | Refresh affected sessions, schedules, messaging, and pairing without treating broadcasts as list content. |
| Agent reactions | [Read-only reactions](../openspec/changes/agent-visibility-reactions/proposal.md) | Preserve verified message identity; never guess a target message. |

## Existing coverage and app-only limits

Hosted groups already specify approval actions and Stop recovery. The [unsupported hosted input requirement](../openspec/changes/bot-mode-group-protocol/specs/bot-mode-group-protocol/spec.md) explains clarify, sudo, and secret limitations, preserves polling and Stop, and prohibits attaching to hidden member sessions. No duplicate proposal is added. Answering those inputs in the room requires a backend contract that the current app cannot supply.

No push-enrollment proposal is added because the inspected app and bundled APIs have no push registration infrastructure. The background-status and notification-retry proposals improve current polling and local posting without claiming timely remote delivery.

Usage is session-wide in the verified gateway contract, including final completion usage. Memory inspection uses `/api/learning/graph` and `/api/learning/node`; `/api/memory` describes memory status, not learned-node content. Mutation proposals use the existing learning-node PUT and DELETE routes and do not add server endpoints.

## Validation and review

All 18 changes passed strict planning validation and report complete planning artifacts. Every index link resolves. Implementation task checkboxes record verified progress; remaining verification stays unchecked.

Run `openspec validate <change-name> --strict` for each linked change and `openspec status --change <change-name> --json` to check planning completeness. Validation checks artifact structure; implementation tasks still need their own tests and isolated app verification. Shared gateway routing, profile ownership, authentication, App Lock, and telemetry rules apply across the proposals.

Strict validation now passes all 147 existing changes and main specs. The historical `mac-menu-bar-extra` scenario omission was corrected in [#751](https://github.com/cedricziel/hermes-app/pull/751). All 43 main specs and all 18 gap proposals pass their strict checks.

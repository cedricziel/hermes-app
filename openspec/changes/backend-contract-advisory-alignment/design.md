## Context

See `proposal.md` for the compatibility mismatch. `real-backend-contract.yml` pins a backend SHA independently of `openapi/HERMES_REF` and `openrpc/HERMES_REF`. `update-hermes-contracts.yml` currently decides whether to open a PR from contract JSON differences, so provenance-only updates do not open a PR.

The existing test file includes local scripted-model scenarios as well as separately gated paid-provider scenarios. This change reuses those fixtures rather than introducing paid credentials.

## Goals / Non-Goals

Run an advisory check against the exact contract revision and make exclusions visible. Do not change required checks or promise compatibility with every Hermes version.

## Decisions

### Resolve and validate provenance before downloading

A small testable script reads both committed provenance files, trims trailing whitespace, requires matching full 40-character hexadecimal SHAs, and returns that revision. Missing, malformed, or mismatched files fail the advisory run before downloading a backend. Replace the workflow's separate hard-coded revision with this result and use it for the source archive and web-build cache key.

Keeping a separate workflow pin was considered, but permits the current mismatch to recur. Do not guess a supported release from a commit SHA.

### Detect provenance-only contract updates

The update workflow includes both provenance files in its change detection. A matching new upstream SHA therefore produces a reviewable update even if the JSON is identical. Regenerate the Dart client only when the OpenAPI JSON changed. Existing gateway classification tests remain responsible for new events.

### Preserve advisory semantics and bounded test cost

Keep the standalone workflow outside `Analyze & test`. Leave `HERMES_DEV_MODEL_CALLS` and `HERMES_DEV_TELEGRAM_PAIRING` unset. Verify that existing scripted-model turns execute without those flags; report their coverage separately from intentionally skipped paid-provider cases. Do not describe the whole suite as making no model calls: scripted local models are model calls without paid-provider access.

Use a fresh isolated home for each run because the current tests document that deleted profile state can make a reused backend fail. Cleanup stops only the process created by the checkout's helper.

### Report evidence without runtime telemetry

The workflow summary records pinned SHA, provenance agreement, suite outcome, and disabled paid/external pairing flags. Any latest-upstream advisory experiment remains a separate run reporting its own resolved SHA. No latest experiment is added by this bounded change.

## Platforms and invariants

No runtime changes on iOS, Android, macOS, Windows, Linux, or watchOS. No native entitlements, manifests, or Xcode changes. Tests run on the existing Linux runner. Preserve isolated state, generated-client ownership, and existing authentication behavior. No new application spans, log events, or breadcrumbs; CI summaries contain fixed outcomes and public revision hashes only, never user content, tokens, or private server addresses.

## Risks / Trade-offs

- An aligned revision can expose genuine test failures. Keep failures visible as advisory results and fix compatibility rather than falling back to an unrelated older pin.
- Backend installation or network failures can prevent evidence. Report failed setup separately from passed tests; do not convert either to a green test outcome.
- Provenance-only updates can create additional weekly PRs. Their benefit is explicit source traceability; they need no generated-client churn.

## Migration Plan

Land one tooling PR of roughly 500 changed lines or fewer, titled with a conventional `ci(api)` scope. Run the workflow manually and verify the resolved SHA and exclusions. Rollback reverts the tooling change and does not affect application data or required checks.

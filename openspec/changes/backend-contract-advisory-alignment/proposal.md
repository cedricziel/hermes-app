## Why

The bundled REST and gateway contracts identify one Hermes revision, while the advisory real-backend workflow runs another. A passing check therefore does not establish compatibility with the revision used to generate the client.

## What Changes

- Resolve the advisory backend revision from the committed REST and gateway provenance files, and fail the advisory run clearly if they disagree.
- Refresh provenance with the contracts even when an upstream revision produces identical contract JSON.
- Keep backend checks advisory. Do not add them to the required `Analyze & test` job or change repository rules.
- Reuse the existing free scripted-model tests for deterministic turns. Report deliberately skipped paid-provider tests separately from passing coverage.
- Keep any latest-upstream experiment separate from the pinned check, with its resolved revision reported.

## Capabilities

### New Capabilities

None. This change updates development tooling only; `.openspec.yaml` opts out of delta specs with `skip_specs: true`.

### Modified Capabilities

None.

## Impact

Affected files include `.github/workflows/real-backend-contract.yml`, `.github/workflows/update-hermes-contracts.yml`, provenance validation script tests, and the development instructions in `CLAUDE.md`. No Hermes backend API changes are required.

The current provenance files identify `167e9fdb84248cd0fff80762dc57b6a914b6e930`; the workflow pins `7b3c7aef31da73aabab0aa7fd15fdfe7c838834e`. Implementation must resolve committed values rather than hard-code either revision.

### Non-goals

No merge gate, paid model calls, minimum-version matrix, native platform builds, or Hermes server changes. A latest-upstream run is not evidence that the pinned revision passed.

### Security and privacy

Use an isolated backend home, OS-assigned loopback port, and scripted local model. Do not inherit personal Hermes state or provider credentials. Do not print session tokens or transcripts in workflow summaries.

### Observability

No application spans, log events, or breadcrumbs are needed because runtime behavior does not change. CI reports the resolved revision, provenance agreement, test outcome, and excluded paid tests so maintainers can interpret the advisory result.

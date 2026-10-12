## Why

The Swift package excludes SwiftUI, VoiceRecorder, and WatchConnectivity. Passing core tests cannot establish watch and phone lifecycle behavior or native storage isolation.

## What Changes

- Add a repeatable, isolated watch and phone verification procedure with synthetic sessions and credentials.
- Add native relay tests for callback races, missing Dart handler, and background expiry.
- Record a lifecycle matrix with evidence and explicit device-only limitations.

## Capabilities

### New Capabilities

None. This change adds verification tooling and documentation without changing product behavior. `.openspec.yaml` declares `skip_specs: true`.

### Modified Capabilities

None.

## Impact

Touches native test targets or verification-only seams, fixture support, and the project verify skill. Split fixture documentation and native tests into micro-commits within one PR, targeting fewer than 500 changed lines.

Non-goals: new delivery behavior, production entitlements, and claims that simulators prove hardware or operating-system delivery guarantees.

Security and privacy: use a dedicated simulator pair or disposable device setup with isolated preferences, caches, keychain access, app groups, routing, and backend storage. Never reuse personal credentials or destinations.

Observability: no new production spans, log events, or breadcrumbs. Capture existing sanitized relay logs and test outcomes as local fixture evidence.

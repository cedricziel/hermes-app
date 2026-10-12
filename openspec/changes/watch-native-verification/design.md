## Context

`ios/HermesWatch/Package.swift` tests only `Core`. `WCSessionTransport.request` bridges reply and error callbacks into an async continuation. `ios/Runner/WatchRelay.swift` guards its reply against background expiry racing the Dart response. The current verify skill proves neither isolated mobile entry points nor these native paths.

Platforms: iOS and watchOS verification targets, macOS development host. Android, macOS product UI, Windows, and Linux are unaffected. Add Xcode test-target membership if necessary. Keep production entitlements and manifests unchanged; fixture-only bundle identifiers and signing settings must not ship.

## Goals / Non-Goals

Goal: provide meaningful native evidence before watch behavior changes are called complete.

Non-goal: replace Swift core and Dart HTTP-layer tests with UI automation.

## Decisions

Use a dedicated freshly created simulator pair, verified as empty before installation. Require preflight evidence of the created pair identifiers, isolated storage and routing, synthetic credentials, built plist and entitlements, and throwaway backend home. Missing or failed evidence rejects launch. Review native storage paths, shared groups, keychain services, preferences, URL schemes, Handoff routes, and background entry points. Use temporary fixture identifiers and synthetic credentials. A unique bundle ID alone is insufficient. If a hardware check cannot be isolated, record it as unavailable and do not run it against personal state.

Build narrow native relay tests around injectable callback and background-task boundaries while keeping production behavior unchanged. Exercise reply then expiry, expiry then late reply, missing handler, malformed reply, and activation failure. Test each underlying API according to its documented callback contract; do not require new duplicate-callback recovery behavior in this tooling-only change. If a test reveals a production behavior bug, open a separately specified behavior change rather than silently fixing it here. Assert exactly one native reply or continuation completion and background-task cleanup. Avoid replacing Hermes repository tests with generated-client mocks.

Maintain a matrix for cold launch with backgrounded phone, watch sleep and wake, phone process termination after submission, disconnection and reconnection, delayed approval, Stop waiting followed by late completion, voice interruption and recording limit, logout during an operation, owner or server switch, delayed invalidation arriving after a fresh handshake, legacy cache migration, and watch/phone protocol-version skew. Link each case to the staged change defining its expected result. Cover smallest supported screen and larger Dynamic Type for new controls. Simulator results must remain separate from paired-device results because mirrored notification actions and real background scheduling may require hardware.

Project invariants: keep tokens in isolated secure storage, use the generated REST client, and keep telemetry opt-in and non-blocking. Fixture evidence captures only fixed outcomes and numeric codes. Do not capture message contents or credentials in logs. Synthetic UI screenshots can contain synthetic text.

Observability adds no production signals. Reuse `watch.request.started`, `watch.request.completed`, and native Apple logs. Record toolchain, OS versions, fixture isolation checks, case, expected result, actual result, and evidence location. A missing device or unsupported automation is a coverage gap, never a pass.

## Risks / Trade-offs

- Native background behavior may be unavailable in the simulator. Keep an explicit hardware section and block claims of full lifecycle verification until checked.
- Fixture settings could leak into release builds. Verify built identifiers and entitlements, keep changes under verification configuration, and test that ordinary targets retain their configuration.
- Native test setup could exceed one PR. Keep the first change limited to the fixture procedure and relay callback tests; feature changes own their acceptance cases.

## Migration plan

Introduce the verification procedure before broader watch UX changes. Clean up only fixture-owned processes, simulator pair, backend, and temporary files. Do not stop unrelated Hermes backends or modify personal app storage.

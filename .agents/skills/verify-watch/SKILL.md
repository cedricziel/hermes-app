---
name: verify-watch
description: Verify watch lifecycle behavior using a disposable watch and phone pair.
---

# Verify the watch companion

Read `.claude/skills/verify-in-app/SKILL.md` for backend setup. Do not launch an
ordinary build on personal hardware or erase an existing simulator.

## Verify without a simulator

Use this path when the user excludes simulators. Do not create, boot, install,
or launch simulator devices. Run portable Swift core tests, Dart relay tests,
static analysis, and a watchOS device-target compile with signing disabled.
Limit compiler concurrency to two jobs and run verification commands sequentially.
Keep one reusable temporary build directory rather than parallel scratch builds.
Check free disk space before building and stop on resource failures.

RunnerTests that need an iOS host, visual layout, VoiceOver interaction, mirrored
notifications, and actual sleep/wake delivery remain unverified in this mode.
Record those gaps. A compile or portable test does not establish native lifecycle
behavior. Do not launch simulators later to fill those gaps without the user's
explicit authorization.

## Establish isolation before launch

1. Create `/private/tmp/watch-fixture-<run>`, where `<run>` uses lowercase
   letters and digits. Keep backend storage, build output, and evidence there.
2. Inspect `xcrun simctl list runtimes -j` and `xcrun simctl list devicetypes -j`.
   Choose available compatible iOS and watchOS runtimes and the smallest watch.
3. Use `xcrun simctl create <name> <type> <runtime>` to create devices named
   `watch-fixture-<run>-phone` and `watch-fixture-<run>-watch`. Record returned
   UDIDs. Pair with `xcrun simctl pair <watch-udid> <phone-udid>`. Save the pair ID
   and `xcrun simctl list -j` output.
4. Boot only those devices. Before installation, inspect their containers and
   confirm no Hermes storage or migrated credentials. Do not restore backups
   or sign into an Apple Account.
5. Review TokenStore, preferences, caches, keychain access groups and fixed
   services, share inbox, complication storage, WatchConnectivity context,
   intents, and background-engine entry points. Record each storage path and
   routing entry. Fresh simulators isolate their storage. Any host-shared path
   requires a fixture substitution before launch.
6. Build temporary copies outside the checkout. Use identifiers beneath
   `app.hermes.fixture.<run>` for phone, watch, and extensions. Keep companion
   identities consistent. Disable URL schemes, Services, Handoff, App Groups,
   and iCloud. Inspect every built Info.plist and
   `codesign -d --entitlements :- <app>`, including nested extensions. Record
   the inspection. Fixture changes must not ship. Confirm ordinary target
   settings still match their checked-in configuration.
7. Start an isolated backend with a home beneath the fixture directory and a
   free port. Confirm `/api/status` reports that exact home. Use invented chats
   and synthetic credentials. Apply the backend skill's profile alias isolation
   before creating profiles. Do not inherit personal tokens or model keys.
8. Write a manifest and run `python3 scripts/watch-preflight.py <manifest>`.
   Rejection prevents installation or launch. The script reads live simulator
   inventory, pairing, backend status, built plists, and entitlements. Review
   flags are attestations backed by saved evidence, not automatic proofs.

The manifest has `run_id`, `fixture_root`, `backend_home`, `backend_url` using
`http://127.0.0.1:<port>`, `credentials: "synthetic"`,
`storage_review: "fresh-pair-no-host-storage"`, and `routing_review: "disabled"`.
Both `phone` and `watch` contain `udid`, `app`, and these true review flags:
`created_for_run`, `empty_before_install`, `built_plist_review`, and
`built_entitlements_review`. Keep manifests local because they contain paths
and device identifiers. Review nested extensions before setting review flags.

## Exercise native behavior

Run `swift test --package-path ios/HermesWatch`. Run RunnerTests with isolated
build output on the dedicated phone:

```sh
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,id=<phone-udid>' \
  -derivedDataPath <fixture-root>/DerivedData \
  -only-testing:RunnerTests -resultBundlePath <fixture-root>/relay.xcresult
```

RunnerTests inject Dart-result and background-task callbacks into WatchRelay.
They cover expiry before and after reply, missing Dart handler, invalid Dart
result, exactly one reply, and background-task cleanup. They do not prove
system wake delivery, suspension, or WatchConnectivity activation. The test
host needs the isolation preflight before launch.

Install and launch only the recorded fixture devices and bundles. Exercise
[the evidence matrix](evidence-matrix.md). Capture invented UI text on the
smallest supported screen and with larger Dynamic Type. Use existing
`watch.request.started`, `watch.request.completed`, and native Apple logs.
These diagnostics contain fixed outcomes and numeric codes. Do not add
production telemetry or capture prompts, credentials, or addresses in logs.

Record commit, toolchain, OS versions, preflight evidence, expected result,
actual result, and evidence path for each case. Keep simulator and hardware
results separate. Use passed, failed, or unavailable with a reason. Missing
hardware and unsupported automation are gaps, never passes.

## Clean up only fixture resources

Stop processes whose PID and ownership you recorded. Shut down the two fixture
UDIDs, unpair the recorded pair ID, and delete only those devices. Preserve
sanitized evidence before removing the temporary directory. Stop apps before
restoring exact backups of fixture substitutions. Inspect git diff for
unintended configuration changes. Never use `hermes dashboard --stop`,
`simctl erase all`, or `simctl delete all`.

Use a disposable hardware setup without personal app state for device-only
checks. Inspect storage and signing before installation. If isolation cannot
be established, record those cases as unavailable and do not launch.

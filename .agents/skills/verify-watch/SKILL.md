---
name: verify-watch
description: Verify watch lifecycle behavior using a disposable watch and phone pair.
---

# Verify the watch companion

Read `.claude/skills/verify-in-app/SKILL.md` for backend setup. Do not launch an
ordinary build on personal hardware or erase an existing simulator.

## Respect the current host constraints

For the watch quality series, the user excluded watch simulators on 2026-10-13
and asked agents to limit host load. Do not create, boot, install, or launch
simulator devices. Do not run local native builds, `swift test`, or native
Xcode tests unless the user later authorizes them. Use cloud CI for Swift core
tests, native host tests, and platform compilation. A simulator SDK build in
cloud CI does not authorize launching a simulator on the user's computer.

Run at most one local headless Flutter check at a time, with
`flutter test --no-pub --concurrency=2 <focused-test-files>`. Serialize tests,
formatting, analysis, and commit hooks. Read host load and free disk space before
resource-intensive work. If the host becomes constrained, stop the task-owned
check and move that validation to cloud CI. Do not kill unrelated processes or
remove shared caches. Keep temporary outputs bounded and remove only resources
created for this task.

Record the exact commit and selected tests. Test the staged implementation in an
isolated checkout when the shared working tree contains later layers. Reuse
resolved dependency metadata without installing extra toolchains or launching
an app. Headless tests do not establish native layout or delivery behavior.

Native visual layout, VoiceOver interaction, gestures, microphone interruption,
mirrored notifications, and real sleep/wake delivery remain unverified until
checked on an isolated physical device pair. Cloud compilation and core tests
do not substitute for those checks. Mark unavailable cases with a reason, never
as passed. Follow the physical-device isolation requirements below before any
later device check. Simulator procedures below apply only after renewed user
authorization.

## Check the 13 behavior changes

Use synthetic data and the current scoped protocol. These cases cover the source
contract; the evidence matrix records native acceptance separately.

| Change | Portable checks and expected behavior | Native acceptance still required |
| --- | --- | --- |
| Native verification | Preflight rejects personal or unverified storage and routing. Core tests cover narrow relay seams. RunnerTests source targets one reply and background cleanup; its native execution remains unverified. | Cold launch, background wake, activation, suspension, and notification delivery. |
| Session privacy | Remembered replies require authorization. Confirmed departure clears cached chats, drafts, retry audio, pending navigation, and private status. A late result cannot restore them. Deletion failure leaves a persisted cleanup marker and startup retries cleanup. Transient refresh failure must not impersonate confirmed departure. | Logout while viewing cached content or recording; reconnect after unreachable-phone logout. |
| Context identity | Same-owner restart and token refresh retain protected context. Server or owner departure rotates context. Storage failure blocks content. Version 2 IDs preserve delimiter characters and historical profiles. Legacy or mismatched requests fail before repository access. Check every post-await guard, stale publication, complication target, handoff, and legacy startup cleanup. | Owner/server switches, offline cold launch, delayed updates, and handoff on a paired device. |
| Send-attempt isolation | Leave waiting locally, start another attempt, then deliver every old reply kind. Old results must not mutate messages, phase, identity, Handoff target, retry state, or poll ownership. | Leaving a wait during disconnect and sleep/wake. |
| Send journal | Persist reservation before dispatch and exact completion before acknowledgement. Identical concurrent IDs join; changed target or payload fails. Restart lookup never guesses from latest assistant history. Unknown retry never dispatches. Test corruption, protected-storage failure, retention, timestamp expiry and future skew, tombstone pressure, slot release, and deletion failure. No prompt or token belongs in journal diagnostics. | Terminate the phone after dispatch but before acknowledgement, then recover the exact result. |
| Send recovery | Restore the original ID and timestamp after a fresh handshake. Check result before offering explicit resend. Pending status does not permit resend. Unknown delivery requires a duplicate-risk confirmation and a new ID; cancellation submits nothing. Preserve the uncertain original. Forget recovery releases local state without cancelling server work. Old phones show compatibility guidance. | Watch restart, lost reply, capacity failure, and confirmation controls on the smallest screen. |
| Voice review | Default transcription waits for review. Editing changes only the draft. Manual fast-send is optional. Duration-cap, interruption, natural stop, and retry always require review. Empty speech, discard, auth reset, and late transcription cannot submit. Discard or retry must not release another operation's busy state. | Microphone interruption, duration-boundary stop, manual gesture, review editing, and VoiceOver focus. |
| Conversation usability | Outgoing rows distinguish submission, accepted evidence, and uncertain delivery. Guard Edit against existing drafts and owner changes. Check result and resend use recovery rules. New completion reveals the answer start only while following; history readers retain position and get a New reply control. Historical messages never impersonate a new completion. | Reading position, chronological speaker announcements, focus, and large-text recovery controls. |
| Request guidance | Waiting text names notification and iPhone answer paths. Leave waiting closes local waiting and retains the accepted user message. It must not claim server cancellation. | Delayed mirrored notification and local waiting controls. |
| Inline approvals | Gate details and answers with verified owner, revision, request epoch, and App Lock state. Show the complete current command and exact offered choice. Confirm affirmative choices, deny immediately, and prevent duplicate activation. Expiry and lost acknowledgement permit status checking, not blind resubmission. | Long commands, lock changes, confirmation, Deny, and stale request controls. |
| Inline questions | Preserve exact question IDs and values through the structured answer path. Test text, single choice, multiple choice, multi-question progress, invalid choices, cleared drafts, expiry, and unknown acknowledgement. Request answers never become ordinary chat prompts. | Selection, text entry, progress, and accessibility on the watch. |
| Glanceable chats | Optional profile and known status metadata has old-peer fallback. Unknown status stays unknown. Persist messages and their fetchedAt atomically; failed writes retain both old values. First observation establishes a seen baseline. Only a successful fresh read clears its captured update, never a later update. Owner reset clears metadata and seen markers. | Profile/status/freshness rows, New chat label, large text, and non-color update markers. |
| Contextual actions | Empty new chats offer editable built-in starters without overwriting a draft or sending. Completed idle answers offer ordinary Continue and Summarize. Busy, uncertain, voice, or request states suppress ordinary actions. Stale activation submits nothing; exact request actions use the request views. | Starter editing, ordinary follow-ups, gesture behavior, large text, and VoiceOver action labels. |

## Choose focused portable tests

Phone suites live in `test/watch_auth_gate_test.dart`,
`test/watch_session_publication_test.dart`, `test/watch_context_test.dart`,
`test/watch_context_relay_test.dart`, `test/watch_request_handler_test.dart`,
`test/watch_bridge_test.dart`, `test/watch_send_journal_test.dart`,
`test/watch_send_journal_relay_test.dart`, `test/watch_request_actions_test.dart`,
and `test/watch_glanceable_relay_test.dart`. Include
`test/intents/ask_hermes_test.dart` and `test/background/background_alerts_test.dart`
when changing the shared send handler. A trusted local intent must remain usable
without weakening the watch's scoped protocol checks. Include the gateway receipt
tests when changing `PromptAcknowledged` or transport acceptance evidence.

The existing cloud CI runs the Swift package tests in `ios/HermesWatch`. Native
Xcode tests in `ios/RunnerTests/RunnerTests.swift` need a separate isolated cloud
job if that coverage is required. Do not report those tests as executed from a
compile-only platform job. Core source and
regressions live under `ios/HermesWatch/Core` and
`ios/HermesWatch/Tests/HermesWatchCoreTests`. Check privacy, context, outbox,
recovery, voice ownership, presentation, request access, glanceability, and action
selector regressions relevant to the change. Run formatting and static analysis
for changed Dart files and strict OpenSpec validation for touched changes. Record
cloud checks against the PR's current commit; an older green run is not evidence
for a later revision.

SwiftUI previews and DemoClient modes provide synthetic fixtures, not acceptance
evidence. Inspect the checked-in fixture source before naming a mode. Do not
claim a preview was rendered when only its source was reviewed.

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

## Exercise native behavior after authorization

The current host constraint above takes precedence over these commands. Do not
run this local native loop during the current series.

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

# Messenger verification

## Source and scope

Base: `504175f5`. Branch: `codex/messenger-chats-home`.

The implemented slice includes compact Chats navigation, local profile
recipients, scoped drafts and attachments, and authenticated avatar reads.
All-agent aggregation, unified Agents management, previews, and Groups
integration remain separate changes. No generated API, native project,
dependency, or telemetry contract changed.

## Automated checks

- Initial navigation, local-selection, avatar, and ownership regressions were
  observed failing before their corresponding fixes where practical.
- The full suite identified obsolete compact-navigation fixtures and draft
  ownership regressions. Each failure is covered by the corrected focused run.
- The 64 new messenger Widgetbook combinations passed across light/dark themes
  and phone/desktop frames.
- `flutter test --concurrency=4`: 11,942 passed, 116 skipped, 15 failures.
  Those failures exposed the ownership fixes and fixture updates described
  above. A subsequent run of all affected files and new messenger regressions,
  `flutter test --concurrency=1`, passed all 118 tests. The complete suite was
  not repeated after those corrections.
- `flutter analyze`: no issues on the final source.
- `openspec validate messenger-chats-home --strict` passed;
  `openspec validate --specs --strict` passed all 68 main specs.
- Formatting and staged whitespace checks passed through normal commit hooks.
- `flutter build ios --simulator --debug` passed on the final source with the
  fixture URL supplied through `HERMES_SERVER_URL`.

## Isolated native check

The run used a fresh iPhone 17 Pro simulator, iOS 27, named
`Hermes Messenger Verification`, UDID
`F80899B9-DFFE-414B-A0F8-8A0EB093A78B`. Its logical screen is 402 × 874.
Device Hub provided native interaction and screenshot inspection. The app was
installed only into that simulator; its fresh app container was checked before
launch.

The backend used `/private/tmp/hermes-messenger-verify-QJqaR8/home` and
`127.0.0.1:61070`, launched with a scrubbed environment and isolated runtime
home. The manifest recorded listener ownership and `/api/status` confirmed the
exact fixture home. Only synthetic default/work chats and a small generated
work avatar were seeded. Replies used the existing local Ollama instance with
a synthetic credential, without personal provider settings.

Observed through the native UI:

- Ordinary launch showed full-page Chats and synthetic default conversations.
- New message offered default/work recipients with a monogram and configured
  work image. The work image appeared in rows, picker, chip, and header.
- An unsent work draft survived header Back and reopening without a send.
- The native edge gesture returned from detail to Chats.
- The Chats menu reached Bots and returned through the existing shell.
- A work reply remained active after Back, showed Working in Chats, and
  completed with “Hello there!” after reopening.
- A synthetic work deep link opened its target directly in detail.
- Read-only backend inspection after local recipient selection reported both
  active and current profiles as `default`.

The backend did not retain access logs, so native absence of mutation requests
is established by the unchanged active profile plus automated HTTP/RPC
assertions. Account image cleanup, invalid images, unavailable recipients,
protected navigation, resize, and desktop parity use automated regression
coverage; native desktop and account replacement were not exercised.

## Completion

The final rebuilt app repeated ordinary Chats launch, work recipient/avatar
selection, and unsent-draft Back/reopen successfully. Backend active/current
remained `default`, and the unsent draft created no backend session.

The fixture app was terminated, its simulator shut down and deleted, and only
the recorded backend PID was stopped. The loopback listener was confirmed gone.
The fixture root and task-owned temporary evidence were removed. The existing
local Ollama service was left running.

## Selector-state follow-up

A separate native run used the disposable iPhone 17 Pro simulator
`Hermes Selector Verification 20261016`, UDID
`3BC71216-2246-48DB-9DFF-393359CC83EE`. Its fixture manifest, removed during
teardown, recorded `/private/tmp/hermes-selector-verify-MXuo5e`. The app
connected through the fixture-only loopback proxy at
`http://127.0.0.1:57392`, forwarding to backend `127.0.0.1:57040`. The proxy
controlled only `/api/profiles` and `/api/model/options`; it forwarded the
remaining HTTP and WebSocket traffic to the isolated backend. Proxy logs store
route paths without query strings.

Observed in the native UI:

- Model discovery showed Loading, then Failed with a separate Retry after the
  held request timed out. Releasing the route to the real empty fixture response
  changed the composer to Set up a model. The `Test` draft remained and Send was
  disabled.
- Setup guidance for work showed `hermes -p work model`. After configuring
  only the fixture work profile with local Ollama, Check again showed
  `gemma4:e4b`; Send became enabled and the existing draft remained. The model
  picker displayed provider `custom` with `gemma4:e4b`.
- A `/api/profiles` 503 showed Could not load recipients and its own Retry while
  the model stayed ready. Retry against an empty profiles response showed No
  profiles available and Set up profiles; opening setup reached Profiles.
- Restoring the real profile response and returning from setup retained the
  `T` draft and selected `To: work` recipient. Holding profile discovery showed
  Loading recipients while retaining `T` and disabling Send. Temporarily moving
  the work profile directory elsewhere within the disposable fixture made the
  released real response show work unavailable; restoring the directory and
  retrying returned the selected work recipient to ready.
- The UI sent `T`. The local reply completed in the chat titled `Single letter
  input session` with: “Could you please provide more context or let me know
  what you would like assistance with?” The completed message showed Copy,
  Try again, and Edit actions, with no remaining Thinking or Stop state.
- The final simulator rebuild succeeded in 33.1 seconds and the rebuilt app
  was reinstalled and launched on this disposable device. On the final New
  message screen, `To: work` and `gemma4:e4b` were both visible. The final
  `flutter analyze` run reported no issues in 11.2 seconds. The simulator's
  Capture Keyboard setting was restored to off after the check.

The proxy's authenticated profile-list request and a read-only
`profiles.get_asset` WebSocket RPC also passed; the latter returned the seeded
work avatar metadata. Automated verification reported 299 broader checks, 27
focused checks, 64 integrated messenger cases, 104 catalog checks, and 20 pure
checks. These groups overlap and must not be added together. The latest native
build and reply completed. The native run verified model setup and Retry,
recipient loading/empty/error/recovery, profile unavailability and recovery,
draft retention, ready-state model/recipient labels, and a successful local
send. Resize, desktop parity, account image replacement/cleanup, and protected
navigation remain covered by automated regressions rather than this selector
follow-up's native run. Teardown stopped fixture PIDs 25378 and 26655, shut down
and deleted simulator `3BC71216-2246-48DB-9DFF-393359CC83EE`, and removed the
fixture root and task-owned temporary logs. Both fixture listeners were
confirmed gone; the existing development backend on port 62207 and local
Ollama service were left running.

## Pull request evidence and remaining checks

PR #770 compares six rendered screens at a 390 × 844 logical viewport on
`main` (`504175f5`) and the feature branch (`8010fb1d`): launch, conversation,
recipient selection, and loading, incomplete, and failed discovery. Both
six-scene render runs passed with matching synthetic fixtures. These renders
are separate from the native iPhone checks above. The baseline recipient image
uses Profiles because the baseline has no New message recipient dialog.

Task 3.4 remains open for the native desktop and account-replacement checks.
Automated coverage does not establish those native results.

The initial PR run failed two assertions: unsupported-profile discovery used
an inconsistent fixture, and an initial startup target discarded a held quote.
The fixture now marks profile discovery unsupported. Startup delivery adopts
only the initial request and still lets later navigation supersede it. Review
also found a moved draft retained under its old recipient key; the successful
transfer now removes that cached text and attachment list. A retirement/remount
regression preserves the closed account boundary and verifies fresh owner reads.
The nine-file follow-up batch passed 104 tests; formatting and scoped analysis
were clean. These flow corrections were checked in widget tests, not another
native run.

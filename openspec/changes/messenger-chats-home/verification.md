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

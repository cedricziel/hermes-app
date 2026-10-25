# Tasks

One PR, `feat(bot-screen): read the bot's screen state over the gateway`, about 450 changed lines including tests and the skill. First of eight Bot Screen changes; no UI.

## 1. Gateway plumbing

- [x] 1.1 Write failing tests in `test/gateway/`: an error answer with `data: {code: "viewer_mismatch"}` yields a `GatewayRpcException` whose `data` and `dataCode` hold it; `requestKeepingConnection(..., timeout:)` that gets no answer throws `GatewayRequestTimeout` and the next `request` reuses the same connection; the default `request` still drops the connection on timeout.
- [x] 1.2 Add `GatewayRpcException.data`, `GatewayRequestTimeout` and `requestKeepingConnection`; verify 1.1 and the existing transport tests pass.

## 2. Repository and contract

- [x] 2.1 Write failing tests for `BotScreenRepository` against a fake gateway: every call sends `profile`, and `default` when built for the default profile; `display.status` parses every field the spec names, tolerates missing optional ones and yields `unsupported` on `-32601`; `display.thumbnail` decodes a JPEG data URL, maps `data_url: null` with `suppressed` to suppressed and without it to stopped; 5300, a timeout and a closed connection yield `failed` with the matching kind; `display.start` returns the new status or the failure.
- [x] 2.2 Implement the repository and models; verify 2.1 passes.
- [x] 2.3 In `test/gateway/gateway_contract_test.dart`, change `display.status` and `display.lease` in `notifications` to `Use.transport` with the reason "Bot Screen state"; verify the contract test passes.
- [x] 2.4 Add `display.status` and `display.thumbnail` shape checks for the default profile to `test/real_backend_contract_test.dart` (skipped without `HERMES_DEV_URL`, like the rest); on a macOS backend expect `supported: false`.

## 3. Controller

- [x] 3.1 Write failing tests for `BotScreenController` with a fake clock: it polls every 3 s only while demand is held, the status is running, and it is foreground and unlocked; never two requests in flight; a `display.lease` broadcast with `holder: human` for its `profile_key` clears the frame at once, one for another key changes nothing; `display.status` with `running: false` clears the frame; it re-reads status on gaining demand, on `GatewayConnectionEvent.lost` while demanded, on resume, and with every 10th poll; a frame answer arriving after `unlocked = false` or dispose is dropped; Start goes off → starting → running, or back to off with the failure.
- [x] 3.2 Implement the controller; verify 3.1 passes.

## 4. Observability

- [x] 4.1 Write failing tests with a recording telemetry and event logger: a thumbnail records `bot_screen.thumbnail` with `outcome` and `bytes_kib` only; method-not-found logs `bot_screen.unsupported` once per connection; a failed call logs `bot_screen.read_failed` with `method` and `error_type`; no attribute holds a data URL, path or profile name. Implement and verify.

## 5. Docs and skills

- [ ] 5.1 Add a Bot Screen paragraph to `CLAUDE.md`'s Architecture: `lib/src/bot_screen/`, explicit `profile` (`default` for the default profile), the display timeout that keeps the connection, when status is re-read, and the minimum Hermes version.
- [ ] 5.2 Create `.claude/skills/verify-bot-screen/SKILL.md`: start a throwaway Linux Hermes with the desktop packages in a container (`nousresearch/hermes-agent:latest-desktop` or a pinned `-desktop` tag; `nousresearch/hermes-sandbox:desktop` for the sandbox placement) with its own ports and `HERMES_HOME` volume, start a profile's screen (`display.start` or a `computer_use` turn), point `scripts/dev-app.sh` or `HERMES_DEV_URL` at it, and tear the container and volume down afterwards. Say that a macOS host reports `supported: false`, so the `scripts/dev-backend.sh` backend on a Mac never shows a screen. Never mount the real `~/.hermes`. Reference it from the `verify-in-app` skill.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 6.2 Following the new `verify-bot-screen` skill, run `test/real_backend_contract_test.dart` with `HERMES_DEV_URL` against the container backend with a started screen, and record the result in the PR. No verify-in-app run: there is no UI.

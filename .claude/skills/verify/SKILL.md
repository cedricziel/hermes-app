---
name: verify
description: Use before opening a PR that changes connection, sign-in, API, gateway or chat behaviour in hermes-app, or when asked to certify a change against a real backend in a Linux cloud container — runs the contract tests against a throwaway Hermes at the pinned revision and drives the real Linux app (sign in, send a prompt, see the reply) under Xvfb, then cleans up everything.
---

# Verify against throwaway instances (Linux)

`scripts/verify.sh` certifies a change against real, disposable instances in
one command. It runs on Linux, including a cloud container (root, no Xcode,
no Android SDK, no devices). On a Mac use `verify-in-app`, which runs the
macOS app and covers the native features this cannot.

| Where you are                                  | Use                                                           |
| ---------------------------------------------- | ------------------------------------------------------------- |
| Linux, cloud container, CI-like box            | this skill (`scripts/verify.sh`)                              |
| Mac, native UI, menu bar, iOS simulator, watch | `verify-in-app`                                               |
| Bot Screen (`display.*`)                       | `verify-bot-screen`                                           |
| Bot Mode hosted rooms in depth                 | `verify-bot-mode-contract` (its contract test also runs here) |

## When

Before every PR that changes connection, sign-in, API, gateway or chat
behaviour, after `dart format`, `flutter analyze` and `flutter test` pass.
UI-only changes are checked in the Widgetbook catalog (`component-catalog`)
and the workflow screenshots (`workflow-screenshots`); run `verify.sh app`
too when the change touches sign-in or the chat screen. Put the final lines
of the run in the PR body.

## Commands

```bash
scripts/verify.sh            # both tiers (about 5 min warm, 10 cold)
scripts/verify.sh contract   # backend + contract tests only
scripts/verify.sh app        # backend + app only
scripts/verify.sh clean      # sweep runs left by a verify.sh killed with SIGKILL
```

Exit 0 and `[verify] verify all passed` (printed last, after cleanup) mean
every tier passed and nothing of the run survived. Screenshots
and logs are in `build/verify/<time>-<id>/` (not committed): read
`shots/*.png` with the Read tool. First time in a container, install the
packages in [reference.md](reference.md#packages) (one `apt-get` line). Run `flutter pub get`
once beforehand (Flutter runs with `--no-pub`). The first run needs network
access to GitHub, npm and PyPI to install Hermes (cached afterwards) and
builds the Linux app from scratch. `build/verify/` keeps the newest ten runs.

## What each tier proves

1. **Backend.** `scripts/install-hermes.sh` installs Hermes at
   `openapi/HERMES_REF` (resolved by `scripts/hermes_contracts.py resolve`)
   as `real-backend-contract.yml` does, into `~/.cache/hermes-agent/<sha>`
   (code only, reused). Each run then starts dashboards through
   `scripts/dev-backend.sh` with their own HERMES_HOME and HOME in a temp
   dir, on an OS-assigned port, and checks the PID it recorded runs on that
   home.
2. **Contract** (`contract`): `test/real_backend_contract_test.dart`,
   `test/bot_mode_chat_contract_test.dart` and
   `test/bot_mode/group_protocol/real_groups_contract_test.dart` against a
   no-auth loopback backend, with `HERMES_DEV_MODEL_CALLS`,
   `HERMES_DEV_TELEGRAM_PAIRING` and `HERMES_DEV_BOT_SCREEN` unset. Proves
   the generated client, the lenient repositories and the gateway still match
   the pinned backend, including free scripted-model turns. Skipped tests
   prove nothing; say so. They are the paid-model, Telegram, Bot Screen and
   files-root checks, and the ones that need a provider on the default
   profile (`approval.pending` there, a profile's own default model): the
   contract backend has none, as in CI.
3. **App** (`app`): `flutter test -d linux integration_test/verify_flow_test.dart`
   builds and runs the real app under its own Xvfb display, a private D-Bus
   session with an unlocked throwaway gnome-keyring (and a stand-in
   NetworkManager on a private system bus), and an isolated
   HOME/XDG. The backend has the password gate on (synthetic user, random
   password per run) and a scripted model (`scripts/verify_scripted_model.py`,
   fixed reply, no key). The app signs in through its real RFC 8252 loopback
   - PKCE flow: `scripts/verify_browser.py`, registered as the http handler,
     plays the browser. Then it sends a prompt and waits for the reply.
     Screenshots: `01-sign-in`, `02-signed-in`, `03-reply`.

**Not proven here:** anything native outside Linux desktop: iOS, macOS,
Android, Windows builds and behaviour; notifications, Home Screen widgets,
Live Activities, the watch, Siri/App Intents, Spotlight, share extensions,
App Lock biometrics, Keychain behaviour, the menu bar. OIDC sign-in (only the
password provider runs), real model output, Telegram pairing and the Bot
Screen. Visual polish at phone width (the window is desktop-sized). Use
`verify-in-app` on a Mac, `verify-bot-screen`, or say plainly in the PR that
it was not checked.

## Adding a check

The PR that adds or changes behaviour in the areas above adds its check here,
in the same PR:

- API or gateway shape: a test in `test/real_backend_contract_test.dart`
  (skips without `HERMES_DEV_URL`), or a new `*_contract_test.dart` added to
  `run_contract` in `scripts/verify.sh`.
- A user flow: a `testWidgets` in `integration_test/verify_flow_test.dart`
  (or a new step with its own `shot(...)`). Keep it free: scripted model
  only, synthetic data only.
- Backend setup it needs (config, a second profile, a different model
  script): in `start_backend`/`run_app`, written into the run's temp home.

Then add a row to "Covered behaviour" below and run `scripts/verify.sh` twice.

## Reading failures

- `missing tools: ...`: install the packages in reference.md.
- `backend <name> did not start`: the dashboard log tail is printed above it;
  `build/verify/<run>/<name>-dashboard.log` has all of it.
- Contract failures: `contract-test.log`. A shape change in the pinned
  backend is a real finding; do not loosen the test to pass.
- App failures: `app-test.log` names the step (`sign-in did not finish`,
  `reply did not arrive`) and lists the visible texts. `browser.log` shows
  whether the stand-in browser was invoked and what the dashboard answered.
- More in [reference.md](reference.md#troubleshooting).

## Isolation and cleanup rules

- Every instance lives in `/tmp/hermes-verify.XXXXXX` (outside the working
  tree; the script refuses otherwise): backend homes, the backend's HOME
  (profile aliases land there, not in `~/.local/bin`), app HOME and XDG dirs,
  keyring, logs. Ports are OS-assigned, the X display is picked by Xvfb.
- Credentials are synthetic and new per run; nothing real is read, and the
  password is never printed or put on a command line. Never put a real key
  or account in.
- The script re-runs itself from an allowlisted environment (paths, locale,
  proxy and CA settings, package-manager locations, its own options) and
  refuses to start, or to keep a backend, with anything that looks like a
  token or key (`*TOKEN*`, `*_KEY`, `AWS_*`, `GH_*`, provider names…). A
  cloud session's own `GH_TOKEN` or AWS keys never reach Hermes, which would
  otherwise offer them as model providers.
- Never point anything at the real `~/.hermes`; never run
  `hermes dashboard --stop`; never `pkill -f` broad patterns.
- On any exit (pass, fail, Ctrl-C, TERM) the trap stops the backends by their
  recorded PIDs, kills the run's processes (those carrying this run's
  `HERMES_VERIFY_RUN` marker, plus their descendants and the members of the
  sessions the run created, started after the run began: Hermes scrubs the
  environment of some children), and deletes the temp dir. After SIGKILL no
  trap runs: the next `verify.sh` (or `verify.sh clean`) sweeps runs whose
  owner is gone. `clean` touches only real directories you own, never a
  symlink's target.
- One run per checkout at a time (a lock on `build/verify/.lock` refuses a
  second): runs share `build/linux` and the mimalloc seed. For a second run in
  parallel, use another worktree.
- The Linux build can rewrite tracked `linux/flutter/generated_plugin*`
  files: check `git status` and `git restore` them.
- The first run installs Hermes with `npm ci`, which runs third-party install
  scripts (as root in a container), as CI does.
- If isolation is unavailable (no `/proc`, cannot write `/tmp`, not Linux),
  do not run it; use `verify-in-app` on a Mac or report the check as not run.

## Covered behaviour

| Behaviour                                                                                                   | Tier     | Check                                                                     |
| ----------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------- |
| REST shapes the app reads (status, sessions, profiles, config, skills, plugins, MCP, memory, kanban, cron…) | contract | `test/real_backend_contract_test.dart`                                    |
| Gateway JSON-RPC: session create/resume, prompt, an approval answered (Allow once), branching, on a scripted-model profile | contract | same file, scripted-model group |
| Bot Mode chat registry, hosted group send/replay/stop/disband                                               | contract | `test/bot_mode_chat_contract_test.dart`, `real_groups_contract_test.dart` |
| Connect to a password-gated server from `HERMES_SERVER_URL`                                                 | app      | `verify_flow_test.dart` step 1                                            |
| Password sign-in via loopback + PKCE, session stored in secure storage (keyring)                                     | app      | step 2                                                                    |
| Send a prompt, receive the streamed reply in the chat                                                       | app      | step 3                                                                    |

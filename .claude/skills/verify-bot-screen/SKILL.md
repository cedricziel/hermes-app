---
name: verify-bot-screen
description: Use when a change touches the Bot Screen (lib/src/bot_screen/, the display.* gateway methods, the Activity panel's screen card, the live view or takeover) and must be checked against a real Hermes that has a running screen, or when asked to run a throwaway Linux Hermes with the desktop packages.
---

# Verify the Bot Screen against a real screen

A profile's Bot Screen (Xvnc and Xfce, driven by `computer_use`) exists only on Linux. A macOS or Windows Hermes answers `display.status` with `supported: false`, so the `scripts/dev-backend.sh` backend on a Mac can never show a screen. To see real frames, run Hermes in a throwaway container from the `-desktop` image, which ships the packages (`tigervnc-standalone-server`, Xfce, `chromium`) the plain image lacks. Fixtures prove parsing; only this proves the shapes, the broadcasts and the frames.

Hermes needs v2026.9.24 or later for `display.*`, `viewer_hash` and `display.install.sudo`.

Rules: never mount the real `~/.hermes` (use a named volume), never point the app or `hermes` at it, never run `hermes dashboard --stop`, and remove the container and volume afterwards. The commands below were written from Hermes' `Dockerfile`, `docker-compose.yml`, `docker.yml` and docker docs; correct this skill as soon as one turns out wrong.

## 1. Start the container

Use a Linux Docker host (or a Linux VM or remote box), because the dashboard must be reachable without its auth gate: a loopback bind needs no provider, a non-loopback bind fails closed without one.

```bash
docker volume create hermes-bot-screen-verify
docker run -d --name hermes-bot-screen-verify --network host \
  -v hermes-bot-screen-verify:/opt/data \
  -e HERMES_DASHBOARD=1 -e HERMES_DASHBOARD_HOST=127.0.0.1 \
  -e HERMES_DASHBOARD_PORT=19119 \
  nousresearch/hermes-agent:main-desktop gateway run
curl -s http://127.0.0.1:19119/api/status | head -c 300   # version, hermes_home /opt/data
```

- `main-desktop` is the newest build of main. For a release use its tag with the `-desktop` suffix, such as `<version>-desktop`. For the sandbox placement (the screen runs in the terminal backend's container) use `nousresearch/hermes-sandbox:desktop` as the terminal image.
- `--network host` is a Linux feature. Docker Desktop on a Mac needs "Enable host networking" in its settings, or use a Linux box and `ssh -L 19119:127.0.0.1:19119 box`.
- Without host networking: publish the port (`-p 127.0.0.1:19119:9119`, `-e HERMES_DASHBOARD_HOST=0.0.0.0`) and add `-e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=... -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=... -e HERMES_DASHBOARD_BASIC_AUTH_SECRET=...` with throwaway values. The app can sign in to that, but `test/real_backend_contract_test.dart` cannot (it reads the page token, not a login), so only the manual app checks apply.
- Check `/api/status` reports `/opt/data` as `hermes_home` before changing anything.

## 2. Start a profile's screen

```bash
docker exec hermes-bot-screen-verify hermes computer-use screen start
docker exec hermes-bot-screen-verify hermes computer-use screen status --json
```

`status` should say `supported: true`, `installed: true`, `running: true` and a lease held by the agent. Alternatively let the app do it with `BotScreenController.start()`, which calls `display.start`, or run a `computer_use` turn.

If the packages are missing (a plain image), `installed` is false and `missing` lists them. Installing from the app is the later change `bot-screen-host-install`.

## 3. Run the checks

Contract test, against the container:

```bash
HERMES_DEV_URL=http://127.0.0.1:19119 HERMES_DEV_BOT_SCREEN=1 \
  flutter test test/real_backend_contract_test.dart --plain-name "Bot Screen"
```

With `HERMES_DEV_BOT_SCREEN=1` the test requires `supported` and `running` and a JPEG from `display.thumbnail`. Without the flag it accepts a stopped screen or an unsupported host, which is what a Mac backend reports.

For UI changes, run the app against the container with the `verify-in-app` skill (`scripts/dev-app.sh` with `HERMES_SERVER_URL=http://127.0.0.1:19119`) and watch the card or viewer. Also check:

- Stop the screen (`hermes computer-use screen stop`): the app drops its frame within one broadcast.
- Take over from another process, then confirm the app shows no picture and learns it at the latest with the 10th frame request: the lease changes made by the CLI are not broadcast.
- Restart the container while a surface is shown: the app re-reads the status after the connection comes back.
- Lock the app (App Lock) while a frame request is in flight: no frame appears after unlocking until the next one arrives.

## 4. Tear down

```bash
docker rm -f hermes-bot-screen-verify
docker volume rm hermes-bot-screen-verify
```

Record in the PR what ran: the image tag or digest, the Hermes version from `/api/status`, and which checks passed or were skipped.

---
name: verify-bot-screen
description: Use when a change touches the Bot Screen (lib/src/bot_screen/, the display.* gateway methods, the Activity panel's screen card, the live view or takeover) and must be checked against a real Hermes that has a running screen, or when asked to run a throwaway Linux Hermes with the desktop packages.
---

# Verify the Bot Screen against a real screen

A profile's Bot Screen (Xvnc and Xfce, driven by `computer_use`) exists only on Linux. A macOS or Windows Hermes answers `display.status` with `supported: false`, so the `scripts/dev-backend.sh` backend on a Mac can never show a screen. To see real frames, run Hermes in a throwaway container from the `-desktop` image, which ships the packages (`tigervnc-standalone-server`, Xfce, `chromium`) the plain image lacks. Fixtures prove parsing; only this proves the shapes, the broadcasts and the frames.

Hermes needs v2026.9.24 or later for `display.*`, `viewer_hash` and `display.install.sudo`.

Rules: never mount the real `~/.hermes` (use a named volume), never point the app or `hermes` at it, never run `hermes dashboard --stop`, and remove the container and volume afterwards, **whether the checks pass or fail**: run step 4 every time, or start with `trap 'docker rm -f hermes-bot-screen-verify >/dev/null 2>&1; docker volume rm hermes-bot-screen-verify >/dev/null 2>&1' EXIT` in the shell that runs steps 1 to 3. The commands below were written from Hermes' `Dockerfile`, `docker-compose.yml`, `docker.yml` and docker docs and have not been run end to end; correct this skill as soon as one turns out wrong.

## 1. Start the container

Use a Linux Docker host. The dashboard must be reachable without its auth gate: a loopback bind needs no provider, a non-loopback bind fails closed without one. A Mac has no equivalent that is known to work: run this on a Linux box (or a Linux VM) and forward the port with `ssh -L 19119:127.0.0.1:19119 <box>`.

```bash
# Nothing else may use the port, and a leftover container or volume must not leak in.
ss -ltn 'sport = :19119' | grep -q LISTEN && { echo "port 19119 is in use"; exit 1; }
docker rm -f hermes-bot-screen-verify 2>/dev/null
docker volume rm hermes-bot-screen-verify 2>/dev/null
docker volume create hermes-bot-screen-verify
docker run -d --name hermes-bot-screen-verify --network host \
  -v hermes-bot-screen-verify:/opt/data \
  -e HERMES_DASHBOARD=1 -e HERMES_DASHBOARD_HOST=127.0.0.1 \
  -e HERMES_DASHBOARD_PORT=19119 \
  nousresearch/hermes-agent:main-desktop gateway run
curl -s http://127.0.0.1:19119/api/status | head -c 300   # version, hermes_home /opt/data
```

- `main-desktop` is the newest build of main. For a release use its tag with the `-desktop` suffix, such as `<version>-desktop`. For the sandbox placement (the screen runs in the terminal backend's container) use `nousresearch/hermes-sandbox:desktop` as the terminal image.
- Check `/api/status` reports `/opt/data` as `hermes_home` before changing anything.

Without host networking (a remote Docker host you cannot tunnel to), publish the port instead. The dashboard then binds `0.0.0.0` inside the container, which needs an auth provider, so use throwaway basic-auth values:

```bash
docker run -d --name hermes-bot-screen-verify \
  -p 127.0.0.1:19119:9119 \
  -v hermes-bot-screen-verify:/opt/data \
  -e HERMES_DASHBOARD=1 \
  -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=verify \
  -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=verify-only-password \
  -e HERMES_DASHBOARD_BASIC_AUTH_SECRET=verify-only-secret \
  nousresearch/hermes-agent:main-desktop gateway run
```

The app can sign in to that, but `test/real_backend_contract_test.dart` cannot (it reads the page token, not a login), so only the manual app checks apply.

## 2. Start a profile's screen

```bash
docker exec hermes-bot-screen-verify hermes computer-use screen start
docker exec hermes-bot-screen-verify hermes computer-use screen status --json
```

`status` should say `supported: true`, `installed: true`, `running: true` and a lease held by the agent. It exits 1 while the screen is stopped, and its JSON has no `profile_key` (that one only appears in the gateway's `display.status`), so read it for the booleans and the lease only. Alternatively let the app do it with `BotScreenController.start()`, which calls `display.start`, or run a `computer_use` turn.

If the packages are missing (a plain image), `installed` is false and `missing` lists them. Installing from the app is section 3b.

## 3. Run the checks

Contract test, against the container:

```bash
HERMES_DEV_URL=http://127.0.0.1:19119 HERMES_DEV_BOT_SCREEN=1 \
  flutter test test/real_backend_contract_test.dart --plain-name "Bot Screen"
```

With `HERMES_DEV_BOT_SCREEN=1` the test requires `supported` and `running` and a JPEG from `display.thumbnail`. Without the flag it accepts a stopped screen or an unsupported host, which is what a Mac backend reports.

For UI changes, run the app against the container. `scripts/dev-app.sh` takes its URL from `scripts/dev-backend.sh url` and ignores `HERMES_SERVER_URL`, so start the app directly, under the isolation rules of the `verify-in-app` skill:

```bash
flutter run -d macos --dart-define=HERMES_SERVER_URL=http://127.0.0.1:19119
```

Then open a chat, press the Activity button (View > Inspector, ⌥⌘I, on a Mac) and watch the Bot screen card under Now (a picture refreshed every 3 seconds and "Hermes is in control"; Off with Start Screen after `hermes computer-use screen stop`; "Someone else is in control" with no picture after a takeover), and also check:

- Stop the screen (`hermes computer-use screen stop`): the app drops its frame within one broadcast.
- Take over from another process, then confirm the app shows no picture and learns it at the latest with the 10th frame request: the lease changes made by the CLI are not broadcast.
- Restart the container while a surface is shown: the app re-reads the status after the connection comes back.
- Lock the app (App Lock) while a frame request is in flight: no frame appears after unlocking until the next one arrives.

## 3b. Install on Server

The app can have Hermes install the desktop packages itself (`display.install`), and Hermes asks the app for the server's sudo password (`display.install.sudo`). Check it on a server that does not have the packages yet, in two layers. Use a loopback or tunnelled dashboard as in step 1, with its own container, volume and port, and the same cleanup rules.

**Plain image: no sudo.** The plain image (`nousresearch/hermes-agent:latest`) runs Hermes unprivileged and ships no `sudo`, so the install ends with `display.install.done` code -2 and the manual command streamed. Start it as in step 1 but with the plain image (no `-desktop` suffix) and the names `hermes-bot-screen-install-plain` (container and volume), then in the app: open a chat that has a `computer_use` tool call (the card is listed only while the screen runs or while the open chat used `computer_use`, and this server has no screen yet), open the Activity panel and check:

- the card says the desktop is not installed on the server, shows the command with Copy, and Install on Server;
- pressing Install on Server shows Installing, with the package manager's lines and "You can close this; the install keeps going.";
- it ends as "There's no sudo on the server, so Hermes can't install the desktop itself." with the command to run by hand.

**Sudo layer: the password prompt.** Build a throwaway layer on the plain image that has `sudo` and a Hermes user with a password-protected sudo rule. The user name and the image's package manager are not known here, so read them first and correct this layer if they differ:

```bash
docker run --rm --entrypoint id nousresearch/hermes-agent:latest   # the Hermes user and its uid
docker run --rm --entrypoint sh nousresearch/hermes-agent:latest -c 'command -v apt-get dnf pacman'
mkdir -p /tmp/hermes-sudo-layer && cat > /tmp/hermes-sudo-layer/Dockerfile <<'EOF'
FROM nousresearch/hermes-agent:latest
ARG HERMES_USER=hermes
USER root
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
 && rm -rf /var/lib/apt/lists/* \
 && echo "${HERMES_USER} ALL=(ALL) ALL" > /etc/sudoers.d/hermes-verify \
 && chmod 0440 /etc/sudoers.d/hermes-verify \
 && echo "${HERMES_USER}:verify-only-password" | chpasswd
USER ${HERMES_USER}
EOF
docker build --build-arg HERMES_USER=<the user from id> -t hermes-bot-screen-install-sudo /tmp/hermes-sudo-layer
```

The password `verify-only-password` is a test value for this throwaway image and never a real one. If the image already runs as root, Hermes does not ask for a password and this layer shows nothing new. Start a container from `hermes-bot-screen-install-sudo` as in step 1 (names `hermes-bot-screen-install-sudo`, a named volume, and the image's own entrypoint arguments `gateway run` with the same environment), then in the app:

- press Install on Server; the password question appears with the dashboard's host and an obscured field, also after opening Kanban while it waits (the prompt must appear over Kanban); screenshot it;
- type `verify-only-password` and press Install: the card shows Installing with lines, then, when the packages are in, Off with Start Screen (screenshot both); the typed text is gone from the field and appears nowhere in the app's log output (`scripts/dev-app.sh logs` style output, or the debug console);
- repeat with Cancel in the question: the card ends as "The install was cancelled." and offers Install on Server again;
- while the install runs, restart the container once: after the connection comes back the card leaves Installing (status says the packages are installed, or the install failed) without waiting 20 minutes.

Record in the PR what ran. This section was written from Hermes' `methods_display.py` and has not been run end to end; correct it as soon as a step turns out wrong.

## 4. Tear down

Always, also when a check failed:

```bash
docker rm -f hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo
docker volume rm hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo
docker rmi hermes-bot-screen-install-sudo
rm -rf /tmp/hermes-sudo-layer
```

Record in the PR what ran: the image tag or digest, the Hermes version from `/api/status`, and which checks passed or were skipped.

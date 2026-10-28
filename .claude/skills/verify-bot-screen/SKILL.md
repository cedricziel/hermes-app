---
name: verify-bot-screen
description: Use when a change touches the Bot Screen (lib/src/bot_screen/, the display.* gateway methods, the Activity panel's screen card, the live view or takeover) and must be checked against a real Hermes that has a running screen, or when asked to run a throwaway Linux Hermes with the desktop packages.
---

# Verify the Bot Screen against a real screen

A profile's Bot Screen (Xvnc and Xfce, driven by `computer_use`) exists only on Linux. A macOS or Windows Hermes answers `display.status` with `supported: false`, so the `scripts/dev-backend.sh` backend on a Mac can never show a screen. To see real frames, run Hermes in a throwaway container from the `-desktop` image, which ships the packages (`tigervnc-standalone-server`, Xfce, `chromium`) the plain image lacks. Fixtures prove parsing; only this proves the shapes, the broadcasts and the frames.

Hermes needs v2026.9.24 or later for `display.*`, `viewer_hash` and `display.install.sudo`.

Rules: never mount the real `~/.hermes` (use a named volume), never point the app or `hermes` at it, never run `hermes dashboard --stop`, and remove the container and volume afterwards, **whether the checks pass or fail**: run step 4 every time, or start with `trap 'docker rm -f hermes-bot-screen-verify >/dev/null 2>&1; docker volume rm hermes-bot-screen-verify >/dev/null 2>&1' EXIT` in the shell that runs steps 1 to 3 (section 3b has a longer trap for its two containers, volumes and image). The commands below were written from Hermes' `Dockerfile`, `docker-compose.yml`, `docker.yml` and docker docs and have not been run end to end; correct this skill as soon as one turns out wrong.

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

Watch the screen live (the card's Enlarge or its picture; the transcript preview once it exists):

- Open the viewer: the picture moves by itself (let Hermes run a `computer_use` turn, or move something on the screen), the header says the profile and "Hermes is in control", and a click or tap on the picture does nothing on the screen. A phone (shortest side under 600 pt, landscape too) shows a full-screen page, a larger window shows it over the whole window; Escape and Back close either, and a dialog opened over it (Settings, Sign Out) is drawn above it.
- Send the app to the background and return: the stream closes while away and a new one opens on return (an attached viewer counts as use on the server, and a changing screen can be kept from its idle stop, so none should stay attached). On a desktop only hiding or minimising the app does this; losing focus does not.
- Take over from another process: the viewer blanks and says someone else is in control, and the picture returns when control goes back to Hermes.
- Stop the screen (`hermes computer-use screen stop`) with the viewer open: it shows "The screen is off" and Start Screen, with no reconnect loop. Restart the container with the viewer open: it says Reconnecting, then either recovers or ends on "Can't reach the screen" with Try Again after 5 attempts.

## 3b. Install on Server

The app can have Hermes install the desktop packages itself (`display.install`), and Hermes asks the app for the server's sudo password (`display.install.sudo`). Check it on a server that does not have the packages yet, in two layers: the plain image (no `sudo`) and a throwaway layer on it with `sudo`. Each gets its own container, named volume and port, and the same cleanup rules as step 1: run step 4 whether the checks pass or fail, or start the shell with

```bash
trap 'docker rm -f hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo >/dev/null 2>&1; docker volume rm hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo >/dev/null 2>&1; docker rmi hermes-bot-screen-install-sudo >/dev/null 2>&1; rm -rf /tmp/hermes-sudo-layer; kill $(cat /tmp/hermes-fake-model.pid 2>/dev/null) 2>/dev/null' EXIT
```

Use the published-port variant of step 1, not `--network host`: the dashboard then binds `0.0.0.0` inside the container and needs the throwaway basic-auth values, and the container can reach a model on the host through `host.docker.internal`.

**A chat that used `computer_use`, without a paid model.** The card is listed only while the screen runs or while the open chat has a `computer_use` tool call, and these servers have no screen. `scripts/fake_tool_model.py` is a scripted OpenAI-compatible model whose "computer" prompt makes one `computer_use` screenshot call (Hermes records the call even though the tool then fails). Run it on the host (`python3 scripts/fake_tool_model.py 18555 & echo $! > /tmp/hermes-fake-model.pid`), then write this `config.yaml` into each volume before its container starts (`HERMES_HOME` is `/opt/data`; the files must belong to the Hermes user, uid 10000):

```bash
docker volume create hermes-bot-screen-install-plain
docker run --rm -v hermes-bot-screen-install-plain:/opt/data alpine sh -c 'cat > /opt/data/config.yaml <<EOF
model:
  default: "fake-tools"
  provider: "custom"
  base_url: "http://host.docker.internal:18555/v1"
  api_key: "fake"
  context_length: 131072
EOF
chown 10000:10000 /opt/data/config.yaml'
```

Add `--add-host=host.docker.internal:host-gateway` to `docker run` on Linux (Docker Desktop has the name already). In the app send the prompt "use the computer", and the chat then holds a `computer_use` call.

**Plain image: no sudo.** The plain image (`nousresearch/hermes-agent:latest`) runs Hermes unprivileged and ships no `sudo`, so the install ends with `display.install.done` code -2. Start it with the volume above:

```bash
docker run -d --name hermes-bot-screen-install-plain --add-host=host.docker.internal:host-gateway \
  -p 127.0.0.1:19120:9119 -v hermes-bot-screen-install-plain:/opt/data \
  -e HERMES_DASHBOARD=1 \
  -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=verify \
  -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=verify-only-password \
  -e HERMES_DASHBOARD_BASIC_AUTH_SECRET=verify-only-secret \
  nousresearch/hermes-agent:latest gateway run
```

Run the app as in step 3 with `--dart-define=HERMES_SERVER_URL=http://127.0.0.1:19120`, sign in with the basic-auth values, send "use the computer", open the Activity panel and check:

- the card says the desktop is not installed on the server, shows the command with Copy, and Install on Server;
- pressing Install on Server shows Installing, with the package manager's lines and "You can close this; the install keeps going.";
- it ends as "There's no sudo on the server, so Hermes can't install the desktop itself." with the command to run by hand, shown without `sudo`, and no Install on Server.

**Sudo layer: the password question.** Build a throwaway layer on the plain image that has `sudo` and a password-protected sudo rule for the Hermes user. Hermes' image ends with `USER root` on purpose: its s6-overlay `/init` and stage 2 must start as root, and `main-wrapper.sh` drops the services to the `hermes` user (uid 10000) with `s6-setuidgid`. So the layer must not set `USER` at the end. Read the user and the package manager first and correct the layer if they differ:

```bash
docker run --rm --entrypoint id nousresearch/hermes-agent:latest hermes   # the user's uid and groups
docker run --rm --entrypoint sh nousresearch/hermes-agent:latest -c 'command -v apt-get dnf pacman'
mkdir -p /tmp/hermes-sudo-layer && cat > /tmp/hermes-sudo-layer/Dockerfile <<'EOF'
FROM nousresearch/hermes-agent:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
 && rm -rf /var/lib/apt/lists/* \
 && echo "hermes ALL=(ALL) ALL" > /etc/sudoers.d/hermes-verify \
 && chmod 0440 /etc/sudoers.d/hermes-verify \
 && echo "hermes:verify-sudo-password" | chpasswd
EOF
docker build -t hermes-bot-screen-install-sudo /tmp/hermes-sudo-layer
```

`verify-sudo-password` is a test value for this throwaway image and never a real one. Create the volume and `config.yaml` as above for `hermes-bot-screen-install-sudo`, then start it like the plain one with the image `hermes-bot-screen-install-sudo`, the name `hermes-bot-screen-install-sudo` and the port `127.0.0.1:19121:9119`; run the app against `http://127.0.0.1:19121`, send "use the computer", and in the Activity panel:

- press Install on Server; the password question appears with the dashboard's host and the profile, and an obscured field, also after opening Kanban while it waits (it must appear over Kanban; on a Mac the main window comes forward first); screenshot it;
- type `verify-sudo-password` and press Install: the card shows Installing with lines, then, when the packages are in, Off with Start Screen (screenshot both); the typed text is gone and appears nowhere in the app's console output;
- repeat with Cancel in the question: the card ends as "The install was cancelled." and offers Install on Server again;
- leave the question open for more than 300 s: Hermes withdraws it (`request.cancel`) and the question closes by itself;
- while the install runs, restart the container once: after the connection comes back the card leaves Installing (the status says the packages are installed, or the install failed) without waiting 22 minutes;
- on an iOS device against a dashboard it can reach, check that the password field offers no Save Password or QuickType suggestion, and on Android that the keyboard shows no suggestions.

Record in the PR what ran. This section was written from Hermes' `methods_display.py` and the image's Dockerfile and has not been run end to end; correct it as soon as a step turns out wrong.

## 4. Tear down

Always, also when a check failed:

```bash
docker rm -f hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo
docker volume rm hermes-bot-screen-verify hermes-bot-screen-install-plain hermes-bot-screen-install-sudo
docker rmi hermes-bot-screen-install-sudo
rm -rf /tmp/hermes-sudo-layer
kill "$(cat /tmp/hermes-fake-model.pid)" 2>/dev/null; rm -f /tmp/hermes-fake-model.pid
```

Record in the PR what ran: the image tag or digest, the Hermes version from `/api/status`, and which checks passed or were skipped.

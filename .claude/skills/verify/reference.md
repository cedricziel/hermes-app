# verify: reference

Detail for [SKILL.md](SKILL.md). Scripts: `scripts/verify.sh`,
`scripts/install-hermes.sh`, `scripts/dev-backend.sh`,
`scripts/verify_scripted_model.py`, `scripts/verify_browser.py`,
`integration_test/verify_flow_test.dart`.

## Packages

Ubuntu 24.04, as root (prefix `sudo` otherwise):

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev libmpv-dev \
  xvfb xdotool imagemagick gnome-keyring dbus-x11 libsecret-tools lsof iproute2 procps
```

The first line of the second command is what CI's "Build Linux (release)"
installs; the rest runs the app headless (`xvfb`, `imagemagick` for `import`,
`gnome-keyring` and `dbus-x11` for secure storage, `xdotool` for poking the
window by hand), and `lsof` is what `dev-backend.sh` finds the dashboard's PID
with. `libsecret-tools` gives `secret-tool` for looking into the throwaway
keyring while debugging. Also needed: Flutter at `.fvmrc` (`flutter` on PATH),
`uv`, `git`, Node/npm (the Hermes web UI build), `curl`, Python 3.

## Layout of one run

```
/tmp/hermes-verify.XXXXXX/          RUN_DIR, removed on exit
  owner                             PID of verify.sh (for `clean`)
  contract/  home/ userhome/        no-auth backend: HERMES_HOME, HOME
             pid port dashboard.log dev-backend.sh's state (HERMES_DEV_STATE_DIR)
  app/       home/ userhome/ ...    password-gated backend
  model.port model.log              scripted model
  display xvfb.log                  Xvfb's chosen display
  apphome/   config data cache state runtime   the app's HOME and XDG_* dirs
             data/keyrings/         the throwaway keyring
             data/applications/hermes-verify-browser.desktop
             config/mimeapps.list   makes it the http/https handler
  tmp/                              TMPDIR of the contract tests
build/verify/<time>-<id>/           kept (newest ten): shots/, *-test.log, *-dashboard.log, browser.log
```

Every process the run starts inherits `HERMES_VERIFY_RUN=<RUN_DIR>`.
`cleanup` (the EXIT trap) runs `dev-backend.sh stop` for each backend, then
TERMs every process whose `/proc/<pid>/environ` carries the marker, KILLs
what is left after 10 s, copies the logs and deletes `RUN_DIR`. It warns and
fails the run if a marked process survives.

## How the pieces fit

- **Hermes install.** `install-hermes.sh` checks the pinned revision is a
  40-hex commit id, takes a `flock` per revision (and fails without `flock`),
  and `git fetch`es that commit id, so git checks the tree against it. It then
  builds the web UI (`npm ci` + `npm run build --workspace web`; the
  dashboard injects its session token into that page) and deletes
  `node_modules`. Note that `npm ci` runs the packages' install scripts, as
  root in a container, exactly as CI runs them. Then `uv venv --python 3.14`
  and `uv pip install -e .[mcp]`. A marker file marks a finished install; a
  half-finished one is removed and redone. Older revisions under
  `~/.cache/hermes-agent/` are not pruned; delete them by hand.
- **Backends.** `start_backend` writes `config.yaml` into the run's home and
  calls `dev-backend.sh start` under `setsid` with `HERMES_DEV_STATE_DIR`,
  `HOME` and (for the app tier) the basic-auth env. `dev-backend.sh` waits for
  `HERMES_DASHBOARD_READY port=N`, records the listener's PID with `lsof`, and
  refuses a backend on another home: from `/api/status` `hermes_home`, or,
  when the password gate hides it, from `/proc/<pid>/environ`. `verify.sh`
  then checks the PID's HERMES_HOME and marker itself.
- **Password gate on loopback.** Hermes engages its auth gate on a loopback
  bind only when `dashboard.public_url` names a non-loopback host, so the app
  backend gets `public_url: http://hermes-verify.invalid` (never resolved) and
  `HERMES_DASHBOARD_BASIC_AUTH_{USERNAME,PASSWORD,SECRET}`. `/api/status` then
  reports `auth_required: true`, providers `["basic"]`, flows
  `cookie, native_pkce`.
- **Sign-in.** The app opens `/auth/native/authorize?...` with url_launcher,
  which on Linux asks GIO for the `x-scheme-handler/http(s)` default. The
  run's `mimeapps.list` points that at `verify_browser.py`, which GETs the
  authorize URL (cookie jar; it redirects to `/login`), POSTs
  `/auth/password-login` with the synthetic credentials and follows the
  returned `next` URL to the app's listener. The authorize URL and every
  redirect must be on exactly the dashboard's origin (`HERMES_VERIFY_ORIGIN`,
  scheme, host and port), and `next` must be `http://127.0.0.1:<port>/...`;
  anything else is refused before credentials or the code leave.
  `python3 -I scripts/test_verify_browser.py` tests that. It logs steps,
  never credentials.
- **Secure storage.** `flutter_secure_storage` on Linux talks to the Secret
  Service over the session bus. The app tier runs inside `dbus-run-session`
  and starts `gnome-keyring-daemon --unlock --components=secrets` there; with
  `XDG_DATA_HOME` in the run dir the keyring file is throwaway too.
- **NetworkManager.** `connectivity_plus` asks NetworkManager on the system
  bus, which a container lacks; the unhandled D-Bus error fails the app at
  start. Inside the private session the run starts a second `dbus-daemon`,
  exports it as `DBUS_SYSTEM_BUS_ADDRESS`, and `scripts/verify_fake_nm.dart`
  owns `org.freedesktop.NetworkManager` there with an empty object manager.
- **git.** The isolated HOME hides the real `~/.gitconfig`, whose
  `safe.directory` entry Flutter's own checkout may need ("dubious ownership",
  exit 128), so `GIT_CONFIG_GLOBAL` keeps pointing at it.
- **mimalloc.** `media_kit_libs_linux` downloads
  `github.com/microsoft/mimalloc/archive/...tar.gz` at CMake time and checks
  its MD5. Where that URL is refused, `seed_mimalloc` rebuilds the identical
  file with `git archive --format=tar --prefix=mimalloc-<v>/ v<v> | gzip -n`
  into `build/linux/x64/debug/` and verifies the MD5.

## Troubleshooting

- `Woah! You appear to be trying to run flutter as root`: harmless in a
  container.
- `git status` shows `linux/flutter/generated_plugin*` changed: the Linux
  build regenerated them. `git restore` them; never stage them by accident
  (stage files by name).
- Dart ignores `SSL_CERT_FILE`; behind a TLS-intercepting proxy `pub get`
  hangs until the proxy CA is in `/etc/ssl/certs/ca-certificates.crt`.
  `verify.sh` runs Flutter with `--no-pub`: run `flutter pub get` first.
- `Failed to find bundle/hermes_app`, or the build "succeeds" with no
  `bundle/`: a first CMake configure that failed left
  `CMAKE_INSTALL_PREFIX=/usr/local` in `build/linux/x64/debug/CMakeCache.txt`,
  so later builds install into `/usr/local`. `rm -rf build/linux` (and remove
  what landed in `/usr/local` per `build/linux/x64/debug/install_manifest.txt`)
  and run again.
- `Integrity check failed` for mimalloc: the seeding could not reach
  github.com over git either; fetch the tag elsewhere and drop the tarball
  into `build/linux/x64/debug/`.
- Sign-in hangs with an empty `browser.log`: GIO did not pick the stand-in
  browser. Check `XDG_DATA_HOME`/`XDG_CONFIG_HOME` reach the app (the Flutter
  tool passes its environment to the app it launches).
- `dbus` `SocketException` at app start: no system bus in a container;
  harmless.
- A run killed with SIGKILL leaves `/tmp/hermes-verify.*` and processes:
  `scripts/verify.sh clean` (also done at the start of every run).
- To look at a live run, add a `sleep` to the test and, from another shell,
  `DISPLAY=:<n> import -window root /tmp/x.png` with `<n>` from
  `RUN_DIR/display`.

## Proving cleanup by hand

```bash
scripts/verify.sh app & V=$!
# once the app is up, kill this run's app and no other run's:
# the run whose owner file holds this verify.sh's PID
until OWNER=$(grep -lx "$V" /tmp/hermes-verify.*/owner 2>/dev/null); do sleep 1; done
RUN=$(cd "$(dirname "$OWNER")" && pwd -P)
until P=$(for p in $(pgrep -x hermes_app); do
  tr '\0' '\n' </proc/$p/environ | grep -qx "HERMES_VERIFY_RUN=$RUN" && echo "$p"
done) && [[ -n $P ]]; do sleep 1; done
kill -9 $P
wait $V                                                         # non-zero: app tier failed
# or instead: kill -TERM $V  (the trap stops everything at once)
pgrep -af 'hermes|Xvfb|gnome-keyring|dbus-daemon|hermes_app'    # nothing of the run
ss -ltnp                                                        # no dashboard/model port
ls -d /tmp/hermes-verify.* /tmp/hermes-contract-*               # none
```

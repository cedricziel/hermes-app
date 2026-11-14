#!/usr/bin/env bash
# Certifies a change against throwaway instances on Linux (cloud containers
# included): a Hermes backend at the pinned contract revision, the contract
# tests against it, and the real Linux app under Xvfb signing in with a
# synthetic account and getting a scripted model's reply.
#
#   scripts/verify.sh [all|contract|app]   # default: all
#   scripts/verify.sh clean                # sweep runs whose owner died (SIGKILL)
#
# Everything a run starts lives in one temporary directory outside the working
# tree (backend HERMES_HOME and HOME, app HOME and XDG dirs, keyring, logs),
# on OS-assigned ports and its own X display and D-Bus session. Every process
# inherits HERMES_VERIFY_RUN=<that directory>; on any exit the trap stops the
# backends by their recorded PIDs, kills whatever still carries the marker,
# and deletes the directory. Screenshots and logs worth keeping are copied to
# build/verify/<run>/ first. See .claude/skills/verify/SKILL.md.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-all}"
TMP_ROOT="${HERMES_VERIFY_TMP:-/tmp}"
APP_TIMEOUT="${HERMES_VERIFY_APP_TIMEOUT:-1200}"

log() { printf '[verify] %s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# Every process carrying HERMES_VERIFY_RUN=$1 in its environment, except this
# shell. Builtins only, so the scan itself starts no marked process.
marked_pids() {
  local marker="HERMES_VERIFY_RUN=$1" dir pid entry
  for dir in /proc/[0-9]*; do
    pid="${dir#/proc/}"
    [[ "$pid" == "$$" || "$pid" == "$BASHPID" ]] && continue
    [[ -r "$dir/environ" ]] || continue
    { while IFS= read -r -d '' entry; do
      if [[ "$entry" == "$marker" ]]; then
        printf '%s\n' "$pid"
        break
      fi
    done <"$dir/environ"; } 2>/dev/null || true
  done
}

kill_marked() {
  local run="$1" pids tries=0
  mapfile -t pids < <(marked_pids "$run")
  ((${#pids[@]})) || return 0
  local pid names=() name
  for pid in "${pids[@]}"; do
    name=""
    { read -r name <"/proc/$pid/comm"; } 2>/dev/null || true
    names+=("${name:-?}($pid)")
  done
  log "stopping ${#pids[@]} process(es) of this run: ${names[*]}"
  kill -TERM "${pids[@]}" 2>/dev/null || true
  while ((tries < 20)); do
    mapfile -t pids < <(marked_pids "$run")
    ((${#pids[@]})) || return 0
    sleep 0.5
    tries=$((tries + 1))
  done
  kill -KILL "${pids[@]}" 2>/dev/null || true
}

# Runs left behind by a verify.sh that was killed with SIGKILL (no trap ran).
cmd_clean() {
  local dir owner
  for dir in "$TMP_ROOT"/hermes-verify.*; do
    [[ -d "$dir" && -f "$dir/owner" ]] || continue
    owner="$(cat "$dir/owner")"
    if [[ "$owner" =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null &&
      [[ "$(tr '\0' ' ' <"/proc/$owner/cmdline" 2>/dev/null)" == *verify.sh* ]]; then
      continue # still running
    fi
    log "cleaning stale run $dir"
    kill_marked "$dir"
    rm -rf "$dir"
  done
}

need() {
  local tool missing=()
  for tool in "$@"; do command -v "$tool" >/dev/null || missing+=("$tool"); done
  ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]} (see .claude/skills/verify/reference.md, Packages)"
}

free_of_tree() {
  local path
  path="$(cd "$1" && pwd -P)"
  case "$path/" in
    "$(cd "$ROOT_DIR" && pwd -P)"/*) die "refusing: $path is inside the working tree" ;;
  esac
}

# --- backend ---------------------------------------------------------------

# start_backend <name> <gated: 0|1>: a dashboard with HERMES_HOME and HOME under
# $RUN_DIR/<name>, started by scripts/dev-backend.sh, which records its PID.
# Sets BACKEND_URL.
start_backend() {
  local name="$1" gated="$2" state="$RUN_DIR/$1"
  mkdir -p "$state/home" "$state/userhome"
  {
    if [[ -n "${MODEL_PORT:-}" ]]; then
      cat <<EOF
model:
  default: "verify-scripted"
  provider: "custom"
  base_url: "http://127.0.0.1:$MODEL_PORT/v1"
  api_key: "verify-scripted"
  context_length: 131072
EOF
    fi
    if [[ "$gated" == 1 ]]; then
      # A non-loopback public URL engages the password gate on a loopback bind;
      # nothing ever resolves or serves this name.
      cat <<EOF
dashboard:
  public_url: "http://hermes-verify.invalid"
EOF
    fi
  } >"$state/home/config.yaml"
  local -a auth_env=()
  if [[ "$gated" == 1 ]]; then
    auth_env=(
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME="$VERIFY_USER"
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$VERIFY_PASSWORD"
      HERMES_DASHBOARD_BASIC_AUTH_SECRET="$VERIFY_SECRET"
    )
  fi
  # setsid: the dashboard gets its own session, so a Ctrl-C meant for this
  # script reaches it only through the trap.
  env -u HERMES_HOME HOME="$state/userhome" HERMES_DEV_STATE_DIR="$state" \
    PATH="$HERMES_DIR/.venv/bin:$PATH" HERMES_WEB_DIST="$HERMES_DIR/hermes_cli/web_dist" \
    "${auth_env[@]}" setsid "$ROOT_DIR/scripts/dev-backend.sh" start >&2 ||
    {
      tail -n 40 "$state/dashboard.log" >&2 2>/dev/null || true
      die "backend $name did not start"
    }
  BACKENDS+=("$state")
  local url pid
  url="$(HERMES_DEV_STATE_DIR="$state" "$ROOT_DIR/scripts/dev-backend.sh" url)"
  pid="$(cat "$state/pid")"
  # The process must be ours, on our home, and not the real ~/.hermes.
  local env_home
  env_home="$(tr '\0' '\n' <"/proc/$pid/environ" | sed -n 's/^HERMES_HOME=//p' | head -n1)"
  [[ "$env_home" == "$state/home" ]] || die "backend $name runs on HERMES_HOME=$env_home, not $state/home"
  [[ "$env_home" != "$ORIG_HOME/.hermes"* ]] || die "backend $name points at the real ~/.hermes"
  tr '\0' '\n' <"/proc/$pid/environ" | grep -qx "HERMES_VERIFY_RUN=$RUN_DIR" ||
    die "backend $name does not carry this run's marker"
  log "backend $name: $url (pid $pid, home $state/home, password gate: $gated)"
  BACKEND_URL="$url"
}

# --- tiers -----------------------------------------------------------------

run_contract() {
  start_backend contract 0
  local url="$BACKEND_URL"
  log "contract tier: real backend, Bot Mode chat and hosted group contracts"
  # The tests' own temp dirs go into the run dir too, so a test that dies
  # before its teardown leaves nothing in /tmp.
  mkdir -p "$RUN_DIR/tmp"
  local status=0
  # In the background and waited for, so TERM or INT to this script runs the
  # trap at once instead of after the tests finish.
  (cd "$ROOT_DIR" && TMPDIR="$RUN_DIR/tmp" HERMES_DEV_URL="$url" HERMES_DEV_HOME="$RUN_DIR/contract/home" \
    flutter test --no-pub --concurrency=1 \
    test/real_backend_contract_test.dart \
    test/bot_mode_chat_contract_test.dart \
    test/bot_mode/group_protocol/real_groups_contract_test.dart) >"$RUN_DIR/contract-test.log" 2>&1 &
  wait "$!" || status=$?
  tail -n 60 "$RUN_DIR/contract-test.log" >&2
  HERMES_DEV_STATE_DIR="$RUN_DIR/contract" "$ROOT_DIR/scripts/dev-backend.sh" stop >&2 || true
  ((status == 0)) || die "contract tier failed (log: $OUT_DIR/contract-test.log)"
  log "contract tier passed"
}

# mimalloc's GitHub archive URL (media_kit_libs_linux) is refused by some
# proxies; the same bytes come from `git archive | gzip -n` of the tag.
seed_mimalloc() {
  local cmake="$ROOT_DIR/linux/flutter/ephemeral/.plugin_symlinks/media_kit_libs_linux/linux/CMakeLists.txt"
  [[ -f "$cmake" ]] || return 0
  local file md5 url tag dest
  file="$(sed -n 's/.*set(MIMALLOC "\(mimalloc-[^"]*\.tar\.gz\)").*/\1/p' "$cmake")"
  md5="$(sed -n 's/.*set(MIMALLOC_MD5 "\([0-9a-f]*\)").*/\1/p' "$cmake")"
  url="$(sed -n 's/.*set(MIMALLOC_URL "\([^"]*\)").*/\1/p' "$cmake")"
  [[ -n "$file" && -n "$md5" && -n "$url" ]] || return 0
  dest="$ROOT_DIR/build/linux/x64/debug/$file"
  [[ -f "$dest" && "$(md5sum "$dest" | cut -d' ' -f1)" == "$md5" ]] && return 0
  curl -fsSL -o /dev/null "$url" 2>/dev/null && return 0
  tag="${url##*/tags/}"
  tag="${tag%.tar.gz}"
  log "seeding $file from git (archive URL refused)"
  mkdir -p "$RUN_DIR/mimalloc" "$(dirname "$dest")"
  git -C "$RUN_DIR/mimalloc" init -q
  git -C "$RUN_DIR/mimalloc" fetch -q --depth 1 https://github.com/microsoft/mimalloc "refs/tags/$tag:refs/tags/$tag"
  git -C "$RUN_DIR/mimalloc" archive --format=tar --prefix="${file%.tar.gz}/" "$tag" | gzip -n >"$dest"
  [[ "$(md5sum "$dest" | cut -d' ' -f1)" == "$md5" ]] || {
    rm -f "$dest"
    die "rebuilt $file does not match its MD5"
  }
}

run_app() {
  need Xvfb dbus-run-session gnome-keyring-daemon import xdotool
  local model_log="$RUN_DIR/model.log"
  python3 -I "$ROOT_DIR/scripts/verify_scripted_model.py" "$RUN_DIR/model.port" >"$model_log" 2>&1 &
  local tries=0
  until [[ -s "$RUN_DIR/model.port" ]]; do
    ((tries++ < 50)) || die "scripted model did not start"
    sleep 0.2
  done
  MODEL_PORT="$(cat "$RUN_DIR/model.port")"
  start_backend app 1
  local url="$BACKEND_URL"

  # The app's HOME and XDG dirs: settings, secure storage (a keyring in a
  # private D-Bus session) and the stand-in browser for sign-in.
  local apphome="$RUN_DIR/apphome"
  mkdir -p "$apphome"/{config,data/applications,cache,state,runtime}
  chmod 700 "$apphome/runtime"
  cat >"$apphome/data/applications/hermes-verify-browser.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hermes verify browser
Exec=python3 -I $ROOT_DIR/scripts/verify_browser.py %u
MimeType=x-scheme-handler/http;x-scheme-handler/https;
NoDisplay=true
EOF
  cat >"$apphome/config/mimeapps.list" <<EOF
[Default Applications]
x-scheme-handler/http=hermes-verify-browser.desktop
x-scheme-handler/https=hermes-verify-browser.desktop
EOF

  # An X display of our own: Xvfb picks a free number and reports it.
  Xvfb -displayfd 3 -screen 0 1280x720x24 -nolisten tcp 3>"$RUN_DIR/display" >"$RUN_DIR/xvfb.log" 2>&1 &
  tries=0
  until [[ -s "$RUN_DIR/display" ]]; do
    ((tries++ < 50)) || die "Xvfb did not start"
    sleep 0.2
  done
  local display=":$(tr -d '\n' <"$RUN_DIR/display")"
  log "app tier: display $display, backend $url"

  seed_mimalloc
  mkdir -p "$OUT_DIR/shots"
  local status=0
  (cd "$ROOT_DIR" && env \
    HOME="$apphome" XDG_CONFIG_HOME="$apphome/config" XDG_DATA_HOME="$apphome/data" \
    XDG_CACHE_HOME="$apphome/cache" XDG_STATE_HOME="$apphome/state" XDG_RUNTIME_DIR="$apphome/runtime" \
    PUB_CACHE="${PUB_CACHE:-$ORIG_HOME/.pub-cache}" DISPLAY="$display" \
    GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-$ORIG_HOME/.gitconfig}" \
    HERMES_VERIFY_USER="$VERIFY_USER" HERMES_VERIFY_PASSWORD="$VERIFY_PASSWORD" \
    HERMES_VERIFY_BROWSER_LOG="$RUN_DIR/browser.log" NM_LOG="$RUN_DIR/fake-nm.log" KEYRING_PASSWORD="$VERIFY_SECRET" \
    timeout -k 10 "$APP_TIMEOUT" dbus-run-session -- bash -c '
      set -e
      printf %s "$KEYRING_PASSWORD" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
      unset KEYRING_PASSWORD
      # connectivity_plus asks NetworkManager on the system bus, which a
      # container lacks. A private second bus with a stand-in service (an empty
      # object manager) keeps the app from failing on that at startup.
      DBUS_SYSTEM_BUS_ADDRESS="$(dbus-daemon --session --fork --print-address)"
      export DBUS_SYSTEM_BUS_ADDRESS
      dart run scripts/verify_fake_nm.dart >"$NM_LOG" 2>&1 &
      for _ in $(seq 150); do
        grep -q ready "$NM_LOG" && break
        sleep 0.2
      done
      grep -q ready "$NM_LOG" || { cat "$NM_LOG" >&2; echo "fake NetworkManager did not start" >&2; exit 1; }
      exec "$@"' bash \
    flutter test --no-pub --suppress-analytics -d linux integration_test/verify_flow_test.dart \
    --dart-define=HERMES_SERVER_URL="$url" \
    --dart-define=HERMES_VERIFY_SHOTS="$OUT_DIR/shots") >"$RUN_DIR/app-test.log" 2>&1 &
  wait "$!" || status=$?
  tail -n 40 "$RUN_DIR/app-test.log" >&2
  HERMES_DEV_STATE_DIR="$RUN_DIR/app" "$ROOT_DIR/scripts/dev-backend.sh" stop >&2 || true
  ((status == 0)) || die "app tier failed (exit $status; log: $OUT_DIR/app-test.log)"
  log "app tier passed; screenshots in $OUT_DIR/shots"
}

# --- run -------------------------------------------------------------------

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  set +e
  local state
  for state in "${BACKENDS[@]}"; do
    HERMES_DEV_STATE_DIR="$state" "$ROOT_DIR/scripts/dev-backend.sh" stop >/dev/null 2>&1
  done
  kill_marked "$RUN_DIR"
  mkdir -p "$OUT_DIR"
  for state in contract-test.log app-test.log browser.log model.log contract/dashboard.log app/dashboard.log; do
    [[ -f "$RUN_DIR/$state" ]] && cp "$RUN_DIR/$state" "$OUT_DIR/${state//\//-}"
  done
  rm -rf "$RUN_DIR"
  # Keep the newest ten runs' screenshots and logs.
  local verify_out="$ROOT_DIR/build/verify" old_run
  if [[ "$(dirname "$OUT_DIR")" == "$verify_out" ]]; then
    while IFS= read -r old_run; do
      [[ -n "$old_run" ]] && rm -rf "${verify_out:?}/$old_run"
    done < <(ls -1t "$verify_out" | tail -n +11)
  fi
  if [[ -n "$(marked_pids "$RUN_DIR")" ]]; then
    log "WARNING: processes of this run survived: $(marked_pids "$RUN_DIR" | tr '\n' ' ')"
    status=1
  fi
  log "cleaned up $RUN_DIR; logs in $OUT_DIR"
  exit "$status"
}

case "$MODE" in
  all | contract | app) ;;
  clean)
    cmd_clean
    exit 0
    ;;
  *)
    echo "usage: $0 [all|contract|app|clean]" >&2
    exit 2
    ;;
esac

[[ "$(uname -s)" == Linux ]] || die "this runs on Linux; on a Mac use the verify-in-app skill"
need git curl python3 uv npm flutter setsid lsof timeout md5sum

# Paid model calls, external pairing and the Bot Screen stay off, and nothing
# inherited may point a tool at another Hermes.
unset HERMES_DEV_MODEL_CALLS HERMES_DEV_TELEGRAM_PAIRING HERMES_DEV_BOT_SCREEN \
  HERMES_DEV_URL HERMES_DEV_HOME HERMES_DEV_STATE_DIR HERMES_DEV_PORT HERMES_HOME
ORIG_HOME="$HOME"

cmd_clean
HERMES_DIR="$(cd "$ROOT_DIR" && scripts/install-hermes.sh)"

[[ -d "$TMP_ROOT" ]] || die "HERMES_VERIFY_TMP=$TMP_ROOT does not exist"
free_of_tree "$TMP_ROOT"
RUN_DIR="$(mktemp -d "$TMP_ROOT/hermes-verify.XXXXXX")"
RUN_DIR="$(cd "$RUN_DIR" && pwd -P)"
OUT_DIR="${HERMES_VERIFY_OUT:-$ROOT_DIR/build/verify/$(date +%Y%m%d-%H%M%S)-${RUN_DIR##*.}}"
BACKENDS=()
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
free_of_tree "$RUN_DIR"
echo "$$" >"$RUN_DIR/owner"
export HERMES_VERIFY_RUN="$RUN_DIR"

# Synthetic credentials, new for every run and never printed.
VERIFY_USER="verify"
VERIFY_PASSWORD="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(18))')"
VERIFY_SECRET="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(48))')"

log "run $RUN_DIR (hermes $(basename "$HERMES_DIR"))"
case "$MODE" in
  contract) run_contract ;;
  app) run_app ;;
  all)
    run_contract
    run_app
    ;;
esac
log "verify $MODE passed"

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
# on OS-assigned ports and its own X display and D-Bus session, from an
# allowlisted environment that carries no token or key of the caller's. Every
# process inherits HERMES_VERIFY_RUN=<that directory>; on any exit the trap
# stops the backends by their recorded PIDs, kills the run's processes (the
# marked ones, their descendants and the members of the run's own sessions)
# and deletes the directory. Screenshots and logs worth keeping are copied to
# build/verify/<run>/ first. See .claude/skills/verify/SKILL.md.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Names that may carry a secret are never passed on, whatever the allowlist.
secret_name() {
  case "${1^^}" in
    *TOKEN* | *SECRET* | *PASSW* | *CREDENTIAL* | *AUTH* | *_KEY | *_KEY_* | *APIKEY* | *COOKIE* | *SESSION* | *ASKPASS*) return 0 ;;
    AWS_* | GH_* | GITHUB_* | CLOUDSDK_* | GOOGLE_* | AZURE_* | OPENAI* | ANTHROPIC* | OPENROUTER* | HF_* | HUGGINGFACE*) return 0 ;;
  esac
  return 1
}

# The caller's environment, reduced to what the tools need: paths, locale,
# proxy and CA settings, package-manager locations and this script's own
# options. Re-executes once; the copy then refuses to run with anything that
# looks like a secret.
if [[ -z "${HERMES_VERIFY_CLEAN_ENV:-}" ]]; then
  clean_env=(HERMES_VERIFY_CLEAN_ENV=1)
  while IFS= read -r -d '' entry; do
    name="${entry%%=*}"
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    secret_name "$name" && continue
    case "$name" in
      PATH | HOME | USER | LOGNAME | SHELL | LANG | LC_* | TZ | TERM | COLUMNS | LINES) ;;
      http_proxy | https_proxy | no_proxy | all_proxy | HTTP_PROXY | HTTPS_PROXY | NO_PROXY | ALL_PROXY) ;;
      SSL_CERT_FILE | SSL_CERT_DIR | REQUESTS_CA_BUNDLE | CURL_CA_BUNDLE | NODE_EXTRA_CA_CERTS | GIT_SSL_CAINFO | PIP_CERT | UV_NATIVE_TLS) ;;
      PUB_CACHE | PUB_HOSTED_URL | FLUTTER_ROOT | FLUTTER_STORAGE_BASE_URL | XDG_CACHE_HOME) ;;
      HERMES_VERIFY_TMP | HERMES_VERIFY_OUT | HERMES_VERIFY_APP_TIMEOUT | HERMES_AGENT_CACHE) ;;
      *) continue ;;
    esac
    clean_env+=("$entry")
  done </proc/self/environ
  exec env -i "${clean_env[@]}" bash "$0" "$@"
fi
while IFS= read -r -d '' entry; do
  if secret_name "${entry%%=*}"; then
    echo "[verify] error: refusing to run with ${entry%%=*} in the environment" >&2
    exit 1
  fi
done </proc/self/environ

MODE="${1:-all}"
TMP_ROOT="${HERMES_VERIFY_TMP:-/tmp}"
APP_TIMEOUT="${HERMES_VERIFY_APP_TIMEOUT:-1200}"

log() { printf '[verify] %s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# --- processes of a run ----------------------------------------------------

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

# The processes of run $1: the marked ones, plus, among processes started
# after the run began, their descendants and the members of the sessions the
# run created ($1/sids). Hermes scrubs the environment of some children (tool
# runners, package installs), so the marker alone would miss them.
run_pids() {
  local run="$1" since=0 pid line rest
  local -A in_run=() sids=() ppid_of=() sid_of=() start_of=() zombie=()
  [[ -f "$run/start" ]] && since="$(<"$run/start")"
  if [[ -f "$run/sids" ]]; then
    while read -r line; do [[ "$line" =~ ^[0-9]+$ ]] && sids[$line]=1; done <"$run/sids"
  fi
  for pid in $(marked_pids "$run"); do in_run[$pid]=1; done
  local dir f
  for dir in /proc/[0-9]*; do
    pid="${dir#/proc/}"
    { read -r line <"$dir/stat"; } 2>/dev/null || continue
    rest="${line##*) }"
    read -r -a f <<<"$rest"
    [[ "${f[0]}" == Z ]] && zombie[$pid]=1
    ppid_of[$pid]="${f[1]}"
    sid_of[$pid]="${f[3]}"
    start_of[$pid]="${f[19]}"
  done
  local grew=1
  while ((grew)); do
    grew=0
    for pid in "${!ppid_of[@]}"; do
      [[ -n "${in_run[$pid]:-}" || "$pid" == "$$" || "$pid" == "$BASHPID" ]] && continue
      [[ "${start_of[$pid]:-0}" -ge "$since" ]] || continue
      if [[ -n "${in_run[${ppid_of[$pid]}]:-}" || -n "${sids[${sid_of[$pid]}]:-}" ]]; then
        in_run[$pid]=1
        grew=1
      fi
    done
  done
  # A zombie has exited and only waits to be reaped by its parent or PID 1.
  for pid in "${!in_run[@]}"; do
    [[ -d "/proc/$pid" && -z "${zombie[$pid]:-}" ]] && printf '%s\n' "$pid"
  done
}

kill_run() {
  local run="$1" pids tries=0
  mapfile -t pids < <(run_pids "$run")
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
    mapfile -t pids < <(run_pids "$run")
    ((${#pids[@]})) || return 0
    sleep 0.5
    tries=$((tries + 1))
  done
  kill -KILL "${pids[@]}" 2>/dev/null || true
}

# The session id of process $1, recorded so its members are found even after
# they drop the marker. Only sessions this run created are recorded.
record_sid() {
  local line rest f
  read -r line <"/proc/$1/stat"
  rest="${line##*) }"
  read -r -a f <<<"$rest"
  echo "${f[3]}" >>"$RUN_DIR/sids"
}

resolve_tmp_root() {
  [[ -d "$TMP_ROOT" ]] || die "HERMES_VERIFY_TMP=$TMP_ROOT does not exist"
  TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
  case "$TMP_ROOT/" in
    "$(cd "$ROOT_DIR" && pwd -P)"/*) die "refusing: $TMP_ROOT is inside the working tree" ;;
  esac
}

# Runs left behind by a verify.sh that was killed with SIGKILL (no trap ran).
# Only real directories this user owns are touched, never a symlink's target.
cmd_clean() {
  local dir owner
  for dir in "$TMP_ROOT"/hermes-verify.*; do
    [[ -d "$dir" && ! -L "$dir" && -O "$dir" ]] || continue
    if [[ -f "$dir/owner" ]]; then
      owner="$(<"$dir/owner")"
      if [[ "$owner" =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null &&
        [[ "$(tr '\0' ' ' <"/proc/$owner/cmdline" 2>/dev/null)" == *verify.sh* ]]; then
        continue # still running
      fi
    elif [[ -z "$(find "$dir" -maxdepth 0 -mmin +10)" ]]; then
      continue # just created; its owner file may not be written yet
    fi
    log "cleaning stale run $dir"
    kill_run "$dir"
    rm -rf -- "$dir"
  done
}

need() {
  local tool missing=()
  for tool in "$@"; do command -v "$tool" >/dev/null || missing+=("$tool"); done
  ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]} (see .claude/skills/verify/reference.md, Packages)"
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
  # Exported in a subshell rather than passed as arguments, so the synthetic
  # password never shows in a command line. setsid gives the dashboard its own
  # session, recorded for cleanup.
  (
    unset HERMES_HOME
    export HOME="$state/userhome" HERMES_DEV_STATE_DIR="$state"
    export PATH="$HERMES_DIR/.venv/bin:$PATH" HERMES_WEB_DIST="$HERMES_DIR/hermes_cli/web_dist"
    if [[ "$gated" == 1 ]]; then
      export HERMES_DASHBOARD_BASIC_AUTH_USERNAME="$VERIFY_USER"
      export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$VERIFY_PASSWORD"
      export HERMES_DASHBOARD_BASIC_AUTH_SECRET="$VERIFY_SECRET"
    fi
    exec setsid "$ROOT_DIR/scripts/dev-backend.sh" start
  ) >&2 || {
    tail -n 40 "$state/dashboard.log" >&2 2>/dev/null || true
    die "backend $name did not start"
  }
  BACKENDS+=("$state")
  local url pid
  url="$(HERMES_DEV_STATE_DIR="$state" "$ROOT_DIR/scripts/dev-backend.sh" url)"
  pid="$(cat "$state/pid")"
  record_sid "$pid"
  # The process must be ours, on our home, not the real ~/.hermes, and hold
  # no secret but the run's synthetic ones.
  local env_home var
  env_home="$(tr '\0' '\n' <"/proc/$pid/environ" | sed -n 's/^HERMES_HOME=//p' | head -n1)"
  [[ "$env_home" == "$state/home" ]] || die "backend $name runs on HERMES_HOME=$env_home, not $state/home"
  [[ "$env_home" != "$ORIG_HOME/.hermes"* ]] || die "backend $name points at the real ~/.hermes"
  tr '\0' '\n' <"/proc/$pid/environ" | grep -qx "HERMES_VERIFY_RUN=$RUN_DIR" ||
    die "backend $name does not carry this run's marker"
  while IFS= read -r var; do
    [[ "$var" == HERMES_DASHBOARD_BASIC_AUTH_* ]] && continue
    secret_name "$var" && die "backend $name has $var in its environment"
  done < <(tr '\0' '\n' <"/proc/$pid/environ" | cut -d= -f1)
  log "backend $name: $url (pid $pid, home $state/home, password gate: $gated)"
  BACKEND_URL="$url"
}

# --- tiers -----------------------------------------------------------------

run_contract() {
  # No default model, as in CI: some contract tests expect a backend without
  # one (and skip what needs one).
  start_backend contract 0
  local url="$BACKEND_URL"
  log "contract tier: real backend, Bot Mode chat and hosted group contracts"
  # The tests' own temp dirs go into the run dir too, so a test that dies
  # before its teardown leaves nothing in /tmp.
  mkdir -p "$RUN_DIR/tmp"
  local status=0
  # In the background and waited for, so TERM or INT to this script runs the
  # trap at once instead of after the tests finish; in a session of its own,
  # recorded for cleanup.
  (cd "$ROOT_DIR" && TMPDIR="$RUN_DIR/tmp" HERMES_DEV_URL="$url" HERMES_DEV_HOME="$RUN_DIR/contract/home" \
    exec setsid flutter test --no-pub --suppress-analytics --concurrency=1 \
    test/real_backend_contract_test.dart \
    test/bot_mode_chat_contract_test.dart \
    test/bot_mode/group_protocol/real_groups_contract_test.dart) >"$RUN_DIR/contract-test.log" 2>&1 &
  echo "$!" >>"$RUN_DIR/sids"
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

# The free scripted model the app tier's backend uses as its default, so no
# turn needs a provider key. Sets MODEL_PORT.
start_model() {
  [[ -n "${MODEL_PORT:-}" ]] && return
  python3 -I "$ROOT_DIR/scripts/verify_scripted_model.py" "$RUN_DIR/model.port" >"$RUN_DIR/model.log" 2>&1 &
  local tries=0
  until [[ -s "$RUN_DIR/model.port" ]]; do
    ((tries++ < 50)) || die "scripted model did not start"
    sleep 0.2
  done
  MODEL_PORT="$(cat "$RUN_DIR/model.port")"
}

run_app() {
  need Xvfb dbus-run-session gnome-keyring-daemon import xdotool
  local tries=0
  start_model
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
Exec=python3 -I "$ROOT_DIR/scripts/verify_browser.py" %u
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
  # Exported in a subshell, not passed as arguments, so no secret shows in a
  # command line; in a session of its own, recorded for cleanup.
  (
    cd "$ROOT_DIR"
    export HOME="$apphome" XDG_CONFIG_HOME="$apphome/config" XDG_DATA_HOME="$apphome/data"
    export XDG_CACHE_HOME="$apphome/cache" XDG_STATE_HOME="$apphome/state" XDG_RUNTIME_DIR="$apphome/runtime"
    export PUB_CACHE="${PUB_CACHE:-$ORIG_HOME/.pub-cache}" DISPLAY="$display"
    # The isolated HOME hides Flutter's safe.directory entry.
    export GIT_CONFIG_GLOBAL="$ORIG_HOME/.gitconfig"
    export HERMES_VERIFY_USER="$VERIFY_USER" HERMES_VERIFY_PASSWORD="$VERIFY_PASSWORD"
    export HERMES_VERIFY_ORIGIN="$url" HERMES_VERIFY_BROWSER_LOG="$RUN_DIR/browser.log"
    export NM_LOG="$RUN_DIR/fake-nm.log" KEYRING_PASSWORD="$VERIFY_KEYRING"
    exec setsid timeout -k 10 "$APP_TIMEOUT" dbus-run-session -- bash -c '
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
      --dart-define=HERMES_VERIFY_SHOTS="$OUT_DIR/shots"
  ) >"$RUN_DIR/app-test.log" 2>&1 &
  echo "$!" >>"$RUN_DIR/sids"
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
  kill_run "$RUN_DIR"
  mkdir -p "$OUT_DIR"
  for state in contract-test.log app-test.log browser.log model.log contract/dashboard.log app/dashboard.log; do
    [[ -f "$RUN_DIR/$state" ]] && cp "$RUN_DIR/$state" "$OUT_DIR/${state//\//-}"
  done
  # Builtins only: an external command here would carry the marker itself.
  local survivors=()
  mapfile -t survivors < <(run_pids "$RUN_DIR")
  rm -rf -- "$RUN_DIR"
  # Keep the newest ten runs' screenshots and logs.
  local verify_out="$ROOT_DIR/build/verify" old_run
  if [[ "$(dirname "$OUT_DIR")" == "$verify_out" ]]; then
    while IFS= read -r old_run; do
      [[ -n "$old_run" ]] && rm -rf -- "${verify_out:?}/$old_run"
    done < <(ls -1t "$verify_out" | tail -n +11)
  fi
  if ((${#survivors[@]})); then
    log "WARNING: processes of this run survived: ${survivors[*]}"
    status=1
  fi
  log "cleaned up $RUN_DIR; logs in $OUT_DIR"
  ((status == 0)) && [[ -n "${PASSED:-}" ]] && log "verify $MODE passed"
  exit "$status"
}

case "$MODE" in
  all | contract | app) ;;
  clean)
    resolve_tmp_root
    cmd_clean
    exit 0
    ;;
  *)
    echo "usage: $0 [all|contract|app|clean]" >&2
    exit 2
    ;;
esac

[[ "$(uname -s)" == Linux ]] || die "this runs on Linux; on a Mac use the verify-in-app skill"
need git curl python3 uv npm flutter setsid lsof timeout md5sum flock find

# Paid model calls, external pairing and the Bot Screen stay off, and nothing
# inherited may point a tool at another Hermes. (The allowlist above drops
# these already; this keeps it true if the allowlist grows.)
unset HERMES_DEV_MODEL_CALLS HERMES_DEV_TELEGRAM_PAIRING HERMES_DEV_BOT_SCREEN \
  HERMES_DEV_URL HERMES_DEV_HOME HERMES_DEV_STATE_DIR HERMES_DEV_PORT HERMES_HOME
ORIG_HOME="$HOME"

resolve_tmp_root
# One run per checkout: runs share build/linux and the mimalloc seed.
mkdir -p "$ROOT_DIR/build/verify"
exec 8>"$ROOT_DIR/build/verify/.lock"
flock -n 8 || die "another verify.sh run is using this checkout; use another worktree"
cmd_clean
HERMES_DIR="$(cd "$ROOT_DIR" && scripts/install-hermes.sh)"

RUN_DIR="$(mktemp -d "$TMP_ROOT/hermes-verify.XXXXXX")"
OUT_DIR="${HERMES_VERIFY_OUT:-$ROOT_DIR/build/verify/$(date +%Y%m%d-%H%M%S)-${RUN_DIR##*.}}"
BACKENDS=()
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "$$" >"$RUN_DIR/owner"
# Processes of this run start after this verify.sh did.
read -r line </proc/$$/stat
rest="${line##*) }"
read -r -a fields <<<"$rest"
echo "${fields[19]}" >"$RUN_DIR/start"
export HERMES_VERIFY_RUN="$RUN_DIR"

# Synthetic credentials, new for every run and never printed.
VERIFY_USER="verify"
VERIFY_PASSWORD="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(18))')"
VERIFY_SECRET="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(48))')"
VERIFY_KEYRING="$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(18))')"

log "run $RUN_DIR (hermes $(basename "$HERMES_DIR"))"
case "$MODE" in
  contract) run_contract ;;
  app) run_app ;;
  all)
    run_contract
    run_app
    ;;
esac
PASSED=1

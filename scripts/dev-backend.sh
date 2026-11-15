#!/usr/bin/env bash
# Runs a throwaway Hermes Agent dashboard for trying the app against a real
# backend, without touching the real ~/.hermes.
#
#   scripts/dev-backend.sh start   # start on a free port, wait until ready
#   scripts/dev-backend.sh start --launch-profile NAME [--sticky-profile NAME]
#                                  # start the dashboard as `hermes -p NAME dashboard`
#   scripts/dev-backend.sh url     # print the base URL of the running backend
#   scripts/dev-backend.sh status  # running? which URL? which home?
#   scripts/dev-backend.sh stop    # stop only the process this script started
#
# Safe to run from several checkouts/worktrees at once: state (throwaway
# HERMES_HOME, pid, port, log) lives in this checkout's .dart_tool/hermes-dev/
# and the OS picks the port. State survives `stop`, so restarts are quick;
# delete the directory to start clean. Set HERMES_DEV_PORT to force a port,
# and HERMES_DEV_STATE_DIR to keep the state somewhere else (scripts/verify.sh
# puts it in a temporary directory outside the working tree).
#
# --launch-profile NAME makes NAME the profile the dashboard was launched with,
# which GET /api/profiles/active reports as `current`. NAME is created in the
# throwaway home first (once: a profile that is there already is reused), with
# no wrapper alias, so nothing lands in ~/.local/bin. --sticky-profile NAME
# creates another profile and makes it the sticky `active` one, which `hermes
# profile use` writes and the launch profile does not follow. Flags only, no
# environment variables: every start removes the home's `active_profile` unless
# a sticky profile is given, so a plain start after a launch-profile one
# launches the default profile again. NAME may not be one Hermes reserves
# (scripts/profile-names.sh).
#
# Before any `hermes` call the script refuses a state directory at or under the
# real Hermes home ($HOME/.hermes) or under an ambient HERMES_HOME, where
# Hermes would write the real profiles; profile commands run with a throwaway
# HOME of their own.
#
# Never use `hermes dashboard --stop` here: it kills every Hermes web server
# on the machine, including ones other sessions or the developer started.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${HERMES_DEV_STATE_DIR:-$ROOT_DIR/.dart_tool/hermes-dev}"
HOME_DIR="$STATE_DIR/home"
PID_FILE="$STATE_DIR/pid"
PORT_FILE="$STATE_DIR/port"
LOG_FILE="$STATE_DIR/dashboard.log"
READY_TIMEOUT="${HERMES_DEV_READY_TIMEOUT:-120}"
LAUNCH_FILE="$STATE_DIR/launch-profile"

# shellcheck source=profile-names.sh
source "$ROOT_DIR/scripts/profile-names.sh"

listening_pid() { lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null | head -n1 || true; }

# True only if the recorded pid still owns the recorded port, so a recycled pid
# or a port reused by something else is never mistaken for ours.
ours() {
  [[ -f "$PID_FILE" && -f "$PORT_FILE" ]] || return 1
  local pid port
  pid="$(cat "$PID_FILE")"
  port="$(cat "$PORT_FILE")"
  [[ -n "$pid" && "$(listening_pid "$port")" == "$pid" ]]
}

base_url() { echo "http://127.0.0.1:$(cat "$PORT_FILE")"; }

reported_home() {
  curl -fsS -m 5 "$(base_url)/api/status" |
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("hermes_home",""))'
}

# A dashboard behind its password gate leaves hermes_home out of /api/status;
# on Linux the listening process's own environment still says which home it
# was given. That is a weaker check than the server's own answer: it reads the
# environment this script set, not where the server actually writes.
process_home() {
  local environ="/proc/$(cat "$PID_FILE")/environ"
  [[ -r "$environ" ]] || return 0
  tr '\0' '\n' <"$environ" | sed -n 's/^HERMES_HOME=//p' | head -n1
}

# The physical path of $1 even when it, or part of it, does not exist yet:
# nothing is created to find out.
resolve_path() {
  local path="$1" rest=""
  while [[ ! -d "$path" ]]; do
    rest="/$(basename "$path")$rest"
    path="$(dirname "$path")"
  done
  echo "$(cd "$path" && pwd -P)$rest"
}

# Exits unless the state directory is clear of the real Hermes home: with
# HERMES_HOME at or under ~/.hermes (or an ambient HERMES_HOME) Hermes takes
# that directory for its root, and `profile create` and `profile use` would
# write the real profiles and the real `active_profile`. A `.` or `..` segment
# is refused outright (a path that does not exist yet is only checked
# lexically), and so is a run where the real home cannot be found.
refuse_real_hermes_home() {
  local state real home path
  for path in "$STATE_DIR" "${HERMES_HOME:-}"; do
    if has_dot_segment "$path"; then
      echo "refusing: '$path' has a . or .. segment; give an absolute path without them" >&2
      exit 3
    fi
  done
  home="$(real_user_home || true)"
  if [[ -z "$home" ]]; then
    echo "refusing: HOME is unset and the passwd entry names no home, so the real Hermes home cannot be told" >&2
    exit 3
  fi
  state="$(resolve_path "$STATE_DIR")"
  local guarded=("$(resolve_path "$home/.hermes")")
  # Python takes HOME first, the passwd entry otherwise: guard both.
  local passwd_home
  passwd_home="$(real_passwd_home || true)"
  [[ -n "$passwd_home" ]] && guarded+=("$(resolve_path "$passwd_home/.hermes")")
  [[ -n "${HERMES_HOME:-}" ]] && guarded+=("$(resolve_path "$HERMES_HOME")")
  for real in "${guarded[@]}"; do
    if [[ "$state" == "$real" || "$state" == "$real"/* ]]; then
      echo "refusing: the state directory $state is at or under $real, a real Hermes home" >&2
      echo "set HERMES_DEV_STATE_DIR to a directory elsewhere" >&2
      exit 3
    fi
  done
}

# Creates profile $1 in the throwaway home unless it is there already. Never
# writes a wrapper alias, and runs with a throwaway HOME.
create_profile() {
  [[ -d "$HOME_DIR/profiles/$1" ]] && return 0
  mkdir -p "$STATE_DIR/userhome"
  HOME="$STATE_DIR/userhome" HERMES_HOME="$HOME_DIR" hermes profile create "$1" --no-alias --no-skills >>"$LOG_FILE" 2>&1 || {
    echo "could not create profile $1; last log lines:" >&2
    tail -n 20 "$LOG_FILE" >&2
    exit 1
  }
}

cmd_start() {
  local launch="" sticky="" problem
  shift || true
  while (($#)); do
    case "$1" in
      --launch-profile)
        launch="${2:?--launch-profile needs a name}"
        shift 2
        ;;
      --sticky-profile)
        sticky="${2:?--sticky-profile needs a name}"
        shift 2
        ;;
      *)
        echo "unknown option: $1" >&2
        exit 2
        ;;
    esac
  done
  if [[ -n "$launch" ]] && ! problem="$(profile_name_problem "$launch")"; then
    echo "invalid launch profile: $problem" >&2
    exit 2
  fi
  if [[ -n "$sticky" ]] && ! problem="$(profile_name_problem "$sticky")"; then
    echo "invalid sticky profile: $problem" >&2
    exit 2
  fi
  if [[ -n "$sticky" && -z "$launch" ]]; then
    echo "--sticky-profile only makes sense with --launch-profile" >&2
    exit 2
  fi
  if [[ -n "$launch" && "$launch" == "$sticky" ]]; then
    echo "the sticky profile must differ from the launch profile" >&2
    exit 2
  fi
  refuse_real_hermes_home
  if ! command -v hermes >/dev/null; then
    echo "hermes not found on PATH. Install Hermes Agent:" >&2
    echo "  https://github.com/NousResearch/hermes-agent (see its README)" >&2
    echo "or use the recipe in .claude/skills/verify-in-app/SKILL.md (\"Hermes Agent setup\")." >&2
    exit 1
  fi
  if ours; then
    echo "already running: $(base_url) (pid $(cat "$PID_FILE"))"
    return
  fi
  if [[ -n "${HERMES_DEV_PORT:-}" && -n "$(listening_pid "$HERMES_DEV_PORT")" ]]; then
    echo "port $HERMES_DEV_PORT is taken by another process" >&2
    exit 1
  fi

  mkdir -p "$HOME_DIR"
  rm -f "$PID_FILE" "$PORT_FILE" "$LAUNCH_FILE"
  # The state directory outlives a run: a sticky profile left by an earlier
  # launch-profile start must not decide which profile this start launches.
  [[ -n "$sticky" ]] || rm -f "$HOME_DIR/active_profile"
  : >"$LOG_FILE"
  local launch_args=()
  if [[ -n "$launch" ]]; then
    create_profile "$launch"
    if [[ -n "$sticky" ]]; then
      create_profile "$sticky"
      HOME="$STATE_DIR/userhome" HERMES_HOME="$HOME_DIR" hermes profile use "$sticky" >>"$LOG_FILE" 2>&1 || {
        echo "could not make $sticky the sticky profile" >&2
        exit 1
      }
    fi
    echo "$launch" >"$LAUNCH_FILE"
    launch_args=(-p "$launch")
  fi
  # A launch-profile start runs the dashboard with a throwaway HOME too, so
  # nothing it does can reach the real home. A plain start keeps the caller's
  # HOME as before: it is what `dev-app.sh` and the verify-in-app recipe have
  # always used, and nothing shows the dashboard needs none of it.
  local run_home="${HOME:-}"
  if [[ -n "$launch" ]]; then
    mkdir -p "$STATE_DIR/userhome"
    run_home="$STATE_DIR/userhome"
  fi
  HOME="$run_home" HERMES_HOME="$HOME_DIR" nohup hermes ${launch_args[@]+"${launch_args[@]}"} dashboard --isolated --no-open \
    --port "${HERMES_DEV_PORT:-0}" >>"$LOG_FILE" 2>&1 &
  local launcher=$!

  local waited=0
  until grep -q "HERMES_DASHBOARD_READY" "$LOG_FILE"; do
    if ! kill -0 "$launcher" 2>/dev/null; then
      echo "dashboard exited early; last log lines:" >&2
      tail -n 20 "$LOG_FILE" >&2
      exit 1
    fi
    if ((waited >= READY_TIMEOUT)); then
      echo "dashboard not ready after ${READY_TIMEOUT}s; see $LOG_FILE" >&2
      kill "$launcher" 2>/dev/null || true
      exit 1
    fi
    sleep 1
    waited=$((waited + 1))
  done

  local port
  port="$(sed -n 's/.*HERMES_DASHBOARD_READY port=\([0-9][0-9]*\).*/\1/p' "$LOG_FILE" | head -n1)"
  echo "$port" >"$PORT_FILE"
  listening_pid "$port" >"$PID_FILE"

  # Confirm the backend is using the throwaway home, not the real one.
  # With a launch profile the server reports that profile's own folder
  # (<home>/profiles/<name>); the listener's environment (the fallback behind
  # a password gate) still names the home itself.
  local actual_home want_home="$HOME_DIR"
  actual_home="$(reported_home)"
  if [[ -n "$actual_home" ]]; then
    [[ -n "$launch" ]] && want_home="$HOME_DIR/profiles/$launch"
  else
    actual_home="$(process_home)"
  fi
  if [[ "$actual_home" != "$want_home" && "$actual_home" != "$(cd "$want_home" && pwd -P)" ]]; then
    echo "refusing: backend is using $actual_home, not $want_home" >&2
    cmd_stop
    exit 1
  fi
  if [[ -n "$launch" ]]; then
    echo "ready: $(base_url) (pid $(cat "$PID_FILE"), home $HOME_DIR, launch profile $launch${sticky:+, sticky $sticky})"
  else
    echo "ready: $(base_url) (pid $(cat "$PID_FILE"), home $HOME_DIR)"
  fi
}

cmd_stop() {
  if ours; then
    kill "$(cat "$PID_FILE")"
    echo "stopped"
  else
    echo "nothing of ours running"
  fi
  rm -f "$PID_FILE" "$PORT_FILE"
}

cmd_url() {
  ours || {
    echo "not running" >&2
    exit 1
  }
  base_url
}

cmd_status() {
  if ours; then
    local launch=""
    [[ -f "$LAUNCH_FILE" ]] && launch=", launch profile $(cat "$LAUNCH_FILE")"
    echo "running: $(base_url) (pid $(cat "$PID_FILE"), home $HOME_DIR$launch)"
  else
    echo "not running"
    exit 1
  fi
}

case "${1:-}" in
  start) cmd_start "$@" ;;
  stop) cmd_stop ;;
  url) cmd_url ;;
  status) cmd_status ;;
  *)
    echo "usage: $0 start [--launch-profile NAME [--sticky-profile NAME]]|stop|url|status" >&2
    exit 2
    ;;
esac

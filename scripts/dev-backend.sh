#!/usr/bin/env bash
# Runs a throwaway Hermes Agent dashboard for trying the app against a real
# backend, without touching the real ~/.hermes.
#
#   scripts/dev-backend.sh start   # start on a free port, wait until ready
#   scripts/dev-backend.sh url     # print the base URL of the running backend
#   scripts/dev-backend.sh status  # running? which URL? which home?
#   scripts/dev-backend.sh stop    # stop only the process this script started
#
# Safe to run from several checkouts/worktrees at once: state (throwaway
# HERMES_HOME, pid, port, log) lives in this checkout's .dart_tool/hermes-dev/
# and the OS picks the port. State survives `stop`, so restarts are quick;
# delete the directory to start clean. Set HERMES_DEV_PORT to force a port.
#
# Never use `hermes dashboard --stop` here: it kills every Hermes web server
# on the machine, including ones other sessions or the developer started.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$ROOT_DIR/.dart_tool/hermes-dev"
HOME_DIR="$STATE_DIR/home"
PID_FILE="$STATE_DIR/pid"
PORT_FILE="$STATE_DIR/port"
LOG_FILE="$STATE_DIR/dashboard.log"
READY_TIMEOUT="${HERMES_DEV_READY_TIMEOUT:-120}"

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

cmd_start() {
  if ! command -v hermes >/dev/null; then
    echo "hermes not found on PATH. Install Hermes Agent:" >&2
    echo "  https://github.com/NousResearch/hermes-agent (see its README)" >&2
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
  rm -f "$PID_FILE" "$PORT_FILE"
  : >"$LOG_FILE"
  HERMES_HOME="$HOME_DIR" nohup hermes dashboard --no-open \
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
  local actual_home
  actual_home="$(reported_home)"
  if [[ "$actual_home" != "$HOME_DIR" && "$actual_home" != "$(cd "$HOME_DIR" && pwd -P)" ]]; then
    echo "refusing: backend is using $actual_home, not $HOME_DIR" >&2
    cmd_stop
    exit 1
  fi
  echo "ready: $(base_url) (pid $(cat "$PID_FILE"), home $HOME_DIR)"
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
    echo "running: $(base_url) (pid $(cat "$PID_FILE"), home $HOME_DIR)"
  else
    echo "not running"
    exit 1
  fi
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  url) cmd_url ;;
  status) cmd_status ;;
  *)
    echo "usage: $0 start|stop|url|status" >&2
    exit 2
    ;;
esac

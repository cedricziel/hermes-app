#!/usr/bin/env bash
# Runs the macOS app against this checkout's dev backend and lets you look at
# it: hot reload, per-window screenshots, logs. Needs scripts/dev-backend.sh
# to be running first.
#
#   scripts/dev-app.sh start        # build + launch, wait until it is up
#   scripts/dev-app.sh reload       # hot reload (state kept)
#   scripts/dev-app.sh restart      # hot restart (state reset)
#   scripts/dev-app.sh screenshot [out.png]   # capture this app's window only
#   scripts/dev-app.sh logs [lines]
#   scripts/dev-app.sh stop
#
# Safe alongside other checkouts/worktrees: state lives in this checkout's
# .dart_tool/hermes-dev/, the app is told its server with a build flag (never
# the shared saved address), and screenshots target this app's own window.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$ROOT_DIR/.dart_tool/hermes-dev"
FIFO="$STATE_DIR/flutter.in"
LOG_FILE="$STATE_DIR/app.log"
FLUTTER_PID_FILE="$STATE_DIR/flutter.pid"
HOLDER_PID_FILE="$STATE_DIR/holder.pid"
SHOT_DIR="$STATE_DIR/shots"
PRODUCT_NAME="$(sed -n 's/^PRODUCT_NAME *= *//p' "$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig")"
APP_BINARY="$ROOT_DIR/build/macos/Build/Products/Debug/$PRODUCT_NAME.app/Contents/MacOS/$PRODUCT_NAME"
START_TIMEOUT="${HERMES_DEV_APP_TIMEOUT:-900}"

running() {
  [[ -f "$FLUTTER_PID_FILE" ]] && kill -0 "$(cat "$FLUTTER_PID_FILE")" 2>/dev/null
}

require_running() {
  running || {
    echo "app not running; run: scripts/dev-app.sh start" >&2
    exit 1
  }
}

# Sends a flutter run key ("r", "R", "q") and waits for the log line that
# confirms it, looking only at output written after the key was sent.
send_key() {
  local key="$1" pattern="$2" waited=0 offset
  offset="$(wc -c <"$LOG_FILE")"
  echo "$key" >"$FIFO"
  until tail -c +"$((offset + 1))" "$LOG_FILE" | grep -q "$pattern"; do
    if ! running; then
      echo "flutter exited; see $LOG_FILE" >&2
      exit 1
    fi
    if ((waited >= 60)); then
      echo "no '$pattern' within 60s; see $LOG_FILE" >&2
      exit 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

cmd_start() {
  if running; then
    echo "already running (flutter pid $(cat "$FLUTTER_PID_FILE"))"
    return
  fi
  local url
  url="$("$ROOT_DIR/scripts/dev-backend.sh" url)" || {
    echo "start the backend first: scripts/dev-backend.sh start" >&2
    exit 1
  }

  mkdir -p "$STATE_DIR" "$SHOT_DIR"
  rm -f "$FIFO"
  mkfifo "$FIFO"
  : >"$LOG_FILE"
  # Holds the fifo open for writing so flutter's stdin never sees EOF between
  # the keys we send. Its output must be detached: a background process that
  # keeps the caller's stdout open makes `dev-app.sh start | tail` wait for it.
  sleep 2147483647 <>"$FIFO" >/dev/null 2>&1 &
  echo $! >"$HOLDER_PID_FILE"

  # exec so the recorded pid is flutter itself, not a wrapper subshell that
  # would hold the caller's stdout open (and hang `start | tail`) until exit.
  (cd "$ROOT_DIR" && exec nohup flutter run -d macos \
    --dart-define=HERMES_SERVER_URL="$url" <"$FIFO" >>"$LOG_FILE" 2>&1) &
  echo $! >"$FLUTTER_PID_FILE"

  local waited=0
  until grep -q "Flutter run key commands" "$LOG_FILE"; do
    if ! running; then
      echo "flutter exited early; last log lines:" >&2
      tail -n 30 "$LOG_FILE" >&2
      cleanup
      exit 1
    fi
    if ((waited >= START_TIMEOUT)); then
      echo "app not up after ${START_TIMEOUT}s; see $LOG_FILE" >&2
      cmd_stop
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo "app up against $url"
}

app_pid() { pgrep -f "$APP_BINARY" | head -n1; }

cmd_screenshot() {
  require_running
  local out="${1:-$SHOT_DIR/$(date +%Y%m%d-%H%M%S).png}" pid win
  pid="$(app_pid)" || {
    echo "app process not found" >&2
    exit 1
  }
  mkdir -p "$(dirname "$out")"

  # macOS doesn't paint a covered window, so a capture of a background app
  # shows a stale frame (a hot reload looks like it did nothing). Bring the
  # app forward for the capture, then give focus back.
  local previous
  previous="$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')"
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true"
  sleep 1 # let the frame land
  win="$(xcrun swift "$ROOT_DIR/scripts/window-id.swift" "$pid")"
  screencapture -x -o -l "$win" "$out"
  osascript -e "tell application \"$previous\" to activate" || true
  echo "$out"
}

cleanup() {
  [[ -f "$HOLDER_PID_FILE" ]] && kill "$(cat "$HOLDER_PID_FILE")" 2>/dev/null || true
  rm -f "$FIFO" "$FLUTTER_PID_FILE" "$HOLDER_PID_FILE"
}

cmd_stop() {
  if running; then
    echo q >"$FIFO" || true
    local waited=0
    while running && ((waited < 15)); do
      sleep 1
      waited=$((waited + 1))
    done
    running && kill "$(cat "$FLUTTER_PID_FILE")" 2>/dev/null || true
    echo "stopped"
  else
    echo "not running"
  fi
  cleanup
}

case "${1:-}" in
  start) cmd_start ;;
  reload)
    require_running
    send_key r "Reloaded"
    echo "reloaded"
    ;;
  restart)
    require_running
    send_key R "Restarted application"
    echo "restarted"
    ;;
  screenshot) cmd_screenshot "${2:-}" ;;
  logs) tail -n "${2:-40}" "$LOG_FILE" ;;
  stop) cmd_stop ;;
  *)
    echo "usage: $0 start|reload|restart|screenshot [out.png]|logs [lines]|stop" >&2
    exit 2
    ;;
esac

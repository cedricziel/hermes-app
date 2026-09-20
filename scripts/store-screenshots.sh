#!/usr/bin/env bash
# Takes the App Store and README screenshots of the real app, against a
# throwaway Hermes backend seeded with invented demo chats.
#
#   scripts/store-screenshots.sh ios [iphone|ipad]   # simulators, light and dark
#   scripts/store-screenshots.sh mac       # the Mac app's window, light and dark
#   scripts/store-screenshots.sh finish    # flatten, tidy and size what was taken
#
# Raw captures land in build/screenshots/<device>-<light|dark>/, the finished
# store images in fastlane/screenshots/ios/en-US/ (not committed; regenerate
# them) and the README-sized ones in docs/screenshots/.
#
# The Mac run opens the app and takes over the screen for a few minutes (the
# window has to be in front to be captured), so leave the machine alone.
#
# Needs `hermes` on PATH (see scripts/dev-backend.sh), Xcode with iOS 26
# simulators and Python 3 with Pillow. Each run boots the two simulators and
# leaves them running.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="$ROOT_DIR/build/screenshots"
PORT="${SHOT_PORT:-45777}"
IPHONE="${SHOT_IPHONE:-iPhone 17 Pro Max}"
IPAD="${SHOT_IPAD:-iPad Pro 13-inch (M5)}"
RUNTIME="${SHOT_RUNTIME:-iOS-26}"
HERMES_PYTHON="${HERMES_PYTHON:-$HOME/.hermes/hermes-agent/venv/bin/python}"

udid_of() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
for key, devices in json.load(sys.stdin)["devices"].items():
    if runtime in key:
        for device in devices:
            if device["name"] == name:
                print(device["udid"])
                sys.exit(0)
sys.exit(f"no simulator named {name} for {runtime}")
' "$1" "$RUNTIME"
}

start_backend() {
  local home="$ROOT_DIR/.dart_tool/hermes-dev/home"
  "$ROOT_DIR/scripts/dev-backend.sh" stop >&2 || true
  rm -f "$home"/state.db*
  "$ROOT_DIR/scripts/dev-backend.sh" start >&2
  HERMES_HOME="$home" "$HERMES_PYTHON" "$ROOT_DIR/scripts/seed_demo_sessions.py" >&2
  "$ROOT_DIR/scripts/dev-backend.sh" url
}

# The status bar shows the date on an iPad in the system language, and the
# listing is English.
ensure_english() { # udid
  local udid="$1"
  if xcrun simctl spawn "$udid" defaults read "Apple Global Domain" AppleLocale 2>/dev/null | grep -q '^en_US'; then
    return
  fi
  xcrun simctl spawn "$udid" defaults write "Apple Global Domain" AppleLanguages -array en
  xcrun simctl spawn "$udid" defaults write "Apple Global Domain" AppleLocale -string en_US
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
}

capture() { # device-name label appearance server-url
  local name="$1" label="$2" appearance="$3" url="$4" udid
  udid="$(udid_of "$name")"
  echo "== $label ($appearance) on $name [$udid]"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  ensure_english "$udid"
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged \
    --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
  xcrun simctl ui "$udid" appearance "$appearance"
  rm -rf "$RAW_DIR/$label-$appearance"
  SHOT_PORT="$PORT" SHOT_UDID="$udid" SHOT_DIR="$RAW_DIR/$label-$appearance" \
    flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/store_screenshots_test.dart -d "$udid" \
    --dart-define=HERMES_SERVER_URL="$url" --dart-define=SHOT_PORT="$PORT"
}

cmd_ios() { # [iphone|ipad]
  local only="${1:-}" url
  url="$(start_backend)"
  for appearance in light dark; do
    if [[ -z "$only" || "$only" == iphone ]]; then capture "$IPHONE" iphone "$appearance" "$url"; fi
    if [[ -z "$only" || "$only" == ipad ]]; then capture "$IPAD" ipad "$appearance" "$url"; fi
  done
  "$ROOT_DIR/scripts/dev-backend.sh" stop || true
}

# The Mac window opens at 800x600, below the 900 point breakpoint of the wide
# layout, so this run takes the compact layout, into mac-compact-*. The wide
# shots are taken with the user widening the window by hand (see the
# store-screenshots skill) into mac-*, and finish prefers those. Widening the
# window from a script needs Accessibility permission, and changing the size in
# the xib or in MainFlutterWindow.swift did not change the built app's window.
cmd_mac() {
  local url process
  process="$(sed -n 's/^PRODUCT_NAME *= *//p' "$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig")"
  url="$(start_backend)"
  for appearance in dark light; do
    echo "== mac ($appearance)"
    rm -rf "$RAW_DIR/mac-compact-$appearance"
    SHOT_PORT="$PORT" SHOT_MAC_PROCESS="$process" SHOT_DIR="$RAW_DIR/mac-compact-$appearance" \
      flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/store_screenshots_test.dart -d macos \
      --dart-define=HERMES_SERVER_URL="$url" --dart-define=SHOT_PORT="$PORT" \
      --dart-define=SHOT_THEME="$appearance"
  done
  "$ROOT_DIR/scripts/dev-backend.sh" stop || true
}

case "${1:-}" in
  ios) shift; cmd_ios "$@" ;;
  mac) cmd_mac ;;
  finish) python3 "$ROOT_DIR/scripts/finish_screenshots.py" ;;
  *)
    echo "usage: $0 ios [iphone|ipad] | mac | finish" >&2
    exit 2
    ;;
esac

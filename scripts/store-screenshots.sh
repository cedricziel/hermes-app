#!/usr/bin/env bash
# Takes the App Store and README screenshots of the real app, against a
# throwaway Hermes backend seeded with invented demo chats.
#
#   scripts/store-screenshots.sh ios [iphone|ipad]   # simulators, light and dark
#   scripts/store-screenshots.sh mac [compact]  # the Mac window, wide (or at its default size)
#   scripts/store-screenshots.sh watch     # the watch app, through its paired phone (~3 min)
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
WATCH="${SHOT_WATCH:-Apple Watch Ultra 4 (49mm)}"
RUNTIME="${SHOT_RUNTIME:-iOS-26}"

# The interpreter the installed hermes runs on, which has its dependencies.
hermes_python() {
  if [[ -n "${HERMES_PYTHON:-}" ]]; then
    echo "$HERMES_PYTHON"
  elif hermes --print-runtime-command >/dev/null 2>&1; then
    hermes --print-runtime-command | python3 -c 'import json, sys; print(json.load(sys.stdin)[0])'
  else
    echo "$HOME/.hermes/hermes-agent/venv/bin/python"
  fi
}

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
  # Runs inside $(...), where a failure would not stop the script.
  HERMES_HOME="$home" "$(hermes_python)" "$ROOT_DIR/scripts/seed_demo_sessions.py" >&2 || exit 1
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
# layout, so the test resizes it to SHOT_MAC_WINDOW first (points; the
# finished image is 2880x1800 pixels). `mac compact` keeps the default size,
# into mac-compact-*.
cmd_mac() { # [compact]
  local url process label=mac size="${SHOT_MAC_WINDOW:-1440x900}"
  if [[ "${1:-}" == compact ]]; then label=mac-compact size=""; fi
  process="$(sed -n 's/^PRODUCT_NAME *= *//p' "$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig")"
  url="$(start_backend)"
  for appearance in dark light; do
    echo "== $label ($appearance)"
    rm -rf "$RAW_DIR/$label-$appearance"
    SHOT_PORT="$PORT" SHOT_MAC_PROCESS="$process" SHOT_DIR="$RAW_DIR/$label-$appearance" \
      flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/store_screenshots_test.dart -d macos \
      --dart-define=HERMES_SERVER_URL="$url" --dart-define=SHOT_PORT="$PORT" \
      --dart-define=SHOT_THEME="$appearance" --dart-define=SHOT_WINDOW="$size"
  done
  "$ROOT_DIR/scripts/dev-backend.sh" stop || true
}

# The watch and the phone it is paired with; Xcode pairs the simulators.
pair_of() { # watch name -> "<watch udid> <phone udid>"
  xcrun simctl list pairs -j | python3 -c '
import json, sys
name = sys.argv[1]
for pair in json.load(sys.stdin)["pairs"].values():
    if pair["watch"]["name"] == name:
        print(pair["watch"]["udid"], pair["phone"]["udid"])
        sys.exit(0)
sys.exit(f"no simulator pair with {name}; the watchOS runtime may be missing")
' "$1"
}

# The watch app has no data of its own: it asks the phone app, which asks the
# backend. So the phone app runs too, and the watch screen is captured after the
# threads have come back. Needs the watchOS simulator runtime (Xcode > Settings
# > Components). The simulator cannot be tapped, so this is the screen the watch
# app opens on.
cmd_watch() {
  local url pair watch phone app
  pair="$(pair_of "$WATCH")"
  read -r watch phone <<<"$pair"
  url="$(start_backend)"
  xcrun simctl bootstatus "$phone" -b >/dev/null
  xcrun simctl bootstatus "$watch" -b >/dev/null

  flutter build ios --simulator --debug --no-codesign -d "$phone" \
    --dart-define=HERMES_SERVER_URL="$url"
  app="$ROOT_DIR/build/ios/iphonesimulator/Runner.app"
  xcrun simctl install "$phone" "$app"
  # Installing the phone app does not install the watch app inside it.
  xcrun simctl install "$watch" "$app/Watch/HermesWatch.app"
  xcrun simctl launch "$phone" com.cedricziel.hermesApp

  # The phone takes a minute to notice the hand-installed watch app, and a
  # request made before then waits. Start the watch app afterwards.
  sleep 100
  xcrun simctl terminate "$watch" com.cedricziel.hermesApp.watchkitapp || true
  xcrun simctl launch "$watch" com.cedricziel.hermesApp.watchkitapp
  sleep 20

  mkdir -p "$RAW_DIR/watch-light"
  xcrun simctl io "$watch" screenshot --type=png "$RAW_DIR/watch-light/threads.png"
  "$ROOT_DIR/scripts/dev-backend.sh" stop || true
}

case "${1:-}" in
  ios) shift; cmd_ios "$@" ;;
  mac) shift; cmd_mac "$@" ;;
  watch) cmd_watch ;;
  finish) python3 "$ROOT_DIR/scripts/finish_screenshots.py" ;;
  *)
    echo "usage: $0 ios [iphone|ipad] | mac [compact] | watch | finish" >&2
    exit 2
    ;;
esac

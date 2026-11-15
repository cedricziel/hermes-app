#!/usr/bin/env bash
# Checks scripts/dev-backend.sh start without a real Hermes: a stand-in
# `hermes` on PATH records each call and creates profiles the way the real one
# lays them out. Covers the refusal to start where Hermes would write the real
# profiles (it must refuse before any hermes call and before writing
# anything), name validation, the flags-only options, and starts repeated on
# one state directory.
#
#   scripts/test_dev_backend.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/dev-backend-test.XXXXXX")"
trap 'rm -rf -- "$T"' EXIT
FAKE_HOME="$T/home"
mkdir -p "$T/bin" "$FAKE_HOME/.hermes/profiles/real" "$T/state-elsewhere"
echo "real" >"$FAKE_HOME/.hermes/active_profile"

cat >"$T/bin/hermes" <<'EOF'
#!/usr/bin/env bash
echo "HOME=$HOME HERMES_HOME=${HERMES_HOME:-} :: $*" >>"$HERMES_STUB_LOG"
args=("$@")
[[ "${args[0]:-}" == -p ]] && args=("${args[@]:2}")
case "${args[0]:-} ${args[1]:-}" in
  "profile create") mkdir -p "$HERMES_HOME/profiles/${args[2]}" ;;
  "profile use") echo "${args[2]}" >"$HERMES_HOME/active_profile" ;;
  dashboard*) exit 1 ;;
esac
EOF
chmod +x "$T/bin/hermes"
export HERMES_STUB_LOG="$T/calls.log"
export PATH="$T/bin:$PATH"
unset HERMES_HOME HERMES_DEV_PORT HERMES_DEV_LAUNCH_PROFILE HERMES_DEV_STICKY_PROFILE

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
start() { HOME="$FAKE_HOME" "$ROOT_DIR/scripts/dev-backend.sh" start "$@" 2>"$T/err" >"$T/out"; }
calls() { [[ -f "$HERMES_STUB_LOG" ]] && cat "$HERMES_STUB_LOG" || true; }

# 1. A state directory under the real home is refused before anything runs.
touch "$T/marker"
sleep 1.1
rc=0
HERMES_DEV_STATE_DIR="$FAKE_HOME/.hermes/dev-state" start --launch-profile lp --sticky-profile sp || rc=$?
[[ "$rc" -ne 0 ]] || fail "started under the real home"
grep -q "at or under" "$T/err" || fail "no clear message: $(cat "$T/err")"
[[ -z "$(calls)" ]] || fail "hermes was called: $(calls)"
[[ -z "$(find "$FAKE_HOME" -newer "$T/marker")" ]] || fail "wrote under the home: $(find "$FAKE_HOME" -newer "$T/marker")"
[[ "$(cat "$FAKE_HOME/.hermes/active_profile")" == real ]] || fail "touched the real active_profile"
echo "ok   refuses a state dir under \$HOME/.hermes (exit $rc): $(cat "$T/err" | head -n1)"

# The same plain, with no launch profile: any hermes call is off limits.
rc=0
HERMES_DEV_STATE_DIR="$FAKE_HOME/.hermes" start || rc=$?
[[ "$rc" -ne 0 && -z "$(calls)" ]] || fail "plain start under the real home was not refused"
echo "ok   refuses a plain start there too (exit $rc)"

# 2. Under an ambient HERMES_HOME.
rc=0
HERMES_HOME="$T/ambient" HERMES_DEV_STATE_DIR="$T/ambient/sub/state" start --launch-profile lp || rc=$?
[[ "$rc" -ne 0 && -z "$(calls)" && ! -e "$T/ambient" ]] || fail "ambient HERMES_HOME not refused cleanly"
grep -q "at or under" "$T/err" || fail "no clear message for ambient HERMES_HOME"
echo "ok   refuses a state dir under an ambient HERMES_HOME (exit $rc)"

# 3. Names Hermes does not accept never reach it.
for name in default hermes root status Upper 'bad name' ../x; do
  rc=0
  HERMES_DEV_STATE_DIR="$T/state-elsewhere" start --launch-profile "$name" || rc=$?
  [[ "$rc" -eq 2 ]] || fail "'$name' gave exit $rc, not 2"
done
rc=0
HERMES_DEV_STATE_DIR="$T/state-elsewhere" start --launch-profile lp --sticky-profile lp || rc=$?
[[ "$rc" -eq 2 && -z "$(calls)" ]] || fail "same launch and sticky profile"
echo "ok   rejects reserved and malformed names with exit 2"

# 4. Stray variables from the test do not change a plain start.
S="$T/state-elsewhere"
rc=0
HERMES_DEV_LAUNCH_PROFILE=stray HERMES_DEV_STICKY_PROFILE=stray2 HERMES_DEV_STATE_DIR="$S" start || rc=$?
[[ "$rc" -eq 1 ]] || fail "a plain start with stray variables gave exit $rc (the stand-in dashboard exits 1)"
calls | grep -q "profile" && fail "profile commands ran: $(calls)"
calls | grep -q -- " -p " && fail "started with -p: $(calls)"
echo "ok   ignores HERMES_DEV_LAUNCH_PROFILE and HERMES_DEV_STICKY_PROFILE"

# 5. One state directory, started again and again.
: >"$HERMES_STUB_LOG"
HERMES_DEV_STATE_DIR="$S" start --launch-profile lp --sticky-profile sp || true
[[ "$(cat "$S/home/active_profile")" == sp ]] || fail "sticky profile not set"
HERMES_DEV_STATE_DIR="$S" start --launch-profile lp --sticky-profile sp || true
creates="$(calls | grep -c 'profile create lp' || true)"
[[ "$creates" -eq 1 ]] || fail "lp was created $creates times"
HERMES_DEV_STATE_DIR="$S" start --launch-profile lp || true
[[ ! -e "$S/home/active_profile" ]] || fail "the sticky profile survived a start without one"
HERMES_DEV_STATE_DIR="$S" start || true
[[ ! -e "$S/home/active_profile" ]] || fail "a plain start left a sticky profile"
last="$(calls | tail -n1)"
[[ "$last" == *":: dashboard "* && "$last" != *" -p "* ]] || fail "a plain start launched a profile: $last"
calls | grep -q "HOME=$S/userhome " || fail "profile commands did not run with a throwaway HOME"
echo "ok   --launch-profile twice reuses the profile; a start without --sticky-profile drops the sticky one; a plain start launches the default"

echo "all dev-backend checks passed"

#!/usr/bin/env bash
# Trial-merge check: run before arming auto-merge on a PR, or before a hand merge.
#
#   scripts/premerge_check.sh <pr> [--stack <n> ...] [--others <n> ...] [--base main] [--keep]
#
# Merges the PR's head into the CURRENT origin/<base> in a throwaway worktree
# outside the repo, then runs pub get, analyze, the architecture tests and the
# affected tests there. Two PRs that are each green on their own can break main
# together (a duplicate declaration; #1196 rewrote a workflow test while #1213
# changed the screen it drives); this finds that before the merge, not after.
#
# --stack merges those PRs' heads onto the base first, in the given order, then
# this PR; the affected-test selection covers all of them.
#
# Affected tests (scripts/premerge_affected_tests.py, which says what it follows
# and what it does not): the test files the PR(s) changed, then the ones main
# changed since the merge base, then the ones that import a changed lib/ file,
# then the ones that import anything under a touched lib/src/<dir>/.
# PREMERGE_TEST_BUDGET (600 s), PREMERGE_TEST_CAP (150 files),
# PREMERGE_TEST_CONCURRENCY (4), PREMERGE_TEST_BATCH (20 files per flutter test).
# test/widgetbook_test.dart never goes into a batch (one process runs a 15 GB
# machine out of memory): it runs last in CATALOG_PARTS (6) sequential
# `--total-shards` parts, as scripts/test-shard.sh does for CI.
# A theme-wide or helper-wide selection (a change to lib/src/theme/ or to
# test/support/fake_hermes_server.dart) needs PREMERGE_TEST_CAP and
# PREMERGE_TEST_BUDGET raised; one recent run needed a budget of 3000 s.
# PREMERGE_ALLOW_CAPPED=1 accepts a capped run as a pass (exit 0).
#
# Exit: 0 pass | 1 usage or fetch error, a selection error, or the PR is already
#       in the base | 2 merge conflict | 3 pub get or analyze failed
#       4 architecture tests failed | 5 affected tests failed
#       6 affected tests cut short by the budget (not a pass)
#       7 PASS (CAPPED: ...): the cap dropped (c2) directory-wide tests, so the
#         run is not the full selection; exit 0 only with PREMERGE_ALLOW_CAPPED=1.
#         A failure (5) or a budget cut (6) wins over capped.
#
# Uses git only. PREMERGE_LIST_OPEN=1 also asks `gh` (GraphQL, so not in cloud
# sessions) for the open PRs that have auto-merge armed and adds them to
# --others. The caller's working tree, index, branch and stash are never
# touched; nothing is pushed.
#
# A SIGKILL cannot be trapped and leaves refs/premerge/<host>.<ns>.<pid>, a
# premerge.* temp dir and its registered worktree behind. The next run sweeps
# those whose pid is dead (the pid file is <tempdir>/pid), and only when host
# and pid namespace match too: a pid from another host or container means
# nothing here (an unknown namespace, "-" or "x", matches any). --keep removes
# the pid file, so a kept worktree is never swept. Leftovers of older versions
# (refs/premerge/<pid>) are never swept; an old 4-field pid file is swept when
# its host and repo match and its pid is dead.
set -euo pipefail

# An inherited git environment would aim every git call below at the caller's
# repo, index or config instead of ours. Drop all GIT_* except a few that only
# affect transport, terminal or tracing.
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do
  case "$v" in
    GIT_SSH | GIT_SSH_COMMAND | GIT_ASKPASS | GIT_TERMINAL_PROMPT | GIT_EXEC_PATH | \
      GIT_CONFIG_GLOBAL | GIT_CONFIG_SYSTEM | GIT_CONFIG_NOSYSTEM | GIT_TRACE*) ;;
    *) unset "$v" ;;
  esac
done

USAGE="Usage: scripts/premerge_check.sh <pr-number> [--stack <n> <n> ...] [--others <n> <n> ...] [--base main] [--keep]"

die_usage() {
  echo "premerge: $1" >&2
  echo "$USAGE" >&2
  exit 1
}

is_num() { case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR=""
OTHERS=()
STACK=()
BASE="main"
KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --others)
      shift
      [ $# -gt 0 ] && ! [[ "$1" == --* ]] || die_usage "--others needs at least one PR number"
      while [ $# -gt 0 ] && ! [[ "$1" == --* ]]; do
        is_num "$1" || die_usage "not a PR number: $1"
        OTHERS+=("$1")
        shift
      done
      ;;
    --stack)
      shift
      [ $# -gt 0 ] && ! [[ "$1" == --* ]] || die_usage "--stack needs at least one PR number"
      while [ $# -gt 0 ] && ! [[ "$1" == --* ]]; do
        is_num "$1" || die_usage "not a PR number: $1"
        STACK+=("$1")
        shift
      done
      ;;
    --base)
      [ $# -ge 2 ] || die_usage "--base needs a branch name"
      BASE="$2"
      shift 2
      ;;
    --keep)
      KEEP=1
      shift
      ;;
    -h | --help)
      echo "$USAGE"
      exit 0
      ;;
    --*) die_usage "unknown option: $1" ;;
    *)
      [ -z "$PR" ] || die_usage "only one PR number goes first; use --others for the rest"
      is_num "$1" || die_usage "not a PR number: $1"
      PR="$1"
      shift
      ;;
  esac
done
[ -n "$PR" ] || die_usage "missing PR number"

# Numeric settings: a typo must not turn into a silent default (or, for the
# budget, an unlimited run).
positive_setting() {
  local name="$1" default="$2" val
  val="${!name-$default}"
  if ! is_num "$val" || [ "$val" -lt 1 ]; then
    die_usage "$name must be a positive integer, got '$val'"
  fi
  printf '%s' "$val"
}
TEST_BUDGET="$(positive_setting PREMERGE_TEST_BUDGET 600)"
TEST_CAP="$(positive_setting PREMERGE_TEST_CAP 150)"
TEST_CONCURRENCY="$(positive_setting PREMERGE_TEST_CONCURRENCY 4)"
TEST_BATCH="$(positive_setting PREMERGE_TEST_BATCH 20)"
# The Widgetbook test is ~17,500 cases and grows one process past 11 GB, so it
# never goes into a batch: it runs in this many sequential parts, as in
# scripts/test-shard.sh (the same CATALOG_PARTS).
CATALOG_PARTS="$(positive_setting CATALOG_PARTS 6)"
if [ "$CATALOG_PARTS" -gt 99 ]; then
  die_usage "CATALOG_PARTS must be a whole number from 1 to 99, got '$CATALOG_PARTS'"
fi
CATALOG_TEST=test/widgetbook_test.dart

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die_usage "not inside a git repository"
NOHOOKS=(-c core.hooksPath=/dev/null)
RGIT=(git -C "$REPO" "${NOHOOKS[@]}")
COMMON="$("${RGIT[@]}" rev-parse --git-common-dir)"
case "$COMMON" in /*) ;; *) COMMON="$REPO/$COMMON" ;; esac
COMMON="$(cd "$COMMON" && pwd -P)"
HOST="$(hostname 2>/dev/null || echo unknown)"

# Where the trial worktree lives. A TMPDIR inside the repo would put the
# worktree in the caller's tree, so fall back to /tmp.
REPO_PHYS="$(cd "$REPO" && pwd -P)"
TMPBASE="${TMPDIR:-/tmp}"
TMPBASE="${TMPBASE%/}"
if [ -z "$TMPBASE" ] || [ ! -d "$TMPBASE" ]; then TMPBASE=/tmp; fi
TMPBASE_PHYS="$(cd "$TMPBASE" && pwd -P)"
case "$TMPBASE_PHYS/" in
  "$REPO_PHYS"/*)
    echo "premerge: TMPDIR is inside the repository; using /tmp for the trial worktree" >&2
    TMPBASE=/tmp
    TMPBASE_PHYS="$(cd /tmp && pwd -P)"
    ;;
esac

# Optional: open PRs that already have auto-merge armed.
if [ "${PREMERGE_LIST_OPEN:-}" = "1" ]; then
  if command -v gh >/dev/null 2>&1; then
    if armed="$(gh pr list --state open --json number,autoMergeRequest \
      --jq '.[] | select(.autoMergeRequest != null) | .number' 2>/dev/null)"; then
      for n in $armed; do
        [ "$n" = "$PR" ] && continue
        dup=0
        for o in ${OTHERS[@]+"${OTHERS[@]}"}; do [ "$o" = "$n" ] && dup=1; done
        [ "$dup" = 1 ] || OTHERS+=("$n")
      done
    else
      echo "premerge: PREMERGE_LIST_OPEN is set but gh failed; using --others only" >&2
    fi
  else
    echo "premerge: PREMERGE_LIST_OPEN is set but gh is not installed; using --others only" >&2
  fi
fi

FILTERED=()
for o in ${OTHERS[@]+"${OTHERS[@]}"}; do
  [ "$o" = "$PR" ] || FILTERED+=("$o")
done
OTHERS=(${FILTERED[@]+"${FILTERED[@]}"})

# The stack: in the given order, without this PR and without repeats.
FILTERED=()
for s in ${STACK[@]+"${STACK[@]}"}; do
  [ "$s" = "$PR" ] && continue
  dup=0
  for o in ${FILTERED[@]+"${FILTERED[@]}"}; do [ "$o" = "$s" ] && dup=1; done
  [ "$dup" = 1 ] || FILTERED+=("$s")
done
STACK=(${FILTERED[@]+"${FILTERED[@]}"})
STACK_DESC=""
for s in ${STACK[@]+"${STACK[@]}"}; do STACK_DESC="$STACK_DESC #$s"; done
STACK_DESC="${STACK_DESC# }"

OUR_NS="$(readlink /proc/self/ns/pid 2>/dev/null || true)"
OUR_NS="${OUR_NS:--}"
# Ref names cannot hold "[" or ":", so the run's refs carry the host and the
# namespace id as plain characters: refs/premerge/<host>.<ns>.<pid>/...
HOSTTAG="$(printf '%s' "$HOST" | tr -c 'A-Za-z0-9-' '_')"
NSTAG="${OUR_NS//[^0-9]/}"
NSTAG="${NSTAG:-x}"
NS="refs/premerge/$HOSTTAG.$NSTAG.$$"
TMP=""
WT=""
WT_ADMIN=""
CHILD=""
WATCH=""
STAGE="setup"

kill_tree() {
  local pid="$1" kid
  for kid in $(pgrep -P "$pid" 2>/dev/null || true); do kill_tree "$kid"; done
  kill -TERM "$pid" 2>/dev/null || true
}

# A process and everything below it: list first, signal after, so a parent's
# death cannot hide its children.
tree_pids() {
  local pid="$1" kid
  echo "$pid"
  for kid in $(pgrep -P "$pid" 2>/dev/null || true); do tree_pids "$kid"; done
}

# TERM the whole tree, give it two seconds, then KILL whatever is left,
# including processes that were re-parented in between.
kill_hard() {
  local before after p i alive
  before="$(tree_pids "$1")"
  kill -TERM $before 2>/dev/null || true
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    alive=0
    for p in $before; do kill -0 "$p" 2>/dev/null && alive=1; done
    [ "$alive" = 0 ] && break
    sleep 0.1
  done
  after="$(tree_pids "$1")"
  kill -KILL $before $after 2>/dev/null || true
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  if [ -n "$WATCH" ]; then
    kill_tree "$WATCH"
    wait "$WATCH" 2>/dev/null || true
  fi
  if [ -n "$CHILD" ]; then
    kill_hard "$CHILD"
    wait "$CHILD" 2>/dev/null || true
  fi
  # Refs go always, even with --keep: the kept worktree's HEAD holds the commits.
  local ref
  for ref in $("${RGIT[@]}" for-each-ref --format='%(refname)' "$NS" 2>/dev/null || true); do
    "${RGIT[@]}" update-ref -d "$ref" 2>/dev/null || true
  done
  if [ "$KEEP" = 1 ] && [ -n "$WT" ] && [ -d "$WT" ]; then
    rm -f "$TMP/pid"
    echo "premerge: --keep: trial merge left at $WT"
    echo "premerge: remove it with: git worktree remove --force '$WT' && rm -rf '$TMP'"
  else
    # Only our own worktree: never `git worktree prune`, which would also drop
    # the caller's other worktrees whose folders are temporarily away.
    if [ -n "$WT" ]; then
      "${RGIT[@]}" worktree remove --force "$WT" 2>/dev/null || true
      case "$WT_ADMIN" in
        "$COMMON"/worktrees/?*) rm -rf "$WT_ADMIN" ;;
      esac
    fi
    [ -z "$TMP" ] || rm -rf "$TMP"
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'echo "premerge: interrupted during $STAGE; cleaning up" >&2; exit 130' INT
trap 'echo "premerge: hangup during $STAGE; cleaning up" >&2; exit 129' HUP
trap 'echo "premerge: terminated during $STAGE; cleaning up" >&2; exit 143' TERM

# Remove what a SIGKILLed run left: refs, registered worktrees and temp dirs.
# Only directories this script made are touched: directly under TMPBASE, named
# like its mktemp template, holding a pid file "premerge_check <pid> <host>
# <pid-namespace> <git-common-dir>" that matches this host, repo and pid
# namespace, with a dead pid. Anything
# else named premerge.* (another tool's, a project folder) is left alone. A dir
# without the marker (--keep) is left alone too.
# A pid is dead only if neither ps nor kill -0 finds it: kill -0 also fails
# with EPERM for another user's live process.
pid_dead() {
  if ps -p "$1" >/dev/null 2>&1; then return 1; fi
  ! kill -0 "$1" 2>/dev/null
}

read_marker() {
  local tag
  IFS=' ' read -r tag M_PID M_HOST M_NS M_COMMON <"$1/pid" 2>/dev/null || return 1
  case "$M_NS" in
    - | pid:\[*\]) ;;
    *) # old 4-field marker (no namespace): the repo path was read into M_NS
      M_COMMON="$M_NS${M_COMMON:+ $M_COMMON}"
      M_NS="-"
      ;;
  esac
  [ "$tag" = premerge_check ] && is_num "$M_PID"
}

is_dead_run_of_ours() {
  local dir="$1"
  case "${dir##*/}" in premerge.??????) ;; *) return 1 ;; esac
  [ -d "$dir" ] && [ -f "$dir/pid" ] || return 1
  [ "$(cd "$dir/.." && pwd -P)" = "$TMPBASE_PHYS" ] || return 1
  read_marker "$dir" || return 1
  [ "$M_HOST" = "$HOST" ] && [ "$M_COMMON" = "$COMMON" ] || return 1
  # A pid from another pid namespace says nothing about this one: alive.
  if [ "$M_NS" != "$OUR_NS" ] && [ "$M_NS" != "-" ] && [ "$OUR_NS" != "-" ]; then return 1; fi
  pid_dead "$M_PID"
}

sweep_dead_runs() {
  local ref p admin gitdir dir rhost rns rpid
  for ref in $("${RGIT[@]}" for-each-ref --format='%(refname)' refs/premerge 2>/dev/null || true); do
    p="${ref#refs/premerge/}"
    p="${p%%/*}"
    [ "$p" = "${NS#refs/premerge/}" ] && continue
    case "$p" in *.*.*) ;; *) continue ;; esac # legacy refs/premerge/<pid>: keep
    rhost="${p%%.*}"
    rpid="${p#*.}"
    rns="${rpid%%.*}"
    rpid="${rpid#*.}"
    is_num "$rpid" || continue
    [ "$rhost" = "$HOSTTAG" ] || continue
    if [ "$rns" != "$NSTAG" ] && [ "$rns" != x ] && [ "$NSTAG" != x ]; then continue; fi
    if pid_dead "$rpid"; then "${RGIT[@]}" update-ref -d "$ref" 2>/dev/null || true; fi
  done
  for admin in "$COMMON"/worktrees/*; do
    [ -f "$admin/gitdir" ] || continue
    gitdir="$(cat "$admin/gitdir")"
    case "$gitdir" in
      */premerge.??????/tree/.git)
        dir="${gitdir%/tree/.git}"
        if is_dead_run_of_ours "$dir"; then rm -rf "$admin" "$dir"; fi
        ;;
    esac
  done
  for dir in "$TMPBASE"/premerge.??????; do
    if is_dead_run_of_ours "$dir"; then rm -rf "$dir"; fi
  done
}
sweep_dead_runs

# Run a command in the background and wait, so a signal reaches the trap now
# instead of after a minutes-long flutter run, and the child can be killed.
run() {
  "$@" &
  CHILD=$!
  local rc=0
  wait "$CHILD" || rc=$?
  CHILD=""
  return "$rc"
}

step_start() { STAGE="$1"; STEP_T0=$SECONDS; echo; echo "==> $1"; }
step_done() { echo "<== $1: $((SECONDS - STEP_T0))s"; }

# 1. Fetch -------------------------------------------------------------------
# --refmap= and --no-write-fetch-head: leave the caller's refs/remotes/<remote>/*
# and FETCH_HEAD exactly as they were.
FETCH=("${RGIT[@]}" fetch --quiet --no-tags --refmap= --no-write-fetch-head origin)
step_start "fetch origin/$BASE and PR heads"
if ! "${FETCH[@]}" "+refs/heads/$BASE:$NS/base" 2>&1; then
  echo "premerge: could not fetch origin/$BASE. Check the remote and the --base name, then rerun." >&2
  exit 1
fi
BASE_SHA="$("${RGIT[@]}" rev-parse "$NS/base")"
for n in "$PR" ${STACK[@]+"${STACK[@]}"} ${OTHERS[@]+"${OTHERS[@]}"}; do
  if ! "${FETCH[@]}" "+refs/pull/$n/head:$NS/pr-$n" 2>&1; then
    echo "premerge: could not fetch refs/pull/$n/head. Is #$n a real PR number? Fix it and rerun." >&2
    exit 1
  fi
done
PR_SHA="$("${RGIT[@]}" rev-parse "$NS/pr-$PR")"
echo "base  origin/$BASE  $BASE_SHA"
echo "head  #$PR  $PR_SHA"
for n in ${STACK[@]+"${STACK[@]}"}; do
  echo "stack #$n  $("${RGIT[@]}" rev-parse "$NS/pr-$n")"
done
if "${RGIT[@]}" merge-base --is-ancestor "$PR_SHA" "$BASE_SHA"; then
  echo "premerge: #$PR ($PR_SHA) is already contained in base origin/$BASE. Nothing to merge; check the PR number and that the PR is still open." >&2
  exit 1
fi
step_done "fetch"

# 2. Overlap report (needs only the fetched refs) ----------------------------
# Library directories (parents of changed lib/ and test/ .dart files) with a
# per-directory file count, from the diff against the merge-base with the base.
# Renames count as a delete plus an add, so both directories show up.
# Returns 1 without a merge base (shallow clone), 2 when git diff fails.
dirs_of() {
  local mb files
  mb="$("${RGIT[@]}" merge-base "$NS/base" "$NS/pr-$1")" || return 1
  files="$("${RGIT[@]}" diff --no-renames --name-only "$mb" "$NS/pr-$1")" || return 2
  printf '%s\n' "$files" |
    { grep -E '^(lib|test)/.*\.dart$' || true; } |
    sed -e 's|/[^/]*$|/|' | sort | uniq -c | sed -e 's/^ *//'
}

unknown_reason() {
  if [ "$1" = 1 ]; then
    echo "no merge base; shallow clone? git fetch --unshallow"
  else
    echo "git diff failed"
  fi
}

OVERLAP=0
if [ ${#OTHERS[@]} -gt 0 ]; then
  step_start "directories shared with other PRs"
  MINE_RC=0
  MINE="$(dirs_of "$PR")" || MINE_RC=$?
  for n in "${OTHERS[@]}"; do
    if [ "$MINE_RC" != 0 ]; then
      echo "overlap UNKNOWN for #$n ($(unknown_reason "$MINE_RC"))"
      OVERLAP=1
      continue
    fi
    THEIRS_RC=0
    THEIRS="$(dirs_of "$n")" || THEIRS_RC=$?
    if [ "$THEIRS_RC" != 0 ]; then
      echo "overlap UNKNOWN for #$n ($(unknown_reason "$THEIRS_RC"))"
      OVERLAP=1
      continue
    fi
    found=0
    while read -r cnt dir; do
      [ -n "$dir" ] || continue
      there="$(printf '%s\n' "$THEIRS" | awk -v d="$dir" '$2 == d { print $1 }')"
      if [ -n "$there" ]; then
        echo "overlap with #$n: $dir ($cnt files here, $there there)"
        found=1
      fi
    done <<EOF
$MINE
EOF
    if [ "$found" = 1 ]; then
      OVERLAP=1
    else
      echo "no shared library directory with #$n"
    fi
  done
  if [ "$OVERLAP" = 1 ]; then
    echo "WARNING: PR #$PR may share library directories with another listed PR (see above)."
    echo "WARNING: Arm only one of them at a time; merge it, then rerun this check for the other."
  fi
  step_done "overlap"
fi

# 3. Trial merge in a throwaway worktree outside the repo --------------------
# Every git call in the trial tree runs with hooks off, rerere off, no signing.
step_start "trial merge of ${STACK_DESC:+stack $STACK_DESC, then }#$PR into origin/$BASE"
TMP="$(mktemp -d "$TMPBASE/premerge.XXXXXX")"
printf 'premerge_check %s %s %s %s\n' "$$" "$HOST" "$OUR_NS" "$COMMON" >"$TMP/pid"
WT="$TMP/tree"
"${RGIT[@]}" worktree add --quiet --detach "$WT" "$BASE_SHA"
WT_ADMIN="$(git -C "$WT" rev-parse --absolute-git-dir)"
TGIT=(git -C "$WT" "${NOHOOKS[@]}" -c user.name=premerge -c user.email=premerge@localhost
  -c commit.gpgsign=false -c rerere.enabled=false -c rerere.autoUpdate=false)

# merge_one <pr> <label>: merge that PR's head; exit 2 on a conflict, 1 on any
# other merge failure.
merge_one() {
  local n="$1" label="$2" sha f
  local CONFLICTS=()
  sha="$("${RGIT[@]}" rev-parse "$NS/pr-$n")"
  if "${TGIT[@]}" merge --no-ff --no-edit "$sha" >"$TMP/merge.log" 2>&1; then
    return 0
  fi
  while IFS= read -r -d '' f; do CONFLICTS+=("$f"); done < <("${TGIT[@]}" diff -z --name-only --diff-filter=U)
  if [ ${#CONFLICTS[@]} -gt 0 ]; then
    if [ "$label" = stacked ]; then
      echo "CONFLICT: stacked #$n does not merge cleanly into origin/$BASE ($BASE_SHA) with the stack before it. Conflicted files:"
      printf '  %s\n' "${CONFLICTS[@]}"
      echo "Do not arm #$PR. Fix the stack (merge origin/$BASE into #$n, or reorder --stack), then rerun this check."
    else
      echo "CONFLICT: #$n does not merge cleanly into origin/$BASE ($BASE_SHA)${STACK_DESC:+ with stack $STACK_DESC}. Conflicted files:"
      printf '  %s\n' "${CONFLICTS[@]}"
      echo "Do not arm #$n. Merge origin/$BASE into the PR branch, resolve the files above, push, then rerun this check."
    fi
    exit 2
  fi
  cat "$TMP/merge.log" >&2
  echo "premerge: the merge of #$n failed without conflicts (see above). Do not arm #$PR." >&2
  exit 1
}

for n in ${STACK[@]+"${STACK[@]}"}; do merge_one "$n" stacked; done
merge_one "$PR" pr
echo "merged: $("${TGIT[@]}" rev-parse HEAD)"
step_done "trial merge"

# 4. Checks ------------------------------------------------------------------
cd "$WT"

step_start "flutter pub get"
if ! run flutter pub get; then
  step_done "pub get (failed)"
  echo "FAIL: flutter pub get failed on the merged tree. Do not arm #$PR." >&2
  echo "Fix pubspec or l10n problems on the PR branch (merge origin/$BASE first), push, then rerun this check." >&2
  exit 3
fi
step_done "pub get"

step_start "flutter analyze"
if ! run flutter analyze --no-pub; then
  step_done "analyze (failed)"
  echo "FAIL: flutter analyze reports issues on origin/$BASE + #$PR (listed above). Do not arm #$PR." >&2
  echo "Analyze fails on the PR merged with current $BASE: rerun with --keep and run flutter analyze in the trial merge, then fix the PR, or merge $BASE in if the clash comes from $BASE (a duplicate declaration means another PR landed the same symbol). Push, then rerun this check." >&2
  exit 3
fi
step_done "analyze"

step_start "flutter test test/architecture"
if ! run flutter test --no-pub test/architecture; then
  step_done "architecture tests (failed)"
  echo "FAIL: architecture tests fail on origin/$BASE + #$PR (listed above). Do not arm #$PR." >&2
  echo "the architecture tests fail on the PR merged with current $BASE: run \`flutter test test/architecture\` on the trial merge (use --keep) and fix the PR, or merge $BASE in if the clash comes from $BASE. Push, then rerun this check." >&2
  exit 4
fi
step_done "architecture tests"

# 5. Affected tests ----------------------------------------------------------
# Selection is import-based (scripts/premerge_affected_tests.py, taken from this
# script's own checkout, never from the PR). An empty selection runs nothing:
# `flutter test` without files would run the whole suite.
command -v python3 >/dev/null 2>&1 || {
  echo "premerge: python3 is needed to select the affected tests. Install it and rerun; a run without the selection is not a pass." >&2
  exit 1
}
step_start "select affected tests"
PAIRS=()
for n in ${STACK[@]+"${STACK[@]}"} "$PR"; do
  sha="$("${RGIT[@]}" rev-parse "$NS/pr-$n")"
  if ! mb="$("${RGIT[@]}" merge-base "$BASE_SHA" "$sha")"; then
    echo "premerge: no merge base between origin/$BASE and #$n (shallow clone? git fetch --unshallow); cannot select the affected tests. Rerun after fixing; this is not a pass." >&2
    exit 1
  fi
  PAIRS+=(--pr "$mb" "$sha")
done
if ! run python3 -I "$SCRIPT_DIR/premerge_affected_tests.py" --repo "$WT" \
  --main-tip "$BASE_SHA" --cap "$TEST_CAP" --out "$TMP/select" "${PAIRS[@]}"; then
  echo "premerge: could not select the affected tests (see above). Fix that and rerun; a run without the selection is not a pass." >&2
  exit 1
fi
TEST_FILES=()
while IFS= read -r -d '' f; do TEST_FILES+=("$f"); done <"$TMP/select/selected"
CAPPED_DIRS="$(tr '\n' ' ' <"$TMP/select/capped")"
CAPPED_DIRS="${CAPPED_DIRS% }"
N_SEL=${#TEST_FILES[@]}
# The catalog file moves to the end and out of the batches (see CATALOG_PARTS).
HAS_CATALOG=0
BATCHABLE=()
for f in "${TEST_FILES[@]}"; do
  if [ "$f" = "$CATALOG_TEST" ]; then HAS_CATALOG=1; else BATCHABLE+=("$f"); fi
done
if [ "$HAS_CATALOG" = 1 ]; then
  TEST_FILES=("${BATCHABLE[@]}" "$CATALOG_TEST")
fi
N_BATCH=${#BATCHABLE[@]}
step_done "selection ($N_SEL files)"

# run_limited <seconds> <command...>: run it, output shown and kept in
# $TMP/batch.out; after the limit its whole process tree is killed. Sets
# LIM_RC and LIM_CUT (1 when the limit killed it).
run_limited() {
  local limit="$1"
  shift
  rm -f "$TMP/expired"
  ( set -o pipefail; "$@" 2>&1 | tee "$TMP/batch.out" ) &
  CHILD=$!
  ( sleep "$limit"; : >"$TMP/expired"; kill_hard "$CHILD" ) &
  WATCH=$!
  LIM_RC=0
  wait "$CHILD" || LIM_RC=$?
  CHILD=""
  if [ -f "$TMP/expired" ]; then
    wait "$WATCH" 2>/dev/null || true # let it finish the KILL round
  else
    kill_tree "$WATCH"
    wait "$WATCH" 2>/dev/null || true
  fi
  WATCH=""
  LIM_CUT=0
  if [ -f "$TMP/expired" ] && [ "$LIM_RC" -ge 128 ]; then LIM_CUT=1; fi
}

RAN=0
CUT=0
FAILED=()
I=0
if [ "$N_SEL" -gt 0 ]; then
  step_start "affected tests ($N_SEL files, budget ${TEST_BUDGET}s)"
  DEADLINE=$((SECONDS + TEST_BUDGET))
  while [ "$I" -lt "$N_BATCH" ]; do
    REMAINING=$((DEADLINE - SECONDS))
    if [ "$REMAINING" -le 0 ]; then CUT=1; break; fi
    BATCH_FILES=("${BATCHABLE[@]:$I:$TEST_BATCH}")
    run_limited "$REMAINING" flutter test --no-pub --concurrency="$TEST_CONCURRENCY" "${BATCH_FILES[@]}"
    if [ "$LIM_CUT" = 1 ]; then CUT=1; break; fi
    if [ "$LIM_RC" -ne 0 ]; then
      FAIL_LINES="$(grep -E '\[E\]|Failed to load' "$TMP/batch.out" || true)"
      NAMED=0
      for f in "${BATCH_FILES[@]}"; do
        if [ -n "$FAIL_LINES" ] && grep -qF -- "$f" <<<"$FAIL_LINES"; then
          FAILED+=("$f")
          NAMED=1
        fi
      done
      if [ "$NAMED" = 0 ]; then
        FAILED+=("(could not tell which of these failed:)" "${BATCH_FILES[@]}")
      fi
    fi
    RAN=$((RAN + ${#BATCH_FILES[@]}))
    I=$((I + TEST_BATCH))
  done
  if [ "$CUT" = 0 ]; then I=$N_BATCH; fi
  if [ "$HAS_CATALOG" = 1 ] && [ "$CUT" = 0 ]; then
    # One part after the other; every part runs even after one failed.
    CATALOG_BAD=0
    for ((part = 0; part < CATALOG_PARTS; part++)); do
      REMAINING=$((DEADLINE - SECONDS))
      if [ "$REMAINING" -le 0 ]; then CUT=1; break; fi
      echo "Catalog part $((part + 1)) of $CATALOG_PARTS"
      run_limited "$REMAINING" flutter test --no-pub --total-shards "$CATALOG_PARTS" --shard-index "$part" "$CATALOG_TEST"
      if [ "$LIM_CUT" = 1 ]; then CUT=1; break; fi
      if [ "$LIM_RC" -ne 0 ]; then CATALOG_BAD=1; fi
    done
    if [ "$CUT" = 0 ]; then
      if [ "$CATALOG_BAD" = 1 ]; then FAILED+=("$CATALOG_TEST"); fi
      RAN=$((RAN + 1))
      I=$N_SEL
    fi
  fi
  step_done "affected tests"
else
  echo "no affected tests selected; nothing to run"
fi

CAPNOTE=""
PASS_LABEL="PASS"
if [ -n "$CAPPED_DIRS" ]; then
  CAPNOTE=" (CAPPED: (c2) tests skipped for $CAPPED_DIRS)"
  PASS_LABEL="PASS (CAPPED: directory-wide tests skipped for $CAPPED_DIRS)"
  echo "affected tests: CAPPED at $TEST_CAP files; (c2) tests skipped for: $CAPPED_DIRS"
fi
if [ "$CUT" = 1 ]; then
  {
    echo "affected tests CUT SHORT after $RAN/$N_SEL files (budget ${TEST_BUDGET} s); not a pass"
    echo "files not run:"
    for f in "${TEST_FILES[@]:$I}"; do printf '  %s\n' "$f"; done
  } >&2
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  {
    echo "FAIL: affected tests failed on origin/$BASE + ${STACK_DESC:+$STACK_DESC + }#$PR. Do not arm #$PR. Failing test files:"
    for f in "${FAILED[@]}"; do printf '  %s\n' "$f"; done
    echo "Run \`flutter test <file>\` in the trial merge (use --keep), then fix the PR, or merge origin/$BASE in if the clash comes from $BASE. Push, then rerun this check."
  } >&2
  exit 5
fi
if [ "$CUT" = 1 ]; then
  echo "Do not arm #$PR on this result. Rerun with a larger PREMERGE_TEST_BUDGET, or run the files listed above, then rerun this check." >&2
  exit 6
fi

echo
echo "$PASS_LABEL: origin/$BASE ($BASE_SHA) + ${STACK_DESC:+stacked $STACK_DESC + }#$PR ($PR_SHA) analyzes, passes the architecture tests and the affected tests."
echo "affected tests: $RAN files run$CAPNOTE"
if [ -n "$STACK_DESC" ]; then
  echo "stacked: $STACK_DESC (merge them first, bottom-up, then #$PR)"
fi
echo "checked against: head #$PR $PR_SHA, base origin/$BASE $BASE_SHA"
echo "RULE: merge or arm only while origin/$BASE still equals $BASE_SHA; rerun otherwise."
if [ "$OVERLAP" = 1 ]; then
  echo "WARNING: overlap reported above. Arm #$PR only if no overlapping PR is armed."
fi
if [ -n "$CAPPED_DIRS" ] && [ "${PREMERGE_ALLOW_CAPPED:-}" != 1 ]; then
  {
    echo "CAPPED: the cap of $TEST_CAP files skipped the directory-wide tests for $CAPPED_DIRS. This is NOT a full pass: exit 7."
    echo "Rerun with PREMERGE_TEST_CAP and PREMERGE_TEST_BUDGET raised (a theme-wide selection needed 3000 s), or set PREMERGE_ALLOW_CAPPED=1 to accept the skipped tests."
  } >&2
  exit 7
fi
echo "Next: safe to arm #$PR at exactly $PR_SHA: arm with a head-SHA match (\`gh pr merge --auto --squash --match-head-commit $PR_SHA\` locally, or the auto-merge route with that sha); rerun after ANY push to the PR or to main."
exit 0

#!/usr/bin/env bash
# Trial-merge check: run before arming auto-merge on a PR, or before a hand merge.
#
#   scripts/premerge_check.sh <pr> [--others <n> <n> ...] [--base main] [--keep]
#
# Merges the PR's head into the CURRENT origin/<base> in a throwaway worktree
# outside the repo, then runs pub get, analyze and the architecture tests there.
# Two PRs that are each green on their own can break main together (a duplicate
# declaration, say); this finds that before the merge, not after.
#
# Exit: 0 pass | 1 usage or fetch error, or the PR is already in the base
#       2 merge conflict | 3 pub get or analyze failed | 4 architecture tests failed
#
# Uses git only. PREMERGE_LIST_OPEN=1 also asks `gh` (GraphQL, so not in cloud
# sessions) for the open PRs that have auto-merge armed and adds them to
# --others. The caller's working tree, index, branch and stash are never
# touched; nothing is pushed.
#
# A SIGKILL cannot be trapped and leaves refs/premerge/<pid>, a premerge.*
# temp dir and its registered worktree behind. The next run sweeps those whose
# pid is dead (the pid file is <tempdir>/pid). --keep removes the pid file, so a
# kept worktree is never swept.
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

USAGE="Usage: scripts/premerge_check.sh <pr-number> [--others <n> <n> ...] [--base main] [--keep]"

die_usage() {
  echo "premerge: $1" >&2
  echo "$USAGE" >&2
  exit 1
}

is_num() { case "$1" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

PR=""
OTHERS=()
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

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die_usage "not inside a git repository"
NOHOOKS=(-c core.hooksPath=/dev/null)
RGIT=(git -C "$REPO" "${NOHOOKS[@]}")
COMMON="$("${RGIT[@]}" rev-parse --git-common-dir)"
case "$COMMON" in /*) ;; *) COMMON="$REPO/$COMMON" ;; esac

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

NS="refs/premerge/$$"
TMP=""
WT=""
WT_ADMIN=""
CHILD=""
STAGE="setup"

kill_tree() {
  local pid="$1" kid
  for kid in $(pgrep -P "$pid" 2>/dev/null || true); do kill_tree "$kid"; done
  kill -TERM "$pid" 2>/dev/null || true
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  if [ -n "$CHILD" ]; then
    kill_tree "$CHILD"
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

# Remove what a SIGKILLed run left: refs, registered worktrees and temp dirs
# whose pid is dead. A dir without a pid file (--keep) is left alone.
pid_dead() { ! kill -0 "$1" 2>/dev/null; }

sweep_dead_runs() {
  local ref p admin gitdir tree dir pid
  for ref in $("${RGIT[@]}" for-each-ref --format='%(refname)' refs/premerge 2>/dev/null || true); do
    p="${ref#refs/premerge/}"
    p="${p%%/*}"
    is_num "$p" || continue
    [ "$p" = "$$" ] && continue
    if pid_dead "$p"; then "${RGIT[@]}" update-ref -d "$ref" 2>/dev/null || true; fi
  done
  for admin in "$COMMON"/worktrees/*; do
    [ -f "$admin/gitdir" ] || continue
    gitdir="$(cat "$admin/gitdir")"
    case "$gitdir" in
      */premerge.*/tree/.git)
        tree="${gitdir%/.git}"
        dir="${tree%/tree}"
        [ -f "$dir/pid" ] || continue
        pid="$(cat "$dir/pid" 2>/dev/null || true)"
        if is_num "$pid" && pid_dead "$pid"; then
          rm -rf "$admin" "$dir"
        fi
        ;;
    esac
  done
  for dir in "${TMPDIR:-/tmp}"/premerge.*; do
    [ -d "$dir" ] && [ -f "$dir/pid" ] && [ ! -e "$dir/tree" ] || continue
    pid="$(cat "$dir/pid" 2>/dev/null || true)"
    if is_num "$pid" && pid_dead "$pid"; then rm -rf "$dir"; fi
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
for n in "$PR" ${OTHERS[@]+"${OTHERS[@]}"}; do
  if ! "${FETCH[@]}" "+refs/pull/$n/head:$NS/pr-$n" 2>&1; then
    echo "premerge: could not fetch refs/pull/$n/head. Is #$n a real PR number? Fix it and rerun." >&2
    exit 1
  fi
done
PR_SHA="$("${RGIT[@]}" rev-parse "$NS/pr-$PR")"
echo "base  origin/$BASE  $BASE_SHA"
echo "head  #$PR  $PR_SHA"
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
step_start "trial merge of #$PR into origin/$BASE"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/premerge.XXXXXX")"
echo "$$" >"$TMP/pid"
WT="$TMP/tree"
"${RGIT[@]}" worktree add --quiet --detach "$WT" "$BASE_SHA"
WT_ADMIN="$(git -C "$WT" rev-parse --absolute-git-dir)"
TGIT=(git -C "$WT" "${NOHOOKS[@]}" -c user.name=premerge -c user.email=premerge@localhost
  -c commit.gpgsign=false -c rerere.enabled=false -c rerere.autoUpdate=false)
if ! "${TGIT[@]}" merge --no-ff --no-edit "$PR_SHA" >"$TMP/merge.log" 2>&1; then
  CONFLICTS=()
  while IFS= read -r -d '' f; do CONFLICTS+=("$f"); done < <("${TGIT[@]}" diff -z --name-only --diff-filter=U)
  if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "CONFLICT: #$PR does not merge cleanly into origin/$BASE ($BASE_SHA). Conflicted files:"
    printf '  %s\n' "${CONFLICTS[@]}"
    echo "Do not arm #$PR. Merge origin/$BASE into the PR branch, resolve the files above, push, then rerun this check."
    exit 2
  fi
  cat "$TMP/merge.log" >&2
  echo "premerge: the merge failed without conflicts (see above). Do not arm #$PR." >&2
  exit 1
fi
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

echo
echo "PASS: origin/$BASE ($BASE_SHA) + #$PR ($PR_SHA) analyzes and passes the architecture tests."
if [ "$OVERLAP" = 1 ]; then
  echo "WARNING: overlap reported above. Arm #$PR only if no overlapping PR is armed."
fi
echo "Next: safe to arm #$PR at exactly $PR_SHA: arm with a head-SHA match (\`gh pr merge --auto --match-head-commit $PR_SHA\` locally, or the auto-merge route with that sha); rerun after ANY push to the PR or to main."
exit 0

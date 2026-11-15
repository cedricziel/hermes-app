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
# Exit: 0 pass | 1 usage or fetch error | 2 merge conflict
#       3 pub get or analyze failed | 4 architecture tests failed
#
# Uses git only. PREMERGE_LIST_OPEN=1 also asks `gh` for the open PRs that have
# auto-merge armed and adds them to --others. The caller's working tree, index,
# branch and stash are never touched; nothing is pushed.
set -euo pipefail

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
  for ref in $(git -C "$REPO" for-each-ref --format='%(refname)' "$NS" 2>/dev/null || true); do
    git -C "$REPO" update-ref -d "$ref" 2>/dev/null || true
  done
  if [ "$KEEP" = 1 ] && [ -n "$WT" ] && [ -d "$WT" ]; then
    echo "premerge: --keep: trial merge left at $WT"
    echo "premerge: remove it with: git worktree remove --force '$WT' && rm -rf '$TMP'"
  else
    if [ -n "$WT" ]; then
      git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
    fi
    [ -z "$TMP" ] || rm -rf "$TMP"
    git -C "$REPO" worktree prune 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'echo "premerge: interrupted during $STAGE; cleaning up" >&2; exit 130' INT
trap 'echo "premerge: terminated during $STAGE; cleaning up" >&2; exit 143' TERM HUP

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
step_start "fetch origin/$BASE and PR heads"
if ! git -C "$REPO" fetch --quiet --no-tags origin "+refs/heads/$BASE:$NS/base" 2>&1; then
  echo "premerge: could not fetch origin/$BASE. Check the remote and the --base name, then rerun." >&2
  exit 1
fi
BASE_SHA="$(git -C "$REPO" rev-parse "$NS/base")"
for n in "$PR" ${OTHERS[@]+"${OTHERS[@]}"}; do
  if ! git -C "$REPO" fetch --quiet --no-tags origin "+refs/pull/$n/head:$NS/pr-$n" 2>&1; then
    echo "premerge: could not fetch refs/pull/$n/head. Is #$n a real PR number? Fix it and rerun." >&2
    exit 1
  fi
done
PR_SHA="$(git -C "$REPO" rev-parse "$NS/pr-$PR")"
echo "base  origin/$BASE  $BASE_SHA"
echo "head  #$PR  $PR_SHA"
step_done "fetch"

# 2. Overlap report (needs only the fetched refs) ----------------------------
# Library directories (parents of changed lib/ and test/ .dart files) with a
# per-directory file count, from the diff against the merge-base with the base.
dirs_of() {
  git -C "$REPO" diff --name-only "$NS/base...$NS/pr-$1" |
    grep -E '^(lib|test)/.*\.dart$' |
    sed -e 's|/[^/]*$|/|' | sort | uniq -c | sed -e 's/^ *//' || true
}

OVERLAP=0
if [ ${#OTHERS[@]} -gt 0 ]; then
  step_start "directories shared with other PRs"
  MINE="$(dirs_of "$PR")"
  for n in "${OTHERS[@]}"; do
    THEIRS="$(dirs_of "$n")"
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
    echo "WARNING: PR #$PR changes library directories that another listed PR also changes."
    echo "WARNING: Arm only one of them at a time; merge it, then rerun this check for the other."
  fi
  step_done "overlap"
fi

# 3. Trial merge in a throwaway worktree outside the repo --------------------
step_start "trial merge of #$PR into origin/$BASE"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/premerge.XXXXXX")"
WT="$TMP/tree"
git -C "$REPO" worktree add --quiet --detach "$WT" "$BASE_SHA"
MERGE_GIT=(git -C "$WT" -c user.name=premerge -c user.email=premerge@localhost
  -c commit.gpgsign=false -c core.hooksPath=/dev/null)
if ! "${MERGE_GIT[@]}" merge --no-ff --no-edit "$PR_SHA" >"$TMP/merge.log" 2>&1; then
  CONFLICTS="$(git -C "$WT" diff --name-only --diff-filter=U)"
  if [ -n "$CONFLICTS" ]; then
    echo "CONFLICT: #$PR does not merge cleanly into origin/$BASE ($BASE_SHA). Conflicted files:"
    printf '  %s\n' $CONFLICTS
    echo "Do not arm #$PR. Merge origin/$BASE into the PR branch, resolve the files above, push, then rerun this check."
    exit 2
  fi
  cat "$TMP/merge.log" >&2
  echo "premerge: the merge failed without conflicts (see above). Do not arm #$PR." >&2
  exit 1
fi
echo "merged: $("${MERGE_GIT[@]}" rev-parse HEAD)"
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
  echo "FAIL: flutter analyze reports errors on origin/$BASE + #$PR (listed above). Do not arm #$PR." >&2
  echo "Merge origin/$BASE into the PR branch, fix what analyze names (a duplicate declaration means another PR landed the same symbol), push, then rerun this check." >&2
  exit 3
fi
step_done "analyze"

step_start "flutter test test/architecture"
if ! run flutter test --no-pub test/architecture; then
  step_done "architecture tests (failed)"
  echo "FAIL: architecture tests fail on origin/$BASE + #$PR (listed above). Do not arm #$PR." >&2
  echo "Merge origin/$BASE into the PR branch, fix the rule it names, push, then rerun this check." >&2
  exit 4
fi
step_done "architecture tests"

echo
echo "PASS: origin/$BASE ($BASE_SHA) + #$PR ($PR_SHA) analyzes and passes the architecture tests."
if [ "$OVERLAP" = 1 ]; then
  echo "WARNING: overlap reported above. Arm #$PR only if no overlapping PR is armed."
fi
echo "Next: safe to arm #$PR now. Rerun this check if $BASE moves before it merges."
exit 0

#!/bin/bash
set -uo pipefail

# Warn when this checkout loads no Bash guard (stale checkout). Local and cloud
# sessions alike; read-only and never fails the session.
python3 -I "$(dirname "$0")/check_guard_freshness.py" 2>/dev/null || true

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

claude plugin marketplace add cedricziel/claude-plugins >/dev/null 2>&1
claude plugin install oss@cedricziel >/dev/null 2>&1

(cd "$CLAUDE_PROJECT_DIR" && flutter pub get >/dev/null 2>&1 && dart run tool/setup_git_hooks.dart >/dev/null 2>&1)

exit 0

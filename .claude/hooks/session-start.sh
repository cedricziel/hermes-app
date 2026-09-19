#!/bin/bash
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

claude plugin marketplace add cedricziel/claude-plugins >/dev/null 2>&1
claude plugin install oss@cedricziel >/dev/null 2>&1

if ! command -v pre-commit >/dev/null 2>&1; then
  pip install --user pre-commit >/dev/null 2>&1
fi

if command -v pre-commit >/dev/null 2>&1; then
  (cd "$CLAUDE_PROJECT_DIR" && pre-commit install >/dev/null 2>&1)
fi

exit 0

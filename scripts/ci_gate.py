"""Decides whether a CI run is FULL or DEFERRED.

    python3 -I scripts/ci_gate.py >> "$GITHUB_OUTPUT"

Reads EVENT_NAME, BASE_REF, HEAD_REF, LABELS (one label name per line) and
LABELS_ERROR (true when the label lookup failed) from the environment and
prints `full=true|false` and `gate_reason=...` for the Changes job.

A run is FULL, and runs the test shards, the native audio test, the watch test
and the platform builds, when any of these holds:
  - the event is push, workflow_dispatch or merge_group;
  - the pull request's base is not main (a stacked pull request);
  - the pull request has the label `ci:full`;
  - it comes from the release-please branch;
  - the decision cannot be made (error, missing or malformed data).
Everything else is DEFERRED. The answer depends on the label set, never on which
label event started the run, so an unrelated label gives the same answer as the
label set before it.
"""

import os
import sys

FULL_LABEL = "ci:full"
MAIN = "main"
RELEASE_BRANCH = "release-please--branches--main--components--hermes-app"
FULL_EVENTS = frozenset({"push", "workflow_dispatch", "merge_group"})

REASON_EVENT = "push, manual or merge-group run"
REASON_STACKED = "base is not main (stacked pull request)"
REASON_LABEL = "label ci:full is set"
REASON_RELEASE = "release-please pull request"
REASON_DEFERRED = "pull request without label ci:full"
REASON_ERROR = "label lookup failed; failing closed"
REASON_UNKNOWN_EVENT = "unknown event; failing closed"
REASON_MISSING = "event data missing or malformed; failing closed"

FULL = "full"
DEFERRED = "deferred"


def decide(event_name, base_ref, labels, head_ref="", error=False):
    """Returns (mode, reason); mode is 'full' or 'deferred'."""
    if error:
        return FULL, REASON_ERROR
    if event_name in FULL_EVENTS:
        return FULL, REASON_EVENT
    if event_name != "pull_request":
        return FULL, REASON_UNKNOWN_EVENT
    if not isinstance(base_ref, str) or not base_ref:
        return FULL, REASON_MISSING
    if not isinstance(labels, (list, tuple)) or not all(
        isinstance(name, str) for name in labels
    ):
        return FULL, REASON_MISSING
    if base_ref != MAIN:
        return FULL, REASON_STACKED
    if head_ref == RELEASE_BRANCH:
        return FULL, REASON_RELEASE
    if FULL_LABEL in labels:
        return FULL, REASON_LABEL
    return DEFERRED, REASON_DEFERRED


def from_env(env):
    flag = env.get("LABELS_ERROR", "false")
    if flag not in ("true", "false"):
        return FULL, REASON_ERROR
    raw = env.get("LABELS")
    labels = None if raw is None else [line for line in raw.splitlines() if line]
    return decide(
        env.get("EVENT_NAME"),
        env.get("BASE_REF"),
        labels,
        head_ref=env.get("HEAD_REF", ""),
        error=flag == "true",
    )


def output_lines(mode, reason):
    return [f"full={'true' if mode == FULL else 'false'}", f"gate_reason={reason}"]


def main():
    try:
        mode, reason = from_env(os.environ)
    except Exception:  # never let the classifier decide by crashing
        mode, reason = FULL, REASON_ERROR
    print("\n".join(output_lines(mode, reason)))


if __name__ == "__main__":
    sys.exit(main())

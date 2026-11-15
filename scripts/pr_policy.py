#!/usr/bin/env python3
"""PR policy checks, run by .github/workflows/pr-policy.yml.

    python3 -I scripts/pr_policy.py policy   # job "PR policy"
    python3 -I scripts/pr_policy.py review   # job "Review recorded"

Both read the pull_request event from $GITHUB_EVENT_PATH, so the title and body
never pass through a shell line. `check` and `review_recorded` are pure and are
tested in scripts/test_pr_policy.py.
"""

import json
import os
import re
import subprocess
import sys

# The types release-please-config.json lists in changelog-sections.
TYPES = "feat|fix|docs|chore|refactor|test|ci|build|perf|style|revert"
TITLE_RE = re.compile(rf"^({TYPES})(\([a-z0-9_./,-]+\))?!?: \S")
FIX_RE = re.compile(r"^fix(\([a-z0-9_./,-]+\))?!?: ")

HEADINGS = ["Behaviour changes", "Proof", "Not verified on a device", "Review"]
CAUGHT_EARLIER = "What would have caught this earlier?"

# Branches the repo's own automation opens (prefix match). release-please's is
# release-please--branches--main--components--hermes-app. update-claude-plugins
# runs a shared action whose branch name is not in this repo, so that entry is
# a guess; its PRs are also covered when they come from a [bot] author.
RELEASE_PLEASE_PREFIX = "release-please--"
BOT_BRANCH_PREFIXES = (
    RELEASE_PLEASE_PREFIX,
    "chore/update-flutter",
    "chore/update-hermes-contracts",
    "chore/update-claude-plugins",
    "chore/readme-screenshots-",
    "dependabot/",
)

ROADMAP = "docs/roadmap.md"
ROADMAP_BRANCH_PREFIX = "claude/quirky-einstein-"

_MODEL_RES = [
    re.compile(
        r"claude[-_ ]?(?:\d+(?:[-.]\d+)*[-_ ])?(?:opus|sonnet|haiku|fable)", re.I
    ),
    re.compile(r"\b(?:opus|sonnet|haiku|fable)[-_ ]?v?\d", re.I),
    re.compile(r"\bgpt[-_ ]?\d", re.I),
    re.compile(r"\bgemini[-_ ]?\d", re.I),
]
_SESSION_URL_RE = re.compile(r"^\s*<?https?://claude\.ai/code/session_\S+?>?\s*$")
_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
_FENCE_RE = re.compile(r"^\s*(```|~~~)")

REVIEW_HINT = (
    "run the isolated-reviewer agent on this head and paste its block into ## Review"
)


def is_bot(author, head_ref):
    return author.endswith("[bot]") or head_ref.startswith(BOT_BRANCH_PREFIXES)


def _strip_comments(text):
    return _COMMENT_RE.sub("", text)


def _sections(body):
    """Maps each `## ` heading to its text, comments stripped. Fenced code is
    not scanned for headings. Returns (ordered headings, {heading: text})."""
    order, texts, current, fenced = [], {}, None, False
    for line in _strip_comments(body or "").splitlines():
        if _FENCE_RE.match(line):
            fenced = not fenced
        if not fenced and line.startswith("## "):
            current = line[3:].strip()
            order.append(current)
            texts.setdefault(current, [])
            continue
        if current is not None:
            texts[current].append(line)
    return order, {k: "\n".join(v).strip() for k, v in texts.items()}


def _model_mentions(text):
    found = []
    for line in (text or "").splitlines():
        s = line.strip()
        if (
            s.lower().startswith(("co-authored-by:", "claude-session:"))
            or "Generated with [Claude Code]" in line
            or _SESSION_URL_RE.match(line)
        ):
            continue
        for rx in _MODEL_RES:
            m = rx.search(line)
            if m:
                found.append(m.group(0))
                break
    return found


CORRUPTION_FILES = ("CLAUDE.md", "docs/roadmap.md")
CORRUPTION_MESSAGE = (
    "This line looks corrupted by a Markdown formatter; restore it from main "
    "and re-apply only your change."
)


def _suspicious(line):
    if "x86*64" in line:
        return True
    if line.lstrip().startswith(("```", "~~~")):
        return False
    return line.count("`") % 2 == 1


def corrupted_lines(diff):
    """Added lines of a unified diff (-U0 or more) that a Markdown formatter
    probably mangled: `x86*64`, or an odd number of backticks where the line
    it replaced (paired in order within the hunk) had an even number. A pure
    addition needs only the odd count. Fence lines are not counted."""
    found = []
    removed, added = [], []

    def flush():
        for i, line in enumerate(added):
            if "x86*64" in line:
                found.append(line)
            elif _suspicious(line):
                if i >= len(removed) or not _suspicious(removed[i]):
                    found.append(line)
        removed.clear()
        added.clear()

    for raw in (diff or "").splitlines():
        if raw.startswith(("+++", "---")):
            flush()
        elif raw.startswith("-"):
            if added:
                flush()
            removed.append(raw[1:])
        elif raw.startswith("+"):
            added.append(raw[1:])
        else:
            flush()
    flush()
    return found


def check(
    title,
    body,
    head_ref,
    author,
    head_sha,
    changed_files,
    version_changed,
    diff="",
):
    """Returns the policy failures, each saying what to do instead. `diff` is
    the PR's unified diff of CORRUPTION_FILES."""
    failures = []
    bot = is_bot(author, head_ref)
    body = body or ""

    if not bot:
        # a. Bots are exempt: their titles are checked only if they comply, so
        # a non-conforming bot title is never a failure.
        if not TITLE_RE.match(title or ""):
            failures.append(
                f"Title {title!r} is not a Conventional Commit: write "
                f"'<type>(<scope>): <summary>' with type one of {TYPES.replace('|', ', ')}."
            )

        # b. Template sections, in order, non-empty.
        order, texts = _sections(body)
        missing = [h for h in HEADINGS if h not in order]
        if missing:
            failures.append(
                "The body is missing "
                + ", ".join(f"'## {h}'" for h in missing)
                + ": start from .github/pull_request_template.md."
            )
        else:
            positions = [order.index(h) for h in HEADINGS]
            if positions != sorted(positions):
                failures.append(
                    "The body's sections are out of order: use "
                    + ", ".join(f"'## {h}'" for h in HEADINGS)
                    + " in that order."
                )
        for h in HEADINGS:
            if h in order and not texts.get(h):
                failures.append(
                    f"'## {h}' is empty (an HTML comment does not count): "
                    "fill it in, or say 'Nothing' where that is the answer."
                )

        # c. A fix says what would have caught it earlier.
        if FIX_RE.match(title or ""):
            clean = _strip_comments(body)
            i = clean.find(CAUGHT_EARLIER)
            if i < 0:
                failures.append(
                    f"A fix: PR must answer '{CAUGHT_EARLIER}' in ## Proof: "
                    "name the check, test or review that would have caught it."
                )
            else:
                tail = clean[i + len(CAUGHT_EARLIER) :]
                tail = re.split(r"^## ", tail, maxsplit=1, flags=re.M)[0]
                if not re.sub(r"[\s*_:>\-]+", "", tail):
                    failures.append(
                        f"Answer '{CAUGHT_EARLIER}': write what would have "
                        "caught the bug earlier after the question."
                    )

        # d. No model names in the title or body.
        names = _model_mentions(title) + _model_mentions(body)
        if names:
            failures.append(
                "Remove model names ("
                + ", ".join(sorted(set(n.strip() for n in names), key=str.lower))
                + ") from the title and body; only the Co-Authored-By and "
                "Claude-Session trailers may carry them."
            )

    # e. Versions are release-please's.
    if version_changed and not head_ref.startswith(RELEASE_PLEASE_PREFIX):
        failures.append(
            "pubspec.yaml's version: changed: release-please bumps the version; "
            "revert that line."
        )

    # f. Loud, not tight: the branch prefix is an honour system. It exists so a
    # session that was not given the orchestrator's brief stops and asks.
    if ROADMAP in changed_files and not head_ref.startswith(ROADMAP_BRANCH_PREFIX):
        failures.append(
            "Only the orchestrator edits docs/roadmap.md; revert it and send "
            "the orchestrator the row."
        )

    # g. The formatter hook in agent sessions mangles Markdown.
    for line in corrupted_lines(diff)[:5]:
        failures.append(f"{CORRUPTION_MESSAGE} Line: {line.strip()[:120]}")
    return failures


def review_recorded(body, head_sha):
    """Returns the failures of the ## Review section for head_sha."""
    _, texts = _sections(body or "")
    section = texts.get("Review", "")
    heads = re.findall(r"\bHead:\W*([0-9a-fA-F]{40})\b", section)
    verdicts = re.findall(
        r"\bVerdict:\W*(clean|changes-requested)\b(?!\s*\|)", section, re.I
    )
    if not heads or not verdicts:
        return [f"No isolated review recorded for {head_sha}: {REVIEW_HINT}"]
    if heads[-1].lower() != head_sha.lower():
        return [
            f"The review is for {heads[-1].lower()}, the head is {head_sha}: "
            "review the new commits."
        ]
    if verdicts[-1].lower() != "clean":
        return [
            f"The review of {head_sha} says changes-requested: fix the findings, "
            "push, and review the new head."
        ]
    return []


def _git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout


def changed_files(base_sha, head_sha):
    out = _git("diff", "--name-only", f"{base_sha}...{head_sha}")
    return [line for line in out.splitlines() if line]


def version_changed(base_sha, head_sha):
    out = _git("diff", "-U0", f"{base_sha}...{head_sha}", "--", "pubspec.yaml")
    return any(re.match(r"^[+-]version:", line) for line in out.splitlines())


def corruption_diff(base_sha, head_sha):
    return _git(
        "diff", "-U0", f"{base_sha}...{head_sha}", "--", *CORRUPTION_FILES
    )


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as f:
        pr = json.load(f)["pull_request"]
    head_sha = pr["head"]["sha"]
    author = (pr.get("user") or {}).get("login", "")
    head_ref = pr["head"]["ref"]
    if mode == "policy":
        base_sha = pr["base"]["sha"]
        failures = check(
            pr.get("title") or "",
            pr.get("body") or "",
            head_ref,
            author,
            head_sha,
            changed_files(base_sha, head_sha),
            version_changed(base_sha, head_sha),
            corruption_diff(base_sha, head_sha),
        )
    elif mode == "review":
        failures = (
            []
            if is_bot(author, head_ref)
            else review_recorded(pr.get("body") or "", head_sha)
        )
    else:
        print("usage: pr_policy.py policy|review", file=sys.stderr)
        return 2
    for failure in failures:
        print(f"::error::{failure}")
    if not failures:
        print("ok")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

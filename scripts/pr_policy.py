#!/usr/bin/env python3
"""PR policy checks, run by .github/workflows/pr-policy.yml.

    python3 -I scripts/pr_policy.py policy   # job "PR policy"
    python3 -I scripts/pr_policy.py review   # job "Review recorded"

The workflow runs on pull_request_target from the default branch, so this file
is main's copy, never the PR's. The script reads the pull_request event from
$GITHUB_EVENT_PATH (the title and body never pass through a shell line) and
asks the REST API for the PR's files and patches with a read-only token. It
never checks out, executes or installs anything from the PR.
The review job also reads git objects of the PR head (fetched by SHA by the
workflow) with git plumbing that only reads (merge-tree also writes its
result tree into the runner's ephemeral object store): see "Review recorded".
`check`, `review_recorded` and `main` are tested in scripts/test_pr_policy.py.
"""

import base64
import difflib
import json
import os
import re
import subprocess
import sys
import urllib.request
from urllib.parse import quote

# The types release-please-config.json lists in changelog-sections.
TYPES = "feat|fix|docs|chore|refactor|test|ci|build|perf|style|revert"
TITLE_RE = re.compile(rf"^({TYPES})(\([a-z0-9_./,-]+\))?!?: \S")
REVERT_RE = re.compile(r'^Revert ".+"$')  # GitHub's default revert title
FIX_RE = re.compile(r"^fix(\([a-z0-9_./,-]+\))?!?: ")

HEADINGS = ["Behaviour changes", "Proof", "Not verified on a device", "Review"]
CAUGHT_EARLIER = "What would have caught this earlier?"

# The branches the repo's own automation opens, exact (update-flutter.yml,
# update-hermes-contracts.yml, readme-screenshots.yml with its run id, and
# release-please's PR #945). update-claude-plugins runs an external action whose
# branch is not visible from this repo, so it is not listed. Exemptions need a
# same-repo head; a fork can use any branch name.
RELEASE_PLEASE_BRANCH = "release-please--branches--main--components--hermes-app"
BOT_BRANCH_RE = re.compile(
    r"chore/update-flutter"
    r"|chore/update-hermes-contracts"
    r"|chore/readme-screenshots-\d+"
    rf"|{re.escape(RELEASE_PLEASE_BRANCH)}"
)

ROADMAP = "docs/roadmap.md"
ROADMAP_BRANCH_PREFIX = "claude/quirky-einstein-"

# Zero-width and soft-hyphen characters are removed, NBSP becomes a space.
_INVISIBLE_RE = re.compile("[​‌‍⁠﻿­]")
_FAMILY = r"(?:opus|sonnet|haiku|fable)"
_MODEL_RES = [
    # claude-opus-4-1, Claude Sonnet 4.5, claude-3-5-sonnet-20241022
    re.compile(
        rf"\bclaude[-_ ](?:\d+(?:[-.]\d+)*[-_ ]{_FAMILY}|{_FAMILY}[-_ ]v?\d)", re.I
    ),
    # Opus 4, Sonnet 4.5, Haiku-3: a single-digit major of 3 or more, so codec
    # text such as "Opus 1.5" is not a model name.
    re.compile(r"\b(?:opus|sonnet|haiku)[-_ ]v?[3-9](?!\d)", re.I),
    re.compile(r"\bfable[-_ ]v?\d", re.I),
    re.compile(r"\bgpt[-_ ]?\d", re.I),
    re.compile(r"\bgemini[-_ ]?\d", re.I),
]
_FOOTER = "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
_SESSION_URL_RE = re.compile(r"^\s*<?https?://claude\.ai/code/session_\S+?>?\s*$")
_FENCE_RE = re.compile(r"^\s*(```|~~~)")
_INLINE_CODE_RE = re.compile(r"(`+)(?!`).+?(?<!`)\1(?!`)")
# TODO, TBD, n/a, "-", "..." (with bullets and punctuation) are not answers.
_PLACEHOLDER_RE = re.compile(r"^[\s\-.…*_]*(?:(?:todo|tbd|n/?a)[\s.!]*)?$", re.I)

REVIEW_HINT = (
    "run the isolated-reviewer agent on this head and paste its block into ## Review"
)
REVIEW_LINE_RE = re.compile(
    r"^Reviewer:[ \t]*\S+[ \t]+Head:[ \t]*([0-9a-fA-F]{40})"
    r"[ \t]+Verdict:[ \t]*(clean|changes-requested|changes-needed)[ \t]*$",
    re.M,
)


def same_repo(pr):
    head = (pr.get("head") or {}).get("repo") or {}
    base = (pr.get("base") or {}).get("repo") or {}
    return bool(head.get("full_name")) and head.get("full_name") == base.get(
        "full_name"
    )


def is_bot(author, head_ref, same_repo=True):
    """True for the repo's own automation: dependabot (its branch and its
    author), or one of the exact automation branches. Always false for a fork."""
    if not same_repo:
        return False
    if head_ref.startswith("dependabot/"):
        return author == "dependabot[bot]"
    return bool(BOT_BRANCH_RE.fullmatch(head_ref))


_MASK = "\x00"
_COMMENT_START_RE = re.compile(r" {0,3}")


def _scan_line(line, close_later, at_start):
    """Removes the HTML comments GitHub would hide from one line outside a
    fence. Returns (kept text, whether a comment stays open past the line). A
    `<!--` inside an inline code span is literal. An unclosed `<!--` opens a
    comment only at the start of a line (up to 3 spaces of indent: an HTML
    block, which runs to the next `-->` or the end of the text) or when a
    `-->` follows on a later line; mid-line with no `-->` it is plain text."""
    masked = _INLINE_CODE_RE.sub(lambda m: m.group(0).replace("<!--", _MASK), line)
    out, pos = [], 0
    while True:
        i = masked.find("<!--", pos)
        if i < 0:
            out.append(masked[pos:])
            return "".join(out).replace(_MASK, "<!--"), False
        out.append(masked[pos:i])
        j = masked.find("-->", i + 4)
        if j >= 0:
            pos, at_start = j + 3, False
            continue
        if close_later or (at_start and _COMMENT_START_RE.fullmatch(masked[:i])):
            return "".join(out).replace(_MASK, "<!--"), True
        out.append("<!--")
        pos = i + 4


def _strip_comments(text):
    """Text as GitHub renders it, minus HTML comments. A fence line inside a
    comment is hidden with it, so it does not toggle the fence state."""
    lines = text.split("\n")
    out, fenced, in_comment = [], False, False
    for n, line in enumerate(lines):
        close_later = "-->" in "\n".join(lines[n + 1 :])
        if in_comment:
            end = line.find("-->")
            if end < 0:
                continue
            kept, in_comment = _scan_line(line[end + 3 :], close_later, False)
            out.append(kept)
        elif _FENCE_RE.match(line):
            fenced = not fenced
            out.append(line)
        elif fenced:
            out.append(line)
        else:
            kept, in_comment = _scan_line(line, close_later, True)
            out.append(kept)
    return "\n".join(out)


def _strip_fences(text):
    out, fenced = [], False
    for line in text.splitlines():
        if _FENCE_RE.match(line):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return "\n".join(out)


def _is_empty(text):
    return bool(_PLACEHOLDER_RE.match(text or ""))


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
    return order, {k: "\n".join(v).strip("\n") for k, v in texts.items()}


def _model_mentions(text):
    text = _INVISIBLE_RE.sub("", (text or "").replace(" ", " "))
    found = []
    for line in _strip_fences(text).splitlines():
        s = line.strip()
        if (
            s == _FOOTER
            or s.lower().startswith(("co-authored-by:", "claude-session:"))
            or _SESSION_URL_RE.match(line)
        ):
            continue
        line = _INLINE_CODE_RE.sub(" ", line)
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
_DOUBLE_SPAN_RE = re.compile(r"``.+?``")


def _suspicious(line):
    if "x86*64" in line:
        return True
    if line.lstrip().startswith(("```", "~~~")):
        return False
    # A valid ``a`b`` span holds a single backtick; count outside such spans.
    return _DOUBLE_SPAN_RE.sub("", line).count("`") % 2 == 1


def corrupted_lines(diff):
    """Added lines of a unified diff that a Markdown formatter probably
    mangled: `x86*64`, or an odd number of backticks where the line it replaced
    (paired in order within the hunk) had an even number. A pure addition needs
    only the odd count. Fence lines are not counted. Only lines inside a hunk
    (after `@@`) are content, so a removed line starting with `--` is not a
    file header."""
    found = []
    removed, added = [], []
    in_hunk = False

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
        if raw.startswith("diff --git"):
            flush()
            in_hunk = False
        elif raw.startswith("@@"):
            flush()
            in_hunk = True
        elif not in_hunk:
            continue
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
    same_repo=True,
):
    """Returns the policy failures, each saying what to do instead. `diff` is
    the PR's unified diff of CORRUPTION_FILES."""
    failures = []
    bot = is_bot(author, head_ref, same_repo)
    body = body or ""

    if not bot:
        # a. Bots are exempt: their titles are checked only if they comply, so
        # a non-conforming bot title is never a failure.
        if not (TITLE_RE.match(title or "") or REVERT_RE.match(title or "")):
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
            if h in order and _is_empty(texts.get(h)):
                failures.append(
                    f"'## {h}' is empty (an HTML comment, TODO, TBD, n/a or '-' "
                    "does not count): fill it in, or say 'Nothing' where that "
                    "is the answer."
                )

        # c. A fix says in ## Proof what would have caught it earlier.
        if FIX_RE.match(title or ""):
            proof = texts.get("Proof", "")
            i = proof.find(CAUGHT_EARLIER)
            if i < 0:
                failures.append(
                    f"A fix: PR must answer '{CAUGHT_EARLIER}' in ## Proof: "
                    "name the check, test or review that would have caught it."
                )
            elif _is_empty(proof[i + len(CAUGHT_EARLIER) :].lstrip("*_: \t")):
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
    if version_changed and not (same_repo and head_ref == RELEASE_PLEASE_BRANCH):
        failures.append(
            "pubspec.yaml's version: changed: release-please bumps the version; "
            "revert that line."
        )

    # f. Loud, not tight: the branch prefix is an honour system. It exists so a
    # session that was not given the orchestrator's brief stops and asks.
    if ROADMAP in changed_files and not (
        same_repo and head_ref.startswith(ROADMAP_BRANCH_PREFIX)
    ):
        failures.append(
            "Only the orchestrator edits docs/roadmap.md; revert it and send "
            "the orchestrator the row."
        )

    # g. The formatter hook in agent sessions mangles Markdown.
    for line in corrupted_lines(diff)[:5]:
        failures.append(f"{CORRUPTION_MESSAGE} Line: {line.strip()[:120]}")
    return failures


# --- Review recorded -------------------------------------------------------
#
# The PR body is written through the same GitHub identity as the PR, so a
# `Reviewer:` line proves nothing by itself. What the check can prove from git
# is that a MERGE head is the clean automatic merge of main into a commit that
# was reviewed. So a merge commit is never accepted on a review line (rule a);
# it needs rule (b), a mechanical proof (b1) or a real review of the merge (b2).
#
#   (a)  non-merge commit C: a block `Reviewer: <name> Head: <C> Verdict:
#        clean` plus `Range: <base>..<C>` (base an ancestor of C, range head
#        equal to Head). The body may hold several such blocks, one per
#        reviewed head (the pre-merge head, later heads).
#   (b1) merge commit H = merge(P, M): P is accepted (recursively), M is on the
#        base branch, and `git merge-tree --write-tree P M` is clean and
#        yields exactly H's tree (no conflict resolution, no extra change).
#   (b2) merge commit H: a `Merge-review: <files>` block naming H, with its own
#        Reviewer/Head/Verdict and Range lines. P is accepted as in (b1), and
#        the files cover every file whose content differs from merge-tree.
# A plain block never accepts a merge commit by itself. Any block, plain or
# Merge-review, naming a commit with a verdict other than clean keeps it from
# being accepted; otherwise any clean block with a valid Range accepts it.
# The Range base to ask for is merge-base(base tip, commit).
# A Merge-review whose second parent is not on the base branch must list
# everything the merge brings into its first parent, since merge-tree proves
# nothing about that parent's content.
#
# Transition: PRs opened before Range existed carry ONE plain block, often
# naming their merge head, with the reviewed pre-merge head only in prose.
# While this flag is True: a NON-MERGE head is accepted on a one-line block
# without Range, and a MERGE head H is accepted on such a legacy block when H
# passes the tree test (second parent on the base tip, merge-tree clean and
# equal to H's tree, not an octopus). P is not checked in that legacy case.
# That is a known, temporary gap: an unreviewed P behind a clean merge. Today's
# state has the same gap, so it adds nothing worse. It closes when this flips
# to False, in the change that makes Range mandatory everywhere.
ACCEPT_LEGACY_REVIEW_BLOCK = True
# The walk down the first parents of merges decides each commit once and
# depends on nothing but the commit. A head with more than this many merges in
# a row behind it is refused before any is looked at (one rev-list), and no run
# decides more distinct commits than that chain plus its bottom, nested range
# bases included.
MAX_CHAIN_COMMITS = 200

_RANGE_LINE_RE = re.compile(r"^Range:[ \t]*(.*?)[ \t]*$")
_RANGE_RE = re.compile(r"^([0-9a-fA-F]{40})\.\.([0-9a-fA-F]{40})$")
_MERGE_REVIEW_RE = re.compile(r"^Merge-review:[ \t]*(.*?)[ \t]*$")
# Four or more spaces (or a tab) make a Markdown code block, not a block.
_INDENTED_RE = re.compile(r"^(?: {4,}|\t)")


class _ChainTooLong(Exception):
    pass


class Block:
    """One reviewer block of ## Review: a plain one or a Merge-review one."""

    def __init__(self, files=None):
        self.files = files  # None for a plain block, a list for Merge-review
        self.head = None
        self.verdict = None
        self.range = None  # raw text after `Range:`, None when absent


def parse_blocks(section):
    """The blocks of a ## Review section (fenced code already removed). A
    `Merge-review:` line opens a block that the next Reviewer line fills; any
    other Reviewer line opens a plain block. A Range line goes to the block
    last opened, if that has none. An indented line (4 spaces or a tab) is
    code, not a block line."""
    blocks, cur, pending = [], None, None
    for raw in section.splitlines():
        if _INDENTED_RE.match(raw):
            continue
        line = raw.strip()
        m = _MERGE_REVIEW_RE.match(line)
        if m:
            files = [f.strip() for f in m.group(1).split(",") if f.strip()]
            pending = cur = Block(files)
            blocks.append(cur)
            continue
        m = REVIEW_LINE_RE.match(line)
        if m:
            if pending is not None and pending.head is None:
                cur = pending
            else:
                cur = Block()
                blocks.append(cur)
            pending = None
            cur.head, cur.verdict = m.group(1).lower(), m.group(2)
            continue
        m = _RANGE_LINE_RE.match(line)
        if m and cur is not None and cur.range is None:
            cur.range = m.group(1)
    return blocks


class Git:
    """Git on a checkout of the base branch that also holds the PR's objects.
    Only cat-file, rev-parse, rev-list, merge-base, merge-tree and diff-tree
    run, all on object ids: nothing is checked out or executed, and the only
    write is merge-tree putting its result tree into the runner's ephemeral
    object store."""

    def __init__(self, cwd):
        self.cwd = cwd

    def run(self, *args):
        env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_OPTIONAL_LOCKS="0")
        return subprocess.run(
            ["git", *args],
            cwd=self.cwd,
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

    def has_commit(self, sha):
        return self.run("cat-file", "-e", f"{sha}^{{commit}}").returncode == 0

    def rev(self, name):
        r = self.run("rev-parse", "--verify", "--quiet", name)
        return r.stdout.strip() if r.returncode == 0 else None

    def parents(self, sha):
        r = self.run("rev-list", "--parents", "-n", "1", sha)
        if r.returncode != 0:
            raise ValueError(f"cannot read commit {sha}")
        return r.stdout.split()[1:]

    def is_ancestor(self, a, b):
        r = self.run("merge-base", "--is-ancestor", a, b)
        if r.returncode not in (0, 1):
            raise ValueError(f"cannot compare {a} and {b}")
        return r.returncode == 0

    def merge_run(self, head, limit):
        """How many commits in a row, from `head` down the first parents, are
        merges (two or more parents), counted up to limit + 1: one rev-list."""
        r = self.run(
            "rev-list", "--first-parent", "--parents", f"--max-count={limit + 1}", head
        )
        if r.returncode != 0:
            raise ValueError(f"cannot read commit {head}")
        run = 0
        for line in r.stdout.splitlines():
            if len(line.split()) < 3:
                break
            run += 1
        return run

    def merge_base(self, a, b):
        r = self.run("merge-base", a, b)
        return r.stdout.strip() if r.returncode == 0 else None

    def merge_tree(self, p, m):
        """(clean, tree, conflicted files) of an automatic merge of p and m."""
        r = self.run("merge-tree", "--write-tree", "--name-only", p, m)
        lines = r.stdout.split("\n")
        if r.returncode not in (0, 1) or not lines[0]:
            raise ValueError(f"git merge-tree failed for {p} and {m}")
        conflicted = []
        for line in lines[1:]:
            if not line:
                break
            conflicted.append(line)
        return r.returncode == 0, lines[0].strip(), conflicted

    def tree(self, commit):
        return self.rev(f"{commit}^{{tree}}")

    def changed_files(self, tree_a, tree_b):
        r = self.run("diff-tree", "-r", "--name-only", "--no-renames", tree_a, tree_b)
        if r.returncode != 0:
            raise ValueError(f"git diff-tree failed for {tree_a} and {tree_b}")
        return [line for line in r.stdout.split("\n") if line]


def _paste(commit, range_base, merge_files=None):
    """What to paste, with real newlines so the block can be pasted as is.
    `range_base` is `git merge-base <base tip> <commit>`."""
    lines = []
    if merge_files is not None:
        lines.append(f"Merge-review: {', '.join(merge_files)}")
    lines.append(f"Reviewer: isolated-reviewer  Head: {commit}  Verdict: clean")
    lines.append(f"Range: {range_base}..{commit}")
    return (
        "Paste the reviewer's block verbatim into ## Review (never write or "
        "edit it yourself), in this format:\n" + "\n".join(lines)
    )


class _Review:
    def __init__(self, git, base_tip, blocks, head):
        self.git, self.base_tip, self.head = git, base_tip, head
        self.plain = [b for b in blocks if b.files is None]
        self.merge_blocks = [b for b in blocks if b.files is not None]
        self.memo = {}
        self.visited = 0
        self._forks = {}
        self._covered = {}

    def fork(self, commit):
        """The Range base to ask for: where `commit` left the base branch."""
        if commit not in self._forks:
            self._forks[commit] = (
                self.git.merge_base(self.base_tip, commit) or self.base_tip
            )
        return self._forks[commit]

    def paste(self, commit, merge_files=None):
        return _paste(commit, self.fork(commit), merge_files)

    def where(self, commit):
        if commit == self.head:
            return f"head {commit}"
        return f"commit {commit} (reached from head {self.head} through clean merges)"

    def on_base(self, commit):
        return self.git.has_commit(commit) and self.git.is_ancestor(
            commit, self.base_tip
        )

    def range_failures(self, block, commit):
        """Failures of the Range line of a block naming `commit`, or []."""
        paste = self.paste(commit)
        want = f"{self.fork(commit)}..{commit}"
        if block.range is None:
            return [
                f"The review block for {commit} has no Range line: ask the "
                "isolated reviewer for its current block, which carries "
                f"'Range: <base sha>..<head sha>'. {paste}"
            ]
        m = _RANGE_RE.match(block.range)
        if not m:
            return [
                f"The Range {block.range!r} of the review for {commit} is not "
                "'<base sha>..<head sha>' with two full 40-hex shas: ask the "
                f"isolated reviewer for its block. {paste}"
            ]
        base, tip = m.group(1).lower(), m.group(2).lower()
        if tip != commit:
            return [
                f"The Range of the review for {commit} ends at {tip}, not at "
                f"its Head: ask the isolated reviewer for a review of "
                f"{commit}. {paste}"
            ]
        if base == tip:
            return [
                f"The Range of the review for {commit} is empty (it starts "
                f"and ends at {commit}): ask the isolated reviewer to review "
                f"{want}. {paste}"
            ]
        if not self.git.has_commit(base) or not self.git.is_ancestor(base, commit):
            return [
                f"The Range of the review for {commit} starts at {base}, which "
                f"is not an ancestor of {commit}: ask the isolated reviewer "
                f"to review {want}. {paste}"
            ]
        # A base on the base branch (the fork point is one) is a full review.
        # An incremental review (the fleet's normal flow: each push is
        # reviewed for its new commits) starts at a covered commit, so A..B
        # and B..C together cover C.
        if not self.covered(base):
            return [
                f"The Range of the review for {commit} starts at {base}, which "
                f"covers only part of the branch: it is neither on the base "
                f"branch, nor where {commit} left it ({self.fork(commit)}), nor "
                f"the end of an earlier review of this branch with a valid "
                f"Range, so the commits between them are unreviewed. Ask the "
                f"isolated reviewer to review {want}, or record a review that "
                f"ends at {base}. {paste}"
            ]
        return []

    def covered(self, commit):
        """Whether every commit up to `commit` has been read by a reviewer.
        True when it is on the base branch, when the checker accepts it (a
        clean review, rule b1 or b2, the legacy block), or when a block for it
        with ANY verdict has a valid Range whose base is itself covered. A
        review that asked for changes still counts here: the clean reviewer of
        the next range (B..D after a changes-requested B) has confirmed the
        findings raised at B are fixed, and no commit has gone unread. The
        head's own block must still be clean (see `_decide`). `commit` is a
        strict ancestor of the commit being decided, so this terminates."""
        if commit in self._covered:
            return self._covered[commit]
        self._covered[commit] = False
        found = self.git.is_ancestor(commit, self.base_tip) or not self.accepted(commit)
        for block in self.plain:
            if found:
                break
            m = block.head == commit and block.range and _RANGE_RE.match(block.range)
            if not m:
                continue
            base, tip = m.group(1).lower(), m.group(2).lower()
            # An empty range (base == tip) asks about `commit` itself, which
            # is still marked uncovered here, so it fails by itself.
            found = (
                tip == commit
                and self.git.has_commit(base)
                and self.git.is_ancestor(base, commit)
                and self.covered(base)
            )
        self._covered[commit] = found
        return found

    def requested_changes(self, commit, merge=False):
        what = "merge review" if merge else "review"
        return [
            f"The latest {what} of {commit} requested changes: fix the "
            "findings, push, and ask the isolated reviewer to review the new "
            "head. A block that asks for changes outweighs any clean block "
            "for the same commit."
        ]

    def reviewed(self, commit):
        """Rule (a), for a commit with fewer than two parents."""
        mine = [b for b in self.plain if b.head == commit]
        paste = self.paste(commit)
        if not mine:
            others = sorted({b.head for b in self.plain if b.head})
            if others:
                return [
                    f"The review is for {', '.join(others)}, but "
                    f"{self.where(commit)} needs one: ask the isolated "
                    f"reviewer for a full review of {commit}. {paste}"
                ]
            return [
                f"No isolated review recorded for {self.where(commit)}: ask "
                f"the isolated reviewer for a full review of {commit}. {paste}"
            ]
        # Any clean block with a valid Range accepts the commit, so a
        # corrected block pasted below a bad one works. A verdict other than
        # clean was refused before this point. Otherwise report the last block.
        failures = []
        for block in mine:
            if block.range is None and ACCEPT_LEGACY_REVIEW_BLOCK:
                return []
            failures = self.range_failures(block, commit)
            if not failures:
                return []
        return failures

    def required_files(self, h, p, m):
        """Files a Merge-review of h must list: those whose content differs
        between merge-tree(p, m) and h, the conflicted ones among them; and,
        when m is not on the base branch (so merge-tree proves nothing about
        m's content), everything h brings into p."""
        _, tree, conflicted = self.git.merge_tree(p, m)
        actual = self.git.tree(h)
        files = set(conflicted) | set(self.git.changed_files(tree, actual))
        if not self.on_base(m):
            files |= set(self.git.changed_files(self.git.tree(p), actual))
        return sorted(files)

    def merge_review_failures(self, commit, p, m):
        """Rule (b2) without the first parent. Returns (has_block, failures)."""
        mine = [b for b in self.merge_blocks if b.head == commit]
        if not mine:
            return False, []
        block = mine[0]
        if not block.files:
            return True, [
                f"The Merge-review block for {commit} names no files: it must "
                "read 'Merge-review: <file>, <file>' followed by the "
                "reviewer's Reviewer and Range lines."
            ]
        failures = self.range_failures(block, commit)
        if failures:
            return True, failures
        required = self.required_files(commit, p, m)
        listed = {f.strip() for f in block.files}
        missing = [f for f in required if f not in listed]
        if missing:
            return True, [
                f"The Merge-review for {commit} does not list "
                f"{', '.join(missing)}, which the merge changes against its "
                f"first parent {p} or against `git merge-tree {p} {m}`: ask "
                f"the isolated reviewer for a merge review that covers them. "
                f"{self.paste(commit, sorted(set(required) | listed))}"
            ]
        return True, []

    def accepted(self, root):
        """The failures that keep `root` from being accepted; [] accepts. Each
        commit is decided once, from the commit alone, so the memo is exact.
        The walk keeps its own stack of generators (one per commit that waits
        for its first parent), so a long chain never recurses."""
        if root in self.memo:
            return self.memo[root]
        stack = [(root, self._decide(root))]
        reply = None
        while stack:
            commit, gen = stack[-1]
            try:
                need = gen.send(reply)
            except StopIteration as done:
                self.memo[commit] = done.value
                stack.pop()
                reply = done.value
                continue
            if need in self.memo:
                reply = self.memo[need]
            else:
                stack.append((need, self._decide(need)))
                reply = None
        return self.memo[root]

    def _decide(self, commit):
        """A generator: it yields the first parent it needs a verdict on and
        is sent that verdict; it returns the failures for `commit`."""
        self.visited += 1
        if self.visited > MAX_CHAIN_COMMITS + 1:
            raise _ChainTooLong()
        blocks = [b for b in self.plain + self.merge_blocks if b.head == commit]
        bad = [b for b in blocks if b.verdict != "clean"]
        if bad:
            return self.requested_changes(
                commit, merge=any(b.files is not None for b in bad)
            )
        parents = self.git.parents(commit)
        if len(parents) > 2:
            return [
                f"{self.where(commit)} is an octopus merge ({len(parents)} "
                "parents), which cannot be checked mechanically: merge one "
                "branch at a time (merge the base branch alone, with no edit) "
                "and push."
            ]
        if len(parents) < 2:
            return self.reviewed(commit)
        p, m = parents
        failures = self.tree_failures(commit, p, m)
        if not failures:
            # (b1): the merge is the clean automatic merge.
            # Only for the head: the in-flight PRs name their merge head, and
            # a legacy block naming an inner merge must not vouch for the chain.
            if (
                ACCEPT_LEGACY_REVIEW_BLOCK
                and commit == self.head
                and any(b.head == commit and b.range is None for b in self.plain)
            ):
                return []  # the known transition gap described above
            parent_failures = yield p
            if not parent_failures:
                return []
            failures = parent_failures
        # (b2): a merge review.
        has_block, blocked = self.merge_review_failures(commit, p, m)
        if has_block and not blocked:
            parent_failures = yield p
            if not parent_failures:
                return []
            blocked = parent_failures
        return blocked or failures

    def tree_failures(self, h, p, m):
        """The tree test of rule (b1): second parent on the base branch,
        merge-tree clean and equal to h's tree."""
        if not self.on_base(m):
            files = []
            if self.git.has_commit(m):
                files = self.required_files(h, p, m)
            return [
                f"Merge {h}: its second parent {m} is not on the base branch "
                f"(tip {self.base_tip}), so it brings someone else's work, not "
                "main: merge only the base branch into this one, or ask the "
                "isolated reviewer for a merge review whose Merge-review line "
                f"lists every file the merge brings into {p} "
                f"(`git diff-tree -r --name-only {p} {h}`). "
                f"{self.paste(h, files or ['<files>'])}"
            ]
        clean, tree, conflicted = self.git.merge_tree(p, m)
        actual = self.git.tree(h)
        if not clean or tree != actual:
            files = sorted(set(conflicted) | set(self.git.changed_files(tree, actual)))
            return [
                f"Merge {h} is not a clean automatic merge of its parents "
                f"(first parent {p}, second parent {m}); the files whose "
                f"content differs from `git merge-tree {p} {m}`: "
                f"{', '.join(files) or 'none listed'}. Redo the merge with no "
                "manual edit (git merge, no conflict fixes, no extra changes) "
                "and push, or ask the isolated reviewer for a merge-only "
                f"review of these files. {self.paste(h, files or ['<files>'])}"
            ]
        return []


def review_recorded(body, head_sha, git=None, base_tip=None):
    """Returns the failures of the ## Review section for head_sha.

    With `git` (a Git on a checkout that holds the PR's objects) and `base_tip`
    (the base branch's tip sha) the rules above apply. Without them only the
    one-line Head comparison runs, for callers that have no repository."""
    _, texts = _sections(body or "")
    section = _strip_fences(texts.get("Review", ""))
    if git is None:
        return _legacy_review(section, head_sha)
    head_sha = head_sha.lower()
    review = _Review(git, base_tip, parse_blocks(section), head_sha)
    if not git.has_commit(head_sha):
        return [f"The head {head_sha} is not in the checkout: re-run the job."]
    try:
        if git.merge_run(head_sha, MAX_CHAIN_COMMITS) > MAX_CHAIN_COMMITS:
            raise _ChainTooLong()
        return review.accepted(head_sha)
    except _ChainTooLong:
        pass
    except RecursionError:  # backstop: the walk itself does not recurse
        pass
    except ValueError as e:
        return [f"The review could not be checked mechanically ({e}): re-run the job."]
    return [
        f"More than {MAX_CHAIN_COMMITS} commits need checking behind "
        f"{head_sha}; squash or rebase the branch onto the base branch (tip "
        f"{base_tip}) and get a full review of the new head. This block is a "
        "template for that squashed or rebased head, not for the current one: "
        "replace <new head sha> with it and <merge-base> with `git merge-base "
        f"{base_tip} <new head sha>`. {_paste('<new head sha>', '<merge-base>')}"
    ]


def _legacy_review(section, head_sha):
    """The SHA-only comparison: Head and Verdict come from the one review line,
    so quoted text in the findings cannot stand in for them."""
    lines = REVIEW_LINE_RE.findall(section)
    if not lines:
        return [
            f"No isolated review recorded for {head_sha}: {REVIEW_HINT}. "
            "The line must read 'Reviewer: <name> Head: <full sha> Verdict: "
            "clean | changes-requested' on one line."
        ]
    if len(lines) > 1:
        return [
            f"## Review holds {len(lines)} review lines: keep exactly one, "
            f"the isolated reviewer's block for {head_sha}."
        ]
    head, verdict = lines[0]
    if head.lower() != head_sha.lower():
        return [
            f"The review is for {head.lower()}, the head is {head_sha}: "
            "review the new commits."
        ]
    if verdict != "clean":
        return [
            f"The review of {head_sha} says {verdict}: fix the findings, "
            "push, and review the new head."
        ]
    return []


def api_get(path):
    """GET https://api.github.com/<path> with GITHUB_TOKEN: data only, read-only,
    nothing of the PR is checked out or executed."""
    req = urllib.request.Request(
        f"https://api.github.com/{path}",
        headers={
            "Authorization": f"Bearer {os.environ.get('GITHUB_TOKEN', '')}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def fetch_pr_files(api, repo, number):
    """The PR's files (filename, previous_filename, status, patch)."""
    files, page = [], 1
    while page <= 30:
        chunk = api(f"repos/{repo}/pulls/{number}/files?per_page=100&page={page}")
        files += chunk
        if len(chunk) < 100:
            break
        page += 1
    return files


def _blob(api, repo, path, ref):
    data = api(f"repos/{repo}/contents/{quote(path)}?ref={ref}")
    if data.get("encoding") != "base64":
        raise ValueError("blob too large")
    return base64.b64decode(data["content"]).decode("utf-8", "replace")


def local_patch(api, repo, f, base_sha, head_sha):
    """A patch for a file the files API listed without one (a large diff),
    diffed locally from the base and head blobs. Returns None when the blobs
    cannot be fetched."""
    # The merge base comes from the event's base.sha. On a moved base the patch
    # may differ from GitHub's own list; both sides are real commits.
    try:
        merge_base = base_sha
        if f.get("status") != "added":
            cmp = api(f"repos/{repo}/compare/{base_sha}...{head_sha}")
            merge_base = cmp["merge_base_commit"]["sha"]
            old = _blob(api, repo, f.get("previous_filename") or f["filename"], merge_base)
        else:
            old = ""
        new = _blob(api, repo, f["filename"], head_sha)
    except Exception:
        return None
    return "\n".join(
        difflib.unified_diff(
            old.splitlines(), new.splitlines(), n=0, lineterm="", fromfile="a", tofile="b"
        )
    )


def fill_patches(api, repo, files, base_sha, head_sha):
    """Fills in missing patches of the files the policy reads. Returns the
    failures for those it could not read."""
    failures = []
    for f in files:
        read = f["filename"] in READ_FILES
        if (
            (read or _is_widget_file(f))
            and f.get("status") != "removed"
            and not f.get("patch")
        ):
            patch = local_patch(api, repo, f, base_sha, head_sha)
            if patch is None:
                if not read and _is_widget_file(f):
                    continue  # catalog_first counts it as triggering
                failures.append(
                    f"The diff of {f['filename']} is too large to check and its "
                    "contents could not be fetched; split the change, or ask the "
                    "orchestrator to review it by hand."
                )
            else:
                f["patch"] = patch
    return failures


# Catalog first: a PR that adds a public widget under lib/src/**/widgets/ must
# also touch widgetbook/ with a line naming one of the new classes. Only the
# PR's file list and patches are read. Commit order is not checked: squash
# merges erase it, and merges of main and stacked PRs corrupt it.
WIDGET_PATH_RE = re.compile(r"^lib/src/(?:[^/]+/)*widgets/.+\.dart$")
PUBLIC_WIDGET_RE = re.compile(
    r"^[ \t]*(?:(?:abstract|base|final)\s+)*class\s+([A-Za-z][A-Za-z0-9_]*)"
    r"\s*(?:<[^{;]*?>)?\s+extends\s+(?:StatelessWidget|StatefulWidget)\b",
    re.M,
)
CATALOG_HATCH_RE = re.compile(
    r"^Catalog-first:[ \t]*not applicable,[ \t]*(.*?)[ \t]*$", re.M | re.I
)
_PLACEHOLDER_WORDS = {"n", "a", "na", "tbd", "todo", "reason", "none", "nothing"}


def _is_widget_file(f):
    return f.get("status") == "added" and bool(WIDGET_PATH_RE.match(f["filename"]))


def _is_catalog_file(f):
    return f["filename"].startswith("widgetbook/") and f["filename"].endswith(".dart")


def _added_text(patch):
    """The added lines of a unified diff, after its first hunk header."""
    out, in_hunk = [], False
    for line in (patch or "").splitlines():
        if line.startswith("@@"):
            in_hunk = True
        elif in_hunk and line.startswith("+"):
            out.append(line[1:])
    return "\n".join(out)


def _without_block_comments(text):
    """Dart `/* ... */` comments removed, their newlines kept."""
    return re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)


def _hatch_reason_ok(reason):
    if len(reason) < 10:
        return False
    words = re.findall(r"[a-z0-9]+", reason.replace("<reason>", " ").lower())
    return any(w not in _PLACEHOLDER_WORDS for w in words)


def _hatch_window(section):
    """The text of the clean review block after its `Reviewer:` line, up to its
    `Proof reproduced:` line, or up to the first blank line when the block has
    none. The reviewer emits the hatch inside this window; a line the author
    adds elsewhere in ## Review (editing the body does not change the head)
    is outside it."""
    m = REVIEW_LINE_RE.search(section)
    if not m:
        return ""
    rest = section[m.end() :]
    p = re.search(r"^Proof reproduced:", rest, re.M)
    if p:
        return rest[: p.start()]
    return re.split(r"\n[ \t]*\n", rest, maxsplit=1)[0]


def _hatch(body, head_sha):
    """The reason of an accepted escape hatch, else None. See catalog_first."""
    _, texts = _sections(body or "")
    section = _strip_fences(texts.get("Review", ""))
    if review_recorded(body, head_sha):
        return None
    m = CATALOG_HATCH_RE.search(_hatch_window(section))
    if m and _hatch_reason_ok(m.group(1)):
        return m.group(1)
    return None


def _names_a_class(files, classes):
    used = "\n".join(_added_text(f.get("patch")) for f in files if _is_catalog_file(f))
    return any(re.search(rf"\b{re.escape(n)}\b", used) for n in classes)


def _needs_patch(f):
    """A widgetbook .dart file listed without a patch that may hold added
    lines: not removed, and not a pure rename."""
    return (
        _is_catalog_file(f)
        and not f.get("patch")
        and f.get("status") != "removed"
        and not (f.get("status") == "renamed" and f.get("changes") == 0)
    )


def catalog_first(files, body, head_sha, fetch=None):
    """Returns (failures, notice). The notice is the accepted escape hatch's
    reason. The hatch is the line `Catalog-first: not applicable, <reason>` in
    the reviewer's block: after its `Reviewer:` line for head_sha with Verdict
    clean, before its `Proof reproduced:` line, outside fenced code and HTML
    comments. The reason must be at least 10 characters and not a placeholder.
    Only a line inside the reviewer's pasted block counts; that relies on the
    block being pasted unchanged, the same trust as the `Reviewer:` line itself.
    Any push changes the head, so the review has to be redone.

    `fetch(f)` returns a patch for a widgetbook file listed without one, or
    None. It is called only once the PR adds a public widget that no patch in
    hand names and no hatch covers; a file that cannot be read does not count
    as naming a class."""
    new, unread = {}, []
    for f in files:
        if not _is_widget_file(f):
            continue
        if not f.get("patch"):
            unread.append(f["filename"])
            continue
        for name in PUBLIC_WIDGET_RE.findall(_without_block_comments(_added_text(f["patch"]))):
            new.setdefault(name, f["filename"])
    if not new and not unread:
        return [], None
    if new and not unread and _names_a_class(files, new):
        return [], None
    reason = _hatch(body, head_sha)
    if reason is not None:
        return [], f"Catalog-first: not applicable, {reason}"
    if new and not unread and fetch:
        for f in files:
            if _needs_patch(f):
                f["patch"] = fetch(f) or ""
        if _names_a_class(files, new):
            return [], None
    found = [f"{n} ({path})" for n, path in new.items()]
    found += [f"{path} (its declarations could not be read)" for path in unread]
    return [
        "New public widgets have no Widgetbook use case: "
        + ", ".join(found)
        + ". Add a use case in a widgetbook/ .dart file that names one of them "
        "(the component-catalog skill). If none applies, the isolated reviewer "
        "emits 'Catalog-first: not applicable, <reason>' in its block (at least "
        "10 characters; 'shown through the <Parent> use case' is a reason) for "
        "the current head."
    ], None


def changed_names(files):
    names = []
    for f in files:
        names.append(f["filename"])
        if f.get("previous_filename"):
            names.append(f["previous_filename"])
    return names


def version_changed(files):
    for f in files:
        if f["filename"] == "pubspec.yaml":
            return any(
                re.match(r"^[+-]version:", line)
                for line in (f.get("patch") or "").splitlines()
            )
    return False


def corruption_diff(files):
    return "\n".join(
        f"diff --git a/{f['filename']} b/{f['filename']}\n{f.get('patch') or ''}"
        for f in files
        if f["filename"] in CORRUPTION_FILES
    )


READ_FILES = ("pubspec.yaml",) + CORRUPTION_FILES


def main(argv, api=api_get, git=None):
    """`api(path)` and `git` are injectable so tests can run a saved event JSON
    without the network. `git` defaults to the checkout in the working
    directory (base branch, plus the PR head's objects fetched by the
    workflow)."""
    mode = argv[1] if len(argv) > 1 else ""
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as f:
        pr = json.load(f)["pull_request"]
    head_sha = pr["head"]["sha"]
    author = (pr.get("user") or {}).get("login", "")
    head_ref = pr["head"]["ref"]
    same = same_repo(pr)
    if mode == "policy":
        repo = pr["base"]["repo"]["full_name"]
        # Fail closed: if the API head is not the event's, a push landed (or
        # the API lags). A red run on a superseded SHA is harmless, since the
        # branch protection reads the current head, and a re-run clears a lag.
        current = api(f"repos/{repo}/pulls/{pr['number']}")["head"]["sha"]
        if current != head_sha:
            print(
                f"::error::The PR head moved ({head_sha} → {current}); "
                "the run on the newer head decides."
            )
            return 1
        files = fetch_pr_files(api, repo, pr["number"])
        failures = []
        listed = pr.get("changed_files")
        if isinstance(listed, int) and len(files) < listed:
            failures.append(
                f"Too many files to check: the API lists {len(files)} of "
                f"{listed}. Split the PR."
            )
        failures += fill_patches(api, repo, files, pr["base"]["sha"], head_sha)
        failures += check(
            pr.get("title") or "",
            pr.get("body") or "",
            head_ref,
            author,
            head_sha,
            changed_names(files),
            version_changed(files),
            corruption_diff(files),
            same,
        )
        more, notice = catalog_first(
            files,
            pr.get("body") or "",
            head_sha,
            lambda f: local_patch(api, repo, f, pr["base"]["sha"], head_sha),
        )
        failures += more
        if notice:
            print(f"::notice::{notice}")
    elif mode == "review":
        if is_bot(author, head_ref, same):
            failures = []
        else:
            git = git or Git(os.getcwd())
            base_ref = pr["base"].get("ref", "")
            base_tip = git.rev(f"refs/remotes/origin/{base_ref}^{{commit}}")
            if base_tip is None:
                failures = [
                    f"The base branch {base_ref!r} is not in the checkout: "
                    "re-run the job."
                ]
            else:
                failures = review_recorded(
                    pr.get("body") or "", head_sha, git, base_tip
                )
    else:
        print("usage: pr_policy.py policy|review", file=sys.stderr)
        return 2
    for failure in failures:
        # A workflow command ends at a newline; %0A keeps a long message whole.
        print("::error::" + failure.replace("%", "%25").replace("\n", "%0A"))
    if not failures:
        print("ok")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

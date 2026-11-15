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
_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
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


def _strip_comments(text):
    return _COMMENT_RE.sub("", text)


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
# A plain block never accepts a merge commit by itself. Any block naming a
# commit with a verdict other than clean keeps it from being accepted.
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
# Clean merges followed in a row before a Merge-review block is needed. A
# Merge-review block anchors the chain: its first parent starts a new count.
MAX_MERGE_DEPTH = 20

_RANGE_LINE_RE = re.compile(r"^Range:[ \t]*(.*?)[ \t]*$")
_RANGE_RE = re.compile(r"^([0-9a-fA-F]{40})\.\.([0-9a-fA-F]{40})$")
_MERGE_REVIEW_RE = re.compile(r"^Merge-review:[ \t]*(.*?)[ \t]*$")
# Four or more spaces (or a tab) make a Markdown code block, not a block.
_INDENTED_RE = re.compile(r"^(?: {4,}|\t)")


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


def _paste(commit, base_tip, merge_files=None):
    """What to paste, with real newlines so the block can be pasted as is."""
    lines = []
    if merge_files is not None:
        lines.append(f"Merge-review: {', '.join(merge_files)}")
    lines.append(f"Reviewer: isolated-reviewer  Head: {commit}  Verdict: clean")
    lines.append(f"Range: {base_tip}..{commit}")
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
        paste = _paste(commit, self.base_tip)
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
                f"{self.base_tip}..{commit}. {paste}"
            ]
        if not self.git.has_commit(base) or not self.git.is_ancestor(base, commit):
            return [
                f"The Range of the review for {commit} starts at {base}, which "
                f"is not an ancestor of {commit}: ask the isolated reviewer "
                f"to review {self.base_tip}..{commit}. {paste}"
            ]
        fork = self.git.merge_base(self.base_tip, commit)
        if not self.git.is_ancestor(base, self.base_tip) and base != fork:
            return [
                f"The Range of the review for {commit} starts at {base}, which "
                f"covers only part of the branch (it is neither on the base "
                f"branch nor where {commit} left it, {fork}): ask the "
                f"isolated reviewer to review {self.base_tip}..{commit}. {paste}"
            ]
        return []

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
        paste = _paste(commit, self.base_tip)
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
        if any(b.verdict != "clean" for b in mine):
            return self.requested_changes(commit)
        block = mine[0]
        if block.range is None and ACCEPT_LEGACY_REVIEW_BLOCK:
            return []
        return self.range_failures(block, commit)

    def required_files(self, h, p, m):
        """Files a Merge-review of h must list: those whose content differs
        between merge-tree(p, m) and h; and, when m is not on the base branch
        (so merge-tree proves nothing about m's content), everything h brings
        into p."""
        _, tree, conflicted = self.git.merge_tree(p, m)
        actual = self.git.tree(h)
        files = set(conflicted) | set(self.git.changed_files(tree, actual))
        if not self.on_base(m):
            files |= set(self.git.changed_files(self.git.tree(p), actual))
        return sorted(files)

    def merge_review(self, commit, p, m):
        """Rule (b2). Returns (accepted, failures); failures are empty when no
        Merge-review block names the commit. The first parent starts a new
        depth count: a merge review anchors the chain."""
        mine = [b for b in self.merge_blocks if b.head == commit]
        if not mine:
            return False, []
        if any(b.verdict != "clean" for b in mine):
            return False, self.requested_changes(commit, merge=True)
        block = mine[0]
        if not block.files:
            return False, [
                f"The Merge-review block for {commit} names no files: it must "
                "read 'Merge-review: <file>, <file>' followed by the "
                "reviewer's Reviewer and Range lines."
            ]
        failures = self.range_failures(block, commit)
        if failures:
            return False, failures
        required = self.required_files(commit, p, m)
        listed = {f.strip() for f in block.files}
        missing = [f for f in required if f not in listed]
        if missing:
            return False, [
                f"The Merge-review for {commit} does not list "
                f"{', '.join(missing)}, which the merge changes against its "
                f"first parent {p} or against `git merge-tree {p} {m}`: ask "
                f"the isolated reviewer for a merge review that covers them. "
                f"{_paste(commit, self.base_tip, sorted(set(required) | listed))}"
            ]
        failures = self.accepted(p, 0)
        return not failures, failures

    def accepted(self, commit, depth=0):
        """The failures that keep `commit` from being accepted; [] accepts.
        Memoised per run: the first parent is asked about by (b1) and (b2)."""
        if commit not in self.memo:
            self.memo[commit] = self._accepted(commit, depth)
        return self.memo[commit]

    def _accepted(self, commit, depth):
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
        if depth >= MAX_MERGE_DEPTH:
            failures = [
                f"{MAX_MERGE_DEPTH} clean merges in a row lie between head "
                f"{self.head} and {commit}, which is too long a chain to "
                f"follow: ask the isolated reviewer for a merge review of "
                f"{commit} (list the files it changes, or any file if it "
                f"changes none). {_paste(commit, self.base_tip, ['<files>'])}"
            ]
        else:
            failures = self.clean_merge(commit, p, m, depth)
        if not failures:
            return []
        ok, blocked = self.merge_review(commit, p, m)
        if ok:
            return []
        return blocked or failures

    def clean_merge(self, h, p, m, depth):
        """Rule (b1)."""
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
                f"{_paste(h, self.base_tip, files or ['<files>'])}"
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
                f"review of these files. {_paste(h, self.base_tip, files or ['<files>'])}"
            ]
        named = [b for b in self.plain if b.head == h]
        if (
            ACCEPT_LEGACY_REVIEW_BLOCK
            and named
            and all(b.verdict == "clean" for b in named)
            and any(b.range is None for b in named)
        ):
            return []  # the known transition gap described above
        return self.accepted(p, depth + 1)


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
        return review.accepted(head_sha)
    except RecursionError:
        return [
            f"The merge chain below {head_sha} is too deep to check: ask the "
            "isolated reviewer for a merge review of the head."
        ]
    except ValueError as e:
        return [f"The review could not be checked mechanically ({e}): re-run the job."]


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
        if (
            f["filename"] in READ_FILES
            and f.get("status") != "removed"
            and not f.get("patch")
        ):
            patch = local_patch(api, repo, f, base_sha, head_sha)
            if patch is None:
                failures.append(
                    f"The diff of {f['filename']} is too large to check and its "
                    "contents could not be fetched; split the change, or ask the "
                    "orchestrator to review it by hand."
                )
            else:
                f["patch"] = patch
    return failures


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

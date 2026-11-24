#!/usr/bin/env python3
"""PR policy checks, run by .github/workflows/pr-policy.yml.

    python3 -I scripts/pr_policy.py policy   # job "PR policy"
    python3 -I scripts/pr_policy.py review   # job "Review recorded"

The workflow runs on pull_request_target from the default branch, so this file
is main's copy, never the PR's. The script reads the pull_request event from
$GITHUB_EVENT_PATH (the title and body never pass through a shell line) and
asks the REST API for the PR's files and patches with a read-only token. It
never checks out, fetches, executes or installs anything from the PR.
`check`, `review_recorded` and `main` are tested in scripts/test_pr_policy.py.
"""

import base64
import difflib
import json
import os
import re
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
    r"[ \t]+Verdict:[ \t]*(clean|changes-requested)[ \t]*$",
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


def _scan_line(line, close_later, at_start, raw=False, literal_code=False):
    """Removes the HTML comments GitHub would hide from one line outside a
    fence. Returns (kept text, whether a comment stays open past the line). A
    `<!--` inside an inline code span is literal, except in a raw HTML block
    (`raw`), where nothing is code and an unclosed one hides the rest. An unclosed `<!--` opens a
    comment only at the start of a line (up to 3 spaces of indent: an HTML
    block, which runs to the next `-->` or the end of the text) or when a
    `-->` follows later in the same paragraph; mid-line with no `-->` it is plain text."""
    masked = line
    if not (raw or literal_code):
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
        if close_later or raw or (at_start and _COMMENT_START_RE.fullmatch(masked[:i])):
            return "".join(out).replace(_MASK, "<!--"), True
        out.append("<!--")
        pos = i + 4


_GFM_FENCE_RE = re.compile(r" {0,3}(`{3,}[^`]*$|~{3,})")
_BLOCK_START_RE = re.compile(r" {0,3}(#{1,6}([ \t\r]|$)|<!--)")
# GFM HTML blocks of types 1 and 6, also inside a quote or list item (the
# prefix is wider than GFM allows, which only hides more). A `<!--` inside one
# is raw HTML the browser closes at the next `-->`, whatever the blank lines.
_RAW_TEXT = {"script", "pre", "style", "textarea"}
_HTML_BLOCK_RE = re.compile(
    r"[ \t>\-*+0-9.)]*</?(script|pre|style|textarea|address|article|aside|base|basefont"
    r"|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl"
    r"|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head"
    r"|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol"
    r"|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th"
    r"|thead|title|tr|track|ul)(?:[ \t\r>]|/>|$)",
    re.I,
)


def _closes_in_paragraph(lines):
    """Whether a `-->` arrives in `lines` before the paragraph ends: a blank
    line (spaces and tabs only), or a line that starts a block (ATX heading,
    fence, `<!--` HTML block). An inline comment spans soft line breaks of one
    paragraph only. Block starts this does not know (setext underline, list,
    quote, thematic break, table) keep the paragraph going, which hides more."""
    for line in lines:
        if (
            not line.strip(" \t\r")
            or _GFM_FENCE_RE.match(line)
            or _BLOCK_START_RE.match(line)
        ):
            return False
        if "-->" in line:
            return True
    return False


def _strip_comments(text):
    """Text as GitHub renders it, minus HTML comments. A fence line inside a
    comment is hidden with it, so it does not toggle the fence state."""
    lines = text.split("\n")
    out, fenced, in_comment, html_block = [], False, False, False
    ticks = False  # an unpaired backtick earlier in the paragraph may pair with this line's
    for n, line in enumerate(lines):
        if not fenced and not in_comment:
            m = _HTML_BLOCK_RE.match(line)
            if m:
                html_block = m.group(1).lower() if m.group(1).lower() in _RAW_TEXT else True
            elif html_block is True and not line.strip(" \t\r"):
                html_block = False
            if not line.strip(" \t\r"):
                ticks = False
        if html_block:
            close_later = "-->" in "\n".join(lines[n + 1 :])
        else:
            close_later = _closes_in_paragraph(lines[n + 1 :])
        if in_comment:
            end = line.find("-->")
            if end < 0:
                continue
            kept, in_comment = _scan_line(line[end + 3 :], close_later, False, bool(html_block), ticks)
            out.append(kept)
        elif not html_block and _GFM_FENCE_RE.match(line):
            fenced = not fenced
            out.append(line)
        elif fenced:
            out.append(line)
        else:
            kept, in_comment = _scan_line(line, close_later, True, bool(html_block), ticks)
            out.append(kept)
        if not fenced and "`" in _INLINE_CODE_RE.sub("", line):
            ticks = True
        if html_block in _RAW_TEXT and f"</{html_block}" in line.lower():
            html_block = False
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


def review_recorded(body, head_sha):
    """Returns the failures of the ## Review section for head_sha. The section
    must hold exactly one line `Reviewer: <name> Head: <40-hex> Verdict:
    clean|changes-requested` outside fenced code; Head and Verdict come from
    that one line, so quoted text in the findings cannot stand in for them."""
    _, texts = _sections(body or "")
    section = _strip_fences(texts.get("Review", ""))
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
            f"The review of {head_sha} says changes-requested: fix the findings, "
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


def main(argv, api=api_get):
    """`api(path)` is injectable so tests can run a saved event JSON without
    the network."""
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
        failures = (
            []
            if is_bot(author, head_ref, same)
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

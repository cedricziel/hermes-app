"""Turns a GitHub release body into plain text for TestFlight's "What to Test".

    gh release view "$TAG" --json body --jq .body | python3 scripts/plain_release_notes.py

TestFlight shows the text as it is, so release-please's markdown (headings, bold
scopes, links, and the trailing pull request and commit references) would reach
testers as raw symbols. Links keep their text, the references are dropped, and
the result is cut at a line to fit the 4000 characters TestFlight accepts.

App Review rejects "What's New" text that mentions other platforms (guideline
2.3.10), so lines about Android, Windows or Linux are left out, and a heading
with nothing left under it goes too.
"""

import re
import sys

LIMIT = 4000

# "([#93](url))" and "([2c79bd7](url))", which release-please appends to the end
# of a line. One in the middle of a sentence is part of the sentence.
_REFERENCE = re.compile(r"(?:\s*\(\[(?:#\d+|[0-9a-f]{7,40})\]\([^)]*\)\))+\s*$")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_BOLD = re.compile(r"\*\*(.+?)\*\*|__(.+?)__")
_ITALIC = re.compile(r"\*(.+?)\*|(?<!\w)_(.+?)_(?!\w)")
_CODE = re.compile(r"`([^`]*)`")
_HEADING = re.compile(r"^#{1,6}\s+(.*)$")
_BULLET = re.compile(r"^\s*[*+-]\s+")
# "windows" alone is a Mac app's windows; the platform is "Windows" or a scope.
_OTHER_PLATFORM = re.compile(r"(?i:\b(?:android|linux)\b)|\bWindows\b|\bwindows:")


def _inline(text: str) -> str:
    text = _REFERENCE.sub("", text)
    text = _LINK.sub(r"\1", text)
    text = _BOLD.sub(lambda m: m.group(1) or m.group(2), text)
    text = _ITALIC.sub(lambda m: m.group(1) or m.group(2), text)
    return _CODE.sub(r"\1", text).strip()


def plain(markdown: str) -> str:
    # Heading, the lines kept under it and whether any were left out. The first
    # heading is None, for text before any heading.
    sections: list[tuple[str | None, list[str], list[bool]]] = [(None, [], [False])]
    blank = False
    for raw in markdown.splitlines():
        if not raw.strip():
            blank = True
            continue
        heading = _HEADING.match(raw.strip())
        if heading:
            sections.append((_inline(heading.group(1)), [], [False]))
            blank = False
            continue
        text = _inline(raw)
        if _OTHER_PLATFORM.search(text):
            sections[-1][2][0] = True
            continue
        body = sections[-1][1]
        if blank and body:
            body.append("")
        body.append(f"- {_inline(_BULLET.sub('', raw))}" if _BULLET.match(raw) else text)
        blank = False

    lines: list[str] = []
    for title, body, [left_out] in sections:
        if left_out and not body:
            continue
        if title is not None:
            if lines:
                lines.append("")
            lines.append(title)
        lines.extend(body)

    text = "\n".join(lines)
    if len(text) <= LIMIT:
        return text

    kept: list[str] = []
    size = 0
    for line in lines:
        if size + len(line) + 1 > LIMIT - 2:
            break
        kept.append(line)
        size += len(line) + 1
    while kept and not kept[-1]:
        kept.pop()
    return "\n".join(kept) + "\n…"


def main() -> None:
    text = plain(sys.stdin.read())
    sys.stdout.write(text + ("\n" if text else ""))


if __name__ == "__main__":
    main()

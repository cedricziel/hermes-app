"""Turns a GitHub release body into plain text for TestFlight's "What to Test".

    gh release view "$TAG" --json body --jq .body | python3 scripts/plain_release_notes.py

TestFlight shows the text as it is, so release-please's markdown (headings, bold
scopes, links, and the trailing pull request and commit references) would reach
testers as raw symbols. Links keep their text, the references are dropped, and
the result is cut at a line to fit the 4000 characters TestFlight accepts.
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


def _inline(text: str) -> str:
    text = _REFERENCE.sub("", text)
    text = _LINK.sub(r"\1", text)
    text = _BOLD.sub(lambda m: m.group(1) or m.group(2), text)
    text = _ITALIC.sub(lambda m: m.group(1) or m.group(2), text)
    return _CODE.sub(r"\1", text).strip()


def plain(markdown: str) -> str:
    lines: list[str] = []
    blank = False
    after_heading = False
    for raw in markdown.splitlines():
        if not raw.strip():
            blank = True
            continue
        heading = _HEADING.match(raw.strip())
        if heading:
            if lines:
                lines.append("")
            lines.append(_inline(heading.group(1)))
            blank = False
            after_heading = True
            continue
        if blank and lines and not after_heading:
            lines.append("")
        text = _inline(raw)
        lines.append(f"- {_inline(_BULLET.sub('', raw))}" if _BULLET.match(raw) else text)
        blank = False
        after_heading = False

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

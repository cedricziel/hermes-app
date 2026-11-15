#!/usr/bin/env python3
"""Pick the test files a trial merge must run (used by scripts/premerge_check.sh).

Run it with `python3 -I`, with the trial merge as --repo. It writes
<out>/selected (test paths, NUL separated, in priority order), <out>/capped
(the lib/src directories whose (c2) tests were dropped by the cap, one per
line, empty when nothing was dropped) and prints a report.

The union, in this priority order, deduplicated:

  (a)  test files (test/**/*_test.dart) the PRs changed, merge base to PR head
  (b)  test files changed on main since each merge base
  (c1) test files that import, directly, a lib/ file the PRs changed
  (c2) for each lib/src/<dir>/ a PR touches, every test file that imports any
       file under it

(a), (b) and (c1) are always kept whole. (c2) is dropped beyond --cap files.

Matching: `package:<name>/...` (name read from pubspec.yaml) and relative
imports, resolved to repo paths. One level of re-export is followed (a lib file
that `export`s a changed file counts as changed). A change to a `part` file
counts as a change to its library. Deleted test files are never selected.

NOT followed: imports further than one level (a test reaching lib/ through
test/support/ or through a re-export of a re-export), conditional imports
(`import 'a.dart' if (...) 'b.dart'` counts only 'a.dart'), tests that reach code
only through widgetbook/ or generated code, changes to test helpers that are not
*_test.dart files, and anything outside lib/ and test/ (packages/, ios/, assets).
"""

import argparse
import os
import posixpath
import re
import subprocess
import sys

DIRECTIVE = re.compile(
    r"""^[ \t]*(import|export|part[ \t]+of|part)[ \t\r\n]+['"]([^'"\n]+)['"]""",
    re.M,
)
TEST_RE = re.compile(r"^test/(.*/)?[^/]*_test\.dart$")


def fail(msg):
    print("premerge_affected_tests: " + msg, file=sys.stderr)
    sys.exit(2)


def git_names(repo, a, b):
    p = subprocess.run(
        [
            "git",
            "-C",
            repo,
            "-c",
            "core.quotepath=off",
            "diff",
            "--no-renames",
            "--name-only",
            "-z",
            a,
            b,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if p.returncode != 0:
        fail("git diff %s %s failed: %s" % (a, b, p.stderr.decode("utf-8", "replace")))
    return [n.decode("utf-8", "surrogateescape") for n in p.stdout.split(b"\0") if n]


def package_name(repo):
    try:
        with open(os.path.join(repo, "pubspec.yaml"), encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        fail("cannot read pubspec.yaml in the trial tree: %s" % e)
    m = re.search(r"^name:[ \t]*['\"]?([A-Za-z0-9_]+)", text, re.M)
    if not m:
        fail("no top-level `name:` in pubspec.yaml; cannot match package: imports")
    return m.group(1)


def resolve(src, uri, pkg):
    """Repo-relative path a directive points at, or None."""
    if uri.startswith("package:"):
        name, _, rest = uri[len("package:") :].partition("/")
        return "lib/" + rest if name == pkg and rest else None
    if ":" in uri:
        return None  # dart:, file:, http:
    path = posixpath.normpath(posixpath.join(posixpath.dirname(src), uri))
    return None if path.startswith("..") else path


def scan(repo, root, pkg):
    """{repo-relative .dart path: [(kind, resolved target)]} under root."""
    out = {}
    base = os.path.join(repo, root)
    for dirpath, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in files:
            if not name.endswith(".dart"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, repo).replace(os.sep, "/")
            try:
                with open(full, encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError:
                continue
            found = []
            for kind, uri in DIRECTIVE.findall(text):
                target = resolve(rel, uri, pkg)
                if target:
                    found.append((re.sub(r"\s+", "", kind), target))
            out[rel] = found
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--main-tip", required=True)
    ap.add_argument(
        "--pr", nargs=2, action="append", metavar=("MERGE_BASE", "HEAD"), required=True
    )
    ap.add_argument("--cap", type=int, default=150)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    repo = args.repo

    pkg = package_name(repo)
    lib = scan(repo, "lib", pkg)
    tests = {t: d for t, d in scan(repo, "test", pkg).items() if TEST_RE.match(t)}

    changed_tests, main_tests, changed_lib = set(), set(), set()
    for mb, head in args.pr:
        for n in git_names(repo, mb, head):
            if TEST_RE.match(n):
                changed_tests.add(n)
            elif n.startswith("lib/") and n.endswith(".dart"):
                changed_lib.add(n)
        for n in git_names(repo, mb, args.main_tip):
            if TEST_RE.match(n):
                main_tests.add(n)

    def present(names):
        return sorted(n for n in names if os.path.isfile(os.path.join(repo, n)))

    group_a = present(changed_tests)
    group_b = present(main_tests)

    # A part file's change is its library's change.
    libs = set(changed_lib)
    for f, directives in lib.items():
        for kind, target in directives:
            if kind == "part" and target in changed_lib:
                libs.add(f)
    # One level of re-export.
    direct = set(libs)
    for f, directives in lib.items():
        for kind, target in directives:
            if kind == "export" and target in libs:
                direct.add(f)

    def importers(match):
        return sorted(
            t
            for t, directives in tests.items()
            if any(
                k in ("import", "export") and match(target) for k, target in directives
            )
        )

    group_c1 = importers(lambda target: target in direct)

    dirs = sorted(
        {
            "/".join(f.split("/")[:3]) + "/"
            for f in changed_lib
            if f.startswith("lib/src/") and f.count("/") >= 3
        }
    )
    c2 = [(d, importers(lambda target, d=d: target.startswith(d))) for d in dirs]

    selected, seen = [], set()
    for group in (group_a, group_b, group_c1):
        for t in group:
            if t not in seen:
                seen.add(t)
                selected.append(t)
    must = len(selected)
    added = 0
    capped = []
    for d, files in c2:
        dropped = False
        for t in files:
            if t in seen:
                continue
            if len(selected) < args.cap:
                seen.add(t)
                selected.append(t)
                added += 1
            else:
                dropped = True
        if dropped:
            capped.append(d)

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "selected"), "wb") as f:
        for t in selected:
            f.write(t.encode("utf-8", "surrogateescape") + b"\0")
    with open(os.path.join(args.out, "capped"), "w") as f:
        f.write("".join(d + "\n" for d in capped))

    print(
        "package %s; %d test files scanned, %d lib files scanned"
        % (pkg, len(tests), len(lib))
    )
    print("(a) changed by the PR(s): %d" % len(group_a))
    print("(b) changed on main since the merge base: %d" % len(group_b))
    print("(c1) import a changed lib file: %d" % len(group_c1))
    print(
        "(c2) import anything under a touched lib/src/<dir>/ (%s): %d added"
        % (", ".join(dirs) or "no directory", added)
    )
    for t in selected:
        print("  " + t.replace("\n", "\\n"))
    if capped:
        print(
            "cap of %d files reached; (a), (b), (c1) kept whole (%d); (c2) dropped for: %s"
            % (args.cap, must, " ".join(capped))
        )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Which test files reach the code a mutant list mutates, and which of them
a list's `tests` leaves out.

    scripts/mutant_importers.py                 every list in tool/mutants/
    scripts/mutant_importers.py queue kanban    some lists
    scripts/mutant_importers.py --apply         also add the missing files to `tests`

A test file counts for a list when it reaches a library that one of the list's
mutants edits, in any of these ways:

1. it imports (or exports) that library directly;
2. a mutated file is a `part of` another file: the parent library, which holds
   the `part '...'` line, is the library that gets imported;
3. one hop through lib/: it imports a lib/ library that itself imports the
   mutated library (a listener test reaches a parser through the listener);
4. through test/ helpers: it imports a non-test Dart file under test/ (a
   harness, a fake) that imports the mutated library, or that imports another
   such helper, at any depth.

`test/workflows/*_test.dart` is always included. Both quote styles are read.
Exit code 1 when any list is missing files, 0 when none is.
"""

import argparse
import glob
import json
import os
import re
import sys

IMPORT = re.compile(r"""^\s*(?:import|export)\s+(['"])([^'"]+)\1""", re.M)
PART = re.compile(r"""^\s*part\s+(['"])([^'"]+)\1\s*;""", re.M)
PART_OF = re.compile(r"^\s*part\s+of\b", re.M)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def package_name(repo):
    try:
        m = re.search(r"^name:\s*(\S+)", read(os.path.join(repo, "pubspec.yaml")), re.M)
        if m:
            return m.group(1)
    except OSError:
        pass
    return "hermes_app"


def dart_files(repo, folder):
    """Repo-relative paths of every .dart file under [folder], sorted."""
    root = os.path.join(repo, folder)
    out = []
    for base, _dirs, names in os.walk(root):
        for name in names:
            if name.endswith(".dart"):
                out.append(os.path.relpath(os.path.join(base, name), repo))
    return sorted(out)


class Tree:
    """Import and part facts of a checkout, read once."""

    def __init__(self, repo):
        self.repo = repo
        self.package = package_name(repo)
        self.lib = dart_files(repo, "lib")
        self.test = dart_files(repo, "test")
        self.parent = {}
        self.parts = set()
        for path in self.lib:
            src = read(os.path.join(repo, path))
            if PART_OF.search(src):
                self.parts.add(path)
            for m in PART.finditer(src):
                child = os.path.normpath(
                    os.path.join(os.path.dirname(path), m.group(2))
                )
                self.parent[child] = path
        self.imports = {
            path: self._imports_of(path)
            for path in self.lib + self.test
            if path not in self.parts
        }
        self.tests = [p for p in self.test if p.endswith("_test.dart")]
        self.helpers = [p for p in self.test if not p.endswith("_test.dart")]

    def _imports_of(self, path):
        found = set()
        prefix = f"package:{self.package}/"
        for m in IMPORT.finditer(read(os.path.join(self.repo, path))):
            uri = m.group(2)
            if uri.startswith(prefix):
                found.add(os.path.normpath("lib/" + uri[len(prefix) :]))
            elif not uri.startswith(("dart:", "package:")):
                found.add(os.path.normpath(os.path.join(os.path.dirname(path), uri)))
        return found

    def library_of(self, path):
        """The file that holds [path]'s library: its parent for a `part of`."""
        path = os.path.normpath(path)
        return self.parent.get(path, path)

    def importers_of(self, libs, among):
        return {p for p in among if p in self.imports and self.imports[p] & libs}

    def helper_closure(self, libs):
        """Helpers that import [libs], or another such helper, at any depth."""
        reached = self.importers_of(libs, self.helpers)
        while True:
            more = self.importers_of(reached, self.helpers) - reached
            if not more:
                return reached
            reached |= more

    def reaching(self, mutated_files):
        """Every test file that reaches a library edited in [mutated_files]."""
        libs = {self.library_of(f) for f in mutated_files}
        found = self.importers_of(libs, self.tests)
        hop = self.importers_of(libs, self.lib) - libs
        found |= self.importers_of(hop, self.tests)
        found |= self.importers_of(self.helper_closure(libs), self.tests)
        found |= {p for p in self.tests if p.startswith("test/workflows/")}
        return found


def list_paths(repo, names):
    folder = os.path.join(repo, "tool", "mutants")
    if names:
        return [os.path.join(folder, n + ".json") for n in names]
    return sorted(glob.glob(os.path.join(folder, "*.json")))


def missing_for(tree, spec):
    wanted = tree.reaching({m["file"] for m in spec["mutants"]})
    return sorted(wanted - set(spec["tests"]))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("subjects", nargs="*", help="list names; default: all")
    ap.add_argument(
        "--repo", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    ap.add_argument(
        "--apply", action="store_true", help="add the missing files to `tests`"
    )
    args = ap.parse_args(argv)
    tree = Tree(args.repo)
    bad = False
    for path in list_paths(args.repo, args.subjects):
        with open(path, encoding="utf-8") as fh:
            spec = json.load(fh)
        missing = missing_for(tree, spec)
        print(f"{spec['subject']}: {len(missing)} missing")
        for name in missing:
            print(f"    {name}")
        if missing:
            bad = True
            if args.apply:
                spec["tests"] = sorted(set(spec["tests"]) | set(missing))
                if "quick_tests" in spec:
                    spec["quick_tests"] = sorted(spec["quick_tests"])
                with open(path, "w", encoding="utf-8") as fh:
                    json.dump(spec, fh, indent=2, ensure_ascii=False)
                    fh.write("\n")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

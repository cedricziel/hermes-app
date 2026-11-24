"""Tests for scripts/mutant_importers.py: a tiny repo with one file of each kind."""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import mutant_importers as mi  # noqa: E402

FILES = {
    "pubspec.yaml": "name: demo_app\n",
    # The mutated library: a part file inside a parent library.
    "lib/core/engine.dart": "part 'engine_part.dart';\nvoid run() {}\n",
    "lib/core/engine_part.dart": "part of 'engine.dart';\nvoid step() {}\n",
    # One hop through lib/: imports the mutated library, double quotes.
    "lib/shell/listener.dart": 'import "../core/engine.dart";\n',
    # Unrelated library.
    "lib/other/thing.dart": "void thing() {}\n",
    # Direct importer of the mutated library through the package URI.
    "test/direct_test.dart": "import 'package:demo_app/core/engine.dart';\n",
    # Reaches it through the one-hop library, relative path, double quotes.
    "test/hop_test.dart": 'import "../lib/shell/listener.dart";\n',
    # Helper chain: base imports the library, mid imports base, top imports mid.
    "test/support/base.dart": "import 'package:demo_app/core/engine.dart' show run;\n",
    "test/support/mid.dart": "import 'base.dart';\n",
    "test/support/top.dart": "export 'mid.dart';\n",
    "test/chain_test.dart": "import 'support/top.dart';\n",
    # A helper that reaches nothing, and the test that uses it.
    "test/support/unrelated.dart": "import 'package:demo_app/other/thing.dart';\n",
    "test/unrelated_test.dart": "import 'support/unrelated.dart';\n",
    # Workflows are always included.
    "test/workflows/flow_workflow_test.dart": "void main() {}\n",
    "tool/mutants/demo.json": json.dumps(
        {
            "subject": "demo",
            "tests": [],
            "mutants": [
                {
                    "id": "d01",
                    "file": "lib/core/engine_part.dart",
                    "old": "step",
                    "new": "step2",
                    "note": "x",
                }
            ],
        }
    ),
}

EXPECTED = [
    "test/chain_test.dart",
    "test/direct_test.dart",
    "test/hop_test.dart",
    "test/workflows/flow_workflow_test.dart",
]


def make_repo(files=None):
    root = tempfile.mkdtemp(prefix="mutant-importers-")
    for rel, text in (files or FILES).items():
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
    return root


def load_spec(root):
    with open(os.path.join(root, "tool/mutants/demo.json"), encoding="utf-8") as fh:
        return json.load(fh)


def run(root, *extra):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = mi.main(["--repo", root, *extra])
    return code, out.getvalue()


class ImporterScanTest(unittest.TestCase):
    def test_finds_every_kind_of_importer(self):
        root = make_repo()
        tree = mi.Tree(root)
        spec = load_spec(root)
        self.assertEqual(mi.missing_for(tree, spec), EXPECTED)

    def test_helper_chain_is_followed_transitively(self):
        # chain_test.dart imports top.dart, which re-exports mid.dart, which
        # imports base.dart, which imports the mutated library. Cutting the
        # closure to one level must lose it.
        root = make_repo()
        tree = mi.Tree(root)
        closure = tree.helper_closure({"lib/core/engine.dart"})
        self.assertEqual(
            closure,
            {
                "test/support/base.dart",
                "test/support/mid.dart",
                "test/support/top.dart",
            },
        )
        found = tree.reaching({"lib/core/engine_part.dart"})
        self.assertIn("test/chain_test.dart", found)

    def test_unrelated_test_and_helper_stay_out(self):
        root = make_repo()
        found = mi.Tree(root).reaching({"lib/core/engine_part.dart"})
        self.assertNotIn("test/unrelated_test.dart", found)

    def test_reports_missing_and_exits_nonzero(self):
        root = make_repo()
        code, out = run(root)
        self.assertEqual(code, 1)
        self.assertIn("demo: 4 missing", out)
        for name in EXPECTED:
            self.assertIn(name, out)

    def test_exits_zero_when_nothing_is_missing(self):
        files = dict(FILES)
        spec = json.loads(files["tool/mutants/demo.json"])
        spec["tests"] = EXPECTED
        files["tool/mutants/demo.json"] = json.dumps(spec)
        code, out = run(make_repo(files))
        self.assertEqual(code, 0)
        self.assertIn("demo: 0 missing", out)

    def test_apply_adds_the_files_sorted(self):
        root = make_repo()
        run(root, "--apply")
        spec = load_spec(root)
        self.assertEqual(spec["tests"], EXPECTED)
        code, _ = run(root)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

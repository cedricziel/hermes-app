import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
MERGE = os.path.join(HERE, "merge_test_reports.py")
SUMMARIZE = os.path.join(HERE, "summarize_test_failures.py")

# Stands in for `flutter`: records its arguments, writes the coverage file and
# the report a real run would, and fails in the part named by FAIL_PART.
FLUTTER = r"""#!/usr/bin/env bash
echo "$*" >> "$CALLS"
part=""; report=""; prev=""
for arg in "$@"; do
  [ "$prev" = --shard-index ] && part=$arg
  [ "$prev" = --file-reporter ] && report=${arg#json:}
  prev=$arg
done
for arg in "$@"; do
  if [ "$arg" = --coverage ]; then
    mkdir -p coverage
    printf 'SF:lib/a.dart\nDA:%s,1\nend_of_record\n' "$((part + 1))" > coverage/lcov.info
  fi
done
if [ -n "$report" ]; then
  mkdir -p "$(dirname "$report")"
  {
    echo '{"type":"testStart","test":{"id":1,"name":"case of part '"$part"'","suiteID":0,"url":"file:///repo/test/widgetbook_test.dart","line":1}}'
    [ "$part" = "${FAIL_PART:-none}" ] && echo '{"type":"error","testID":1,"error":"boom in part '"$part"'"}'
  } > "$report"
fi
[ "$part" = "${FAIL_PART:-none}" ] && exit 1
[ -n "${EXIT_WITH:-}" ] && exit "$EXIT_WITH"
exit 0
"""


class TestShardTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        root = self.dir.name
        os.makedirs(os.path.join(root, "scripts"))
        os.makedirs(os.path.join(root, "test"))
        os.makedirs(os.path.join(root, "bin"))
        for name in ("test-shard.sh", "merge_test_reports.py"):
            shutil.copy(os.path.join(HERE, name), os.path.join(root, "scripts", name))
        for name in ("widgetbook_test.dart", "a_test.dart", "b_test.dart"):
            open(os.path.join(root, "test", name), "w").close()
        flutter = os.path.join(root, "bin", "flutter")
        with open(flutter, "w") as f:
            f.write(FLUTTER)
        os.chmod(flutter, os.stat(flutter).st_mode | stat.S_IXUSR)
        self.calls = os.path.join(root, "calls.txt")

    def shard(self, *args, **env):
        root = self.dir.name
        return subprocess.run(
            ["bash", os.path.join(root, "scripts", "test-shard.sh"), *args],
            capture_output=True,
            text=True,
            env=dict(
                os.environ,
                PATH=os.path.join(root, "bin") + os.pathsep + os.environ["PATH"],
                CALLS=self.calls,
                **env,
            ),
        )

    def read(self, *path):
        with open(os.path.join(self.dir.name, *path)) as f:
            return f.read()

    def test_the_catalog_runs_in_one_process_per_part(self):
        proc = self.shard("0", "4", CATALOG_PARTS="3")

        self.assertEqual(proc.returncode, 0, proc.stderr)
        calls = self.read("calls.txt").splitlines()
        self.assertEqual(
            calls,
            [
                "test --total-shards 3 --shard-index %d test/widgetbook_test.dart" % i
                for i in range(3)
            ],
        )

    def test_every_part_adds_to_the_coverage_file(self):
        proc = self.shard("0", "4", "--coverage", CATALOG_PARTS="3")

        self.assertEqual(proc.returncode, 0, proc.stderr)
        lcov = self.read("coverage", "lcov.info")
        self.assertEqual(
            [line for line in lcov.splitlines() if line.startswith("DA:")],
            ["DA:1,1", "DA:2,1", "DA:3,1"],
        )

    def test_a_failing_part_fails_the_shard_after_the_rest_ran(self):
        report = os.path.join("build", "test-report.json")
        proc = self.shard(
            "0",
            "4",
            "--file-reporter",
            "json:" + report,
            CATALOG_PARTS="3",
            FAIL_PART="1",
        )

        self.assertEqual(proc.returncode, 1)
        self.assertEqual(len(self.read("calls.txt").splitlines()), 3)
        # The merged report names the failure after its own part's test,
        # though every part numbered its test 1.
        summary = subprocess.run(
            [sys.executable, "-I", SUMMARIZE, os.path.join(self.dir.name, report)],
            capture_output=True,
            text=True,
            env={k: v for k, v in os.environ.items() if k != "GITHUB_STEP_SUMMARY"},
        ).stdout
        self.assertIn("case of part 1", summary)
        self.assertIn("boom in part 1", summary)
        self.assertNotIn("case of part 2\n  boom", summary)

    def test_a_part_count_that_is_not_a_positive_number_fails_before_any_test(self):
        for parts in ("0", "-1", "abc", "1.5", "06"):
            with self.subTest(parts=parts):
                proc = self.shard("0", "4", CATALOG_PARTS=parts)

                self.assertEqual(proc.returncode, 64)
                self.assertIn("CATALOG_PARTS", proc.stderr)
                self.assertFalse(os.path.exists(self.calls))

    def test_a_run_narrowed_by_name_is_one_process(self):
        for flag in (("--name", "^Handoff "), ("--plain-name=Handoff",)):
            with self.subTest(flag=flag):
                if os.path.exists(self.calls):
                    os.remove(self.calls)
                proc = self.shard("0", "4", *flag)

                self.assertEqual(proc.returncode, 0, proc.stderr)
                self.assertEqual(
                    self.read("calls.txt").splitlines(),
                    ["test %s test/widgetbook_test.dart" % " ".join(flag)],
                )

    def test_a_run_narrowed_by_name_keeps_the_exit_code(self):
        # What `flutter test` does when the name matches no test.
        proc = self.shard("0", "4", "--plain-name", "no such case", EXIT_WITH="79")

        self.assertEqual(proc.returncode, 79)
        self.assertEqual(len(self.read("calls.txt").splitlines()), 1)

    def test_coverage_options_the_parts_cannot_carry_over_are_refused(self):
        for flags in (
            ("--coverage", "--coverage-path", "out/lcov.info"),
            ("--coverage", "--coverage-path=out/lcov.info"),
            ("--coverage", "--branch-coverage"),
            ("--coverage", "--merge-coverage"),
        ):
            with self.subTest(flags=flags):
                proc = self.shard("0", "4", *flags)

                self.assertEqual(proc.returncode, 64)
                self.assertIn("not supported with the catalog parts", proc.stderr)
                self.assertFalse(os.path.exists(self.calls))

    def test_the_other_shards_run_once_without_the_catalog(self):
        proc = self.shard("1", "3")

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self.read("calls.txt").splitlines(), ["test test/a_test.dart"])


class MergeReportsTest(unittest.TestCase):
    def test_ids_of_each_part_get_a_range_of_their_own(self):
        with tempfile.TemporaryDirectory() as tmp:
            parts = []
            for index in range(2):
                path = os.path.join(tmp, "part%d.json" % index)
                with open(path, "w") as f:
                    f.write(
                        json.dumps(
                            {
                                "type": "testStart",
                                "test": {"id": 5, "suiteID": 0, "groupIDs": [2]},
                            }
                        )
                        + "\n"
                    )
                    f.write("not json\n")
                    f.write(
                        json.dumps(
                            {"type": "testDone", "testID": 5, "result": "success"}
                        )
                        + "\n"
                    )
                parts.append(path)
            out = os.path.join(tmp, "merged.json")
            proc = subprocess.run(
                [
                    sys.executable,
                    "-I",
                    MERGE,
                    out,
                    *parts,
                    os.path.join(tmp, "missing.json"),
                ]
            )
            self.assertEqual(proc.returncode, 0)
            with open(out) as f:
                events = [json.loads(line) for line in f]

        self.assertEqual(
            [e["test"]["id"] for e in events if e["type"] == "testStart"],
            [5, 10_000_005],
        )
        self.assertEqual(
            [e["testID"] for e in events if e["type"] == "testDone"], [5, 10_000_005]
        )
        self.assertEqual(events[2]["test"]["groupIDs"], [10_000_002])
        self.assertEqual(events[2]["test"]["suiteID"], 10_000_000)


if __name__ == "__main__":
    unittest.main()

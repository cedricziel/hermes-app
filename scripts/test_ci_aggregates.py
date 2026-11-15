"""Proves that the aggregate jobs of ci.yml fail closed.

The owner may make `Analyze & test` the only required test context, dropping
the individual shards (they never report on a docs-only pull request). Then
every outcome of the jobs it needs must end in a red aggregate unless it is the
expected one. This test runs the real `run:` scripts of the job, in order,
under `bash -e`, with the environment built from the job's own `env:`
expressions, so an edit to ci.yml is tested, not a copy of it.

PyYAML is imported without a fallback: a missing module fails the test.
"""

import functools
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
DEFERRED_MESSAGE = (
    "Tests deferred: add the ci:full label when the PR is ready (fleet rules). "
    "Nothing merges until the tests ran on this head."
)
# GitHub reports a job that hit its timeout-minutes as `failure`, so the
# failure cases below also cover a timeout.
NOT_SUCCESS = ("failure", "cancelled", "skipped", "")


@functools.lru_cache(maxsize=None)
def load_jobs():
    return yaml.safe_load(WORKFLOW.read_text())["jobs"]


_EXPRESSION = re.compile(r"^\$\{\{\s*(.+?)\s*\}\}$")


def resolve(expression, ctx):
    """Resolves one `${{ ... }}` env value from the test's context."""
    match = _EXPRESSION.match(str(expression).strip())
    if not match:
        return str(expression)
    path = match.group(1)
    parts = path.split(".")
    if parts[0] == "needs" and parts[2] == "result":
        return ctx["needs_results"].get(parts[1], "")
    if parts[0] == "needs" and parts[2] == "outputs":
        return ctx["needs_outputs"].get(parts[1], {}).get(parts[3], "")
    if parts[0] == "steps" and parts[2] == "outputs":
        return ctx["step_outputs"].get(parts[1], {}).get(parts[3], "")
    github = {
        "github.event_name": ctx["event_name"],
        "github.base_ref": ctx["base_ref"],
        "github.head_ref": ctx["head_ref"],
        "github.token": "token",
        "github.repository": "o/r",
        "github.event.pull_request.number": "1",
    }
    if path in github:
        return github[path]
    raise AssertionError(f"test cannot resolve ${{{{ {path} }}}}; extend resolve()")


def run_job(job_id, ctx, gh_labels=("ci:full",), gh_fails=False, cache=None):
    """Runs every `run:` step of a job. Returns (job_ok, stdout, summary)."""
    job = load_jobs()[job_id]
    if cache is not None:
        signature = (
            "job",
            job_id,
            ctx["event_name"],
            gh_fails,
            tuple(gh_labels),
            tuple(
                resolve(value, dict(ctx, step_outputs={}))
                for step in job["steps"]
                for value in (step.get("env") or {}).values()
            ),
        )
        if signature in cache:
            return cache[signature]
    work = pathlib.Path(tempfile.mkdtemp())
    try:
        stub = work / "bin"
        stub.mkdir()
        body = (
            "exit 1"
            if gh_fails
            else "".join(f"echo {json.dumps(name)}\n" for name in gh_labels)
        )
        (stub / "gh").write_text("#!/usr/bin/env bash\n" + body + "\n")
        (stub / "gh").chmod(0o755)
        output_file = work / "output"
        summary_file = work / "summary"
        output_file.touch()
        summary_file.touch()
        ctx = dict(ctx, step_outputs={})
        log = []
        job_ok = True
        for index, step in enumerate(job["steps"]):
            if "run" not in step:
                continue
            # The simulation reuses a step's outputs when its inputs (event
            # and label lookup) are the same; the step itself ran once for real.
            cache_key = (job_id, step.get("id"), ctx["event_name"], gh_fails, tuple(gh_labels))
            if cache is not None and step.get("id") and cache_key in cache:
                ctx["step_outputs"][step["id"]] = cache[cache_key]
                continue
            env = dict(
                os.environ,
                PATH=f"{stub}{os.pathsep}{os.environ['PATH']}",
                GITHUB_OUTPUT=str(output_file),
                GITHUB_STEP_SUMMARY=str(summary_file),
            )
            for key, value in (step.get("env") or {}).items():
                env[key] = resolve(value, ctx)
            script = work / f"step{index}.sh"
            script.write_text(step["run"])
            output_file.write_text("")
            result = subprocess.run(
                ["bash", "-e", str(script)],
                env=env,
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            log.append(result.stdout)
            if step.get("id"):
                outputs = {}
                for line in output_file.read_text().splitlines():
                    if "=" in line:
                        key, value = line.split("=", 1)
                        outputs[key] = value
                ctx["step_outputs"][step["id"]] = outputs
                if cache is not None:
                    cache[cache_key] = outputs
            if result.returncode != 0 and not step.get("continue-on-error"):
                job_ok = False
        outcome = (job_ok, "".join(log), summary_file.read_text())
        if cache is not None:
            cache[signature] = outcome
        return outcome
    finally:
        shutil.rmtree(work, ignore_errors=True)


def aggregate(
    *,
    changes="success",
    analyze="success",
    test="success",
    test_watch="skipped",
    code="true",
    watch="false",
    full="true",
    event="pull_request",
    base="main",
    head="claude/feature",
    labels=("ci:full",),
    gh_fails=False,
):
    ctx = {
        "needs_results": {
            "changes": changes,
            "analyze": analyze,
            "test": test,
            "test-watch": test_watch,
        },
        "needs_outputs": {
            "changes": {"code": code, "watch": watch, "full": full, "builds": "true"}
        },
        "event_name": event,
        "base_ref": base,
        "head_ref": head,
    }
    return run_job("analyze-and-test", ctx, gh_labels=labels, gh_fails=gh_fails)


class AggregateStructure(unittest.TestCase):
    def test_if_is_exactly_always_a_skipped_job_reports_success(self):
        # A job skipped by its `if:` reports success to required checks, so
        # `!cancelled()` would let a cancelled current-head run satisfy
        # `Analyze & test`, and `success()` would skip it after any failed
        # need. Only `always()` keeps the aggregate running and red.
        job = load_jobs()['analyze-and-test']
        self.assertEqual(str(job['if']).strip(), 'always()')

    def test_needs_every_job_it_judges(self):
        job = load_jobs()["analyze-and-test"]
        self.assertEqual(
            set(job["needs"]), {"changes", "analyze", "test", "test-watch"}
        )

    def test_baseline_passes(self):
        ok, out, _ = aggregate()
        self.assertTrue(ok, out)


class TestResult(unittest.TestCase):
    def test_only_success_passes_when_tests_are_needed(self):
        for result in ("success",) + NOT_SUCCESS:
            with self.subTest(test=result):
                ok, out, _ = aggregate(test=result)
                self.assertEqual(ok, result == "success", out)

    def test_empty_or_odd_need_outputs_fail(self):
        # An empty `code` or `watch` must not read as "not needed".
        for kwargs in (
            dict(code="", test="skipped"),
            dict(code="yes", test="skipped"),
            dict(watch="", test_watch="skipped"),
            dict(watch="1", test_watch="skipped"),
        ):
            with self.subTest(**kwargs):
                ok, out, _ = aggregate(**kwargs)
                self.assertFalse(ok, out)

    def test_success_when_not_needed_fails(self):
        # Tests ran although `Changes` said docs-only: something is off.
        ok, out, _ = aggregate(code="false", full="true", test="success")
        self.assertFalse(ok, out)

    def test_not_success_when_not_needed_fails_unless_skipped(self):
        for result in ("success", "failure", "cancelled", "skipped", ""):
            with self.subTest(test=result):
                ok, out, _ = aggregate(code="false", test=result)
                self.assertEqual(ok, result == "skipped", out)


class EveryNeedCancelled(unittest.TestCase):
    def test_cancelled_run_is_red(self):
        for code in ('true', 'false'):
            with self.subTest(code=code):
                ok, out, _ = aggregate(
                    changes='cancelled',
                    analyze='cancelled',
                    test='cancelled',
                    test_watch='cancelled',
                    code=code,
                    full='true',
                )
                self.assertFalse(ok, out)

    def test_cancelled_run_with_empty_outputs_is_red(self):
        ok, out, _ = aggregate(
            changes='cancelled',
            analyze='cancelled',
            test='cancelled',
            test_watch='cancelled',
            code='',
            watch='',
            full='',
        )
        self.assertFalse(ok, out)


class AnalyzeAndChanges(unittest.TestCase):
    def test_analyze_not_success_fails(self):
        for result in NOT_SUCCESS:
            with self.subTest(analyze=result):
                ok, out, _ = aggregate(analyze=result)
                self.assertFalse(ok, out)

    def test_changes_not_success_fails(self):
        for result in NOT_SUCCESS:
            with self.subTest(changes=result):
                ok, out, _ = aggregate(changes=result)
                self.assertFalse(ok, out)

    def test_changes_failed_fails_even_when_docs_only_outputs_are_empty(self):
        ok, out, _ = aggregate(
            changes="failure", code="", watch="", full="", test="skipped"
        )
        self.assertFalse(ok, out)


class WatchResult(unittest.TestCase):
    def test_only_success_passes_when_watch_is_needed(self):
        for result in ("success",) + NOT_SUCCESS:
            with self.subTest(test_watch=result):
                ok, out, _ = aggregate(watch="true", test_watch=result)
                self.assertEqual(ok, result == "success", out)

    def test_not_needed_passes_only_when_skipped(self):
        for result in ("success", "failure", "cancelled", "skipped", ""):
            with self.subTest(test_watch=result):
                ok, out, _ = aggregate(watch="false", test_watch=result)
                self.assertEqual(ok, result == "skipped", out)


class LabelGate(unittest.TestCase):
    def test_deferred_code_pull_request_fails_with_the_message(self):
        ok, out, summary = aggregate(full="false", test="skipped", labels=("bot",))
        self.assertFalse(ok)
        self.assertIn(f"::error::{DEFERRED_MESSAGE}", out)
        self.assertIn(DEFERRED_MESSAGE, summary)

    def test_deferred_docs_only_passes(self):
        ok, out, _ = aggregate(code="false", full="false", test="skipped", labels=())
        self.assertTrue(ok, out)

    def test_full_with_passing_tests_passes(self):
        ok, out, _ = aggregate(labels=("ci:full",))
        self.assertTrue(ok, out)

    def test_full_with_failing_tests_fails(self):
        ok, out, _ = aggregate(test="failure", labels=("ci:full",))
        self.assertFalse(ok, out)

    def test_stale_full_with_label_removed_since_fails(self):
        ok, out, _ = aggregate(full="true", labels=("bot",))
        self.assertFalse(ok)
        self.assertIn(DEFERRED_MESSAGE, out)

    def test_label_added_after_a_deferred_run_does_not_make_it_pass(self):
        # Changes was deferred, so its tests were skipped.
        ok, out, _ = aggregate(full="false", test="skipped", labels=("ci:full",))
        self.assertFalse(ok, out)

    def test_failed_lookup_on_a_full_run_gives_the_real_results(self):
        ok, out, _ = aggregate(gh_fails=True)
        self.assertTrue(ok, out)
        ok, out, _ = aggregate(gh_fails=True, test="failure")
        self.assertFalse(ok, out)

    def test_failed_lookup_does_not_rescue_a_deferred_run(self):
        ok, out, _ = aggregate(gh_fails=True, full="false", test="skipped")
        self.assertFalse(ok, out)

    def test_push_is_full_without_a_lookup(self):
        ok, out, _ = aggregate(event="push", base="", labels=(), gh_fails=True)
        self.assertTrue(ok, out)
        ok, out, _ = aggregate(
            event="push", base="", labels=(), gh_fails=True, test="cancelled"
        )
        self.assertFalse(ok, out)


def logical_lines(script):
    """Joins backslash continuations, so a comment may end a command."""
    return re.sub(r'\\\n', ' ', script).splitlines()


def process_substitutions():
    hits = []
    for path in sorted((ROOT / '.github' / 'workflows').glob('*.yml')):
        data = yaml.safe_load(path.read_text())
        for job_id, job in (data.get('jobs') or {}).items():
            for step in job.get('steps') or []:
                for line in logical_lines(step.get('run') or ''):
                    if re.search(r'[<>]\(', line) and (
                        '# process-substitution-ok:' not in line
                    ):
                        hits.append(f'{path.name} {job_id}: {line.strip()[:120]}')
    return hits


class ProcessSubstitution(unittest.TestCase):
    def test_no_unmarked_process_substitution_in_workflow_scripts(self):
        # `set -o pipefail` does not cover <(...) or >(...): a failing command
        # inside exits 0 for the shell (shard 0 once passed without its files).
        # Mark a reviewed one with `# process-substitution-ok: <reason>` on
        # the same command.
        self.assertEqual(process_substitutions(), [])

    def test_scanner_finds_an_unmarked_one(self):
        self.assertTrue(
            re.search(r'[<>]\(', 'diff <(a) <(b)')
            and '# process-substitution-ok:' not in 'diff <(a) <(b)'
        )
        joined = logical_lines('diff -q \\\n  <(a) \\\n  <(b); then # process-substitution-ok: x')
        self.assertEqual(len(joined), 1)
        self.assertIn('# process-substitution-ok:', joined[0])


class BuildsAggregate(unittest.TestCase):
    """The `builds` aggregate comes with the builds-gate pull request. While
    the job is absent this class skips; once it exists the matrix below runs
    against its real scripts."""

    def setUp(self):
        self.job = load_jobs().get("builds")
        if self.job is None:
            self.skipTest(
                "builds aggregate job absent from ci.yml (arrives with #1140)"
            )

    def ctx(self, **overrides):
        needs = {name: "success" for name in self.job["needs"]}
        needs.update(overrides)
        return {
            "needs_results": needs,
            "needs_outputs": {
                "changes": {
                    "code": "true",
                    "watch": "false",
                    "full": "true",
                    "builds": "true",
                }
            },
            "event_name": "pull_request",
            "base_ref": "main",
            "head_ref": "claude/feature",
        }

    def test_always_runs(self):
        self.assertEqual(str(self.job["if"]).strip(), "always()")

    def test_all_needs_success_passes(self):
        ok, out, _ = run_job("builds", self.ctx())
        self.assertTrue(ok, out)

    def test_any_need_failing_cancelled_or_empty_fails(self):
        for name in self.job["needs"]:
            for result in ("failure", "cancelled", ""):
                with self.subTest(need=name, result=result):
                    ok, out, _ = run_job("builds", self.ctx(**{name: result}))
                    self.assertFalse(ok, out)


# ---------------------------------------------------------------------------
# Needs-graph simulation
# ---------------------------------------------------------------------------

_TOKEN = re.compile(
    r"\s*(?:(?P<op>&&|\|\||==|!=|!|\(|\)|,)"
    r"|'(?P<str>(?:[^']|'')*)'"
    r"|(?P<name>[A-Za-z_][\w.\-]*)(?P<call>\(\))?)"
)
_STATUS_FUNCTIONS = ("always", "success", "cancelled", "failure")


class UnsupportedExpression(AssertionError):
    pass


def _tokens(expression):
    pos, out = 0, []
    text = expression.strip()
    while pos < len(text):
        match = _TOKEN.match(text, pos)
        if not match or match.end() == pos:
            raise UnsupportedExpression(
                f"cannot parse {expression!r} at {text[pos : pos + 20]!r}"
            )
        pos = match.end()
        if match.group("op"):
            out.append(("op", match.group("op")))
        elif match.group("str") is not None:
            out.append(("str", match.group("str").replace("''", "'")))
        else:
            out.append(("call" if match.group("call") else "name", match.group("name")))
    return out


def _truthy(value):
    return bool(value) if isinstance(value, bool) else value not in ("", None, "0")


class Expression:
    """The subset of GitHub's expression syntax the `if:` conditions use.
    Anything else raises, so a new construct cannot slip past the simulation."""

    def __init__(self, source, needs, results, outputs, event_name):
        match = _EXPRESSION.match(str(source).strip())
        self.source = match.group(1) if match else str(source)
        self.needs = needs
        self.results = results
        self.outputs = outputs
        self.event_name = event_name
        self.tokens = _tokens(self.source)
        self.pos = 0
        self.has_status = any(
            kind == "call" and name in _STATUS_FUNCTIONS for kind, name in self.tokens
        )

    def fail(self, why):
        raise UnsupportedExpression(f"{why} in {self.source!r}")

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def take(self):
        token = self.peek()
        self.pos += 1
        return token

    def evaluate(self):
        value = self.parse_or()
        if self.pos != len(self.tokens):
            self.fail(f"unexpected {self.peek()[1]!r}")
        value = _truthy(value)
        if not self.has_status:  # GitHub wraps it in success() &&
            value = value and self.status("success")
        return value

    def parse_or(self):
        value = self.parse_and()
        while self.peek() == ("op", "||"):
            self.take()
            right = self.parse_and()
            value = value if _truthy(value) else right
        return value

    def parse_and(self):
        value = self.parse_unary()
        while self.peek() == ("op", "&&"):
            self.take()
            right = self.parse_unary()
            value = right if _truthy(value) else value
        return value

    def parse_unary(self):
        if self.peek() == ("op", "!"):
            self.take()
            return not _truthy(self.parse_unary())
        left = self.parse_atom()
        if self.peek() in (("op", "=="), ("op", "!=")):
            op = self.take()[1]
            right = self.parse_atom()
            if isinstance(left, bool) or isinstance(right, bool):
                self.fail("comparison with a boolean")
            equal = str(left).lower() == str(right).lower()
            return equal if op == "==" else not equal
        return left

    def parse_atom(self):
        kind, value = self.take()
        if kind == "op" and value == "(":
            inner = self.parse_or()
            if self.take() != ("op", ")"):
                self.fail("missing )")
            return inner
        if kind == "str":
            return value
        if kind == "call":
            return self.status(value)
        if kind == "name":
            return self.context(value)
        self.fail(f"unexpected {value!r}")

    def status(self, name):
        results = [self.results[n] for n in self.needs]
        if name == "always":
            return True
        if name == "success":
            return all(r == "success" for r in results)
        if name == "failure":
            return any(r == "failure" for r in results)
        if name == "cancelled":
            return False  # the simulated workflow run is not cancelled
        self.fail(f"unsupported function {name}()")

    def context(self, path):
        parts = path.split(".")
        if parts[0] == "needs" and len(parts) == 3 and parts[2] == "result":
            return self.results[parts[1]]
        if parts[0] == "needs" and len(parts) == 4 and parts[2] == "outputs":
            return self.outputs.get(parts[1], {}).get(parts[3], "")
        if path == "github.event_name":
            return self.event_name
        self.fail(f"unsupported context {path}")


# The policy mirrors CLAUDE.md's CI paragraph: a need may be skipped only when
# its outputs say it is not wanted, never because an output is empty, and
# never under the label gate on a code pull request that is not full.
def skip_allowed(need, outputs):
    if need in ("test", "coverage", "native-audio-test"):
        return outputs["code"] == "false"
    if need == "test-watch":
        return outputs["watch"] == "false"
    if need.startswith("build-"):
        return outputs["code"] == "false" or outputs["builds"] == "false"
    return False


VALUES = ("true", "false", "")
FRESH = {
    "ci:full": dict(gh_labels=("ci:full",), gh_fails=False),
    "none": dict(gh_labels=("bot",), gh_fails=False),
    "fail": dict(gh_labels=(), gh_fails=True),
}


def aggregate_jobs():
    jobs = load_jobs()
    return [name for name in ("analyze-and-test", "builds") if name in jobs]


class NeedsGraphSimulation(unittest.TestCase):
    def simulate(self, event, outputs, fresh, cache):
        """Evaluates every job's `if:` in dependency order, then runs the real
        aggregate scripts with those results."""
        jobs = load_jobs()
        results = {}

        def result_of(name):
            if name in results:
                return results[name]
            job = jobs[name]
            needs = job.get("needs") or []
            if isinstance(needs, str):
                needs = [needs]
            for need in needs:
                result_of(need)
            if name in aggregate_jobs():
                ctx = {
                    "needs_results": {n: results[n] for n in needs},
                    "needs_outputs": {"changes": outputs},
                    "event_name": event,
                    "base_ref": "main" if event == "pull_request" else "",
                    "head_ref": "claude/feature",
                }
                ok, _, _ = run_job(name, ctx, cache=cache, **FRESH[fresh])
                results[name] = "success" if ok else "failure"
                self.checked.append(
                    (name, event, dict(outputs), fresh, ok, ctx["needs_results"])
                )
                return results[name]
            if "if" in job:
                runs = Expression(
                    job["if"], needs, results, {"changes": outputs}, event
                ).evaluate()
            else:
                runs = all(results[n] == "success" for n in needs)
            results[name] = "success" if runs else "skipped"
            return results[name]

        for name in aggregate_jobs():
            result_of(name)

    def test_every_combination_of_changes_outputs(self):
        self.checked = []
        cache = {}
        combos = 0
        for event in ("pull_request", "push"):
            freshes = tuple(FRESH) if event == "pull_request" else ("ci:full",)
            for code in VALUES:
                for watch in VALUES:
                    for builds in VALUES:
                        for full in VALUES:
                            for fresh in freshes:
                                combos += 1
                                outputs = dict(
                                    code=code, watch=watch, builds=builds, full=full
                                )
                                self.simulate(event, outputs, fresh, cache)
        holes = []
        skips = 0
        for name, event, outputs, fresh, ok, needs in self.checked:
            label = f"{name} event={event} outputs={outputs} fresh={fresh}"
            deferred = event == "pull_request" and (
                outputs["full"] == "false" or fresh == "none"
            )
            wanted = outputs["code"] == "true" and (
                name == "analyze-and-test" or outputs["builds"] == "true"
            )
            if deferred and wanted and ok:
                holes.append(f"passes while deferred: {label}")
            if ok:
                for need, result in needs.items():
                    if result == "skipped":
                        skips += 1
                        if not skip_allowed(need, outputs):
                            holes.append(f"passes with {need} skipped: {label}")
                    elif result != "success":
                        holes.append(f"passes with {need}={result}: {label}")
            # The converse: a gate that fails everything is not safe either.
            if (
                name == "analyze-and-test"
                and outputs["code"] == "true"
                and outputs["full"] == "true"
                and outputs["watch"] in ("true", "false")
                and (event == "push" or fresh != "none")
                and not ok
            ):
                holes.append(f"fails although the run is full: {label}")
            if (
                name == "analyze-and-test"
                and outputs["code"] == "false"
                and outputs["watch"] == "false"
                and not ok
            ):
                holes.append(f"fails although the PR is docs-only: {label}")
        print(
            f"\nneeds-graph simulation: {combos} combinations, "
            f"{len(self.checked)} aggregate runs, {skips} passing skips checked, "
            f"{len(holes)} hits"
        )
        self.assertEqual(holes, [])

    def test_full_code_pull_request_with_all_needs_green_passes(self):
        ok, out, _ = aggregate(test="success", watch="true", test_watch="success")
        self.assertTrue(ok, out)

    def test_expression_evaluator_rejects_unknown_syntax(self):
        for source in (
            'contains(needs.x.result, "a")',
            "github.ref == 'x'",
            "needs.a.outputs.b == 1 +",
        ):
            with self.subTest(source=source):
                with self.assertRaises(UnsupportedExpression):
                    Expression(source, [], {}, {}, "push").evaluate()

    def test_expression_evaluator_semantics(self):
        outputs = {"changes": {"code": "true", "full": ""}}
        results = {"changes": "success", "a": "skipped"}
        cases = {
            "needs.changes.outputs.code == 'true' && needs.changes.outputs.full == 'true'": False,
            "needs.changes.outputs.code == 'true' && needs.changes.outputs.full != 'true'": True,
            "!cancelled() && needs.a.result == 'skipped'": True,
            "always()": True,
            "needs.a.result == 'skipped'": True,
            "(github.event_name == 'push' || needs.changes.outputs.code == 'true') && always()": True,
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                value = Expression(
                    source, ["changes"], results, outputs, "pull_request"
                ).evaluate()
                self.assertEqual(value, expected)
        # Without a status function GitHub adds success(): a skipped need
        # skips the job.
        self.assertFalse(
            Expression(
                "needs.a.result == 'skipped'", ["a"], results, outputs, "push"
            ).evaluate()
        )
if __name__ == "__main__":
    unittest.main()

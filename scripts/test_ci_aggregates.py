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
from unittest import mock

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
def load_workflow():
    return yaml.safe_load(WORKFLOW.read_text())


def load_jobs():
    return load_workflow()["jobs"]


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
    """Runs the steps of a job the way GitHub does. Returns (job_ok, stdout,
    summary). A step runs when its `if:` (with the implicit success()) is true,
    or, without an `if:`, while no earlier step failed. The job concludes
    failure only when a step failed without `continue-on-error`; a skipped step
    counts as success."""
    job = load_jobs()[job_id]
    if cache is not None:
        signature = (
            "job",
            job_id,
            ctx["event_name"],
            gh_fails,
            tuple(gh_labels),
            json.dumps(
                [ctx["needs_results"], ctx["needs_outputs"]], sort_keys=True
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
        step_state = {}
        log = []
        failed = False
        for index, step in enumerate(job["steps"]):
            if "if" in step:
                wanted = step_expression(step["if"], ctx, step_state, failed).evaluate()
            else:
                wanted = not failed
            outcome = "skipped"
            outputs = {}
            if wanted and "run" in step:
                # The simulation reuses a step's result when its inputs (event
                # and label lookup) are the same; it ran once for real.
                resolved_env = {
                    key: resolve(value, ctx)
                    for key, value in (step.get("env") or {}).items()
                }
                cache_key = (
                    job_id,
                    index,
                    ctx["event_name"],
                    gh_fails,
                    tuple(gh_labels),
                    tuple(sorted(resolved_env.items())),
                )
                if cache is not None and step.get("id") and cache_key in cache:
                    outputs, returncode = cache[cache_key]
                else:
                    env = dict(
                        os.environ,
                        PATH=f"{stub}{os.pathsep}{os.environ['PATH']}",
                        GITHUB_OUTPUT=str(output_file),
                        GITHUB_STEP_SUMMARY=str(summary_file),
                    )
                    env.update(resolved_env)
                    script = work / f"step{index}.sh"
                    script.write_text(step["run"])
                    output_file.write_text("")
                    result = subprocess.run(
                        # GitHub's default shell: bash --noprofile --norc
                        # -eo pipefail {0}
                        [
                            "bash",
                            "--noprofile",
                            "--norc",
                            "-eo",
                            "pipefail",
                            str(script),
                        ],
                        env=env,
                        cwd=ROOT,
                        capture_output=True,
                        text=True,
                    )
                    log.append(result.stdout)
                    returncode = result.returncode
                    for line in output_file.read_text().splitlines():
                        if "=" in line:
                            key, value = line.split("=", 1)
                            outputs[key] = value
                    if cache is not None and step.get("id"):
                        cache[cache_key] = (outputs, returncode)
                outcome = "success" if returncode == 0 else "failure"
            elif wanted:
                outcome = "success"  # a `uses:` step: nothing to execute
            conclusion = (
                "success"
                if outcome == "failure" and step.get("continue-on-error")
                else outcome
            )
            if outcome == "failure" and not step.get("continue-on-error"):
                failed = True
            if step.get("id"):
                ctx["step_outputs"][step["id"]] = outputs
                step_state[step["id"]] = {"outcome": outcome, "conclusion": conclusion}
        outcome = (not failed, "".join(log), summary_file.read_text())
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


def commands(script):
    """Splits a script into logical commands as (code, comment) pairs. The
    quote state runs across lines, so a newline inside quotes stays inside the
    command and a `#` inside quotes is no comment. A backslash-newline joins
    lines. A comment is a `#` at a word start outside quotes, up to the
    newline."""
    result = []
    code, comment, quote = [], None, None
    index = 0
    while index < len(script):
        char = script[index]
        if comment is not None:
            if char == "\n":
                result.append(("".join(code), "".join(comment)))
                code, comment = [], None
            else:
                comment.append(char)
        elif char == "\\" and quote != "'" and index + 1 < len(script):
            code.append(" " if script[index + 1] == "\n" else char + script[index + 1])
            index += 1
        elif quote:
            code.append(char)
            if char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
            code.append(char)
        elif char == "#" and (not code or code[-1].isspace()):
            comment = ["#"]
        elif char == "\n":
            result.append(("".join(code), ""))
            code = []
        else:
            code.append(char)
        index += 1
    result.append(("".join(code), "".join(comment or [])))
    return result


MARKER = re.compile(r"^#\s*process-substitution-ok:\s*\S")


def unmarked_substitutions(script):
    hits = []
    for code, comment in commands(script):
        if re.search(r"[<>]\(", code) and not MARKER.match(comment):
            hits.append(code.strip()[:120])
    return hits


def process_substitutions():
    hits = []
    for path in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        data = yaml.safe_load(path.read_text())
        for job_id, job in (data.get("jobs") or {}).items():
            for step in job.get("steps") or []:
                for line in unmarked_substitutions(step.get("run") or ""):
                    hits.append(f"{path.name} {job_id}: {line}")
    return hits


class ProcessSubstitution(unittest.TestCase):
    def test_no_unmarked_process_substitution_in_workflow_scripts(self):
        # `set -o pipefail` does not cover <(...) or >(...): a failing command
        # inside exits 0 for the shell (shard 0 once passed without its files).
        # Mark a reviewed one with a trailing shell comment
        # `# process-substitution-ok: <reason>` on the same command.
        # scripts/*.sh is out of scope here.
        self.assertEqual(process_substitutions(), [])

    def test_trailing_comment_marks_a_reviewed_one(self):
        script = "diff -q \\\n  <(a) \\\n  <(b); then # process-substitution-ok: x"
        self.assertEqual(unmarked_substitutions(script), [])

    def test_marker_inside_quotes_does_not_count(self):
        script = 'echo "# process-substitution-ok: x"; diff <(a) <(b)'
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_quote_state_runs_across_lines(self):
        script = 'echo "open\n# process-substitution-ok: fake" <(x)'
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_marker_must_carry_a_reason(self):
        self.assertEqual(
            len(unmarked_substitutions("diff <(a) <(b) # process-substitution-ok:")), 1
        )

    def test_substitution_inside_the_comment_is_no_code(self):
        self.assertEqual(unmarked_substitutions("echo hi # not <(real)"), [])

    def test_output_substitution_is_found(self):
        self.assertEqual(len(unmarked_substitutions("tee >(cat)")), 1)


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


# Step conditions are modelled; these are the aggregate jobs' own steps. A
# step-level `if:` on an aggregate would let GitHub skip the check and report
# success. Allowlist: (job, step name) -> reason. Keep it empty if possible.
STEP_IF_ALLOWLIST = {}


# `shell:` and `working-directory:` change how the scripts run (a `shell: bash
# {0}` drops pipefail), and `defaults.run` does the same for every step. The
# tests run GitHub's default shell, so none may apply to an aggregate job.
# Allowlist: (job, step name, key) -> reason. Keep it empty if possible.
STEP_SHELL_ALLOWLIST = {}


class StepSemantics(unittest.TestCase):
    def test_aggregate_steps_use_the_default_shell_and_directory(self):
        for job_id in aggregate_jobs():
            for step in load_jobs()[job_id]["steps"]:
                for key in ("shell", "working-directory"):
                    if key in step:
                        entry = (job_id, step.get("name") or step.get("uses"), key)
                        self.assertIn(
                            entry,
                            STEP_SHELL_ALLOWLIST,
                            f"{entry} sets {key}: {step[key]!r}; the tests run "
                            "the default shell in the repository root",
                        )

    def test_no_defaults_run_in_the_workflow_or_an_aggregate_job(self):
        workflow = load_workflow()
        self.assertNotIn("defaults", workflow)
        for job_id in aggregate_jobs():
            self.assertNotIn("defaults", workflow["jobs"][job_id], job_id)

    def test_no_aggregate_step_carries_an_if_unless_allowlisted(self):
        for job_id in aggregate_jobs():
            for step in load_jobs()[job_id]["steps"]:
                if "if" in step:
                    key = (job_id, step.get("name") or step.get("uses"))
                    self.assertIn(
                        key,
                        STEP_IF_ALLOWLIST,
                        f"{key} has if: {step['if']!r}; a skipped step reports "
                        "success to the required check",
                    )

    def run_with_steps(self, steps, ctx_overrides=None):
        """Runs a synthetic job through the real run_job semantics."""
        jobs = dict(load_jobs())
        jobs["synthetic"] = {"steps": steps}
        ctx = {
            "needs_results": {},
            "needs_outputs": {},
            "event_name": "push",
            "base_ref": "",
            "head_ref": "",
        }
        with mock.patch(f"{__name__}.load_jobs", lambda: jobs):
            return run_job("synthetic", ctx)

    def test_scripts_run_with_pipefail_like_the_default_shell(self):
        ok, out, _ = self.run_with_steps([{"run": "false | cat\necho after"}])
        self.assertFalse(ok)
        self.assertNotIn("after", out)

    def test_step_cache_is_keyed_on_the_step_inputs(self):
        steps = [
            {
                "id": "a",
                "env": {"V": "${{ needs.changes.outputs.v }}"},
                "run": 'echo "x=$V" >> "$GITHUB_OUTPUT"',
            },
            {"env": {"W": "${{ steps.a.outputs.x }}"}, "run": 'echo "w=$W"'},
        ]
        jobs = dict(load_jobs())
        jobs["synthetic"] = {"steps": steps}
        cache = {}
        logs = []
        with mock.patch(f"{__name__}.load_jobs", lambda: jobs):
            for value in ("1", "2"):
                ctx = {
                    "needs_results": {},
                    "needs_outputs": {"changes": {"v": value}},
                    "event_name": "push",
                    "base_ref": "",
                    "head_ref": "",
                }
                logs.append(run_job("synthetic", ctx, cache=cache)[1])
        self.assertIn("w=1", logs[0])
        self.assertIn("w=2", logs[1])

    def test_step_if_false_skips_the_step_and_the_job_succeeds(self):
        ok, _, _ = self.run_with_steps([{"if": "false", "run": "exit 1"}])
        self.assertTrue(ok)

    def test_failed_step_skips_later_steps_without_always(self):
        ok, out, _ = self.run_with_steps(
            [{"run": "exit 1"}, {"run": "echo later"}]
        )
        self.assertFalse(ok)
        self.assertNotIn("later", out)

    def test_always_and_failure_run_after_a_failed_step(self):
        for condition in ("always()", "failure()"):
            with self.subTest(condition=condition):
                ok, out, _ = self.run_with_steps(
                    [{"run": "exit 1"}, {"if": condition, "run": "echo later"}]
                )
                self.assertFalse(ok)
                self.assertIn("later", out)

    def test_continue_on_error_keeps_the_job_green(self):
        ok, out, _ = self.run_with_steps(
            [
                {"id": "a", "run": "exit 1", "continue-on-error": True},
                {"run": "echo later"},
            ]
        )
        self.assertTrue(ok)
        self.assertIn("later", out)

    def test_step_outcome_and_conclusion(self):
        ok, out, _ = self.run_with_steps(
            [
                {"id": "a", "run": "exit 1", "continue-on-error": True},
                {
                    "if": "steps.a.outcome == 'failure' && steps.a.conclusion == 'success'",
                    "run": "echo seen",
                },
            ]
        )
        self.assertTrue(ok)
        self.assertIn("seen", out)

    def test_step_if_reads_step_outputs(self):
        ok, out, _ = self.run_with_steps(
            [
                {"id": "a", "run": 'echo full=false >> "$GITHUB_OUTPUT"'},
                {"if": "steps.a.outputs.full != 'false'", "run": "echo ran"},
            ]
        )
        self.assertTrue(ok)
        self.assertNotIn("ran", out)

    def test_if_without_status_function_gets_implicit_success(self):
        ok, out, _ = self.run_with_steps(
            [{"run": "exit 1"}, {"if": "true", "run": "echo later"}]
        )
        self.assertFalse(ok)
        self.assertNotIn("later", out)


class TruthinessAndOutputs(unittest.TestCase):
    def test_only_empty_string_null_and_false_are_false(self):
        for value, expected in (
            ("", False),
            (None, False),
            (False, False),
            ("false", True),
            ("0", True),
            ("x", True),
            (True, True),
        ):
            with self.subTest(value=value):
                self.assertEqual(_truthy(value), expected)

    def test_a_false_string_stays_the_output(self):
        self.assertEqual(
            job_expression("'false' || 'true'", [], {}, {}, "push").value(), "false"
        )

    def changes_output(self, name, event, gate):
        expression = load_jobs()["changes"]["outputs"][name]
        return job_expression(
            expression,
            [],
            {},
            {},
            event,
            step_outputs={"gate": {"full": gate, "gate_reason": gate}},
        ).value()

    def test_changes_full_output_over_event_and_gate(self):
        for gate, expected in (("true", "true"), ("false", "false"), ("", "true")):
            with self.subTest(event="pull_request", gate=gate):
                self.assertEqual(
                    self.changes_output("full", "pull_request", gate), expected
                )
        for gate in ("true", "false", ""):
            with self.subTest(event="push", gate=gate):
                self.assertEqual(self.changes_output("full", "push", gate), "true")

    def test_changes_gate_reason_is_never_empty(self):
        for event in ("pull_request", "push"):
            for gate in ("why", ""):
                with self.subTest(event=event, gate=gate):
                    self.assertTrue(self.changes_output("gate_reason", event, gate))


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
    # GitHub: false, 0, null and the empty string are false; every other
    # string, 'false' and '0' included, is true.
    if isinstance(value, bool):
        return value
    return value not in ("", None)


class Expression:
    """The subset of GitHub's expression syntax the `if:` conditions and
    output expressions use. Anything else raises, so a new construct cannot
    slip past the simulation. `lookup(path)` resolves a context path and
    `status(name)` a status function."""

    def __init__(self, source, lookup, status):
        match = _EXPRESSION.match(str(source).strip())
        self.source = match.group(1) if match else str(source)
        self.lookup = lookup
        self.status = status
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

    def value(self):
        """The raw result (a string or a bool), as an output expression."""
        self.pos = 0
        value = self.parse_or()
        if self.pos != len(self.tokens):
            self.fail(f"unexpected {self.peek()[1]!r}")
        return value

    def evaluate(self):
        """An `if:` condition: truthiness, with GitHub's implicit success()."""
        value = _truthy(self.value())
        if not self.has_status:
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
            if value not in _STATUS_FUNCTIONS:
                self.fail(f"unsupported function {value}()")
            return self.status(value)
        if kind == "name" and value in ("true", "false"):
            return value == "true"
        if kind == "name":
            try:
                return self.lookup(value)
            except KeyError:
                self.fail(f"unsupported context {value}")
        self.fail(f"unexpected {value!r}")


def job_expression(source, needs, results, outputs, event_name, step_outputs=None):
    """An expression in a job's `if:` or `outputs:`."""

    def lookup(path):
        parts = path.split(".")
        if parts[0] == "needs" and len(parts) == 3 and parts[2] == "result":
            return results[parts[1]]
        if parts[0] == "needs" and len(parts) == 4 and parts[2] == "outputs":
            return outputs.get(parts[1], {}).get(parts[3], "")
        if parts[0] == "steps" and len(parts) == 4 and parts[2] == "outputs":
            return (step_outputs or {}).get(parts[1], {}).get(parts[3], "")
        if path == "github.event_name":
            return event_name
        raise KeyError(path)

    def status(name):
        values = [results[n] for n in needs]
        if name == "always":
            return True
        if name == "success":
            return all(r == "success" for r in values)
        if name == "failure":
            return any(r == "failure" for r in values)
        return False  # cancelled(): the simulated workflow run is not cancelled

    return Expression(source, lookup, status)


def step_expression(source, ctx, step_state, failed):
    """An expression in a step's `if:`: the steps context and the job status."""

    def lookup(path):
        parts = path.split(".")
        if parts[0] == "steps" and len(parts) == 4 and parts[2] == "outputs":
            return ctx["step_outputs"].get(parts[1], {}).get(parts[3], "")
        if parts[0] == "steps" and len(parts) == 3 and parts[2] in ("outcome", "conclusion"):
            return step_state[parts[1]][parts[2]]
        if parts[0] == "needs" and len(parts) == 3 and parts[2] == "result":
            return ctx["needs_results"].get(parts[1], "")
        if parts[0] == "needs" and len(parts) == 4 and parts[2] == "outputs":
            return ctx["needs_outputs"].get(parts[1], {}).get(parts[3], "")
        if path == "github.event_name":
            return ctx["event_name"]
        raise KeyError(path)

    def status(name):
        if name == "always":
            return True
        if name == "success":
            return not failed
        if name == "failure":
            return failed
        return False

    return Expression(source, lookup, status)


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
                runs = job_expression(
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
                    job_expression(source, [], {}, {}, "push").evaluate()

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
                value = job_expression(
                    source, ["changes"], results, outputs, "pull_request"
                ).evaluate()
                self.assertEqual(value, expected)
        # Without a status function GitHub adds success(): a skipped need
        # skips the job.
        self.assertFalse(
            job_expression(
                "needs.a.result == 'skipped'", ["a"], results, outputs, "push"
            ).evaluate()
        )
if __name__ == "__main__":
    unittest.main()

"""Proves that the aggregate jobs of ci.yml fail closed.

The owner may make `Analyze & test` the only required test context, dropping
the individual shards (they never report on a docs-only pull request). Then
every outcome of the jobs it needs must end in a red aggregate unless it is the
expected one. This test runs the real `run:` scripts of the job, in order,
under `bash -e`, with the environment built from the job's own `env:`
expressions, so an edit to ci.yml is tested, not a copy of it.

PyYAML is imported without a fallback: a missing module fails the test.
"""

import copy
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
        "github.event.pull_request.head.sha": ctx.get("head_sha", "head-a"),
        "github.run_id": "42",
        "github.event.pull_request.head.repo.full_name": ctx.get("head_repo", "o/r"),
    }
    if path in github:
        return github[path]
    raise AssertionError(f"test cannot resolve ${{{{ {path} }}}}; extend resolve()")


def run_job(
    job_id,
    ctx,
    gh_labels=("ci:full",),
    gh_fails=False,
    cache=None,
    pull=None,
    cancel="ok",
    extra_env=None,
):
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
            json.dumps([ctx.get("head_sha"), pull, cancel, extra_env], sort_keys=True),
        )
        if signature in cache:
            return cache[signature]
    work = pathlib.Path(tempfile.mkdtemp())
    try:
        stub = work / "bin"
        stub.mkdir()
        # A gh stub: the labels lookup, the pull request lookup and the run
        # cancel request. Every call is logged to $STUB_LOG.
        (stub / "gh").write_text(
            """#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
if [ -z "$GH_TOKEN" ]; then
  echo "gh: no GH_TOKEN" >&2
  exit 4
fi
case "$*" in
  *"/actions/runs/"*"/cancel"*)
    [ "$STUB_CANCEL" = ok ] || exit 1
    ;;
  *"/pulls/"*)
    [ "$STUB_PULL" != FAIL ] || exit 1
    printf '%s' "$STUB_PULL"
    ;;
  *"/labels"*)
    [ "$STUB_LABELS_FAIL" != 1 ] || exit 1
    printf '%s' "$STUB_LABELS"
    ;;
  *) exit 1 ;;
esac
"""
        )
        (stub / "gh").chmod(0o755)
        stub_log = work / "gh.log"
        stub_log.touch()
        if pull is None:
            pull = {"head": {"sha": ctx.get("head_sha", "head-a")}, "state": "open"}
        stub_env = {
            "STUB_LOG": str(stub_log),
            "STUB_CANCEL": cancel,
            "STUB_PULL": pull if isinstance(pull, str) else json.dumps(pull),
            "STUB_LABELS": "\n".join(gh_labels),
            "STUB_LABELS_FAIL": "1" if gh_fails else "0",
            # A regression in the superseded step fails fast; the YAML default
            # (60) has its own test.
            "SUPERSEDED_WAIT": "0",
            **(extra_env or {}),
        }
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
                        **stub_env,
                        GITHUB_OUTPUT=str(output_file),
                        GITHUB_STEP_SUMMARY=str(summary_file),
                    )
                    # A token only from the step's own env, never the runner's.
                    env.pop("GH_TOKEN", None)
                    env.pop("GITHUB_TOKEN", None)
                    env.update(resolved_env)
                    script = work / f"step{index}.sh"
                    script.write_text(step["run"])
                    output_file.write_text("")
                    result = subprocess.run(
                        # A step without `shell:` runs `bash -e {0}`, with no
                        # pipefail (only an explicit `shell: bash` adds it), so a
                        # script that needs it sets it itself.
                        ["bash", "-e", str(script)],
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
        for line in stub_log.read_text().splitlines():
            log.append(f"[{line}]\n")
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
    head_sha="head-a",
    pull=None,
    cancel="ok",
    extra_env=None,
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
    ctx["head_sha"] = head_sha
    return run_job(
        "analyze-and-test",
        ctx,
        gh_labels=labels,
        gh_fails=gh_fails,
        pull=pull,
        cancel=cancel,
        extra_env=extra_env,
    )


class AggregateStructure(unittest.TestCase):
    def test_the_linux_build_keeps_main_s_soloud_guard(self):
        jobs = load_jobs()
        names = [step.get("name", "") for step in jobs["build-linux"]["steps"]]
        self.assertTrue(any("flutter_soloud" in name for name in names), names)
        filter_script = next(
            step["run"]
            for step in jobs["changes"]["steps"]
            if step.get("id") == "filter"
        )
        self.assertIn("scripts/check-soloud-build-log.sh", filter_script)
        # The build is still gated like the other builds.
        self.assertIn("needs.changes.outputs.full == 'true'", jobs["build-linux"]["if"])

    def test_every_job_and_the_self_cancel_step_has_a_timeout(self):
        for job_id, job in load_jobs().items():
            self.assertIn("timeout-minutes", job, job_id)
        for job_id in aggregate_jobs():
            step = load_jobs()[job_id]["steps"][0]
            self.assertEqual(step["id"], "superseded", job_id)
            self.assertIn("timeout-minutes", step, job_id)

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
        self.assertIn(DEFERRED_MESSAGE, out)

    def test_failed_lookup_on_a_full_run_gives_the_real_results(self):
        ok, out, _ = aggregate(gh_fails=True)
        self.assertTrue(ok, out)
        ok, out, _ = aggregate(gh_fails=True, test="failure")
        self.assertFalse(ok, out)

    def test_failed_lookup_does_not_rescue_a_deferred_run(self):
        ok, out, _ = aggregate(gh_fails=True, full="false", test="skipped")
        self.assertFalse(ok, out)
        self.assertIn(DEFERRED_MESSAGE, out)

    def test_push_is_full_without_a_lookup(self):
        ok, out, _ = aggregate(event="push", base="", labels=(), gh_fails=True)
        self.assertTrue(ok, out)
        ok, out, _ = aggregate(
            event="push", base="", labels=(), gh_fails=True, test="cancelled"
        )
        self.assertFalse(ok, out)


_KEYWORDS = {"then", "do", "else", "elif", "fi", "done", "{", "}"}
def heredoc_word(script, start):
    """Reads the delimiter word of a heredoc at `start`, quotes and backslashes
    removed, as (word, end). None when the word cannot be read with certainty:
    empty, an unterminated quote, or an expansion (`$`, a backtick)."""
    word, index, length = [], start, len(script)
    while index < length:
        char = script[index]
        if char in " \t\n;&|<>()":
            break
        if char == "\\":
            if index + 1 >= length:
                return None
            word.append(script[index + 1])
            index += 2
        elif char in "$`":
            return None
        elif char == "'":
            end = script.find("'", index + 1)
            if end == -1:
                return None
            word.append(script[index + 1 : end])
            index = end + 1
        elif char == '"':
            index += 1
            while index < length and script[index] != '"':
                if script[index] in "$`":
                    return None
                if script[index] == "\\" and index + 1 < length:
                    index += 1
                word.append(script[index])
                index += 1
            if index >= length:
                return None
            index += 1
        else:
            word.append(char)
            index += 1
    return ("".join(word), index) if word else None


def commands(script):
    """Splits a script into (segment, has_substitution, comment) triples.

    A segment is one `;`-separated command at the top level; a lone reserved
    word (`then`, `do`, `else`, ...) belongs to the command before it, so
    `if diff <(a) <(b); then # marker` stays one command. The comment, a `#` at
    a word start outside quotes, belongs to the LAST segment of its line only.
    The quote state runs across lines and nests: `<(` or `>(` inside quotes is
    text, but inside `$(...)` within double quotes it is code again. A
    backslash-newline joins lines. Heredoc bodies (up to their delimiter)
    are text, `$'...'` is quoted text, and a comment inside `$(...)` ends at
    its line. A script that ends inside a quote, a substitution or a heredoc
    cannot be read reliably, so it counts as one unmarked substitution. So does a
    `<<` whose delimiter word cannot be read with certainty; `<<<` and a shift
    inside `((...))` or `$((...))` are not heredocs. Heredocs are recognised in
    every command context, and the delimiter word has its quotes and
    backslashes removed."""
    results = []
    stack = [["cmd", 0, False]]  # kind, paren depth, nested ($( or <( )
    segment, segments, hit = [], [], False
    heredocs = []  # (delimiter, tabs may indent it) waiting for their body
    unbalanced = False
    unreadable = False  # a `<<` that could not be read with certainty
    index, length = 0, len(script)

    def end_segment():
        nonlocal segment, hit
        segments.append(["".join(segment), hit])
        segment, hit = [], False

    def end_command(comment):
        merged = []
        for text, found in segments:
            if merged and text.strip() in _KEYWORDS:
                merged[-1][0] += ";" + text
                merged[-1][1] = merged[-1][1] or found
            else:
                merged.append([text, found])
        for position, (text, found) in enumerate(merged):
            if text.strip():
                last = position == len(merged) - 1
                results.append((text.strip(), found, comment if last else ""))
        segments.clear()

    while index < length:
        char = script[index]
        pair = script[index : index + 2]
        kind = stack[-1][0]
        if kind == "sq":
            segment.append(char)
            if char == "'":
                stack.pop()
        elif kind == "arith":
            # Nothing inside arithmetic is read: bash falls back to nested
            # subshells when it is not arithmetic, so a command substitution, a
            # backtick or a process substitution here makes the script
            # unreadable (flagged). A false positive on `a<(b)` is accepted.
            if pair in ("$(", "<(", ">(") or char == "`":
                unreadable = True
            segment.append(char)
            if char == "(":
                stack[-1][1] += 1
            elif char == ")":
                if stack[-1][1] > 0:
                    stack[-1][1] -= 1
                else:
                    if script[index + 1 : index + 2] == ")":
                        segment.append(")")
                        index += 1
                    stack.pop()
        elif kind == "ansi":
            if char == "\\" and index + 1 < length:
                segment.append(pair)
                index += 1
            else:
                segment.append(char)
                if char == "'":
                    stack.pop()
        elif kind == "dq":
            if char == "\\" and index + 1 < length:
                segment.append(pair)
                index += 1
            elif char == '"':
                segment.append(char)
                stack.pop()
            elif pair == "$(":
                segment.append(pair)
                stack.append(["cmd", 0, True])
                index += 1
            else:
                segment.append(char)
        else:  # a command context
            top_level = len(stack) == 1
            if char == "\\" and index + 1 < length:
                segment.append(" " if script[index + 1] == "\n" else pair)
                index += 1
            elif pair == "$'":
                segment.append(pair)
                stack.append(["ansi", 0, False])
                index += 1
            elif char == "'":
                segment.append(char)
                stack.append(["sq", 0, False])
            elif char == '"':
                segment.append(char)
                stack.append(["dq", 0, False])
            elif script[index : index + 3] == "$((" or pair == "((":
                width = 3 if char == "$" else 2
                segment.append(script[index : index + width])
                stack.append(["arith", 0, True])
                index += width - 1
            elif pair == "$(":
                segment.append(pair)
                stack.append(["cmd", 0, True])
                index += 1
            elif (
                pair == "<<"
                and script[index - 1 : index] != "<"
                and script[index + 2 : index + 3] != "<"
            ):
                position = index + 2
                dash = script[position : position + 1] == "-"
                position += 1 if dash else 0
                while script[position : position + 1] in (" ", "\t"):
                    position += 1
                word = heredoc_word(script, position)
                if word is None:
                    unreadable = True
                    segment.append(pair)
                    index += 1
                else:
                    heredocs.append((word[0], dash))
                    segment.append(script[index : word[1]])
                    index = word[1]
                    continue
            elif pair in ("<(", ">("):
                hit = True
                segment.append(pair)
                stack.append(["cmd", 0, True])
                index += 1
            elif char == "(":
                stack[-1][1] += 1
                segment.append(char)
            elif char == ")":
                if stack[-1][2] and stack[-1][1] == 0:
                    stack.pop()
                elif stack[-1][1] > 0:
                    stack[-1][1] -= 1
                segment.append(char)
            elif top_level and char == "#" and (not segment or segment[-1].isspace()):
                end = script.find("\n", index)
                end = length if end == -1 else end
                end_segment()
                end_command(script[index:end])
                index = end
                continue
            elif not top_level and char == "#" and (
                not segment or segment[-1].isspace()
            ):
                end = script.find("\n", index)
                index = length if end == -1 else end
                continue
            elif top_level and char == ";":
                end_segment()
            elif char == "\n":
                if top_level:
                    end_segment()
                    end_command("")
                else:
                    segment.append(char)
                if heredocs:
                    position = index + 1
                    for delimiter, tabs in heredocs:
                        while True:
                            if position >= length:
                                unbalanced = True
                                break
                            end = script.find("\n", position)
                            end = length if end == -1 else end
                            line = script[position:end].rstrip("\r")
                            position = min(end + 1, length)
                            if (line.lstrip("\t") if tabs else line) == delimiter:
                                break
                    heredocs.clear()
                    index = position
                    continue
            else:
                segment.append(char)
        index += 1
    end_segment()
    end_command("")
    if unbalanced or unreadable or heredocs or len(stack) > 1:
        results.append(
            (
                "<script ends inside a quote, substitution or heredoc, or has a `<<` "
                "that cannot be read>",
                True,
                "",
            )
        )
    return results


MARKER = re.compile(r"^#\s*process-substitution-ok:\s*\S")


def unmarked_substitutions(script):
    return [
        text[:120]
        for text, found, comment in commands(script)
        if found and not MARKER.match(comment)
    ]


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

    def test_substitution_inside_quoted_text_is_no_code(self):
        for script in (
            'echo "<(x)"',
            "echo '>(x)'",
            'echo "a <(x) b" # fine',
            "echo \\<(x)",
        ):
            with self.subTest(script=script):
                self.assertEqual(unmarked_substitutions(script), [])

    def test_substitution_inside_a_command_substitution_in_quotes_is_code(self):
        self.assertEqual(
            len(unmarked_substitutions('echo "$(diff <(a) <(b))"')), 1
        )

    def test_marker_binds_to_its_own_command(self):
        script = "diff <(a) <(b); echo ok # process-substitution-ok: x"
        self.assertEqual(len(unmarked_substitutions(script)), 1)
        script = "echo first; diff <(a) <(b) # process-substitution-ok: x"
        self.assertEqual(unmarked_substitutions(script), [])

    def test_two_substitution_commands_need_two_markers(self):
        script = "cat <(a); diff <(b) <(c) # process-substitution-ok: x"
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_marker_on_the_next_line_does_not_count(self):
        script = "diff <(a) <(b)\n# process-substitution-ok: x"
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_a_then_belongs_to_the_command_before_it(self):
        script = "if diff <(a) <(b); then # process-substitution-ok: x\n  echo ok\nfi"
        self.assertEqual(unmarked_substitutions(script), [])

    def test_heredoc_body_does_not_hide_a_later_substitution(self):
        script = "cat <<EOF\nit's\nEOF\ndiff <(a) <(b)"
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_heredoc_body_is_text(self):
        for script in (
            "cat <<EOF\n<(x) it's\nEOF",
            "cat <<'EOF'\n>(x)\nEOF",
            'cat <<"EOF"\n<(x)\nEOF',
            "cat <<-EOF\n\t<(x)\n\tEOF",
        ):
            with self.subTest(script=script):
                self.assertEqual(unmarked_substitutions(script), [])

    def test_a_heredoc_inside_a_command_substitution_is_recognised(self):
        # Read as plain text, the apostrophes would hide the diff between them
        # while the script still looks balanced.
        script = (
            "x=$(cat <<EOF\nit's\nEOF\n)\n"
            "diff <(a) <(b)\n"
            "y=$(cat <<EOF\nit's\nEOF\n)"
        )
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_heredoc_delimiter_words_are_unquoted(self):
        for word in ("\\EOF", "E'OF'", "'EOF'", '"EOF"', 'E"O"F', "EO\\F"):
            with self.subTest(word=word):
                # The last line is the word as written. A scanner that does not
                # unquote it takes that line as the delimiter, swallows the
                # diff, and still looks balanced.
                script = (
                    f"cat <<{word}\nit's <(x)\nEOF\ndiff <(a) <(b)\n{word}\n"
                )
                self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_a_heredoc_body_inside_a_command_substitution_is_text(self):
        script = "x=$(cat <<EOF\n<(x)\nEOF\n)\necho done"
        self.assertEqual(unmarked_substitutions(script), [])

    def test_a_shift_in_arithmetic_is_no_heredoc(self):
        for script in (
            "(( y << z ))\ndiff <(a) <(b)",
            "echo $(( 1 << 2 )); diff <(a) <(b)",
            "if (( y << z )); then\n  diff <(a) <(b)\nfi",
            "x=$(( (1 << 2) + (3 << 4) )); diff <(a) <(b)",
        ):
            with self.subTest(script=script):
                self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_a_substitution_inside_arithmetic_is_flagged(self):
        # bash falls back from arithmetic to nested subshells, so each of
        # these runs the diff. The scanner reads nothing inside `((`, so any
        # substitution there makes the script unreadable and flags it.
        for script in (
            "((diff <(a) <(b) && echo RAN); true)",
            "x=$((diff <(a) <(b)) )",
            "echo $(( $(diff <(a) <(b); echo 1) + 1 ))",
            "(( $(diff <(a) <(b) | wc -l) ))",
            "echo $(( `diff <(a) <(b)` + 1 ))",
            "(( >(cat) ))",
            "echo $(( $(echo 1) + 1 ))",
            "echo $(( `echo 1` + 1 ))",
        ):
            with self.subTest(script=script):
                self.assertTrue(unmarked_substitutions(script))

    def test_plain_arithmetic_is_not_flagged(self):
        for script in ("(( y << z ))", "echo $(( (1 + 2) * 3 ))", "(( i++ ))"):
            with self.subTest(script=script):
                self.assertEqual(unmarked_substitutions(script), [])

    def test_a_heredoc_marker_the_scanner_cannot_read_flags(self):
        for script in (
            "cat <<\nbody",
            "cat <<'EOF\nbody\nEOF",
            "cat <<$X\nbody\n$X",
            "cat <<`x`\nbody",
        ):
            with self.subTest(script=script):
                self.assertTrue(unmarked_substitutions(script))

    def test_a_tab_indented_delimiter_does_not_close_a_plain_heredoc(self):
        # Only <<- strips tabs. The <(x) is still body text here, and closes
        # at the real EOF; a scanner that closes early reads it as code.
        script = "cat <<EOF\n\tEOF\n<(x)\nEOF"
        self.assertEqual(unmarked_substitutions(script), [])

    def test_a_tab_indented_delimiter_closes_a_dash_heredoc(self):
        script = "cat <<-EOF\n\tEOF\n<(x)"
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_a_here_string_is_no_heredoc(self):
        # A line `x` follows, so reading `<<< "x"` as a heredoc would swallow
        # the diff line and still look balanced.
        script = 'cat <<< "x"\ndiff <(a) <(b)\nx'
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_ansi_c_quoting_does_not_hide_a_later_substitution(self):
        # The apostrophe in the trailing comment would close the quote that a
        # reader without $'...' support opens, hiding the diff while balanced.
        script = "echo $'a\\'b'; diff <(a) <(b) # it's"
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_ansi_c_quoted_text_is_text(self):
        self.assertEqual(unmarked_substitutions("echo $'<(x)'"), [])

    def test_a_comment_in_a_command_substitution_is_a_comment(self):
        # Without comment support the first apostrophe hides the diff until
        # the second one, and the script still looks balanced.
        script = (
            'echo "$(echo hi # it\'s\n)"\n'
            "diff <(a) <(b)\n"
            'echo "$(echo x # don\'t\n)"'
        )
        self.assertEqual(len(unmarked_substitutions(script)), 1)

    def test_an_unbalanced_script_fails_closed(self):
        for script in (
            "echo 'unterminated\ndiff <(a)",
            'echo "$(echo hi',
            "cat <<EOF\nnever closed",
            'echo "open',
        ):
            with self.subTest(script=script):
                self.assertTrue(unmarked_substitutions(script))

    def test_balanced_scripts_do_not_trip_the_unbalanced_check(self):
        self.assertEqual(
            unmarked_substitutions("echo 'a'\necho \"$(echo b)\"\ncat <<EOF\nx\nEOF"),
            [],
        )

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

    OUTPUTS = {"code": "true", "watch": "false", "full": "true", "builds": "true"}
    DEFERRED_ERROR = "::error::" + DEFERRED_MESSAGE

    def ctx(self, outputs=None, **overrides):
        needs = {name: "success" for name in self.job["needs"]}
        needs.update(overrides)
        return {
            "needs_results": needs,
            "needs_outputs": {"changes": dict(self.OUTPUTS, **(outputs or {}))},
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

    def skipped_builds(self, **overrides):
        return {
            name: "skipped"
            for name in self.job["needs"]
            if name.startswith("build-")
        } | overrides

    def test_deferred_run_that_wants_builds_fails_with_the_message(self):
        ok, out, summary = run_job(
            "builds",
            self.ctx(
                outputs={"full": "false"},
                **self.skipped_builds(**{"analyze-and-test": "failure"}),
            ),
        )
        self.assertFalse(ok)
        self.assertIn(self.DEFERRED_ERROR, out)
        self.assertIn(DEFERRED_MESSAGE, summary)

    def test_deferred_run_fails_even_if_analyze_and_test_looks_green(self):
        # Changes says deferred; a stale green aggregate must not pass it.
        ok, out, _ = run_job(
            "builds",
            self.ctx(outputs={"full": "false"}, **self.skipped_builds()),
        )
        self.assertFalse(ok)
        self.assertIn(self.DEFERRED_ERROR, out)

    def test_deferred_by_the_fresh_labels_fails_through_analyze_and_test(self):
        ok, out, _ = run_job(
            "builds",
            self.ctx(**self.skipped_builds(**{"analyze-and-test": "failure"})),
        )
        self.assertFalse(ok, out)

    def test_deferred_run_that_needs_no_builds_still_fails_on_analyze_and_test(self):
        ok, out, _ = run_job(
            "builds",
            self.ctx(
                outputs={"full": "false", "builds": "false"},
                **self.skipped_builds(**{"analyze-and-test": "failure"}),
            ),
        )
        self.assertFalse(ok, out)

    def test_docs_only_deferred_run_passes_with_the_builds_skipped(self):
        ok, out, _ = run_job(
            "builds",
            self.ctx(
                outputs={"code": "false", "builds": "false", "full": "false"},
                **self.skipped_builds(),
            ),
        )
        self.assertTrue(ok, out)

    def test_dart_only_full_run_passes_with_the_builds_skipped(self):
        ok, out, _ = run_job(
            "builds",
            self.ctx(outputs={"builds": "false"}, **self.skipped_builds()),
        )
        self.assertTrue(ok, out)

    def test_builds_skipped_when_wanted_fails(self):
        ok, out, _ = run_job("builds", self.ctx(**self.skipped_builds()))
        self.assertFalse(ok, out)

    def test_first_step_is_the_same_self_cancel_step_as_analyze_and_test(self):
        jobs = load_jobs()
        self.assertEqual(jobs["builds"]["steps"][0], jobs["analyze-and-test"]["steps"][0])
        self.assertEqual(jobs["builds"]["permissions"]["actions"], "write")

    def test_superseded_head_cancels_the_builds_run_too(self):
        ctx = self.ctx(**{name: "cancelled" for name in self.job["needs"]})
        ctx["head_sha"] = "head-a"
        ok, out, _ = run_job(
            "builds",
            ctx,
            pull={"head": {"sha": "head-b"}, "state": "open"},
        )
        self.assertFalse(ok, out)
        self.assertIn("/actions/runs/42/cancel", out)
        self.assertNotIn("(expected", out)


def superseding_step():
    return load_jobs()["analyze-and-test"]["steps"][0]


class SupersededHead(unittest.TestCase):
    """A run on a head a newer push replaced cancels itself instead of posting
    a red check on the old head. Every other case keeps the aggregate red when
    the needs were cancelled."""

    ALL_CANCELLED = dict(
        changes="cancelled", analyze="cancelled", test="cancelled", test_watch="cancelled"
    )
    NEW_HEAD = {"head": {"sha": "head-b"}, "state": "open"}

    def run_case(self, **kwargs):
        kwargs.setdefault("extra_env", {"SUPERSEDED_WAIT": "0"})
        return aggregate(**self.ALL_CANCELLED, **kwargs)

    def assert_red_as_today(self, ok, out):
        self.assertFalse(ok, out)
        self.assertNotIn("cancel", self.cancel_requests(out))
        self.assertIn("(expected", out, "the existing steps must have run")

    @staticmethod
    def cancel_requests(out):
        return "cancel" if "/actions/runs/42/cancel" in out else ""

    def test_the_step_is_first_and_has_no_if_or_continue_on_error(self):
        step = superseding_step()
        self.assertIn("superseded", step["name"].lower())
        self.assertNotIn("if", step)
        self.assertNotIn("continue-on-error", step)

    def test_the_job_may_cancel_its_own_run(self):
        permissions = load_jobs()["analyze-and-test"]["permissions"]
        self.assertEqual(permissions.get("actions"), "write")

    def test_superseded_open_pull_request_cancels_and_does_not_succeed(self):
        ok, out, _ = self.run_case(pull=self.NEW_HEAD)
        self.assertFalse(ok, out)
        self.assertIn("gh api -X POST repos/o/r/actions/runs/42/cancel", out)
        self.assertNotIn("(expected", out, "later steps must not run")

    def test_superseded_never_succeeds_even_when_every_need_passed(self):
        ok, out, _ = aggregate(pull=self.NEW_HEAD, extra_env={"SUPERSEDED_WAIT": "0"})
        self.assertFalse(ok, out)
        self.assertIn("/actions/runs/42/cancel", out)

    def test_current_head_with_cancelled_needs_stays_red(self):
        ok, out, _ = self.run_case()
        self.assert_red_as_today(ok, out)

    def test_closed_pull_request_on_the_same_head_stays_red(self):
        ok, out, _ = self.run_case(pull={"head": {"sha": "head-a"}, "state": "closed"})
        self.assert_red_as_today(ok, out)

    def test_merged_pull_request_on_the_same_head_stays_red(self):
        ok, out, _ = self.run_case(
            pull={"head": {"sha": "head-a"}, "state": "closed", "merged": True}
        )
        self.assert_red_as_today(ok, out)

    def test_superseded_but_closed_stays_red_without_a_cancel(self):
        for merged in (False, True):
            with self.subTest(merged=merged):
                ok, out, _ = self.run_case(
                    pull={"head": {"sha": "head-b"}, "state": "closed", "merged": merged}
                )
                self.assert_red_as_today(ok, out)

    def test_api_failure_or_odd_answers_stay_red_without_a_cancel(self):
        for pull in (
            "FAIL",
            "not json",
            "",
            "{}",
            '{"head": {}}',
            '{"head": {"sha": "head-b"}}',
            '{"state": "open"}',
            '{"head": {"sha": ""}, "state": "open"}',
            "[]",
            "null",
        ):
            with self.subTest(pull=pull):
                ok, out, _ = self.run_case(pull=pull)
                self.assert_red_as_today(ok, out)

    def test_denied_cancel_stays_red(self):
        ok, out, _ = self.run_case(pull=self.NEW_HEAD, cancel="deny")
        self.assertFalse(ok, out)
        self.assertIn("/actions/runs/42/cancel", out)

    def test_push_and_dispatch_skip_the_step_and_the_rest_is_unchanged(self):
        for event in ("push", "workflow_dispatch"):
            with self.subTest(event=event):
                ok, out, _ = aggregate(
                    event=event, base="", labels=(), pull=self.NEW_HEAD
                )
                self.assertTrue(ok, out)
                self.assertNotIn("/pulls/", out)
                self.assertNotIn("/actions/runs/", out)
                ok, out, _ = aggregate(
                    event=event,
                    base="",
                    labels=(),
                    pull=self.NEW_HEAD,
                    test="cancelled",
                )
                self.assertFalse(ok, out)
                self.assertNotIn("/pulls/", out)
                self.assertNotIn("/actions/runs/", out)

    def test_the_gate_script_runs_without_the_token(self):
        # ci_gate.py needs no token, and this job can cancel runs. The label
        # lookup by gh (before it) keeps GH_TOKEN.
        for job_id in ("changes", "analyze-and-test"):
            gate = [
                step
                for step in load_jobs()[job_id]["steps"]
                if step.get("id") == "gate"
            ][0]
            self.assertEqual(gate["env"]["GH_TOKEN"], "${{ github.token }}")
            script = gate["run"]
            self.assertIn("GH_TOKEN='' python3 -I scripts/ci_gate.py", script)
            self.assertEqual(script.count("python3 -I scripts/ci_gate.py"), 1)
            self.assertLess(
                script.index("gh api"), script.index("python3 -I scripts/ci_gate.py")
            )

    def test_without_a_token_the_step_fails_closed(self):
        # No GH_TOKEN: the pull request lookup fails, so nothing is cancelled
        # and the aggregate stays red on its cancelled needs, as today.
        jobs = copy.deepcopy(load_jobs())
        del jobs["analyze-and-test"]["steps"][0]["env"]["GH_TOKEN"]
        with mock.patch(f"{__name__}.load_jobs", lambda: jobs):
            ok, out, _ = self.run_case(pull=self.NEW_HEAD)
        self.assertFalse(ok, out)
        self.assertNotIn("/actions/runs/42/cancel", out)
        self.assertIn("(expected", out, "the existing steps must have run")

    def test_empty_head_sha_is_not_superseded(self):
        ok, out, _ = self.run_case(pull=self.NEW_HEAD, head_sha="")
        self.assert_red_as_today(ok, out)

    def test_the_wait_defaults_to_sixty_seconds(self):
        self.assertIn("${SUPERSEDED_WAIT:-60}", superseding_step()["run"])
        for env in superseding_step().get("env", {}):
            self.assertNotEqual(env, "SUPERSEDED_WAIT")

    def test_no_path_through_the_superseded_block_exits_zero(self):
        script = superseding_step()["run"]
        match = re.search(
            r'if \[ "\$superseded" = true \]; then\n(.*?)\nfi\n', script, re.S
        )
        self.assertIsNotNone(match, "the superseded block moved; update the test")
        block = match.group(1)
        self.assertNotIn("exit 0", block)
        self.assertEqual(block.strip().splitlines()[-1].strip(), "exit 1")
        # Nothing after the block runs on a superseded decision.
        self.assertNotIn("superseded=true", script[match.end():])


class ConcurrencySimulation(unittest.TestCase):
    """cancel-in-progress is evaluated for the run that ENTERS the group: it
    decides whether the run already in progress is cancelled."""

    def enters(self, event, action="", label="", attempt="1"):
        context = {
            "github.event_name": event,
            "github.event.action": action,
            "github.event.label.name": label,
            "github.run_attempt": attempt,
        }

        def lookup(path):
            if path not in context:
                raise KeyError(path)
            return context[path]

        source = load_workflow()["concurrency"]["cancel-in-progress"]
        return _truthy(Expression(source, lookup, lambda name: False).value())

    def test_the_group_is_per_pull_request(self):
        group = load_workflow()["concurrency"]["group"]
        self.assertIn("github.ref", group)

    def test_a_newer_push_cancels_the_run_in_progress(self):
        for action in ("opened", "synchronize", "reopened"):
            with self.subTest(action=action):
                self.assertTrue(self.enters("pull_request", action))

    def test_ci_full_label_events_on_the_current_head_cancel(self):
        for action in ("labeled", "unlabeled"):
            with self.subTest(action=action):
                self.assertTrue(
                    self.enters("pull_request", action, "ci:full")
                )

    def test_other_labels_never_cancel(self):
        for action in ("labeled", "unlabeled"):
            with self.subTest(action=action):
                self.assertFalse(self.enters("pull_request", action, "bot"))

    def test_a_rerun_of_an_older_run_never_cancels_the_current_one(self):
        # Same group (the pull request), but attempt 2: a re-run of a run on a
        # head that has since been replaced must not cancel the current head.
        for action, label in (
            ("synchronize", ""),
            ("labeled", "ci:full"),
            ("unlabeled", "ci:full"),
            ("opened", ""),
        ):
            with self.subTest(action=action, label=label):
                self.assertFalse(
                    self.enters("pull_request", action, label, attempt="2")
                )
                self.assertFalse(
                    self.enters("pull_request", action, label, attempt="3")
                )

    def test_push_and_dispatch_never_cancel(self):
        for event in ("push", "workflow_dispatch"):
            with self.subTest(event=event):
                self.assertFalse(self.enters(event))
                self.assertFalse(self.enters(event, attempt="2"))


# Step conditions are modelled; these are the aggregate jobs' own steps. A
# step-level `if:` on an aggregate would let GitHub skip the check and report
# success. Allowlist: (job, step name) -> reason. Keep it empty if possible.
STEP_IF_ALLOWLIST = {}


# `shell:` and `working-directory:` change how the scripts run (a `shell: bash
# {0}` would change the shell), and `defaults.run` does the same for every
# step. The tests run GitHub's default shell, so none may apply to an
# aggregate job.
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

    def test_the_default_shell_has_no_pipefail(self):
        ok, out, _ = self.run_with_steps([{"run": "false | cat\necho after"}])
        self.assertTrue(ok)
        self.assertIn("after", out)

    def test_a_script_can_set_pipefail_itself(self):
        ok, out, _ = self.run_with_steps(
            [{"run": "set -o pipefail\nfalse | cat\necho after"}]
        )
        self.assertFalse(ok)
        self.assertNotIn("after", out)

    def test_aggregate_scripts_with_a_pipeline_set_pipefail(self):
        for job_id in aggregate_jobs():
            for step in load_jobs()[job_id]["steps"]:
                script = step.get("run", "")
                # Case patterns (`a | b)`) and comments are no pipelines.
                lines = [
                    line
                    for line in script.splitlines()
                    if not line.lstrip().startswith("#")
                    and not re.search(r"\)\s*(;;)?\s*$", line)
                ]
                if re.search(r"(?<!\|)\|(?!\|)", "\n".join(lines)):
                    self.assertIn(
                        "pipefail",
                        script,
                        f"{job_id}: {step.get('name')} has a pipeline but no "
                        "pipefail, and the default shell is bash -e",
                    )

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


def expected_to_run(job, outputs, aggregate_passed):
    """The policy for every job of ci.yml, mirroring CLAUDE.md's CI paragraph:
    the heavy jobs run only on a full code run, the builds also only when the
    paths asked for them and Analyze & test passed. A job missing here fails
    the simulation, so a new job must get a row."""
    code = outputs["code"] == "true"
    full = outputs["full"] == "true"
    if job in ("changes", "analyze", "analyze-and-test", "builds"):
        return True
    if job in ("test", "coverage"):
        return code and full
    if job == "test-watch":
        return outputs["watch"] == "true" and full
    if job == "native-audio-test":
        return aggregate_passed and code and full
    if job.startswith("build-"):
        return aggregate_passed and code and full and outputs["builds"] == "true"
    raise AssertionError(f"no expectation for job {job!r}; add a row")


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

        for name in jobs:
            result_of(name)
        self.all_results.append((event, dict(outputs), fresh, dict(results)))

    def test_every_combination_of_changes_outputs(self):
        self.checked = []
        self.all_results = []
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
                name == "builds"
                and outputs["code"] == "true"
                and outputs["builds"] == "true"
                and outputs["full"] == "true"
                and outputs["watch"] in ("true", "false")
                and (event == "push" or fresh != "none")
                and not ok
            ):
                holes.append(f"Builds fails although the run is full: {label}")
            if (
                name == "builds"
                and outputs["code"] == "false"
                and outputs["watch"] == "false"
                and not ok
            ):
                holes.append(f"Builds fails although the PR is docs-only: {label}")
            if (
                name == "analyze-and-test"
                and outputs["code"] == "false"
                and outputs["watch"] == "false"
                and not ok
            ):
                holes.append(f"fails although the PR is docs-only: {label}")
        for event, outputs, fresh, results in self.all_results:
            aggregate_passed = results["analyze-and-test"] == "success"
            for job, result in results.items():
                if job in aggregate_jobs():
                    continue
                want = expected_to_run(job, outputs, aggregate_passed)
                ran = result == "success"
                if ran != want:
                    holes.append(
                        f"{job} {'ran' if ran else 'skipped'} but "
                        f"{'should run' if want else 'should skip'}: "
                        f"event={event} outputs={outputs} fresh={fresh}"
                    )
        jobs_covered = len(self.all_results[0][3]) if self.all_results else 0
        print(
            f"\nneeds-graph simulation: {combos} combinations, "
            f"{len(self.checked)} aggregate runs, {skips} passing skips checked, "
            f"{len(holes)} hits; every one of {jobs_covered} jobs checked"
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

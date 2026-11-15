"""Mutation sample: do the tests of a few key subjects fail for real defects?

Run it as `python3 -I scripts/mutation_sample.py ...` from anywhere; it needs
only Python 3 and `flutter` and `git` on PATH.

    scripts/mutation_sample.py --check                  validate every list
    scripts/mutation_sample.py server_address           one subject
    scripts/mutation_sample.py auth_controller --only au03,au17
    scripts/mutation_sample.py token_store --quick      the quick_tests subset
    scripts/mutation_sample.py --summary                print the saved results

A list is `tool/mutants/<subject>.json`:

    {"subject": str, "tests": [files], "quick_tests": [files] (optional),
     "mutants": [{"id", "file", "old", "new", "note"}]}

`old` must occur exactly once in `file`; `new` replaces it. A list that breaks
that is refused before any file is touched.

Per mutant the result is KILLED, SURVIVED, TIMEOUT or INVALID (the mutant did
not compile; it counts for nothing). A killed mutant carries the failing
tests, the first failure's kind (expect_mismatch, unexpected_request, timeout,
uncaught_exception, other), the files that killed it and, when one file did it
alone, `sole_killer`. A TIMEOUT counts as a kill, as a hang is a failure a
user sees. Results go to `.dart_tool/mutation-sample/<subject>.json` and are
resumed on a rerun at the same commit and mode.

The mutated files must be clean in git, and are restored after every run,
on an error and on Ctrl-C or SIGTERM.
"""

import argparse
import atexit
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.dirname(HERE)
LISTS = "tool/mutants"
RESULTS = ".dart_tool/mutation-sample"
KILLED, SURVIVED, TIMEOUT, INVALID = "KILLED", "SURVIVED", "TIMEOUT", "INVALID"


class MutationError(Exception):
    """A list or the tree is not fit to run."""


# Files currently holding a mutant: path -> original text. Whatever happens,
# the atexit hook and the `finally` blocks put them back.
_mutated = {}


def restore_all():
    for path, text in list(_mutated.items()):
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        del _mutated[path]


atexit.register(restore_all)


def _raise_interrupt(signum, frame):
    raise KeyboardInterrupt()


def classify_error(text):
    t = text or ""
    if re.search(
        r"unexpected request|No response (registered|configured)|Unhandled request|not (stubbed|registered)",
        t,
        re.I,
    ):
        return "unexpected_request"
    if re.search(r"TimeoutException|timed out|pumpAndSettle", t, re.I):
        return "timeout"
    if re.search(r"Expected:|Actual:|Which:", t):
        return "expect_mismatch"
    if re.search(
        r"Null check|NoSuchMethod|is not a subtype|StateError|Bad state|RangeError|Unhandled|Exception|Error",
        t,
    ):
        return "uncaught_exception"
    return "other"


def read_text(path):
    with open(path, encoding="utf-8", newline="") as fh:
        return fh.read()


def git(repo, *args):
    return subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True, check=False
    )


def load_spec(path):
    with open(path, encoding="utf-8") as fh:
        spec = json.load(fh)
    for key in ("subject", "tests", "mutants"):
        if key not in spec:
            raise MutationError(f"{path}: missing '{key}'")
    return spec


def validate(repo, spec):
    """Problems of a list against the tree, as strings; empty when it is fit."""
    problems, ids, cache = [], set(), {}
    for m in spec["mutants"]:
        mid = m.get("id", "?")
        if mid in ids:
            problems.append(f"{mid}: duplicate id")
        ids.add(mid)
        for key in ("id", "file", "old", "new"):
            if not isinstance(m.get(key), str) or (key != "new" and not m[key]):
                problems.append(f"{mid}: bad or missing '{key}'")
        if problems and problems[-1].startswith(f"{mid}: bad"):
            continue
        path = os.path.join(repo, m["file"])
        if m["file"] not in cache:
            cache[m["file"]] = read_text(path) if os.path.isfile(path) else None
        src = cache[m["file"]]
        if src is None:
            problems.append(f"{mid}: file {m['file']} does not exist")
            continue
        count = src.count(m["old"])
        if count != 1:
            problems.append(
                f"{mid}: 'old' occurs {count}x in {m['file']}, expected exactly once"
            )
        elif m["old"] == m["new"]:
            problems.append(f"{mid}: 'new' equals 'old'")
    quick = spec.get("quick_tests")
    if quick is not None and not set(quick) <= set(spec["tests"]):
        problems.append("quick_tests is not a subset of tests")
    for t in spec["tests"]:
        if not os.path.isfile(os.path.join(repo, t)):
            problems.append(f"test file {t} does not exist")
    return problems


def require_clean(repo, files):
    r = git(repo, "status", "--porcelain", "--", *sorted(files))
    if r.returncode != 0:
        raise MutationError("git status failed: " + r.stderr.strip())
    if r.stdout.strip():
        raise MutationError(
            "refusing to run: files to mutate have uncommitted changes:\n"
            + r.stdout.rstrip()
        )


def run_tests(repo, tests, timeout, concurrency=2):
    """Runs `flutter test` on [tests]; returns what the JSON report says."""
    fd, report = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    cmd = [
        "flutter",
        "test",
        f"--concurrency={concurrency}",
        "--file-reporter",
        f"json:{report}",
        *tests,
    ]
    t0 = time.time()
    proc = subprocess.Popen(
        cmd,
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    timed_out = False
    try:
        try:
            out, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGKILL)  # only this run's group
            out, _ = proc.communicate()
    finally:
        if proc.poll() is None:  # Ctrl-C or a crash: do not leave it running
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            proc.wait()
    secs = time.time() - t0
    suites, names, failures, load_fail, passed = {}, {}, [], False, 0
    try:
        with open(report, encoding="utf-8") as fh:
            for line in fh:
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                if "suite" in ev:
                    suites[ev["suite"]["id"]] = ev["suite"]["path"]
                elif ev.get("type") == "testStart":
                    names[ev["test"]["id"]] = (
                        ev["test"]["name"],
                        ev["test"].get("suiteID"),
                    )
                elif ev.get("type") == "error":
                    n, sid = names.get(ev["testID"], ("?", None))
                    failures.append(
                        {
                            "file": suites.get(sid, "?"),
                            "test": n,
                            "kind": classify_error(ev.get("error")),
                            "error": (ev.get("error") or "")[:300],
                        }
                    )
                    if n.startswith("loading "):
                        load_fail = True
                elif (
                    ev.get("type") == "testDone"
                    and ev.get("result") == "success"
                    and not ev.get("hidden")
                ):
                    passed += 1
    finally:
        os.unlink(report)
    compile_err = (
        load_fail
        or "Compilation failed" in out
        or bool(re.search(r"lib/\S+:\d+:\d+: Error:", out))
    )
    return {
        "secs": round(secs, 1),
        "timed_out": timed_out,
        "failures": failures,
        "passed": passed,
        "compile_error": compile_err,
        "exit_tail": out[-400:],
    }


def rel(path, repo):
    return os.path.relpath(path, repo) if os.path.isabs(path) else path


def classify_run(m, r, repo):
    """The result record of mutant [m] from a test run [r]."""
    rec = {"id": m["id"], "file": m["file"], "note": m.get("note", "")}
    rec["secs"] = r["secs"]
    if r["compile_error"]:
        rec.update(status=INVALID, reason="compile error")
    elif r["timed_out"] and not r["failures"]:
        rec.update(status=TIMEOUT)
    elif r["failures"]:
        files = sorted({rel(f["file"], repo) for f in r["failures"]})
        rec.update(
            status=KILLED,
            killer_files=files,
            sole_killer=files[0] if len(files) == 1 else None,
            first_failure=r["failures"][0],
            n_failing=len(r["failures"]),
            failing_tests=[
                f"{rel(f['file'], repo)} :: {f['test']}" for f in r["failures"][:8]
            ],
        )
    else:
        rec.update(status=SURVIVED)
    return rec


def save(result, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1)
    os.replace(tmp, path)


def head_sha(repo):
    return git(repo, "rev-parse", "HEAD").stdout.strip()


def run_subject(
    repo,
    spec,
    out_path,
    only=None,
    quick=False,
    fresh=False,
    baseline_only=False,
    concurrency=2,
    log=print,
    runner=run_tests,
):
    problems = validate(repo, spec)
    if problems:
        raise MutationError(
            f"{spec['subject']}: list is not fit:\n  " + "\n  ".join(problems)
        )
    tests = (
        spec.get("quick_tests") if quick and spec.get("quick_tests") else spec["tests"]
    )
    mode = "quick" if tests is not spec["tests"] else "full"
    mutants = [m for m in spec["mutants"] if not only or m["id"] in only]
    if only:
        unknown = only - {m["id"] for m in spec["mutants"]}
        if unknown:
            raise MutationError(f"unknown mutant ids: {', '.join(sorted(unknown))}")
    require_clean(repo, {m["file"] for m in mutants})
    sha = head_sha(repo)
    result = {
        "subject": spec["subject"],
        "commit": sha,
        "mode": mode,
        "tests": tests,
        "mutants": [],
    }
    if not fresh and os.path.exists(out_path):
        with open(out_path, encoding="utf-8") as fh:
            old = json.load(fh)
        if (
            old.get("subject"),
            old.get("commit"),
            old.get("mode"),
            old.get("tests"),
        ) == (result["subject"], sha, mode, tests):
            result = old
    if "baseline" not in result:
        b = runner(repo, tests, 3600, concurrency)
        if b["failures"] or b["timed_out"] or b["compile_error"]:
            raise MutationError(
                "baseline is not green, nothing mutated: " + json.dumps(b)[:800]
            )
        result["baseline"] = {"secs": b["secs"], "passed": b["passed"]}
        save(result, out_path)
    log(
        f"{spec['subject']}: baseline {result['baseline']} ({mode}, {len(tests)} files)"
    )
    if baseline_only:
        return result
    limit = max(120, 3 * result["baseline"]["secs"])
    done = {m["id"] for m in result["mutants"]}
    for m in mutants:
        if m["id"] in done:
            continue
        path = os.path.join(repo, m["file"])
        src = read_text(path)
        _mutated[path] = src
        try:
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(src.replace(m["old"], m["new"], 1))
            r = runner(repo, tests, limit, concurrency)
        finally:
            restore_all()
        rec = classify_run(m, r, repo)
        rec["line"] = src[: src.index(m["old"])].count("\n") + 1
        result["mutants"].append(rec)
        save(result, out_path)
        log(f"{m['id']} {rec['status']} {rec.get('killer_files', '')}")
    return result


def summarize(result):
    """Lines describing one subject's results: kill rate, survivors, killers."""
    ms = result["mutants"]
    counts = {}
    for m in ms:
        counts[m["status"]] = counts.get(m["status"], 0) + 1
    valid = len(ms) - counts.get(INVALID, 0)
    killed = counts.get(KILLED, 0) + counts.get(TIMEOUT, 0)
    rate = round(100 * killed / valid) if valid else 0
    lines = [
        f"== {result['subject']}: kill rate {rate}% ({killed}/{valid} valid), "
        + ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
        + f" [{result.get('mode', '?')}]"
    ]
    kinds, sole = {}, {}
    for m in ms:
        if m["status"] == KILLED:
            k = m["first_failure"]["kind"]
            kinds[k] = kinds.get(k, 0) + 1
            if m.get("sole_killer"):
                sole[m["sole_killer"]] = sole.get(m["sole_killer"], 0) + 1
    if kinds:
        lines.append(
            "   first failure: "
            + ", ".join(f"{k} {v}" for k, v in sorted(kinds.items()))
        )
    if sole:
        lines.append(
            "   sole killer: " + ", ".join(f"{k} {v}" for k, v in sorted(sole.items()))
        )
    for m in ms:
        if m["status"] in (SURVIVED, INVALID):
            extra = f" ({m['reason']})" if m.get("reason") else ""
            lines.append(
                f"   {m['status']} {m['id']} line {m.get('line', '?')}: {m['note']}{extra}"
            )
    return lines


def subject_names(repo):
    d = os.path.join(repo, LISTS)
    return sorted(f[:-5] for f in os.listdir(d) if f.endswith(".json"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("subjects", nargs="*", help="list names; default: all")
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument(
        "--out", help="results directory (default .dart_tool/mutation-sample)"
    )
    ap.add_argument("--only", help="comma separated mutant ids")
    ap.add_argument("--quick", action="store_true", help="run each list's quick_tests")
    ap.add_argument("--fresh", action="store_true", help="ignore saved results")
    ap.add_argument("--check", action="store_true", help="validate the lists and stop")
    ap.add_argument(
        "--summary", action="store_true", help="print saved results and stop"
    )
    ap.add_argument("--baseline-only", action="store_true")
    ap.add_argument("--concurrency", type=int, default=2)
    args = ap.parse_args(argv)
    repo = os.path.abspath(args.repo)
    out_dir = args.out or os.path.join(repo, RESULTS)
    names = args.subjects or subject_names(repo)
    only = set(args.only.split(",")) if args.only else None

    signal.signal(signal.SIGTERM, _raise_interrupt)
    try:
        specs = [load_spec(os.path.join(repo, LISTS, n + ".json")) for n in names]
        if args.summary:
            for s in specs:
                p = os.path.join(out_dir, s["subject"] + ".json")
                if os.path.exists(p):
                    print("\n".join(summarize(json.loads(read_text(p)))))
                else:
                    print(f"== {s['subject']}: no results")
            return 0
        if args.check:
            bad = 0
            for s in specs:
                problems = validate(repo, s)
                bad += len(problems)
                for p in problems:
                    print(f"{s['subject']}: {p}")
                print(
                    f"{s['subject']}: {len(s['mutants'])} mutants, "
                    f"{'ok' if not problems else 'NOT OK'}"
                )
            return 1 if bad else 0
        for s in specs:
            result = run_subject(
                repo,
                s,
                os.path.join(out_dir, s["subject"] + ".json"),
                only=only,
                quick=args.quick,
                fresh=args.fresh,
                baseline_only=args.baseline_only,
                concurrency=args.concurrency,
            )
            print("\n".join(summarize(result)))
        return 0
    except MutationError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("interrupted; files restored", file=sys.stderr)
        return 130
    finally:
        restore_all()


if __name__ == "__main__":
    sys.exit(main())

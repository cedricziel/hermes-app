"""Mutation sample: do the tests of a few key subjects fail for real defects?

Run it as `python3 -I scripts/mutation_sample.py ...` from anywhere; it needs
only Python 3 and `flutter` and `git` on PATH.

    scripts/mutation_sample.py --check                  validate every list
    scripts/mutation_sample.py server_address           one subject
    scripts/mutation_sample.py auth_controller --only au03,au17
    scripts/mutation_sample.py token_store --quick      the quick_tests subset
    scripts/mutation_sample.py --summary                print the saved results

Other flags: `--fresh` ignores saved results, `--baseline-only` runs only the
unmutated tests, `--concurrency N` is passed to `flutter test` (default 2),
`--out DIR` puts the results elsewhere, `--repo DIR` names another checkout.

A list is `tool/mutants/<subject>.json`:

    {"subject": str, "tests": [files], "quick_tests": [files] (optional),
     "mutants": [{"id", "file", "old", "new", "note"}]}

`old` must occur exactly once in `file`, and `file` must stay inside the repo;
`new` replaces it. A list that breaks that is refused before any file is
touched.

Per mutant the result is one of:

- KILLED: a test failed. It carries the failing tests, the first failure's
  kind (expect_mismatch, unexpected_request, timeout, uncaught_exception,
  other), the files that killed it and, when one file did it alone,
  `sole_killer`. A test file that threw while loading, without a compile
  error, is a kill too.
- SURVIVED: `flutter test` exited 0, ran at least 90% as many tests as the
  baseline, and nothing failed.
- TIMEOUT: the run hung past the limit. It counts as a kill.
- INVALID: the mutant does not compile. It counts for nothing.
- INCONCLUSIVE: no verdict can be drawn (a non-zero exit with no failing
  test, no test ran, or far fewer ran than in the baseline). It counts as
  neither killed nor survived; look at `reason` and run it again.

The baseline must exit 0 with at least one test passing. Results go to
`.dart_tool/mutation-sample/<subject>.json`. They are reused on a rerun at
the same commit, mode and test contents; `--only` always reruns the ids it
names and merges them into the saved results. A mutant whose list entry
changed is rerun.

The mutated files must be clean in git. Each one is copied to
`.dart_tool/mutation-sample/backup/<path>` before it is mutated, and restored
after every run, on an error, on Ctrl-C and on SIGTERM or SIGHUP.
"""

import argparse
import atexit
import hashlib
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
BACKUPS = RESULTS + "/backup"
KILLED, SURVIVED, TIMEOUT, INVALID, INCONCLUSIVE = (
    "KILLED",
    "SURVIVED",
    "TIMEOUT",
    "INVALID",
    "INCONCLUSIVE",
)
# A run that ran fewer tests than this share of the baseline proves nothing.
MIN_RAN_SHARE = 0.9


class MutationError(Exception):
    """A list or the tree is not fit to run."""


# Files currently holding a mutant: path -> (original text, backup path).
# Whatever happens, the atexit hook and the `finally` blocks put them back.
_mutated = {}


def restore_all():
    for path, (text, backup) in list(_mutated.items()):
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        del _mutated[path]
        try:
            os.unlink(backup)
        except OSError:
            pass


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
        r"Null check operator|NoSuchMethodError|is not a subtype of type|"
        r"Bad state:|RangeError|StateError|LateInitializationError|"
        r"Unhandled exception|\b\w*Exception:",
        t,
    ):
        return "uncaught_exception"
    return "other"


def is_compile_error(text):
    return "Compilation failed" in text or bool(
        re.search(r"\b(?:lib|test|packages)/\S+:\d+:\d+: Error:", text)
    )


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


def inside(repo, rel_path):
    """Whether [rel_path] stays inside [repo] once symlinks are resolved."""
    root = os.path.realpath(repo)
    full = os.path.realpath(os.path.join(root, rel_path))
    return full == root or full.startswith(root + os.sep)


def validate(repo, spec):
    """Problems of a list against the tree, as strings; empty when it is fit."""
    problems, ids, cache = [], set(), {}
    for m in spec["mutants"]:
        mid = m.get("id", "?")
        if mid in ids:
            problems.append(f"{mid}: duplicate id")
        ids.add(mid)
        bad = False
        for key in ("id", "file", "old", "new"):
            if not isinstance(m.get(key), str) or (key != "new" and not m[key]):
                problems.append(f"{mid}: bad or missing '{key}'")
                bad = True
        if bad:
            continue
        if os.path.isabs(m["file"]) or not inside(repo, m["file"]):
            problems.append(f"{mid}: file {m['file']} is outside the repo")
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
        if os.path.isabs(t) or not inside(repo, t):
            problems.append(f"test file {t} is outside the repo")
        elif not os.path.isfile(os.path.join(repo, t)):
            problems.append(f"test file {t} does not exist")
    return problems


def require_clean(repo, files):
    r = git(repo, "status", "--porcelain", "--", *sorted(files))
    if r.returncode != 0:
        raise MutationError("git status failed: " + r.stderr.strip())
    if r.stdout.strip():
        dirty = [line[3:] for line in r.stdout.splitlines() if line[3:]]
        raise MutationError(
            "refusing to run: files to mutate have uncommitted changes:\n"
            + r.stdout.rstrip()
            + "\nIf an earlier run was killed and left a mutant behind, restore it with\n"
            + "  git restore "
            + " ".join(dirty)
            + f"\n(a copy of each original is under {BACKUPS}/ when one was taken)"
        )


def run_tests(repo, tests, timeout, concurrency=2):
    """Runs `flutter test` on [tests]; returns what the JSON report says."""
    fd, report = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    proc = None
    try:
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
            out, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGKILL)  # only this run's group
            out, _ = proc.communicate()
        secs = time.time() - t0
        suites, names, failures, passed = {}, {}, [], 0
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
                elif (
                    ev.get("type") == "testDone"
                    and ev.get("result") == "success"
                    and not ev.get("hidden")
                ):
                    passed += 1
        # A suite that failed to load is a compile error only when the output
        # (or the failure's own text) says so; a throw while loading is a kill.
        evidence = out + "\n".join(f["error"] for f in failures)
        return {
            "secs": round(secs, 1),
            "timed_out": timed_out,
            "exit_code": proc.returncode,
            "failures": failures,
            "passed": passed,
            "compile_error": is_compile_error(evidence),
            "exit_tail": out[-400:],
        }
    finally:
        if proc is not None and proc.poll() is None:  # Ctrl-C or a crash
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            proc.wait()
        try:
            os.unlink(report)
        except OSError:
            pass


def rel(path, repo):
    return os.path.relpath(path, repo) if os.path.isabs(path) else path


def baseline_problem(b):
    """Why [b], the unmutated run, cannot serve as a baseline; None when it can."""
    if b["timed_out"]:
        return "timed out"
    if b["compile_error"]:
        return "does not compile"
    if b["failures"]:
        return f"{len(b['failures'])} test(s) fail"
    if b.get("exit_code") != 0:
        return f"flutter test exited {b.get('exit_code')} without a failing test"
    if b["passed"] <= 0:
        return "no test ran"
    return None


def classify_run(m, r, repo, baseline_passed=None):
    """The result record of mutant [m] from a test run [r]."""
    rec = {"id": m["id"], "file": m["file"], "note": m.get("note", "")}
    rec["secs"] = r["secs"]
    ran = r["passed"] + len(r["failures"])
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
    elif r.get("exit_code") != 0:
        rec.update(
            status=INCONCLUSIVE,
            reason=f"flutter test exited {r.get('exit_code')} without a failing test",
        )
    elif r["passed"] <= 0:
        rec.update(status=INCONCLUSIVE, reason="no test ran")
    elif baseline_passed and ran < MIN_RAN_SHARE * baseline_passed:
        rec.update(
            status=INCONCLUSIVE,
            reason=f"{ran} tests ran, the baseline had {baseline_passed}",
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


def digest(*parts):
    h = hashlib.sha256()
    for p in parts:
        h.update(p.encode("utf-8"))
        h.update(b"\0")
    return h.hexdigest()


def tests_hash(repo, tests):
    return digest(*[t + "\n" + read_text(os.path.join(repo, t)) for t in tests])


def entry_hash(m):
    return digest(m["id"], m["file"], m["old"], m["new"])


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
    if only:
        unknown = only - {m["id"] for m in spec["mutants"]}
        if unknown:
            raise MutationError(f"unknown mutant ids: {', '.join(sorted(unknown))}")
    mutants = [m for m in spec["mutants"] if not only or m["id"] in only]
    require_clean(repo, {m["file"] for m in mutants})
    key = {
        "commit": head_sha(repo),
        "mode": mode,
        "tests": tests,
        "tests_hash": tests_hash(repo, tests),
    }
    result = {"subject": spec["subject"], **key, "mutants": []}
    if not fresh and os.path.exists(out_path):
        old = json.loads(read_text(out_path))
        if old.get("subject") == spec["subject"]:
            if all(old.get(k) == v for k, v in key.items()):
                result = old
            elif only:
                # Another commit, mode or test content: the saved verdicts of
                # the other ids are kept for reference, marked stale, and the
                # baseline is measured again.
                result["mutants"] = [
                    {**m, "stale": True}
                    for m in old.get("mutants", [])
                    if m["id"] not in only
                ]
    if "baseline" not in result:
        b = runner(repo, tests, 3600, concurrency)
        why = baseline_problem(b)
        if why:
            raise MutationError(
                f"baseline is not green ({why}), nothing mutated: "
                + json.dumps(b)[:800]
            )
        result["baseline"] = {"secs": b["secs"], "passed": b["passed"]}
        save(result, out_path)
    log(
        f"{spec['subject']}: baseline {result['baseline']} ({mode}, {len(tests)} files)"
    )
    if baseline_only:
        return result
    limit = max(120, 3 * result["baseline"]["secs"])
    for m in mutants:
        digest_of = entry_hash(m)
        have = next((x for x in result["mutants"] if x["id"] == m["id"]), None)
        if (
            have
            and not only
            and not have.get("stale")
            and have.get("entry") == digest_of
        ):
            continue
        path = os.path.join(repo, m["file"])
        src = read_text(path)
        backup = os.path.join(repo, BACKUPS, m["file"])
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        with open(backup, "w", encoding="utf-8", newline="") as fh:
            fh.write(src)
        _mutated[path] = (src, backup)
        try:
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(src.replace(m["old"], m["new"], 1))
            r = runner(repo, tests, limit, concurrency)
        finally:
            restore_all()
        rec = classify_run(m, r, repo, result["baseline"]["passed"])
        rec["entry"] = digest_of
        rec["line"] = src[: src.index(m["old"])].count("\n") + 1
        result["mutants"] = [x for x in result["mutants"] if x["id"] != m["id"]]
        result["mutants"].append(rec)
        save(result, out_path)
        log(f"{m['id']} {rec['status']} {rec.get('killer_files', '')}")
    return result


def summarize(result):
    """Lines describing one subject's results: kill rate, survivors, killers."""
    ms = [m for m in result["mutants"] if not m.get("stale")]
    stale = len(result["mutants"]) - len(ms)
    counts = {}
    for m in ms:
        counts[m["status"]] = counts.get(m["status"], 0) + 1
    killed = counts.get(KILLED, 0) + counts.get(TIMEOUT, 0)
    valid = killed + counts.get(SURVIVED, 0)
    rate = round(100 * killed / valid) if valid else 0
    lines = [
        f"== {result['subject']}: kill rate {rate}% ({killed}/{valid} decided), "
        + ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
        + f" [{result.get('mode', '?')}]"
        + (f", {stale} stale (rerun)" if stale else "")
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
        if m["status"] in (SURVIVED, INVALID, INCONCLUSIVE):
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

    for name in ("SIGTERM", "SIGHUP"):
        if hasattr(signal, name):
            signal.signal(getattr(signal, name), _raise_interrupt)
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

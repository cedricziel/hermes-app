"""Every HERMES_HOME a shell script sets comes from a canonicalised path.

Hermes runs expanduser(expandvars(...)) on HERMES_HOME, so a path that looks
like a throwaway folder can resolve to the real ~/.hermes (a directory called
`$X`, a `~`, a symlink onto one). scripts/profile-names.sh holds the check
(`canonical_abs_path`, wrapped with `resolve_path` by `canonical_resolved_path`).
This test reads each script as text and fails, naming file:line, on anything
it cannot show to be safe. The rules are blunt on purpose; nothing here tries
to parse shell.

For every non-comment line of a shell script (continuation lines joined,
heredoc bodies and strings included):
  1. Any mention of HERMES_HOME is a failure, except
       * an assignment `HERMES_HOME=$VAR`, `HERMES_HOME="${VAR}/plain/segments"`
         where VAR is listed in SAFE_VARS for that file;
       * `unset ... HERMES_HOME`, `-u HERMES_HOME`;
       * a read: `$HERMES_HOME`, `${HERMES_HOME}`, `${HERMES_HOME:-...}`;
       * a fragment in EXCEPTIONS (file, regex, reason).
  2. Any occurrence of a SAFE_VARS name that is not a read (`$NAME`, `${NAME}`,
     `${NAME:-...}`) is a write, whatever its form (`cd x && NAME=..`,
     `declare`, `read`, `for NAME in`, `+=`, `printf -v`, a bare `local NAME`).
     It must be one of that variable's listed `assign` lines.
  3. The `requires` lines must exist as non-comment lines.
A workflow file may not mention HERMES_HOME at all (WORKFLOW_EXCEPTIONS).

Not covered: a name built at run time (`${!name}`), and code outside the
scanned files (Python tests that build an environment, for instance).
"""

import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parent.parent

SHELL_GLOBS = ("scripts/**/*.sh", "tool/**/*.sh", ".claude/**/*.sh")
YAML_GLOBS = (".github/workflows/*.yml", ".github/workflows/*.yaml")

# Variables that hold a canonicalised path, per script. `assign` lists every
# line (stripped) that may write the variable; `requires` lists text that must
# appear on a non-comment line of the script for the variable to count as
# checked.
SAFE_VARS = {
    # bind_state_dir sets it from the resolved state directory, which
    # refuse_real_hermes_home passes through canonical_abs_path first
    # (behaviour: test_dev_backend.py).
    "scripts/dev-backend.sh": {
        "HOME_DIR": {
            "assign": ['HOME_DIR="$STATE_DIR/home"'],
            "requires": [
                'canonical_abs_path "$state"',
                'bind_state_dir "$state"',
            ],
        },
    },
    "scripts/fetch_openapi_spec.sh": {
        "WORK_CANON": {
            "assign": ['WORK_CANON="$(canonical_resolved_path "$WORK")" || {'],
            "requires": [],
        },
    },
    "scripts/store-screenshots.sh": {
        "SCREENSHOT_HOME_CANON": {
            "assign": [
                'SCREENSHOT_HOME_CANON="$(canonical_resolved_path "$state/home")" || {'
            ],
            "requires": [
                'if [[ -L "$state/home" ]]; then',
                'if where="$(inside_real_hermes_home "$SCREENSHOT_HOME_CANON")"; then',
            ],
        },
    },
}

# Text in a script that mentions HERMES_HOME without setting it. Each is a
# regex for a fragment of a line, with the reason it is fine.
EXCEPTIONS = [
    (
        "scripts/dev-backend.sh",
        r"sed -n 's/\^HERMES_HOME=//p'",
        "reads the launched process's environment",
    ),
    (
        "scripts/verify.sh",
        r"sed -n 's/\^HERMES_HOME=//p'",
        "reads the launched process's environment",
    ),
    (
        "scripts/verify.sh",
        r'die "backend \$name runs on HERMES_HOME=\$env_home, not \$state/home"',
        "message text",
    ),
]

# Same, for workflow files: (file, regex, reason).
WORKFLOW_EXCEPTIONS = []

FIX = (
    "Hermes expands $VAR and ~ in HERMES_HOME. Take the value from "
    "`canonical_resolved_path` (scripts/profile-names.sh) into a variable, "
    "refuse when it fails, and register that variable in SAFE_VARS in "
    "scripts/test_hermes_home_guard.py"
)

SEGMENT = r"(?!\.{1,2}(?:/|$))[A-Za-z0-9._-]+"


class Site:
    def __init__(self, path, line, value, problem):
        self.path = path
        self.line = line
        self.value = value  # raw value text of a safe assignment, else None
        self.problem = problem  # None when safe

    def __str__(self):
        if self.problem is None:
            return f"{self.path}:{self.line}: HERMES_HOME={self.value} (safe)"
        return f"{self.path}:{self.line}: {self.problem}. {FIX}"


def logical_lines(text):
    """(line number, text) with continuations joined; full-line comments are
    dropped. Nothing else is: heredoc bodies and strings are code here."""
    out = []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        start, cur = i + 1, lines[i]
        while (
            cur.endswith("\\")
            and (len(cur) - len(cur.rstrip("\\"))) % 2 == 1
            and i + 1 < len(lines)
        ):
            i += 1
            cur = cur[:-1] + " " + lines[i]
        i += 1
        if not cur.lstrip().startswith("#"):
            out.append((start, cur))
    return out


def read_forms(name):
    return re.compile(
        r"\$\{" + name + r"(?::-[^}]*)?\}|\$" + name + r"(?![A-Za-z0-9_])"
    )


def assign_form(safe_names):
    names = "|".join(re.escape(n) for n in safe_names) or "(?!)"
    return re.compile(
        r"""(?<![\w"'$-])HERMES_HOME=(?P<q>"?)\$(?:\{(?P<a>"""
        + names
        + r""")\}|(?P<b>"""
        + names
        + r"""))(?P<suffix>(?:/"""
        + SEGMENT
        + r""")*)(?P=q)(?=[\s;)]|$)"""
    )


def check_text(rel, text, safe_vars=None, exceptions=None):
    """Every HERMES_HOME site in a shell script, as Site objects."""
    safe_vars = SAFE_VARS.get(rel, {}) if safe_vars is None else safe_vars
    if exceptions is None:
        exceptions = [(rx, why) for (f, rx, why) in EXCEPTIONS if f == rel]
    sites = []
    assign_re = assign_form(list(safe_vars))
    logical = logical_lines(text)
    for lineno, line in logical:
        rest = line
        for m in assign_re.finditer(line):
            sites.append(Site(rel, lineno, m.group(0).split("=", 1)[1], None))
        rest = assign_re.sub(" ", rest)
        for rx, _why in exceptions:
            rest = re.sub(rx, " ", rest)
        rest = re.sub(r"^\s*unset(?:\s+\w+)+", " ", rest)
        rest = re.sub(r"(?<![\w-])-u\s+HERMES_HOME(?![\w=])", " ", rest)
        rest = read_forms("HERMES_HOME").sub(" ", rest)
        if "HERMES_HOME" in rest:
            if re.search(r"HERMES_HOME\s*(?:[+:]?=)", rest):
                why = "HERMES_HOME is set here from a value that is not a variable listed in SAFE_VARS"
            else:
                why = (
                    "HERMES_HOME is named here in a form the guard cannot take as safe"
                )
            sites.append(Site(rel, lineno, None, f"{why} ({line.strip()[:100]!r})"))
        for name, spec in safe_vars.items():
            if line.strip() in spec["assign"]:
                continue
            bare = read_forms(name).sub(" ", line)
            if re.search(r"(?<![\w$])" + re.escape(name) + r"(?![\w])", bare):
                sites.append(
                    Site(
                        rel,
                        lineno,
                        None,
                        f"{name} is written here ({line.strip()[:100]!r}), which SAFE_VARS does not list",
                    )
                )
    code = [line for _n, line in logical]
    for name, spec in safe_vars.items():
        for needed in spec["requires"]:
            if not any(needed in line for line in code):
                sites.append(
                    Site(
                        rel,
                        1,
                        None,
                        f"{name} is trusted but the script has no non-comment line with {needed!r}",
                    )
                )
    return sites


def check_workflow(rel, text, exceptions=None):
    if exceptions is None:
        exceptions = [(rx, why) for (f, rx, why) in WORKFLOW_EXCEPTIONS if f == rel]
    sites = []
    for lineno, line in enumerate(text.split("\n"), 1):
        rest = line
        for rx, _why in exceptions:
            rest = re.sub(rx, " ", rest)
        if "HERMES_HOME" in rest:
            sites.append(
                Site(
                    rel,
                    lineno,
                    None,
                    f"a workflow mentions HERMES_HOME ({line.strip()[:100]!r})",
                )
            )
    return sites


def tracked_files(root):
    """Repo-relative paths git tracks under [root], or None without git.

    Agent worktrees live in `.claude/worktrees/` inside a checkout; their
    stale copies of the scripts are not part of the repo and must not be scanned.
    """
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            capture_output=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return {n for n in out.decode().split("\0") if n}


def scanned_files(root=None):
    root = ROOT if root is None else root
    tracked = tracked_files(root)

    def keep(p):
        if not p.is_file():
            return False
        rel = p.relative_to(root).as_posix()
        if tracked is not None:
            return rel in tracked
        return not rel.startswith(".claude/worktrees/")

    def pick(globs):
        return sorted({p for g in globs for p in root.glob(g) if keep(p)})

    return pick(SHELL_GLOBS), pick(YAML_GLOBS)


def check_repo(root=None):
    root = ROOT if root is None else root
    sites = []
    shell, yaml = scanned_files(root)
    for path in shell:
        sites.extend(check_text(path.relative_to(root).as_posix(), path.read_text()))
    for path in yaml:
        sites.extend(
            check_workflow(path.relative_to(root).as_posix(), path.read_text())
        )
    return sites


# --- tests -----------------------------------------------------------------


class GuardRules(unittest.TestCase):
    SAFE = {
        "HOME_DIR": {"assign": ['HOME_DIR="$STATE_DIR/home"'], "requires": []},
    }

    def sites(self, text, **kw):
        return check_text("x.sh", text, self.SAFE, **kw)

    def assertFlagged(self, text, fragment=None):
        found = [s for s in self.sites(text) if s.problem]
        self.assertTrue(found, f"not flagged: {text!r}")
        message = str(found[0])
        self.assertIn("x.sh:", message)
        self.assertIn("canonical_resolved_path", message)
        if fragment:
            self.assertIn(fragment, message)

    def assertSafe(self, text):
        found = [s for s in self.sites(text) if s.problem]
        self.assertEqual(found, [], f"flagged: {text!r}: {[str(s) for s in found]}")

    # unsafe HERMES_HOME values
    def test_literal_path_is_flagged(self):
        self.assertFlagged("HERMES_HOME=/tmp/x hermes dashboard")

    def test_home_based_path_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$HOME/.hermes-dev" hermes dashboard')
        self.assertFlagged("export HERMES_HOME=$HOME/x")

    def test_unchecked_variable_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$WORK/home" python x.py', "HERMES_HOME")
        self.assertFlagged('HERMES_HOME="${OTHER}" python x.py')

    def test_tilde_is_flagged(self):
        self.assertFlagged("HERMES_HOME=~/.hermes hermes chat")

    def test_single_quoted_variable_is_flagged(self):
        self.assertFlagged("HERMES_HOME='$HOME_DIR' hermes")

    def test_empty_value_is_flagged(self):
        self.assertFlagged("HERMES_HOME= hermes dashboard")
        self.assertFlagged('HERMES_HOME="" hermes dashboard')

    def test_suffix_with_dot_dot_or_expansion_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$HOME_DIR/../x" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR/$X" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR/~" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR$X" hermes')
        self.assertFlagged('HERMES_HOME="$(pwd)" hermes')

    def test_env_and_declaration_forms_are_flagged(self):
        self.assertFlagged("env HERMES_HOME=/x hermes")
        self.assertFlagged('env "HERMES_HOME=$HOME_DIR" hermes')
        self.assertFlagged('export "HERMES_HOME"=/x')
        self.assertFlagged("declare -x HERMES_HOME=/x")
        self.assertFlagged("local HERMES_HOME=/x")
        self.assertFlagged("cd x && HERMES_HOME=/x hermes")
        self.assertFlagged('x="$(HERMES_HOME=/x hermes)"')

    def test_one_bad_assignment_beside_a_good_one_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$HOME_DIR" hermes; HERMES_HOME=/x hermes')

    def test_code_in_strings_and_heredocs_is_flagged(self):
        self.assertFlagged("eval 'HERMES_HOME=/x hermes'")
        self.assertFlagged("bash -lc 'cd /x; HERMES_HOME=/x hermes'")
        self.assertFlagged("sh -ec 'HERMES_HOME=/x hermes'")
        self.assertFlagged("bash <<EOF\nHERMES_HOME=/x hermes\nEOF")
        self.assertFlagged(
            "python3 - <<PY\nimport os\nos.environ['HERMES_HOME'] = '/x'\nPY"
        )
        self.assertFlagged("python3 -c \"import os; os.environ['HERMES_HOME']='/x'\"")
        self.assertFlagged('eval "$cmd HERMES_HOME"')
        self.assertFlagged(': "${HERMES_HOME:=/x}"')
        self.assertFlagged("source ./env && echo HERMES_HOME")
        self.assertFlagged("echo 'HERMES_HOME=/x' >> env.sh")

    def test_a_heredoc_or_comment_marker_hides_nothing(self):
        self.assertFlagged('echo "<<EOF"\nHERMES_HOME=/x hermes')
        self.assertFlagged("# <<EOF\nHERMES_HOME=/x hermes")
        self.assertFlagged("echo hi # '\nHERMES_HOME=/x hermes")

    def test_continuation_lines_are_read_as_one(self):
        self.assertFlagged('HOME="$a" \\\n  HERMES_HOME="/x" \\\n  hermes')

    def test_unreadable_forms_are_flagged(self):
        self.assertFlagged("export HERMES_HOME")
        self.assertFlagged("read -r HERMES_HOME")
        self.assertFlagged("printf -v HERMES_HOME '%s' x")
        self.assertFlagged("HERMES_HOME+=/x hermes")
        self.assertFlagged('HERMES_HOME="$HOME_DIR hermes')

    def test_the_report_names_the_line(self):
        found = [s for s in self.sites("a\n\nHERMES_HOME=/x hermes") if s.problem]
        self.assertTrue(str(found[0]).startswith("x.sh:3:"))

    # writes to a safe variable
    def test_every_write_to_a_safe_variable_is_flagged(self):
        forms = [
            "HOME_DIR=/tmp/x",
            "cd x && HOME_DIR=/tmp/x",
            "declare HOME_DIR=/x",
            "export HOME_DIR=/x",
            "read -r HOME_DIR",
            "for HOME_DIR in a b; do :; done",
            "HOME_DIR+=/x",
            "printf -v HOME_DIR '%s' /x",
            "local HOME_DIR",
            "local a HOME_DIR=/x",
            "(HOME_DIR=/x; hermes)",
            'HOME_DIR="$(pwd)"',
            ': "${HOME_DIR:=/x}"',
            "eval 'HOME_DIR=/x'",
            "unset HOME_DIR",
            "mapfile HOME_DIR",
        ]
        for form in forms:
            with self.subTest(form=form):
                found = [s for s in self.sites(form) if s.problem]
                self.assertTrue(found, f"not flagged: {form!r}")
                self.assertIn("HOME_DIR is written here", str(found[0]))

    def test_the_listed_assignment_and_reads_of_a_safe_variable_pass(self):
        self.assertSafe('HOME_DIR="$STATE_DIR/home"')
        self.assertSafe('  HOME_DIR="$STATE_DIR/home"  ')
        self.assertSafe(
            '[[ -d "$HOME_DIR/profiles/$1" ]] && echo "${HOME_DIR}" "${HOME_DIR:-}"'
        )
        self.assertSafe('echo "$HOME_DIRS" "$MY_HOME_DIR"')

    def test_a_missing_proof_is_flagged(self):
        safe = {"HOME_DIR": {"assign": [], "requires": ['canonical_abs_path "$state"']}}
        self.assertTrue([s for s in check_text("x.sh", "true", safe) if s.problem])

    def test_a_proof_in_a_comment_does_not_count(self):
        safe = {"HOME_DIR": {"assign": [], "requires": ['canonical_abs_path "$state"']}}
        text = '# canonical_abs_path "$state"\ntrue\n'
        self.assertTrue([s for s in check_text("x.sh", text, safe) if s.problem])
        text = 'canonical_abs_path "$state" || exit 3\n'
        self.assertFalse([s for s in check_text("x.sh", text, safe) if s.problem])

    # workflows
    def test_a_workflow_mention_is_flagged(self):
        self.assertTrue(check_workflow("w.yml", "env:\n  HERMES_HOME: /x\n"))
        self.assertTrue(check_workflow("w.yml", "run: HERMES_HOME=/x hermes\n"))
        self.assertTrue(check_workflow("w.yml", "# HERMES_HOME in a comment\n"))
        self.assertFalse(check_workflow("w.yml", "run: echo ok\n"))

    def test_a_workflow_exception_is_honoured(self):
        text = "run: echo HERMES_HOME is not set\n"
        self.assertFalse(
            check_workflow("w.yml", text, [(r"echo HERMES_HOME is not set", "why")])
        )

    # safe forms
    def test_a_canonical_variable_passes(self):
        self.assertSafe('HERMES_HOME="$HOME_DIR" hermes dashboard')
        self.assertSafe("HERMES_HOME=$HOME_DIR hermes dashboard")
        self.assertSafe('HERMES_HOME="${HOME_DIR}" hermes')
        self.assertSafe('HERMES_HOME="$HOME_DIR/profiles/x" hermes')
        self.assertSafe('export HERMES_HOME="$HOME_DIR"')
        self.assertSafe('env -u A HOME="$h" HERMES_HOME="$HOME_DIR" hermes')

    def test_assigned_inside_a_function_or_continuation_passes(self):
        self.assertSafe(
            'f() {\n  HOME="$a" HERMES_HOME="$HOME_DIR" \\\n    hermes "$@"\n}'
        )

    def test_unset_and_reads_pass(self):
        self.assertSafe("unset HERMES_HOME")
        self.assertSafe("unset A \\\n  B HERMES_HOME \\\n  C")
        self.assertSafe("env -u HERMES_HOME hermes")
        self.assertSafe(
            '[[ -z "${HERMES_HOME:-}" ]] && echo "$HERMES_HOME" "${HERMES_HOME}"'
        )
        self.assertSafe("# HERMES_HOME=/x in a comment")

    def test_an_exception_only_covers_its_fragment(self):
        exceptions = [(r"sed -n 's/\^HERMES_HOME=//p'", "reads the environment")]
        ok = "tr x y | sed -n 's/^HERMES_HOME=//p'"
        self.assertEqual(
            [s for s in self.sites(ok, exceptions=exceptions) if s.problem], []
        )
        bad = ok + "; HERMES_HOME=/x hermes"
        self.assertTrue(
            [s for s in self.sites(bad, exceptions=exceptions) if s.problem]
        )


class RealScripts(unittest.TestCase):
    def test_the_scan_finds_the_known_sites(self):
        # A guard that scans nothing proves nothing.
        shell, _ = scanned_files()
        names = {p.name for p in shell}
        self.assertTrue(
            {
                "dev-backend.sh",
                "verify.sh",
                "fetch_openapi_spec.sh",
                "store-screenshots.sh",
            }
            <= names
        )
        assigned = {(s.path, s.value) for s in check_repo() if s.value is not None}
        self.assertIn(("scripts/dev-backend.sh", '"$HOME_DIR"'), assigned)
        self.assertIn(("scripts/fetch_openapi_spec.sh", '"$WORK_CANON/home"'), assigned)
        self.assertIn(
            ("scripts/store-screenshots.sh", '"$SCREENSHOT_HOME_CANON"'), assigned
        )

    def test_every_hermes_home_in_the_repo_is_canonicalised(self):
        bad = [str(s) for s in check_repo() if s.problem]
        self.assertEqual(bad, [], "\n" + "\n".join(bad))

    def make_repo(self, bad_rel, track):
        repo = pathlib.Path(tempfile.mkdtemp(prefix="hermes-home-scan.")).resolve()
        self.addCleanup(shutil.rmtree, repo, ignore_errors=True)
        subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
        bad = repo / bad_rel
        bad.parent.mkdir(parents=True)
        bad.write_text("HERMES_HOME=/tmp/raw\nhermes dashboard\n")
        if track:
            subprocess.run(["git", "-C", str(repo), "add", bad_rel], check=True)
        return repo

    def test_scan_ignores_untracked_agent_worktree_copies(self):
        repo = self.make_repo(".claude/worktrees/x/scripts/dev.sh", track=False)
        self.assertEqual([s for s in check_repo(repo) if s.problem], [])

    def test_scan_still_catches_a_tracked_offender(self):
        repo = self.make_repo("scripts/dev.sh", track=True)
        found = [s for s in check_repo(repo) if s.problem]
        self.assertTrue(found)
        self.assertIn("scripts/dev.sh", str(found[0]))

    def test_scan_without_git_skips_agent_worktrees(self):
        repo = self.make_repo(".claude/worktrees/x/scripts/dev.sh", track=False)
        with mock.patch.object(sys.modules[__name__], "tracked_files", lambda r: None):
            self.assertEqual([s for s in check_repo(repo) if s.problem], [])

    def test_every_exception_still_matches_a_line(self):
        for rel, rx, why in EXCEPTIONS:
            text = (ROOT / rel).read_text()
            self.assertTrue(
                any(re.search(rx, line) for _n, line in logical_lines(text)),
                f"{rel}: the exception {rx!r} ({why}) matches nothing; remove it",
            )


BASH = shutil.which("bash")


@unittest.skipUnless(BASH and sys.platform != "win32", "needs bash")
class ScriptSites(unittest.TestCase):
    """The scripts that set HERMES_HOME from a raw path refuse a path Hermes
    would expand, before hermes or the seeding runs."""

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="hermes-home-sites.")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.log = self.tmp / "calls.log"

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\n" + body)
        path.chmod(0o755)
        return path

    def run_script(self, script, *args, **env_extra):
        env = {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "LANG": "C",
            "HOME": str(self.tmp / "home"),
            "STUB_LOG": str(self.log),
        }
        env.update(env_extra)
        return subprocess.run(
            [BASH, str(script), *args],
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )

    def logged(self):
        return self.log.read_text() if self.log.exists() else ""

    def layout(self, parent, files):
        """Copies scripts into [parent]/repo/scripts and returns the repo."""
        repo = parent / "repo"
        (repo / "scripts").mkdir(parents=True)
        for name in files:
            shutil.copy(ROOT / "scripts" / name, repo / "scripts" / name)
        return repo

    # -- fetch_openapi_spec.sh ---------------------------------------------

    def fetch(self, tmpdir):
        repo = self.layout(
            self.tmp / "fetch", ["fetch_openapi_spec.sh", "profile-names.sh"]
        )
        (repo / "openapi").mkdir()
        empty = self.tmp / "empty.tgz"
        subprocess.run(["tar", "czf", str(empty), "-T", "/dev/null"], check=True)
        self.stub("gh", "echo 0123456789abcdef0123456789abcdef01234567\n")
        self.stub("curl", f'cat "{empty}"\n')
        # `uv venv ... DIR` makes DIR/bin/python, a stub that records its HERMES_HOME.
        self.stub(
            "uv",
            'if [[ "$1" == venv ]]; then\n'
            '  dir="${@: -1}"; mkdir -p "$dir/bin"\n'
            '  printf \'#!/usr/bin/env bash\\necho "python HERMES_HOME=$HERMES_HOME" >>"$STUB_LOG"\\necho {} >"$4"\\n\' >"$dir/bin/python"\n'
            '  chmod +x "$dir/bin/python"\n'
            "fi\n",
        )
        return self.run_script(
            repo / "scripts" / "fetch_openapi_spec.sh",
            TMPDIR=str(tmpdir),
            X="../outside",
        )

    def test_fetch_gives_hermes_the_resolved_temp_dir(self):
        tmpdir = self.tmp / "plain"
        tmpdir.mkdir()
        result = self.fetch(tmpdir)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(
            self.logged(),
            rf"HERMES_HOME={re.escape(str(tmpdir))}/hermes-openapi\.\w+/home\n",
        )

    def test_fetch_refuses_a_temp_dir_whose_name_hermes_would_expand(self):
        tmpdir = self.tmp / "$X"
        tmpdir.mkdir()
        result = self.fetch(tmpdir)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("refusing", result.stderr)
        self.assertEqual(self.logged(), "", "hermes ran")

    def test_fetch_refuses_a_temp_dir_that_resolves_to_a_name_hermes_would_expand(self):
        target = self.tmp / "t" / "$X"
        target.mkdir(parents=True)
        (self.tmp / "t" / "link").symlink_to(target)
        result = self.fetch(self.tmp / "t" / "link")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(self.logged(), "", "hermes ran")

    # -- store-screenshots.sh ----------------------------------------------

    def screenshots(self, parent):
        """Lays out a checkout under [parent]; returns its path."""
        repo = self.layout(parent, ["store-screenshots.sh", "profile-names.sh"])
        self.stub("xcrun", "exit 1\n")
        backend = repo / "scripts" / "dev-backend.sh"
        backend.write_text(
            '#!/usr/bin/env bash\n[[ "$1" == url ]] && echo http://127.0.0.1:1\nexit 0\n'
        )
        backend.chmod(0o755)
        self.seed = self.stub(
            "seed-python", 'echo "seed HERMES_HOME=$HERMES_HOME" >>"$STUB_LOG"\n'
        )
        return repo

    def shoot(self, repo):
        return self.run_script(
            repo / "scripts" / "store-screenshots.sh",
            "ios",
            "iphone",
            HERMES_PYTHON=str(self.seed),
        )

    def test_screenshots_seed_with_the_resolved_state_dir(self):
        parent = self.tmp / "ok"
        result = self.shoot(self.screenshots(parent))
        self.assertIn(
            f"seed HERMES_HOME={parent}/repo/.dart_tool/hermes-dev/home\n",
            self.logged(),
            result.stderr,
        )

    def test_screenshots_refuse_a_checkout_path_hermes_would_expand(self):
        result = self.shoot(self.screenshots(self.tmp / "$X"))
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("refusing", result.stderr)
        self.assertEqual(self.logged(), "", "the seeding ran")

    def test_screenshots_refuse_a_checkout_that_resolves_to_a_name_hermes_would_expand(
        self,
    ):
        repo = self.screenshots(self.tmp / "$Y")
        (self.tmp / "link").symlink_to(repo)
        result = self.shoot(self.tmp / "link")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(self.logged(), "", "the seeding ran")

    def real_home_with_state(self):
        """A fake HOME (the one run_script gives) with a real-looking state.db."""
        real = self.tmp / "home" / ".hermes"
        real.mkdir(parents=True)
        (real / "state.db").write_text("keep\n")
        return real

    def test_screenshots_leave_the_real_state_db_when_home_is_a_symlink_to_it(self):
        real = self.real_home_with_state()
        repo = self.screenshots(self.tmp / "sym")
        state = repo / ".dart_tool" / "hermes-dev"
        state.mkdir(parents=True)
        (state / "home").symlink_to(real)
        result = self.shoot(repo)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("refusing", result.stderr)
        self.assertEqual(
            (real / "state.db").read_text(), "keep\n", "state.db was deleted"
        )
        self.assertEqual(self.logged(), "", "the seeding ran")

    def test_screenshots_refuse_a_state_dir_under_the_real_home(self):
        real = self.real_home_with_state()
        repo = self.screenshots(self.tmp / "under")
        state = real / "dev"
        (state / "home").mkdir(parents=True)
        (state / "home" / "state.db").write_text("keep\n")
        result = self.run_script(
            repo / "scripts" / "store-screenshots.sh",
            "ios",
            "iphone",
            HERMES_PYTHON=str(self.seed),
            HERMES_DEV_STATE_DIR=str(state),
        )
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("real Hermes home", result.stderr)
        self.assertEqual((state / "home" / "state.db").read_text(), "keep\n")
        self.assertEqual(self.logged(), "", "the seeding ran")

    def test_screenshots_seed_the_home_of_hermes_dev_state_dir(self):
        repo = self.screenshots(self.tmp / "own")
        state = self.tmp / "elsewhere"
        (state / "home").mkdir(parents=True)
        (state / "home" / "state.db").write_text("old\n")
        self.run_script(
            repo / "scripts" / "store-screenshots.sh",
            "ios",
            "iphone",
            HERMES_PYTHON=str(self.seed),
            HERMES_DEV_STATE_DIR=str(state),
        )
        self.assertIn(f"seed HERMES_HOME={state}/home\n", self.logged())
        self.assertFalse(
            (state / "home" / "state.db").exists(), "the old state.db was kept"
        )


if __name__ == "__main__":
    unittest.main()

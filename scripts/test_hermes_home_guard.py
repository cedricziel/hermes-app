"""Every HERMES_HOME a shell script sets comes from a canonicalised path.

Hermes runs expanduser(expandvars(...)) on HERMES_HOME, so a path that looks
like a throwaway folder can resolve to the real ~/.hermes (a directory called
`$X`, a `~`, a symlink onto one). scripts/profile-names.sh holds the check
(`canonical_abs_path`, wrapped with `resolve_path` by `canonical_resolved_path`).
This test reads each script statically and fails, naming file:line, when
HERMES_HOME is assigned from anything but a variable that went through it.

The rules:
  * every `HERMES_HOME=value` word (plain, after `export`, `env`, `local`,
    in `HOME=x HERMES_HOME=y cmd`, or quoted for `env`/`eval`/`bash -c`) is an
    assignment;
  * the value must be `$VAR`, `${VAR}` or `$VAR/<plain segments>` with VAR in
    SAFE_VARS for that file, and each assignment of VAR in that file must be
    one of the lines SAFE_VARS lists;
  * `unset HERMES_HOME` and `env -u HERMES_HOME` are fine; reading it is fine;
  * anything else the reader cannot take at face value (an empty value, `+=`,
    `export HERMES_HOME` with no value, `read`/`printf -v` into it, an
    unbalanced quote) is flagged too.

Not covered: a name built at run time (`${!name}`), and code outside the
scanned shell scripts (Python tests that build an environment, for instance).
"""

import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Scripts scanned: all shell under scripts/, plus other places that could
# launch hermes. A workflow's `HERMES_HOME:` env key is flagged outright.
SHELL_GLOBS = ("scripts/**/*.sh", "tool/**/*.sh", ".claude/**/*.sh")
YAML_GLOBS = (".github/workflows/*.yml", ".github/workflows/*.yaml")

# Variables that hold a canonicalised path, per script. `assign` lists every
# line (stripped) that may assign the variable; `requires` lists lines that
# must exist in the script for the variable to count as checked.
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
        "home": {
            "assign": ['home="$state/home"'],
            "requires": [
                'state="$(canonical_resolved_path "$ROOT_DIR/.dart_tool/hermes-dev")" || {',
            ],
        },
    },
}

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
        self.value = value  # raw value text, or None for a non-assignment
        self.problem = problem  # None when safe

    def __str__(self):
        if self.problem is None:
            return f"{self.path}:{self.line}: HERMES_HOME={self.value} (safe)"
        return f"{self.path}:{self.line}: {self.problem}. {FIX}"


# --- reading shell ---------------------------------------------------------


def logical_lines(text):
    """(line number, text) with continuations joined and heredoc bodies and
    full-line comments dropped."""
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
        if cur.lstrip().startswith("#"):
            continue
        # A quoted string can run over several lines (a python -c snippet).
        while i < len(lines) and "an unbalanced quote" in scan(cur)[1]:
            cur = cur + "\n" + lines[i]
            i += 1
        out.append((start, cur))
        for m in re.finditer(r"(?<!<)<<-?\s*([\"']?)([A-Za-z_]\w*)\1", cur):
            delim = m.group(2)
            while i < len(lines) and lines[i].strip() != delim:
                i += 1
            i += 1
    return out


def matching_paren(text, open_index):
    depth = 0
    for j in range(open_index, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return j
    return -1


def scan(text):
    """(commands, problems): commands are lists of raw words (quotes kept),
    command substitutions are scanned too."""
    cmds, problems = [[]], []
    word = []
    quote = None
    i, n = 0, len(text)

    def flush():
        if word:
            cmds[-1].append("".join(word))
            word.clear()

    def substitution(i):
        # text[i] is `$` and text[i+1] is `(`, or text[i] is a backtick.
        if text[i] == "`":
            j = text.find("`", i + 1)
            inner = text[i + 1 : j] if j != -1 else ""
        else:
            j = matching_paren(text, i + 1)
            inner = text[i + 2 : j] if j != -1 else ""
        if j == -1:
            problems.append("an unbalanced command substitution")
            return n
        word.append(text[i : j + 1])
        sub_cmds, sub_problems = scan(inner)
        cmds.extend(sub_cmds)
        problems.extend(sub_problems)
        return j + 1

    while i < n:
        c = text[i]
        if quote == "'":
            word.append(c)
            if c == "'":
                quote = None
            i += 1
        elif quote == '"':
            if c == "\\" and i + 1 < n:
                word.append(text[i : i + 2])
                i += 2
            elif c == "`" or (c == "$" and text[i + 1 : i + 2] == "("):
                i = substitution(i)
            else:
                word.append(c)
                if c == '"':
                    quote = None
                i += 1
        elif c == "\\" and i + 1 < n:
            word.append(text[i : i + 2])
            i += 2
        elif c in "'\"":
            quote = c
            word.append(c)
            i += 1
        elif c == "`" or (c == "$" and text[i + 1 : i + 2] == "("):
            i = substitution(i)
        elif c in " \t":
            flush()
            i += 1
        elif c in ";|&()":
            flush()
            if cmds[-1]:
                cmds.append([])
            i += 1
        elif c == "#" and not word:
            break
        else:
            word.append(c)
            i += 1
    if quote:
        problems.append("an unbalanced quote")
    flush()
    return [c for c in cmds if c], problems


# --- judging a value -------------------------------------------------------


def judge_value(value, rel, safe_vars):
    """None when `value` is a canonicalised variable of `rel`, else why not."""
    if value.strip("\"'") == "":
        return "HERMES_HOME is set empty, which makes Hermes fall back to ~/.hermes"
    m = re.fullmatch(
        r'(?P<q>"?)\$(?:\{(?P<a>\w+)\}|(?P<b>\w+))(?P<suffix>(?:/'
        + SEGMENT
        + r")*)(?P=q)",
        value,
    )
    if not m:
        return f"HERMES_HOME is set from {value}, which is not a variable that went through canonical_abs_path"
    name = m.group("a") or m.group("b")
    if name not in safe_vars:
        return f"HERMES_HOME is set from ${name}, which is not a variable that went through canonical_abs_path"
    return None


def check_text(rel, text, safe_vars=None):
    """Every HERMES_HOME site in a shell script, as Site objects."""
    safe_vars = SAFE_VARS.get(rel, {}) if safe_vars is None else safe_vars
    sites = []
    assigned = {name: [] for name in safe_vars}  # (line, stripped text)
    for lineno, line in logical_lines(text):
        for name in safe_vars:
            if re.match(
                rf"\s*(?:local\s+|export\s+|readonly\s+)?{re.escape(name)}=", line
            ):
                assigned[name].append((lineno, line.strip()))
        if "HERMES_HOME" not in line:
            continue
        cmds, problems = scan(line)
        for problem in problems:
            sites.append(Site(rel, lineno, None, f"cannot read this line ({problem})"))
        queue = list(cmds)
        while queue:
            words = queue.pop(0)
            for idx, w in enumerate(words):
                prev = words[idx - 1] if idx else ""
                bare = w.strip("\"'")
                if prev in ("eval", "-c") and w[:1] in "\"'" and "HERMES_HOME" in w:
                    inner_cmds, inner_problems = scan(w[1:-1])
                    queue.extend(inner_cmds)
                    for problem in inner_problems:
                        sites.append(
                            Site(
                                rel, lineno, None, f"cannot read this line ({problem})"
                            )
                        )
                    continue
                m = re.match(r"""^(["']?)HERMES_HOME(\+?)=(.*)$""", w)
                if m:
                    quote, plus, value = m.groups()
                    if plus:
                        sites.append(
                            Site(
                                rel,
                                lineno,
                                value,
                                "HERMES_HOME is appended to with +=, which cannot be checked",
                            )
                        )
                        continue
                    if quote:
                        value = value[:-1] if value.endswith(quote) else value
                        value = f'"{value}"' if quote == '"' else f"'{value}'"
                    sites.append(
                        Site(rel, lineno, value, judge_value(value, rel, safe_vars))
                    )
                elif bare == "HERMES_HOME":
                    if words[0] == "unset" or prev == "-u":
                        continue
                    sites.append(
                        Site(
                            rel,
                            lineno,
                            None,
                            "HERMES_HOME is named with no value (export, read or printf -v), so its source cannot be checked",
                        )
                    )
    # The variables must be assigned only where the table says, and the script
    # must carry the checks that make them canonical.
    for name, spec in safe_vars.items():
        for lineno, stripped in assigned[name]:
            if stripped not in spec["assign"]:
                sites.append(
                    Site(
                        rel,
                        lineno,
                        None,
                        f"${name} is assigned here ({stripped!r}), which SAFE_VARS does not list",
                    )
                )
        for needed in spec["requires"]:
            if needed not in text:
                sites.append(
                    Site(
                        rel,
                        1,
                        None,
                        f"${name} is trusted but the script no longer contains {needed!r}",
                    )
                )
    return sites


def check_yaml(rel, text):
    sites = []
    for lineno, line in enumerate(text.split("\n"), 1):
        if re.match(r"\s*(?:-\s*)?['\"]?HERMES_HOME['\"]?\s*:", line):
            sites.append(
                Site(rel, lineno, None, "a workflow sets HERMES_HOME in an env block")
            )
    return sites


def scanned_files():
    shell = sorted({p for g in SHELL_GLOBS for p in ROOT.glob(g) if p.is_file()})
    yaml = sorted({p for g in YAML_GLOBS for p in ROOT.glob(g) if p.is_file()})
    return shell, yaml


def check_repo():
    sites = []
    shell, yaml = scanned_files()
    for path in shell:
        sites.extend(check_text(path.relative_to(ROOT).as_posix(), path.read_text()))
    for path in yaml:
        sites.extend(check_yaml(path.relative_to(ROOT).as_posix(), path.read_text()))
    return sites


# --- tests -----------------------------------------------------------------


class GuardRules(unittest.TestCase):
    SAFE = {"HOME_DIR": {"assign": ['HOME_DIR="$STATE_DIR/home"'], "requires": []}}

    def sites(self, text):
        return check_text("x.sh", text, self.SAFE)

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

    # unsafe forms
    def test_literal_path_is_flagged(self):
        self.assertFlagged("HERMES_HOME=/tmp/x hermes dashboard")

    def test_home_based_path_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$HOME/.hermes-dev" hermes dashboard')
        self.assertFlagged("export HERMES_HOME=$HOME/x")

    def test_unchecked_variable_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$WORK/home" python x.py', "$WORK")
        self.assertFlagged('HERMES_HOME="${OTHER}" python x.py')

    def test_tilde_is_flagged(self):
        self.assertFlagged("HERMES_HOME=~/.hermes hermes chat")

    def test_single_quoted_variable_is_flagged(self):
        self.assertFlagged("HERMES_HOME='$HOME_DIR' hermes")

    def test_empty_value_is_flagged(self):
        self.assertFlagged("HERMES_HOME= hermes dashboard", "empty")
        self.assertFlagged('HERMES_HOME="" hermes dashboard', "empty")

    def test_suffix_with_dot_dot_or_expansion_is_flagged(self):
        self.assertFlagged('HERMES_HOME="$HOME_DIR/../x" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR/$X" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR/~" hermes')
        self.assertFlagged('HERMES_HOME="$HOME_DIR$X" hermes')
        self.assertFlagged('HERMES_HOME="$(pwd)" hermes')

    def test_env_forms_are_flagged(self):
        self.assertFlagged("env HERMES_HOME=/x hermes")
        self.assertFlagged('env -u FOO "HERMES_HOME=/x" hermes')
        self.assertFlagged("declare -x HERMES_HOME=/x")
        self.assertFlagged("local HERMES_HOME=/x")
        self.assertFlagged("cd x && HERMES_HOME=/x hermes")
        self.assertFlagged("(HERMES_HOME=/x hermes)")
        self.assertFlagged('x="$(HERMES_HOME=/x hermes)"')

    def test_code_in_a_string_is_flagged(self):
        self.assertFlagged("eval 'HERMES_HOME=/x hermes'")
        self.assertFlagged("bash -c 'cd /x; HERMES_HOME=/x hermes'")

    def test_continuation_lines_are_read_as_one(self):
        self.assertFlagged('HOME="$a" \\\n  HERMES_HOME="/x" \\\n  hermes')

    def test_unreadable_forms_are_flagged(self):
        self.assertFlagged("export HERMES_HOME", "no value")
        self.assertFlagged("read -r HERMES_HOME", "no value")
        self.assertFlagged("printf -v HERMES_HOME '%s' x", "no value")
        self.assertFlagged("HERMES_HOME+=/x hermes", "+=")
        self.assertFlagged('HERMES_HOME="$HOME_DIR hermes', "unbalanced")

    def test_the_report_names_the_line(self):
        found = [s for s in self.sites("a\n\nHERMES_HOME=/x hermes") if s.problem]
        self.assertTrue(str(found[0]).startswith("x.sh:3:"))

    def test_an_unlisted_assignment_of_a_safe_variable_is_flagged(self):
        text = 'HOME_DIR="$STATE_DIR/home"\nHOME_DIR="/elsewhere"\nHERMES_HOME="$HOME_DIR" hermes\n'
        found = [s for s in self.sites(text) if s.problem]
        self.assertEqual([s.line for s in found], [2])

    def test_a_missing_proof_is_flagged(self):
        safe = {
            "HOME_DIR": {
                "assign": ['HOME_DIR="$STATE_DIR/home"'],
                "requires": ['canonical_abs_path "$state"'],
            }
        }
        found = check_text(
            "x.sh", 'HOME_DIR="$STATE_DIR/home"\nHERMES_HOME="$HOME_DIR" hermes\n', safe
        )
        self.assertTrue([s for s in found if s.problem])

    def test_a_workflow_env_key_is_flagged(self):
        self.assertTrue(check_yaml("w.yml", "env:\n  HERMES_HOME: /x\n"))
        self.assertTrue(check_yaml("w.yml", "      - HERMES_HOME: /x\n"))
        self.assertFalse(check_yaml("w.yml", "run: echo HERMES_HOME is not set\n"))

    # safe forms
    def test_a_canonical_variable_passes(self):
        self.assertSafe('HERMES_HOME="$HOME_DIR" hermes dashboard')
        self.assertSafe("HERMES_HOME=$HOME_DIR hermes dashboard")
        self.assertSafe('HERMES_HOME="${HOME_DIR}" hermes')
        self.assertSafe('HERMES_HOME="$HOME_DIR/profiles/x" hermes')
        self.assertSafe('export HERMES_HOME="$HOME_DIR"')
        self.assertSafe('env -u A HOME="$h" HERMES_HOME="$HOME_DIR" hermes')
        self.assertSafe('env "HERMES_HOME=$HOME_DIR" hermes')

    def test_assigned_inside_a_function_or_continuation_passes(self):
        self.assertSafe(
            'f() {\n  HOME="$a" HERMES_HOME="$HOME_DIR" \\\n    hermes "$@"\n}'
        )

    def test_unset_reads_and_text_pass(self):
        self.assertSafe("unset HERMES_HOME")
        self.assertSafe("unset A \\\n  B HERMES_HOME \\\n  C")
        self.assertSafe("env -u HERMES_HOME hermes")
        self.assertSafe('[[ -z "${HERMES_HOME:-}" ]] && echo "$HERMES_HOME"')
        self.assertSafe("tr '\\0' '\\n' <environ | sed -n 's/^HERMES_HOME=//p'")
        self.assertSafe('die "runs on HERMES_HOME=$env_home, not $state"')
        self.assertSafe("# HERMES_HOME=/x in a comment")
        self.assertSafe("echo ok # HERMES_HOME=/x")
        self.assertSafe("cat <<EOF\nHERMES_HOME=/x\nEOF\nhermes")


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
        sites = [s for s in check_repo() if s.value is not None]
        assigned = {(s.path, s.value) for s in sites}
        self.assertIn(("scripts/dev-backend.sh", '"$HOME_DIR"'), assigned)
        self.assertIn(("scripts/fetch_openapi_spec.sh", '"$WORK_CANON/home"'), assigned)
        self.assertIn(("scripts/store-screenshots.sh", '"$home"'), assigned)

    def test_every_hermes_home_in_the_repo_is_canonicalised(self):
        bad = [str(s) for s in check_repo() if s.problem]
        self.assertEqual(bad, [], "\n" + "\n".join(bad))


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


if __name__ == "__main__":
    unittest.main()

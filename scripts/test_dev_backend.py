"""Checks scripts/dev-backend.sh start and scripts/verify.sh's temp-root check
without a real Hermes: a stand-in `hermes` on PATH records each call and lays
profiles out the way the real one does, in a fake HOME. Covers the refusal to
run where Hermes would write the real profiles, which is an allowlist (only a
canonical absolute path is accepted, then the resolved path is compared with
the real home), one test per spelling that once got past a denylist, a
property test over generated spellings, name validation, flags-only options,
and starts repeated on one state dir.

Needs only bash and coreutils: no network, no hermes, no lsof, no curl.
"""

import concurrent.futures
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEV_BACKEND = ROOT / "scripts" / "dev-backend.sh"
VERIFY = ROOT / "scripts" / "verify.sh"

STUB = """#!/usr/bin/env bash
echo "HOME=${HOME-<unset>} HERMES_HOME=${HERMES_HOME:-} SUDO_USER=${SUDO_USER-<unset>} SUFFIX=${HERMES_DATA_DIR_SUFFIX-<unset>} :: $*" >>"$HERMES_STUB_LOG"
args=("$@")
[[ "${args[0]:-}" == -p ]] && args=("${args[@]:2}")
[[ -n "${HERMES_STUB_FAIL:-}" && "${args[0]:-}" == profile ]] && exit 1
case "${args[0]:-} ${args[1]:-}" in
  "profile create") mkdir -p "$HERMES_HOME/profiles/${args[2]}" ;;
  "profile use") echo "${args[2]}" >"$HERMES_HOME/active_profile" ;;
  dashboard*) exit 1 ;;
esac
"""


def snapshot(path):
    """Every path under [path] with its mtime and size, to compare runs."""
    found = {}
    for dirpath, dirnames, filenames in os.walk(path):
        for name in dirnames + filenames:
            full = os.path.join(dirpath, name)
            stat = os.lstat(full)
            found[full] = (stat.st_mtime_ns, stat.st_size)
    return found


def under_hermes_home(path, home):
    """Whether [path] is at or under [home]/.hermes or [home]/.hermes<suffix>."""
    path, home = os.path.realpath(path), os.path.realpath(home)
    if not path.startswith(home + os.sep):
        return False
    return path[len(home) + 1 :].split(os.sep)[0].startswith(".hermes")


@unittest.skipUnless(sys.platform.startswith("linux"), "verify.sh is Linux only")
class DevBackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="dev-backend-test.")).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        (self.home / ".hermes" / "profiles" / "real").mkdir(parents=True)
        (self.home / ".hermes" / "active_profile").write_text("real\n")
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        hermes = self.bin / "hermes"
        hermes.write_text(STUB)
        hermes.chmod(0o755)
        self.log = self.tmp / "calls.log"
        # Where `getent passwd` says the user's home is: a fake one, so no
        # test names the real home.
        self.pw_home = self.tmp / "pwhome"
        (self.pw_home / ".hermes").mkdir(parents=True)
        self.set_passwd_home(str(self.pw_home))
        (self.tmp / "state").mkdir()
        # Where a mutated script would put a relative path: inside the fake tree.
        self.cwd = self.tmp / "cwd"
        self.cwd.mkdir()

    def set_passwd_home(self, home):
        getent = self.bin / "getent"
        getent.write_text(f'#!/usr/bin/env bash\necho "user:x:1:1::{home}:/bin/bash"\n')
        getent.chmod(0o755)

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""

    def env(self, home="set", **extra):
        env = {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HERMES_STUB_LOG": str(self.log),
            "LANG": "C",
        }
        if home == "set":
            env["HOME"] = str(self.home)
        elif home not in ("unset", None):
            env["HOME"] = home
        env.update(extra)
        return env

    def start(self, *args, state=None, home="set", cwd=None, **extra):
        env = self.env(home=home, **extra)
        env["HERMES_DEV_STATE_DIR"] = str(state or self.tmp / "state")
        return subprocess.run(
            ["bash", str(DEV_BACKEND), "start", *args],
            env=env,
            cwd=cwd or self.cwd,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def mark(self):
        """Records the tree, so a refusal can be shown to write nothing."""
        self._before = snapshot(self.tmp)

    def assertRefused(self, result, *, message=None):
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("refusing", result.stderr)
        if message:
            self.assertIn(message, result.stderr)
        self.assertEqual(self.calls(), "", "hermes was called")
        self.assertEqual(snapshot(self.tmp), self._before, "something was written")

    # -- the refusal: each spelling that once got past a denylist ----------

    def test_refuses_a_state_dir_under_the_real_home(self):
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            "--sticky-profile",
            "sp",
            state=self.home / ".hermes" / "dev-state",
        )
        self.assertRefused(result, message="at or under")
        self.assertEqual(
            (self.home / ".hermes" / "active_profile").read_text(), "real\n"
        )

    def test_refuses_a_plain_start_there_too(self):
        self.mark()
        self.assertRefused(self.start(state=self.home / ".hermes"))

    def test_refuses_a_leading_double_slash(self):
        self.mark()
        self.assertRefused(
            self.start("--launch-profile", "lp", state=f"/{self.home}/.hermes/dev"),
            message="canonical",
        )

    def test_refuses_a_double_slash_in_the_middle(self):
        self.mark()
        self.assertRefused(
            self.start(state=f"{self.home}//.hermes/dev"), message="canonical"
        )

    def test_refuses_a_literal_tilde(self):
        self.mark()
        self.assertRefused(self.start(state="~/.hermes/dev"), message="canonical")
        self.assertRefused(self.start(state=f"{self.tmp}/~"), message="canonical")

    def test_refuses_a_dollar_variable(self):
        self.mark()
        self.assertRefused(self.start(state="$HOME/.hermes/dev"), message="canonical")
        self.assertRefused(self.start(state="${HOME}/.hermes/dev"), message="canonical")

    def test_refuses_a_backtick(self):
        self.mark()
        self.assertRefused(
            self.start(state=f"{self.tmp}/`echo x`"), message="canonical"
        )

    def test_refuses_a_newline(self):
        self.mark()
        self.assertRefused(self.start(state=f"{self.tmp}/a\nb"), message="canonical")
        self.assertRefused(self.start(state=f"{self.tmp}/a\tb"), message="canonical")

    def test_refuses_a_relative_path(self):
        self.mark()
        self.assertRefused(
            self.start(state=".hermes/dev", cwd=self.home), message="canonical"
        )
        self.assertRefused(self.start(state="state", cwd=self.tmp), message="canonical")

    def test_refuses_a_trailing_slash(self):
        self.mark()
        self.assertRefused(self.start(state=f"{self.tmp}/state/"), message="canonical")

    def test_refuses_dot_dot_through_a_missing_directory(self):
        (self.tmp / "w").mkdir()
        self.mark()
        result = self.start(
            "--launch-profile", "lp", state=f"{self.tmp}/w/nope/../../home/.hermes/dev"
        )
        self.assertRefused(result, message="canonical")
        self.assertFalse((self.tmp / "w" / "nope").exists())

    def test_refuses_dot_segments(self):
        for state in (
            f"{self.tmp}/./state",
            f"{self.tmp}/state/.",
            f"{self.tmp}/state/..",
        ):
            with self.subTest(state=state):
                self.mark()
                self.assertRefused(self.start(state=state), message="canonical")

    def test_refuses_a_directory_named_dot_hermes_something(self):
        # HERMES_DATA_DIR_SUFFIX moves Hermes' default home to ~/.hermes<suffix>.
        for name in (".hermes-dev", ".hermes2", ".hermes.bak"):
            with self.subTest(name=name):
                self.mark()
                self.assertRefused(self.start(state=self.home / name / "state"))
        self.assertFalse((self.home / ".hermes-dev").exists())

    def test_refuses_through_a_symlink_into_the_real_home(self):
        (self.tmp / "lnk").symlink_to(self.home / ".hermes")
        (self.tmp / "lnkhome").symlink_to(self.home)
        self.mark()
        self.assertRefused(self.start(state=self.tmp / "lnk" / "dev"))
        self.assertRefused(self.start(state=self.tmp / "lnkhome" / ".hermes" / "dev"))

    def test_refuses_a_real_home_spelled_with_a_double_slash(self):
        self.mark()
        result = self.start(home=f"/{self.home}", state=self.home / ".hermes" / "dev")
        self.assertRefused(result)

    def test_refuses_a_state_dir_under_an_ambient_hermes_home(self):
        ambient = self.tmp / "ambient"
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            state=ambient / "sub" / "state",
            HERMES_HOME=str(ambient),
        )
        self.assertRefused(result)
        self.assertFalse(ambient.exists())

    def test_refuses_a_non_canonical_ambient_hermes_home(self):
        for ambient in (
            f"{self.tmp}/w/nope/../ambient",
            "~/x",
            "$HOME/x",
            f"/{self.tmp}/x",
        ):
            with self.subTest(ambient=ambient):
                self.mark()
                self.assertRefused(self.start(HERMES_HOME=ambient), message="canonical")

    def test_refuses_when_the_data_dir_suffix_is_set(self):
        self.mark()
        self.assertRefused(
            self.start("--launch-profile", "lp", HERMES_DATA_DIR_SUFFIX="-x"),
            message="HERMES_DATA_DIR_SUFFIX",
        )

    def test_with_home_unset_the_passwd_home_is_still_guarded(self):
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            state=self.pw_home / ".hermes" / "dev-state",
            home="unset",
        )
        self.assertRefused(result)

    def test_with_home_unset_and_no_passwd_home_it_refuses_to_run(self):
        self.set_passwd_home("")
        self.mark()
        self.assertRefused(
            self.start("--launch-profile", "lp", home="unset"), message="HOME is unset"
        )

    def test_with_home_unset_and_a_failing_getent_it_refuses_to_run(self):
        (self.bin / "getent").write_text("#!/bin/sh\nexit 2\n")
        self.mark()
        self.assertRefused(
            self.start("--launch-profile", "lp", home="unset"), message="HOME is unset"
        )

    def test_with_home_set_the_passwd_home_is_guarded_too(self):
        self.mark()
        self.assertRefused(self.start(state=self.pw_home / ".hermes" / "dev-state"))

    # -- the property: refused, or outside the real home and nothing changed --

    def run_spelling(self, spelling):
        env = self.env(X=str(self.home / ".hermes"), HERMES_STUB_FAIL="1")
        env["HERMES_DEV_STATE_DIR"] = spelling
        # A log of its own, so runs in parallel do not mix their calls.
        log = self.tmp / f"calls-{abs(hash(spelling))}.log"
        env["HERMES_STUB_LOG"] = str(log)
        result = subprocess.run(
            ["bash", str(DEV_BACKEND), "start", "--launch-profile", "lp"],
            env=env,
            cwd=self.home,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return spelling, result, log.read_text() if log.exists() else ""

    def spellings(self, count, seed):
        rng = random.Random(seed)
        (self.tmp / "lnkh").symlink_to(self.home / ".hermes")
        (self.tmp / "lnkhome").symlink_to(self.home)
        (self.tmp / "lnkpw").symlink_to(self.pw_home)
        prefixes = [
            f"{self.tmp}/state-x",
            f"{self.tmp}/lnkh",
            f"{self.tmp}/lnkhome",
            f"{self.tmp}/lnkpw",
            str(self.home),
            str(self.pw_home),
            "~",
            "$HOME",
            "$X",
            "//",
            ".",
            "..",
            "`echo`",
            f"/{self.home}",
            f"//{self.tmp}",
            f"{self.tmp}/state",
        ]
        pieces = [
            "",
            "/",
            "//",
            ".",
            "..",
            "~",
            "$HOME",
            "$X",
            ".hermes",
            ".hermes-x",
            "dev",
            "nope",
            "lnkh",
            "lnkhome",
            "lnkpw",
            "`echo`",
        ]
        out = []
        for _ in range(count):
            text = rng.choice(prefixes)
            for _ in range(rng.randint(0, 5)):
                text += rng.choice(["/", "/", "//"]) + rng.choice(pieces)
            out.append(text)
        # The dangerous ones, so a seed can never leave them out.
        out += [
            f"{self.home}/.hermes/dev",
            f"/{self.home}/.hermes/dev",
            "~/.hermes/dev",
            "$HOME/.hermes/dev",
            "$X/dev",
            f"{self.tmp}/lnkh/dev",
            f"{self.tmp}/lnkhome/.hermes/dev",
            f"{self.home}/.hermes-x/dev",
        ]
        return out

    def test_every_spelling_is_refused_or_lands_outside_the_real_home(self):
        # Everything a run could add to a real home's `.hermes*`; the rest of
        # the fake homes is ordinary ground a state dir may use.
        def hermes_trees():
            return {
                str(home): {
                    child: snapshot(home / child)
                    for child in sorted(os.listdir(home))
                    if child.startswith(".hermes")
                }
                for home in (self.home, self.pw_home)
            }

        before = hermes_trees()
        spellings = self.spellings(120, seed=20261115)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(self.run_spelling, spellings))
        accepted = 0
        saved = {k: os.environ.get(k) for k in ("HOME", "X")}
        os.environ["HOME"], os.environ["X"] = str(self.home), str(self.home / ".hermes")
        try:
            for spelling, result, calls in results:
                if result.returncode == 3:
                    self.assertNotIn("lp", calls, spelling)
                    continue
                accepted += 1
                self.assertEqual(result.returncode, 1, (spelling, result.stderr))
                # What Hermes would make of it: expanduser(expandvars(...)).
                where = os.path.expanduser(os.path.expandvars(spelling))
                for home in (self.home, self.pw_home):
                    self.assertFalse(under_hermes_home(where, home), spelling)
                for line in calls.splitlines():
                    seen = line.split("HERMES_HOME=")[1].split(" SUDO_USER=")[0]
                    seen = os.path.expanduser(os.path.expandvars(seen))
                    for home in (self.home, self.pw_home):
                        self.assertFalse(
                            under_hermes_home(seen, home), (spelling, line)
                        )
        finally:
            for key, value in saved.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        self.assertGreater(
            accepted, 3, "no spelling was accepted: the test proves nothing"
        )
        self.assertLess(accepted, len(spellings) - 20, "almost nothing was refused")
        self.assertEqual(hermes_trees(), before, "the real home changed")

    # -- verify.sh's temp root ------------------------------------------------

    def verify_clean(self, home="set", tmp_root=None):
        env = self.env(home=home, HERMES_VERIFY_TMP=str(tmp_root or self.tmp / "state"))
        return subprocess.run(
            ["bash", str(VERIFY), "clean"],
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_verify_refuses_a_temp_root_inside_the_real_home(self):
        root = self.home / ".hermes" / "tmp"
        root.mkdir()
        result = self.verify_clean(tmp_root=root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real Hermes home", result.stderr)

    def test_verify_refuses_a_temp_root_inside_the_passwd_home_with_home_set(self):
        root = self.pw_home / ".hermes" / "tmp"
        root.mkdir()
        result = self.verify_clean(tmp_root=root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real Hermes home", result.stderr)

    def test_verify_refuses_a_temp_root_inside_the_passwd_home_with_home_unset(self):
        root = self.pw_home / ".hermes" / "tmp"
        root.mkdir()
        result = self.verify_clean(home="unset", tmp_root=root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real Hermes home", result.stderr)

    def test_verify_refuses_a_temp_root_named_dot_hermes_something(self):
        root = self.home / ".hermes-dev" / "tmp"
        root.mkdir(parents=True)
        result = self.verify_clean(tmp_root=root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real Hermes home", result.stderr)

    def test_verify_refuses_a_non_canonical_temp_root(self):
        for root in (f"/{self.tmp}/state", f"{self.tmp}//state", f"{self.tmp}/state/."):
            with self.subTest(root=root):
                result = self.verify_clean(tmp_root=root)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("canonical", result.stderr)

    def test_verify_refuses_to_run_with_no_home_at_all(self):
        self.set_passwd_home("")
        result = self.verify_clean(home="unset")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HOME is unset", result.stderr)

    def test_verify_accepts_an_ordinary_temp_root(self):
        self.assertEqual(self.verify_clean().returncode, 0)

    # -- names, options, repeated starts ---------------------------------------

    def test_names_hermes_reserves_never_reach_it(self):
        for name in (
            "default",
            "hermes",
            "root",
            "status",
            "Upper",
            "bad name",
            "../x",
        ):
            with self.subTest(name=name):
                result = self.start("--launch-profile", name)
                self.assertEqual(result.returncode, 2, result.stderr)
        result = self.start("--launch-profile", "lp", "--sticky-profile", "lp")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), "")

    def test_environment_variables_do_not_pick_a_launch_profile(self):
        result = self.start(
            HERMES_DEV_LAUNCH_PROFILE="stray", HERMES_DEV_STICKY_PROFILE="stray2"
        )
        # The stand-in dashboard exits 1; a bad option or name would be 2.
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("profile", self.calls())
        self.assertNotIn(" -p ", self.calls())

    def test_repeated_starts_on_one_state_dir(self):
        state = self.tmp / "state"
        both = ("--launch-profile", "lp", "--sticky-profile", "sp")
        self.start(*both)
        self.assertEqual((state / "home" / "active_profile").read_text().strip(), "sp")
        self.start(*both)
        self.assertEqual(self.calls().count("profile create lp"), 1)
        self.start("--launch-profile", "lp")
        self.assertFalse((state / "home" / "active_profile").exists())
        self.start()
        self.assertFalse((state / "home" / "active_profile").exists())
        last = self.calls().strip().splitlines()[-1]
        self.assertIn(":: dashboard ", last)
        self.assertNotIn(" -p ", last)

    def test_every_hermes_call_runs_with_a_throwaway_home_and_a_clean_environment(self):
        state = self.tmp / "state"
        for args in (("--launch-profile", "lp", "--sticky-profile", "sp"), ()):
            self.log.unlink(missing_ok=True)
            self.start(*args, SUDO_USER="someone")
            lines = self.calls().strip().splitlines()
            self.assertTrue(lines)
            for line in lines:
                self.assertIn(f"HOME={state}/userhome ", line, line)
                self.assertIn("SUDO_USER=<unset> ", line, line)
                self.assertIn("SUFFIX=<unset> ", line, line)
                self.assertIn(f"HERMES_HOME={state}/home ", line, line)


if __name__ == "__main__":
    unittest.main()

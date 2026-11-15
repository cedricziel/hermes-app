"""Checks scripts/dev-backend.sh start and scripts/verify.sh's temp-root check
without a real Hermes: a stand-in `hermes` on PATH records each call and lays
profiles out the way the real one does, in a fake HOME. Covers the refusal to
run where Hermes would write the real profiles (before any hermes call and
before anything is written, also through `..` segments and with HOME unset),
name validation, flags-only options, and starts repeated on one state dir.

Needs only bash and coreutils: no network, no hermes, no lsof, no curl.
"""

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEV_BACKEND = ROOT / "scripts" / "dev-backend.sh"
VERIFY = ROOT / "scripts" / "verify.sh"

STUB = """#!/usr/bin/env bash
echo "HOME=${HOME-<unset>} HERMES_HOME=${HERMES_HOME:-} :: $*" >>"$HERMES_STUB_LOG"
args=("$@")
[[ "${args[0]:-}" == -p ]] && args=("${args[@]:2}")
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


@unittest.skipUnless(sys.platform.startswith("linux"), "verify.sh is Linux only")
class DevBackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="dev-backend-test."))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.tmp = self.tmp.resolve()
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
        env.update(extra)
        return env

    def start(self, *args, state=None, home="set", **extra):
        env = self.env(home=home, **extra)
        env["HERMES_DEV_STATE_DIR"] = str(state or self.tmp / "state")
        return subprocess.run(
            ["bash", str(DEV_BACKEND), "start", *args],
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def assertRefusedBeforeAnything(self, result, *, tree=None, message="at or under"):
        before = self._before
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn(message, result.stderr)
        self.assertEqual(self.calls(), "", "hermes was called")
        self.assertEqual(snapshot(self.tmp), before, "something was written")

    def mark(self):
        """Records the tree, so a refusal can be shown to write nothing."""
        self._before = snapshot(self.tmp)

    def test_refuses_a_state_dir_under_the_real_home_before_any_hermes_call(self):
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            "--sticky-profile",
            "sp",
            state=self.home / ".hermes" / "dev-state",
        )
        self.assertRefusedBeforeAnything(result)
        self.assertEqual(
            (self.home / ".hermes" / "active_profile").read_text(), "real\n"
        )

    def test_refuses_a_plain_start_there_too(self):
        self.mark()
        result = self.start(state=self.home / ".hermes")
        self.assertRefusedBeforeAnything(result)

    def test_refuses_a_state_dir_under_an_ambient_hermes_home(self):
        ambient = self.tmp / "ambient"
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            state=ambient / "sub" / "state",
            HERMES_HOME=str(ambient),
        )
        self.assertRefusedBeforeAnything(result)
        self.assertFalse(ambient.exists())

    def test_refuses_dot_dot_through_a_missing_directory(self):
        (self.tmp / "w").mkdir()
        sneaky = f"{self.tmp}/w/nope/../../home/.hermes/dev"
        self.mark()
        result = self.start("--launch-profile", "lp", state=sneaky)
        self.assertRefusedBeforeAnything(result, message="..")
        self.assertFalse((self.tmp / "w" / "nope").exists())
        self.assertFalse((self.home / ".hermes" / "dev").exists())

    def test_refuses_dot_segments(self):
        for state in (
            f"{self.tmp}/./state",
            f"{self.tmp}/state/.",
            f"{self.tmp}/state/..",
        ):
            with self.subTest(state=state):
                self.mark()
                result = self.start(state=state)
                self.assertRefusedBeforeAnything(result, message="segment")

    def test_refuses_dot_dot_in_an_ambient_hermes_home(self):
        self.mark()
        result = self.start(HERMES_HOME=f"{self.tmp}/w/nope/../ambient")
        self.assertRefusedBeforeAnything(result, message="segment")

    def test_with_home_unset_the_passwd_home_is_still_guarded(self):
        self.mark()
        result = self.start(
            "--launch-profile",
            "lp",
            state=self.pw_home / ".hermes" / "dev-state",
            home="unset",
        )
        self.assertRefusedBeforeAnything(result)

    def test_with_home_unset_and_no_passwd_home_it_refuses_to_run(self):
        self.set_passwd_home("")
        self.mark()
        result = self.start("--launch-profile", "lp", home="unset")
        self.assertRefusedBeforeAnything(result, message="HOME is unset")

    def test_with_home_unset_and_a_failing_getent_it_refuses_to_run(self):
        getent = self.bin / "getent"
        getent.write_text("#!/bin/sh\nexit 2\n")
        self.mark()
        result = self.start("--launch-profile", "lp", home="unset")
        self.assertRefusedBeforeAnything(result, message="HOME is unset")

    def test_with_home_set_the_passwd_home_is_guarded_too(self):
        self.mark()
        result = self.start(state=self.pw_home / ".hermes" / "dev-state")
        self.assertRefusedBeforeAnything(result)

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

    def test_verify_refuses_a_temp_root_inside_the_passwd_home_with_home_unset(self):
        root = self.pw_home / ".hermes" / "tmp"
        root.mkdir()
        result = self.verify_clean(home="unset", tmp_root=root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real Hermes home", result.stderr)

    def test_verify_refuses_to_run_with_no_home_at_all(self):
        self.set_passwd_home("")
        result = self.verify_clean(home="unset")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HOME is unset", result.stderr)

    def test_verify_accepts_an_ordinary_temp_root(self):
        self.assertEqual(self.verify_clean().returncode, 0)

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

    def test_homes_the_hermes_calls_run_with(self):
        state = self.tmp / "state"
        self.start("--launch-profile", "lp", "--sticky-profile", "sp")
        lines = self.calls().strip().splitlines()
        for line in lines:
            # Profile commands and the launch-profile dashboard: a throwaway HOME.
            self.assertIn(f"HOME={state}/userhome ", line, line)
        self.log.unlink()
        self.start()
        # A plain start keeps the caller's HOME.
        self.assertIn(f"HOME={self.home} ", self.calls())


if __name__ == "__main__":
    unittest.main()

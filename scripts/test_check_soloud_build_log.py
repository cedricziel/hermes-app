import os
import subprocess
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "check-soloud-build-log.sh")
GOOD = "[flutter_soloud] Building on Linux (x64) with Xiph libs [disabled]\n"


def run(build_log, hook_stdout=None, hook_stderr="", extra_hook=None):
    """Runs the guard on a build log and the stdout of the flutter_soloud hook."""
    with tempfile.TemporaryDirectory() as tmp:
        log = os.path.join(tmp, "build.log")
        with open(log, "w") as f:
            f.write(build_log)
        hooks = os.path.join(tmp, "hooks", "flutter_soloud")
        for name, out in [("aaa", hook_stdout), ("bbb", extra_hook)]:
            if out is None:
                continue
            os.makedirs(os.path.join(hooks, name))
            with open(os.path.join(hooks, name, "stdout.txt"), "w") as f:
                f.write(out)
            with open(os.path.join(hooks, name, "stderr.txt"), "w") as f:
                f.write(hook_stderr)
        return subprocess.run(
            [SCRIPT, log, hooks], capture_output=True, text=True
        )


class CheckSoloudBuildLog(unittest.TestCase):
    def test_a_build_without_downloads_passes(self):
        result = run("Running Gradle\n✓ Built build/linux\n", GOOD)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_a_missing_line_fails(self):
        result = run("Running\n", "Running clang\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Building on Linux", result.stderr)

    def test_no_hook_output_at_all_fails(self):
        result = run("Running\n")
        self.assertNotEqual(result.returncode, 0)

    def test_xiph_libs_not_disabled_fails(self):
        result = run(
            "x\n", "[flutter_soloud] Building on Linux (x64) with Xiph libs [prebuilt]\n"
        )
        self.assertNotEqual(result.returncode, 0)

    def test_vst3_after_the_line_fails(self):
        result = run(
            "x\n",
            "[flutter_soloud] Building on Linux (x64) with Xiph libs [disabled], VST3 [prebuilt]\n",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("VST3", result.stderr)

    def test_other_architecture_passes(self):
        result = run(
            "x\n", "[flutter_soloud] Building on Linux (arm64) with Xiph libs [disabled]\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_every_forbidden_string_fails_in_each_place(self):
        for text in [
            "Downloading prebuild archive",
            "Extracting archive",
            "https://github.com/x/releases/download/v1/a.tar.gz",
            "Configuring ogg",
            "Configuring opus",
            "Configuring vorbis",
            "Configuring flac",
            "Cloning into 'opus'",
        ]:
            with self.subTest(text=text, where="build log"):
                self.assertNotEqual(run(text + "\n", GOOD).returncode, 0)
            with self.subTest(text=text, where="hook stdout"):
                self.assertNotEqual(run("x\n", GOOD + text + "\n").returncode, 0)
            with self.subTest(text=text, where="hook stderr"):
                self.assertNotEqual(run("x\n", GOOD, hook_stderr=text).returncode, 0)

    def test_a_stale_hook_run_with_a_download_fails_too(self):
        result = run("x\n", GOOD, extra_hook="Downloading prebuild archive\n")
        self.assertNotEqual(result.returncode, 0)

    def test_usage(self):
        result = subprocess.run([SCRIPT], capture_output=True, text=True)
        self.assertEqual(result.returncode, 64)

    def test_a_missing_log_fails(self):
        result = subprocess.run(
            [SCRIPT, "/nonexistent/build.log"], capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()

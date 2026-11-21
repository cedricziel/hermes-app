"""Runs the `Changes` job's classification script against real git merges."""

import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parent.parent / ".github/workflows/ci.yml"
RELEASE_REF = "release-please--branches--main--components--hermes-app"

PUBSPEC = "name: app\nversion: 1.0.0+1\ndependencies:\n  a: 1\n"


def filter_script():
    lines = WORKFLOW.read_text().splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "id: filter")
    run = next(i for i in range(start, len(lines)) if lines[i].strip() == "run: |")
    indent = len(lines[run]) - len(lines[run].lstrip())
    body = []
    for line in lines[run + 1 :]:
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        body.append(line)
    return textwrap.dedent("\n".join(body)) + "\n"


def git(cwd, *args):
    subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
    )


class ChangesFilterTest(unittest.TestCase):
    def classify(
        self,
        files,
        head_ref=RELEASE_REF,
        executable=(),
        head_repo="o/r",
        binary=(),
    ):
        """files: path -> content (None deletes). Returns the outputs dict."""
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            git(repo, "init", "-q", "-b", "main")
            base = {
                "CHANGELOG.md": "# Changes\n",
                ".release-please-manifest.json": '{".": "1.0.0"}\n',
                "pubspec.yaml": PUBSPEC,
                "lib/a.dart": "a\n",
            }
            for name, content in base.items():
                p = repo / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(content)
            git(repo, "add", ".")
            git(repo, "commit", "-q", "-m", "base")
            git(repo, "checkout", "-q", "-b", "pr")
            for name, content in files.items():
                p = repo / name
                if content is None:
                    p.unlink()
                else:
                    p.parent.mkdir(parents=True, exist_ok=True)
                    if name in binary:
                        p.write_bytes(b"\x00\x01\x02" + content.encode())
                    else:
                        p.write_text(content)
                    if name in executable:
                        p.chmod(0o755)
            git(repo, "add", "-A")
            git(repo, "commit", "-q", "-m", "pr")
            git(repo, "checkout", "-q", "main")
            # Main moves, so HEAD is a real two-parent merge like on GitHub.
            (repo / "other.txt").write_text("x\n")
            git(repo, "add", "other.txt")
            git(repo, "commit", "-q", "-m", "main moves")
            git(repo, "merge", "-q", "--no-ff", "-m", "merge", "pr")
            out = Path(tmp) / "out"
            summary = Path(tmp) / "summary"
            env = {
                **os.environ,
                "EVENT_NAME": "pull_request",
                "HEAD_REF": head_ref,
                "HEAD_REPO": head_repo,
                "BASE_REPO": "o/r",
                "GITHUB_OUTPUT": str(out),
                "GITHUB_STEP_SUMMARY": str(summary),
            }
            res = subprocess.run(
                ["bash", "-c", filter_script()],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            return dict(l.split("=", 1) for l in out.read_text().split())

    def release_files(self, **extra):
        files = {
            "CHANGELOG.md": "# Changes\n- x\n",
            ".release-please-manifest.json": '{".": "1.1.0"}\n',
            "pubspec.yaml": PUBSPEC.replace("1.0.0+1", "1.1.0+2"),
        }
        files.update(extra)
        return files

    def assertDocsOnly(self, out):
        self.assertEqual(out, {"code": "false", "watch": "false", "builds": "false"})

    def assertNormal(self, out):
        self.assertEqual(out["code"], "true")

    def test_exact_release_diff_is_docs_only(self):
        self.assertDocsOnly(self.classify(self.release_files()))

    def test_extra_file_is_normal(self):
        self.assertNormal(self.classify(self.release_files(**{"lib/a.dart": "b\n"})))

    def test_extra_native_file_still_triggers_builds(self):
        out = self.classify(self.release_files(**{"android/x.gradle": "x\n"}))
        self.assertEqual(out["builds"], "true")

    def test_pubspec_other_line_changed_too_is_normal(self):
        text = PUBSPEC.replace("1.0.0+1", "1.1.0+2").replace("a: 1", "a: 2")
        out = self.classify(self.release_files(**{"pubspec.yaml": text}))
        self.assertNormal(out)
        self.assertEqual(out["builds"], "true")

    def test_pubspec_extra_line_added_is_normal(self):
        text = PUBSPEC.replace("1.0.0+1", "1.1.0+2") + "  b: 1\n"
        self.assertNormal(self.classify(self.release_files(**{"pubspec.yaml": text})))

    def test_pubspec_non_version_line_only_is_normal(self):
        out = self.classify(
            {
                "CHANGELOG.md": "# Changes\n- x\n",
                ".release-please-manifest.json": '{".": "1.1.0"}\n',
                "pubspec.yaml": PUBSPEC.replace("a: 1", "a: 2"),
            }
        )
        self.assertNormal(out)

    def test_pubspec_version_and_removed_line_is_normal(self):
        text = PUBSPEC.replace("1.0.0+1", "1.1.0+2").replace("  a: 1\n", "")
        self.assertNormal(self.classify(self.release_files(**{"pubspec.yaml": text})))

    def test_deleted_file_is_normal(self):
        files = self.release_files()
        files["lib/a.dart"] = None
        self.assertNormal(self.classify(files))

    def test_deleted_release_file_is_normal(self):
        files = self.release_files()
        files[".release-please-manifest.json"] = None
        self.assertNormal(self.classify(files))

    def test_mode_change_is_normal(self):
        out = self.classify(self.release_files(), executable=("CHANGELOG.md",))
        self.assertNormal(out)

    def test_missing_pubspec_change_is_normal(self):
        files = self.release_files()
        del files["pubspec.yaml"]
        self.assertNormal(self.classify(files))

    def test_new_file_is_normal(self):
        self.assertNormal(self.classify(self.release_files(**{"NEW.txt": "x\n"})))

    def test_same_diff_from_other_branch_is_normal(self):
        out = self.classify(self.release_files(), head_ref="feature/x")
        self.assertNormal(out)
        self.assertEqual(out["builds"], "true")

    def test_branch_name_is_never_executed(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker = Path(tmp) / "pwned"
            ref = f'x"; touch {marker}; echo "$(touch {marker})`touch {marker}`'
            out = self.classify(self.release_files(), head_ref=ref)
            self.assertNormal(out)
            self.assertFalse(marker.exists())

    def test_fork_with_same_branch_and_exact_diff_is_normal(self):
        out = self.classify(self.release_files(), head_repo="fork/r")
        self.assertNormal(out)
        self.assertEqual(out["builds"], "true")

    def test_empty_head_repo_is_normal(self):
        self.assertNormal(self.classify(self.release_files(), head_repo=""))

    def test_renamed_code_file_is_normal(self):
        files = self.release_files(**{"lib/b.dart": "a\n"})
        files["lib/a.dart"] = None
        self.assertNormal(self.classify(files))

    def test_rename_onto_release_file_is_normal(self):
        files = self.release_files(**{"CHANGELOG.md": "a\n"})
        files["lib/a.dart"] = None
        self.assertNormal(self.classify(files))

    def test_rename_from_release_file_is_normal(self):
        files = self.release_files(**{"lib/c.md": "# Changes\n"})
        files["CHANGELOG.md"] = None
        self.assertNormal(self.classify(files))

    def test_pubspec_second_version_line_replacing_other_line_is_normal(self):
        text = "name: app\nversion: 1.0.0+1\ndependencies:\n  a: 1\n".replace(
            "dependencies:", "version: 2.0.0+1"
        )
        out = self.classify(self.release_files(**{"pubspec.yaml": text}))
        self.assertNormal(out)

    def test_binary_pubspec_is_normal(self):
        out = self.classify(
            self.release_files(**{"pubspec.yaml": "version: 1.1.0+2\n"}),
            binary=("pubspec.yaml",),
        )
        self.assertNormal(out)

    def test_pubspec_only_is_normal(self):
        files = self.release_files()
        del files["CHANGELOG.md"], files[".release-please-manifest.json"]
        self.assertNormal(self.classify(files))

    def test_pubspec_and_changelog_only_is_normal(self):
        files = self.release_files()
        del files[".release-please-manifest.json"]
        self.assertNormal(self.classify(files))

    def test_workflow_passes_branch_through_env(self):
        text = WORKFLOW.read_text()
        self.assertIn("HEAD_REF: ${{ github.head_ref }}", text)
        self.assertIn("HEAD_REPO: ${{ github.event.pull_request.head.repo.full_name }}", text)
        self.assertNotIn("github.head_ref", filter_script())
        self.assertNotIn("github.event.pull_request", filter_script())


if __name__ == "__main__":
    unittest.main()

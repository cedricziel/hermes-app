import os
import pathlib
import subprocess
import tempfile
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SHA = '71d34bad1045610252eda02ee79549436896e784'


class ContractRevision(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        workflow = (ROOT / '.github/workflows/update-hermes-contracts.yml').read_text()
        step = workflow.split('id: ref\n', 1)[1].split('\n      - name:', 1)[0]
        self.command = textwrap.dedent(step.split('run: ', 1)[1].removeprefix('|\n'))
        gh = self.root / 'gh'
        gh.write_text('''#!/usr/bin/env bash
set -eu
case "$2" in
  */releases/latest) printf '%s\\n' "${RELEASE_TAG:-v0.21.7}" ;;
  */commits/v0.21.7|*/commits/main|*/commits/71d34bad1045610252eda02ee79549436896e784)
    [ "${FAIL_COMMIT:-0}" = 0 ] || exit 1
    printf '%s\\n' "$COMMIT_SHA" ;;
  *) exit 1 ;;
esac
''')
        gh.chmod(0o755)
        self.output = self.root / 'output'
        self.output.touch()

    def resolve(self, override='', **extra):
        return subprocess.run(
            ['bash', '-e', '-o', 'pipefail', '-c', self.command],
            env={**os.environ, 'PATH': f'{self.root}:{os.environ["PATH"]}',
                 'GITHUB_OUTPUT': str(self.output), 'HERMES_REF_OVERRIDE': override,
                 'COMMIT_SHA': SHA, **extra},
            capture_output=True, text=True,
        )

    def test_automatic_update_resolves_stable_release_sha(self):
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), f'sha={SHA}\n')

    def test_manual_branch_override_bypasses_release_lookup(self):
        result = self.resolve('main', RELEASE_TAG='unusable')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), f'sha={SHA}\n')

    def test_manual_sha_override_resolves_commit(self):
        result = self.resolve(SHA, RELEASE_TAG='unusable')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), f'sha={SHA}\n')

    def test_failed_commit_lookup_writes_no_output(self):
        result = self.resolve(FAIL_COMMIT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), '')

    def test_invalid_commit_sha_writes_no_output(self):
        result = self.resolve(COMMIT_SHA='null')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), '')


if __name__ == '__main__':
    unittest.main()

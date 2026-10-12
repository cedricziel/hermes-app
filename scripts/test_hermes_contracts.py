import pathlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/hermes_contracts.py"
SHA = "167e9fdb84248cd0fff80762dc57b6a914b6e930"
NEXT_SHA = "a" * 40


class ContractProvenance(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        (self.root / "openapi").mkdir()
        (self.root / "openrpc").mkdir()
        (self.root / "openapi/HERMES_REF").write_text(SHA + "\n")
        (self.root / "openrpc/HERMES_REF").write_text(SHA + "\n")
        (self.root / "openapi/hermes-agent.openapi.json").write_text("{}\n")
        (self.root / "openrpc/hermes-gateway.openrpc.json").write_text("{}\n")

    def run_script(self, command, *arguments):
        return subprocess.run(
            [sys.executable, "-I", str(SCRIPT), command,
             "--root", str(self.root), *arguments],
            capture_output=True, text=True,
        )

    def commit_fixture(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(
            ["git", "-C", str(self.root), "-c", "user.name=Test",
             "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"],
            check=True,
        )

    def test_matching_provenance_resolves_committed_sha(self):
        result = self.run_script("resolve")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, SHA + "\n")

    def test_trailing_whitespace_does_not_change_provenance(self):
        (self.root / "openrpc/HERMES_REF").write_text(SHA + "\n\n ")
        result = self.run_script("resolve")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), SHA)

    def test_mismatch_rejects_backend_selection(self):
        (self.root / "openrpc/HERMES_REF").write_text(NEXT_SHA)
        result = self.run_script("resolve")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("provenance mismatch", result.stderr)

    def test_missing_provenance_rejects_backend_selection(self):
        (self.root / "openapi/HERMES_REF").unlink()
        result = self.run_script("resolve")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("openapi/HERMES_REF", result.stderr)

    def test_malformed_ref_rejects_backend_selection(self):
        (self.root / "openapi/HERMES_REF").write_text("main\n")
        result = self.run_script("resolve")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("40-character hexadecimal SHA", result.stderr)

    def test_provenance_only_update_needs_pr_without_client_generation(self):
        self.commit_fixture()
        (self.root / "openapi/HERMES_REF").write_text(NEXT_SHA + "\n")
        (self.root / "openrpc/HERMES_REF").write_text(NEXT_SHA + "\n")
        result = self.run_script("changes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed=true\n", result.stdout)
        self.assertIn("openapi_changed=false\n", result.stdout)
        self.assertIn("provenance_changed=true\n", result.stdout)

    def test_rest_update_needs_pr_and_client_generation(self):
        self.commit_fixture()
        (self.root / "openapi/hermes-agent.openapi.json").write_text('{"paths": {}}\n')
        (self.root / "openapi/HERMES_REF").write_text(NEXT_SHA + "\n")
        (self.root / "openrpc/HERMES_REF").write_text(NEXT_SHA + "\n")
        result = self.run_script("changes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed=true\n", result.stdout)
        self.assertIn("openapi_changed=true\n", result.stdout)

    def test_gateway_update_does_not_regenerate_rest_client(self):
        self.commit_fixture()
        (self.root / "openrpc/hermes-gateway.openrpc.json").write_text('{"methods": []}\n')
        result = self.run_script("changes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed=true\n", result.stdout)
        self.assertIn("openapi_changed=false\n", result.stdout)

    def test_unchanged_contracts_do_not_need_pr(self):
        self.commit_fixture()
        result = self.run_script("changes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed=false\n", result.stdout)

    def test_mismatched_update_fails_before_reporting_pr_flags(self):
        self.commit_fixture()
        (self.root / "openrpc/HERMES_REF").write_text(NEXT_SHA)
        result = self.run_script("changes")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("provenance mismatch", result.stderr)

    def test_workflow_resolution_failure_does_not_write_success_output(self):
        workflow = (ROOT / ".github/workflows/real-backend-contract.yml").read_text()
        step = workflow.split("name: Resolve contract provenance", 1)[1].split("\n      -", 1)[0]
        command = re.search(r"run: \|\n((?:          .*\n)+)", step + "\n").group(1)
        (self.root / "scripts").mkdir()
        shutil.copyfile(SCRIPT, self.root / "scripts/hermes_contracts.py")
        (self.root / "openrpc/HERMES_REF").write_text(NEXT_SHA)
        output = self.root / "github-output"
        output.touch()
        result = subprocess.run(
            ["bash", "-e", "-c", command], cwd=self.root,
            env={**os.environ, "GITHUB_OUTPUT": str(output)},
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("provenance mismatch", result.stderr)
        self.assertEqual(output.read_text(), "")

    def test_summary_distinguishes_setup_failure_from_test_result(self):
        result = self.run_script(
            "summary", "--provenance", "success", "--download", "success",
            "--install", "failure", "--start", "skipped", "--tests", "skipped",
            "--cleanup", "success",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(SHA, result.stdout)
        self.assertIn("Backend install | failure", result.stdout)
        self.assertIn("Contract suite | skipped", result.stdout)
        self.assertIn("HERMES_DEV_MODEL_CALLS | unset", result.stdout)
        self.assertIn("HERMES_DEV_TELEGRAM_PAIRING | unset", result.stdout)
        self.assertIn("Free loopback scripted-model turns", result.stdout)

    def test_failed_provenance_summary_does_not_claim_resolved_sha(self):
        (self.root / "openrpc/HERMES_REF").unlink()
        result = self.run_script("summary", "--provenance", "failure")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Resolved Hermes SHA | unavailable", result.stdout)
        self.assertIn("Provenance agreement | failure", result.stdout)


class ContractWorkflows(unittest.TestCase):
    def test_advisory_download_and_cache_use_resolved_provenance(self):
        workflow = (ROOT / ".github/workflows/real-backend-contract.yml").read_text()
        self.assertIn("scripts/hermes_contracts.py resolve", workflow)
        self.assertIn("hermes-web-${{ steps.ref.outputs.sha }}", workflow)
        self.assertIn('HERMES_REF: ${{ steps.ref.outputs.sha }}', workflow)
        self.assertNotIn("7b3c7aef31da73aabab0aa7fd15fdfe7c838834e", workflow)
        self.assertIn('"openapi/HERMES_REF"', workflow)
        self.assertIn('"openrpc/HERMES_REF"', workflow)

    def test_update_detection_uses_flags_and_retains_diff_checks(self):
        workflow = (ROOT / ".github/workflows/update-hermes-contracts.yml").read_text()
        self.assertIn("scripts/hermes_contracts.py changes", workflow)
        self.assertIn("if: steps.diff.outputs.openapi_changed == 'true'", workflow)
        self.assertIn("scripts/diff_gateway_contract.py", workflow)
        self.assertIn("scripts/diff_openapi_spec.py", workflow)
        self.assertIn("gateway_contract_test.dart", workflow)

    def test_summary_runs_after_cleanup_with_provider_flags_disabled(self):
        workflow = (ROOT / ".github/workflows/real-backend-contract.yml").read_text()
        self.assertIn("scripts/hermes_contracts.py summary", workflow)
        self.assertIn("--tests", workflow)
        self.assertIn("steps.tests.outcome", workflow)
        self.assertIn("steps.install.outcome", workflow)
        self.assertIn("steps.stop.outcome", workflow)
        self.assertIn("unset HERMES_DEV_MODEL_CALLS HERMES_DEV_TELEGRAM_PAIRING", workflow)
        self.assertLess(workflow.index("name: Stop the dev backend"),
                        workflow.index("scripts/hermes_contracts.py summary"))


if __name__ == "__main__":
    unittest.main()

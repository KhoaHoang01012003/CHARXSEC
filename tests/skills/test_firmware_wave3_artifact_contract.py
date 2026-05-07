import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "skills" / "firmware-artifact-contract" / "scripts" / "validate_artifact.py"
SCHEMA_DIR = ROOT / "skills" / "firmware-artifact-contract" / "references" / "schemas"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_wave3"


class FirmwareWave3ArtifactContractTests(unittest.TestCase):
    def run_validator(self, artifact_type: str, fixture_name: str, *, jsonl: bool = False) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(VALIDATOR),
            "--artifact-type",
            artifact_type,
            "--schema-dir",
            str(SCHEMA_DIR),
        ]
        if jsonl:
            command.append("--jsonl")
        command.append(str(FIXTURES / fixture_name))
        return subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_schema_files_exist_for_wave3_artifacts(self):
        expected = {
            "probe_plan.schema.json",
            "finding_record.schema.json",
            "verifier_report.schema.json",
        }
        existing = {path.name for path in SCHEMA_DIR.glob("*.schema.json")}
        self.assertTrue(expected.issubset(existing), existing)

    def test_valid_probe_plan_passes(self):
        result = self.run_validator("probe_plan", "valid_probe_plan.json")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid probe_plan", result.stdout)

    def test_valid_findings_jsonl_passes(self):
        result = self.run_validator("finding_record", "valid_findings.jsonl", jsonl=True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid finding_record", result.stdout)

    def test_cve_claim_requires_reproduction_and_verifier(self):
        result = self.run_validator("finding_record", "invalid_cve_claim_without_verifier.jsonl", jsonl=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("verifier_report", result.stderr + result.stdout)
        self.assertIn("reproduced", result.stderr + result.stdout)

    def test_valid_verifier_report_passes(self):
        result = self.run_validator("verifier_report", "valid_verifier_report.json")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid verifier_report", result.stdout)

    def test_verified_report_rejects_static_only_evidence(self):
        result = self.run_validator("verifier_report", "invalid_verified_static_only_report.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("live runtime or verified evidence", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()

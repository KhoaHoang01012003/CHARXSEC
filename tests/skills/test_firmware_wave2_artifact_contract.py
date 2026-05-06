import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "skills" / "firmware-artifact-contract" / "scripts" / "validate_artifact.py"
SCHEMA_DIR = ROOT / "skills" / "firmware-artifact-contract" / "references" / "schemas"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_wave2"


class FirmwareWave2ArtifactContractTests(unittest.TestCase):
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

    def test_schema_files_exist_for_wave2_artifacts(self):
        expected = {
            "observation_record.schema.json",
            "skill_context.schema.json",
            "code_browser_findings.schema.json",
            "reverse_queue.schema.json",
            "hook_plan.schema.json",
            "debug_plan.schema.json",
        }
        existing = {path.name for path in SCHEMA_DIR.glob("*.schema.json")}
        self.assertTrue(expected.issubset(existing), existing)

    def test_valid_observations_jsonl_passes(self):
        result = self.run_validator("observation_record", "valid_observations.jsonl", jsonl=True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid observation_record", result.stdout)

    def test_static_observation_cannot_claim_runtime_behavior(self):
        result = self.run_validator("observation_record", "invalid_static_behavior_claim.jsonl", jsonl=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("behavior_claim_allowed", result.stderr + result.stdout)

    def test_observation_requires_artifact_sensitivity(self):
        result = self.run_validator("observation_record", "invalid_missing_artifact_sensitivity.jsonl", jsonl=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("artifact_sensitivity", result.stderr + result.stdout)

    def test_valid_skill_context_passes(self):
        result = self.run_validator("skill_context", "valid_skill_context.json")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid skill_context", result.stdout)


if __name__ == "__main__":
    unittest.main()

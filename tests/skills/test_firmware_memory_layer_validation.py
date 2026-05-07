import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "skills" / "firmware-memory-layer" / "scripts" / "validate_memory.py"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_memory_layer"


class FirmwareMemoryLayerValidationTests(unittest.TestCase):
    def run_validator(self, fixture_name: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), str(FIXTURES / fixture_name)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_valid_service_memory_passes(self):
        result = self.run_validator("valid_service_memory.md")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid memory", result.stdout)

    def test_secret_like_memory_fails(self):
        result = self.run_validator("invalid_secret_memory.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("secret-like material", result.stderr + result.stdout)

    def test_missing_evidence_fails(self):
        result = self.run_validator("invalid_missing_evidence_memory.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source_artifacts or source_urls", result.stderr + result.stdout)

    def test_behavior_truth_requires_live_or_verified_evidence(self):
        result = self.run_validator("invalid_behavior_claim_memory.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("live runtime or verified evidence", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()

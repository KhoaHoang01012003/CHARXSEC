import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "skills" / "firmware-artifact-contract" / "scripts" / "validate_artifact.py"
SCHEMA_DIR = ROOT / "skills" / "firmware-artifact-contract" / "references" / "schemas"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_wave1"


class FirmwareArtifactContractTests(unittest.TestCase):
    def run_validator(self, artifact_type: str, fixture_name: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "--artifact-type",
                artifact_type,
                "--schema-dir",
                str(SCHEMA_DIR),
                str(FIXTURES / fixture_name),
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_schema_files_exist_for_wave1_artifacts(self):
        expected = {
            "common.schema.json",
            "firmware_manifest.schema.json",
            "model_research.schema.json",
            "rootfs_profile.schema.json",
            "runtime_profile.schema.json",
            "service_readiness.schema.json",
            "api_smoke_results.schema.json",
        }
        existing = {path.name for path in SCHEMA_DIR.glob("*.schema.json")}
        self.assertTrue(expected.issubset(existing), existing)

    def test_valid_firmware_manifest_passes(self):
        result = self.run_validator("firmware_manifest", "valid_firmware_manifest.json")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("valid", result.stdout)

    def test_missing_schema_version_fails(self):
        result = self.run_validator("firmware_manifest", "invalid_missing_schema_version.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("schema_version", result.stderr + result.stdout)

    def test_ready_service_readiness_passes(self):
        result = self.run_validator("service_readiness", "valid_service_readiness_ready.json")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_http_500_service_readiness_fails(self):
        result = self.run_validator("service_readiness", "invalid_service_readiness_500.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 500", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()

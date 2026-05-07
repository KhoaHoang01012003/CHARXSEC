import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
PHASE_SKILLS = [
    "firmware-model-research",
    "firmware-rootfs-profiling",
    "firmware-service-emulating",
    "firmware-code-browsing",
    "firmware-runtime-hooking",
    "firmware-debugging",
    "firmware-probing-sandbox",
    "firmware-cve-verification",
]


class FirmwareMemoryLayerIntegrationTests(unittest.TestCase):
    def test_phase_skills_reference_memory_layer(self):
        for skill in PHASE_SKILLS:
            text = (SKILLS / skill / "SKILL.md").read_text(encoding="utf-8")
            with self.subTest(skill=skill):
                self.assertIn("## Memory Layer", text)
                self.assertIn("firmware-memory-layer", text)
                self.assertIn("suggest_memory.py", text)
                self.assertIn("read_now", text)
                self.assertIn("drafts", text)
                self.assertIn("do not promote memory without validation", text)

    def test_intake_skill_is_not_forced_to_use_memory_before_artifacts_exist(self):
        text = (SKILLS / "firmware-intake-extracting" / "SKILL.md").read_text(encoding="utf-8")
        self.assertNotIn("## Memory Layer", text)


if __name__ == "__main__":
    unittest.main()

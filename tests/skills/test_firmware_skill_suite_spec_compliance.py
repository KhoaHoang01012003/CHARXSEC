import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
ALL_SKILLS = [
    "firmware-artifact-contract",
    "firmware-intake-extracting",
    "firmware-model-research",
    "firmware-rootfs-profiling",
    "firmware-service-emulating",
    "firmware-code-browsing",
    "firmware-runtime-hooking",
    "firmware-debugging",
    "firmware-probing-sandbox",
    "firmware-cve-verification",
]


def read_skill(name: str) -> str:
    return (SKILLS / name / "SKILL.md").read_text(encoding="utf-8")


class FirmwareSkillSuiteSpecComplianceTests(unittest.TestCase):
    def test_all_specified_skills_exist(self):
        for name in ALL_SKILLS:
            with self.subTest(name=name):
                self.assertTrue((SKILLS / name / "SKILL.md").exists())
                self.assertTrue((SKILLS / name / "agents" / "openai.yaml").exists())

    def test_all_skills_state_safety_and_authorization_rules(self):
        required_phrases = [
            "authorized to test",
            "destructive probes disabled by default",
            "record runtime modifications",
            "redacted summaries",
            "exact dates and versions",
            "do not install tools without explicit user approval",
        ]
        for name in ALL_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for phrase in required_phrases:
                    self.assertIn(phrase, text)

    def test_approved_option_has_no_orchestrator_skill(self):
        self.assertFalse((SKILLS / "firmware-auto-pentest-orchestrator").exists())

    def test_skills_are_not_charx_specific(self):
        for name in ALL_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                self.assertNotIn("CHARX", text.upper())


if __name__ == "__main__":
    unittest.main()

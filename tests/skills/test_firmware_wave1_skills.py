import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
WAVE1_SKILLS = [
    "firmware-intake-extracting",
    "firmware-model-research",
    "firmware-rootfs-profiling",
    "firmware-service-emulating",
]


def read_skill(name: str) -> str:
    return (SKILLS / name / "SKILL.md").read_text(encoding="utf-8")


class FirmwareWave1SkillTests(unittest.TestCase):
    def test_wave1_skills_exist(self):
        for name in WAVE1_SKILLS:
            with self.subTest(name=name):
                self.assertTrue((SKILLS / name / "SKILL.md").exists())
                self.assertTrue((SKILLS / name / "agents" / "openai.yaml").exists())

    def test_frontmatter_has_trigger_description(self):
        for name in WAVE1_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                self.assertRegex(text, r"^---\nname: " + re.escape(name) + r"\n", text)
                description = re.search(r"description: (.+)\n---", text, re.DOTALL)
                self.assertIsNotNone(description)
                self.assertIn("Use when", description.group(1))

    def test_no_template_scaffolding_text(self):
        forbidden = ["TO" + "DO", "PLACE" + "HOLDER", "Structuring This Skill", "Replace with"]
        for name in WAVE1_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for token in forbidden:
                    self.assertNotIn(token, text)

    def test_required_sections_exist(self):
        required_sections = [
            "## Overview",
            "## Required Superpowers",
            "## Inputs",
            "## Workflow",
            "## Outputs",
            "## Verification Gate",
            "## Common Mistakes",
        ]
        for name in WAVE1_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for section in required_sections:
                    self.assertIn(section, text)

    def test_skills_reference_artifact_contract_and_safety(self):
        required_phrases = [
            "firmware-artifact-contract",
            "schema_version",
            "behavior_claim_allowed",
            "Do not commit firmware",
            "verification-before-completion",
        ]
        for name in WAVE1_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for phrase in required_phrases:
                    self.assertIn(phrase, text)

    def test_emulating_skill_blocks_http_500(self):
        text = read_skill("firmware-service-emulating")
        self.assertIn("HTTP 500", text)
        self.assertIn("emulation_blocker.json", text)
        self.assertIn("systematic-debugging", text)
        self.assertIn("ready_for_pentest=true", text)


if __name__ == "__main__":
    unittest.main()

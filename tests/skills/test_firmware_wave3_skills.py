import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
WAVE3_SKILLS = [
    "firmware-probing-sandbox",
    "firmware-cve-verification",
]


def read_skill(name: str) -> str:
    return (SKILLS / name / "SKILL.md").read_text(encoding="utf-8")


class FirmwareWave3SkillTests(unittest.TestCase):
    def test_wave3_skills_exist(self):
        for name in WAVE3_SKILLS:
            with self.subTest(name=name):
                self.assertTrue((SKILLS / name / "SKILL.md").exists())
                self.assertTrue((SKILLS / name / "agents" / "openai.yaml").exists())

    def test_frontmatter_has_trigger_description(self):
        for name in WAVE3_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                self.assertRegex(text, r"^---\nname: " + re.escape(name) + r"\n", text)
                description = re.search(r"description: (.+)\n---", text, re.DOTALL)
                self.assertIsNotNone(description)
                self.assertIn("Use when", description.group(1))

    def test_no_template_scaffolding_text(self):
        forbidden = ["TO" + "DO", "PLACE" + "HOLDER", "Structuring This Skill", "Replace with"]
        for name in WAVE3_SKILLS:
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
            "## Safety",
            "## Common Mistakes",
        ]
        for name in WAVE3_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for section in required_sections:
                    self.assertIn(section, text)

    def test_common_contract_and_safety_phrases(self):
        required_phrases = [
            "firmware-artifact-contract",
            "schema_version",
            "behavior_claim_allowed",
            "Do not commit firmware",
            "verification-before-completion",
            "missing_tool",
            "local evidence",
        ]
        for name in WAVE3_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for phrase in required_phrases:
                    self.assertIn(phrase, text)

    def test_probing_sandbox_skill_has_safe_probe_guardrails(self):
        text = read_skill("firmware-probing-sandbox")
        for phrase in [
            "Python sandbox",
            "no network by default",
            "sandbox_generated",
            "behavior_claim_allowed=false",
            "probe_plan.json",
            "destructive actions require explicit user authorization",
            "superpowers:brainstorming",
        ]:
            self.assertIn(phrase, text)

    def test_cve_verification_skill_has_claim_guardrails(self):
        text = read_skill("firmware-cve-verification")
        for phrase in [
            "verifier_report.json",
            "findings.jsonl",
            "CVE candidate",
            "Do not claim CVE assignment",
            "duplicate",
            "NVD",
            "CISA KEV",
            "disclosure_status",
            "verified",
            "unverified",
            "blocked",
        ]:
            self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()

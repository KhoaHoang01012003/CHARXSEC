import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
WAVE2_SKILLS = [
    "firmware-code-browsing",
    "firmware-runtime-hooking",
    "firmware-debugging",
]


def read_skill(name: str) -> str:
    return (SKILLS / name / "SKILL.md").read_text(encoding="utf-8")


class FirmwareWave2SkillTests(unittest.TestCase):
    def test_wave2_skills_exist(self):
        for name in WAVE2_SKILLS:
            with self.subTest(name=name):
                self.assertTrue((SKILLS / name / "SKILL.md").exists())
                self.assertTrue((SKILLS / name / "agents" / "openai.yaml").exists())

    def test_frontmatter_has_trigger_description(self):
        for name in WAVE2_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                self.assertRegex(text, r"^---\nname: " + re.escape(name) + r"\n", text)
                description = re.search(r"description: (.+)\n---", text, re.DOTALL)
                self.assertIsNotNone(description)
                self.assertIn("Use when", description.group(1))

    def test_no_template_scaffolding_text(self):
        forbidden = ["TO" + "DO", "PLACE" + "HOLDER", "Structuring This Skill", "Replace with"]
        for name in WAVE2_SKILLS:
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
        for name in WAVE2_SKILLS:
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
        for name in WAVE2_SKILLS:
            text = read_skill(name)
            with self.subTest(name=name):
                for phrase in required_phrases:
                    self.assertIn(phrase, text)

    def test_code_browsing_skill_has_semantic_engine_guardrails(self):
        text = read_skill("firmware-code-browsing")
        for phrase in ["CodeQL", "Semgrep", "Joern", "binary-map", "reverse_queue.json", "behavior_claim_allowed=false"]:
            self.assertIn(phrase, text)

    def test_runtime_hooking_skill_has_live_capture_guardrails(self):
        text = read_skill("firmware-runtime-hooking")
        for phrase in ["strace", "tcpdump", "Frida", "bpftrace", "Qiling only as a separate instrumentation lane", "host-level", "guest-level", "redact"]:
            self.assertIn(phrase, text)

    def test_debugging_skill_has_debugger_semantics(self):
        text = read_skill("firmware-debugging")
        for phrase in ["GDB", "gdbserver", "QEMU user/system gdbstub", "host QEMU attach", "guest breakpoints", "debug_plan.json"]:
            self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()

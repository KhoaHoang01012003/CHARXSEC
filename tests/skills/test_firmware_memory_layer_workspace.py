import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT / "firmware-agent-workspace"


class FirmwareMemoryLayerWorkspaceTests(unittest.TestCase):
    def test_workspace_skeleton_exists(self):
        for relative in [
            "agent_helpers.py",
            "memory-index.json",
            "product-skills",
            "service-skills",
            "tool-skills",
            "drafts",
        ]:
            with self.subTest(relative=relative):
                self.assertTrue((WORKSPACE / relative).exists())

    def test_initial_index_is_empty_and_valid_shape(self):
        data = json.loads((WORKSPACE / "memory-index.json").read_text(encoding="utf-8"))
        self.assertEqual(data["schema_version"], "1.0.0")
        self.assertEqual(data["memories"], [])


if __name__ == "__main__":
    unittest.main()

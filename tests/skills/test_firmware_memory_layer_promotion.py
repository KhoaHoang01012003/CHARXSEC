import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "skills" / "firmware-memory-layer" / "scripts" / "promote_memory.py"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_memory_layer"


class FirmwareMemoryLayerPromotionTests(unittest.TestCase):
    def test_promote_valid_tool_draft_updates_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "workspace"
            shutil.copytree(FIXTURES / "promotion_workspace", workspace)
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--workspace",
                    str(workspace),
                    "--draft",
                    str(workspace / "drafts" / "qemu-user-common-blockers.md"),
                ],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            promoted = workspace / "tool-skills" / "qemu-user" / "qemu-user-common-blockers.md"
            self.assertTrue(promoted.exists())
            index = json.loads((workspace / "memory-index.json").read_text(encoding="utf-8"))
            paths = [item["path"] for item in index["memories"]]
            self.assertIn("tool-skills/qemu-user/qemu-user-common-blockers.md", paths)


if __name__ == "__main__":
    unittest.main()

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "skills" / "firmware-memory-layer" / "scripts" / "suggest_memory.py"
FIXTURES = ROOT / "tests" / "fixtures" / "firmware_memory_layer"
WORKSPACE = FIXTURES / "suggestion_workspace"


class FirmwareMemoryLayerSuggestionTests(unittest.TestCase):
    def test_suggest_memory_ranks_relevant_service_and_tool_memories(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "memory_suggestions.json"
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--workspace",
                    str(WORKSPACE),
                    "--rootfs-profile",
                    str(FIXTURES / "suggestion_rootfs_profile.json"),
                    "--service-graph",
                    str(FIXTURES / "suggestion_service_graph.json"),
                    "--runtime-profile",
                    str(FIXTURES / "suggestion_runtime_profile.json"),
                    "--output",
                    str(output),
                ],
                cwd=ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            data = json.loads(output.read_text(encoding="utf-8"))
        paths = [item["memory_path"] for item in data["suggestions"]]
        self.assertIn("service-skills/rauc/update-flow.md", paths)
        self.assertIn("tool-skills/qemu-user/common-blockers.md", paths)
        self.assertNotIn("service-skills/mqtt/broker-routing.md", paths)
        recommendations = {item["memory_path"]: item["load_recommendation"] for item in data["suggestions"]}
        self.assertEqual(recommendations["service-skills/rauc/update-flow.md"], "read_now")


if __name__ == "__main__":
    unittest.main()
